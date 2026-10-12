import '../models/combat_recommendation.dart';
import '../models/enemy.dart';
import '../models/equipment.dart';
import 'damage_calculation_engine.dart';

class RecommendationEngine {
  final CombatRecommendationCatalog combat;
  final EquipmentCatalog equipment;
  late final DamageCalculationEngine _damage = DamageCalculationEngine(
    combat.thresholds,
  );

  RecommendationEngine({required this.combat, required this.equipment});

  List<CombatRecommendation> recommend(
    Enemy enemy, {
    CreatureInfusion? infusion,
  }) {
    if (enemy.game != 'g2') return const [];
    final items = {for (final item in equipment.items) item.id: item};
    final bestShield = combat.shields
        .where((shield) => items.containsKey(shield.id))
        .fold<CombatShieldProfile?>(null, (best, value) {
          if (best == null) return value;
          final current = value.blockDamageMultiplier ?? 1;
          final previous = best.blockDamageMultiplier ?? 1;
          return current < previous ? value : best;
        });
    final out = <CombatRecommendation>[];
    for (final profile in combat.weapons) {
      final weapon = items[profile.id];
      if (weapon == null || profile.attacks.isEmpty) continue;
      final tiers = <int>[
        profile.tier,
        ...profile.tierTargets.map((value) => value.tier),
      ];
      final routes = profile.routes.isEmpty
          ? const <EnhancementRouteOutcome?>[null]
          : profile.routes.cast<EnhancementRouteOutcome?>();
      final compatibleAmmo = combat.projectiles
          .where((projectile) => projectile.launcherIds.contains(profile.id))
          .toList(growable: false);
      // A launcher can be useful without a compatible consumable in the
      // current source snapshot. Keep its neutral build and let the damage
      // engine rank projectiles on their actual type instead of forcing every
      // launcher into the recommendation list.
      final ammoOptions = <ProjectileItem?>[null, ...compatibleAmmo];
      for (final tier in tiers) {
        for (final route in routes) {
          for (final projectile in ammoOptions) {
            final base = _bestDamage(profile, route, projectile, tier);
            final family = weapon.normalizedSubtype;
            final damage = _damage.calculate(
              enemy: enemy,
              baseDamage: base.damage,
              physical: base.physical,
              element: base.element,
              weaponFamily: family,
              additionalWeaknesses: [
                ...?infusion?.elementalWeaknesses,
                ...?infusion?.damageWeaknesses,
              ],
              additionalResistances: infusion?.resistances ?? const [],
            );
            final buildTier = [
              tier,
              projectile?.tier ?? 0,
            ].reduce((a, b) => a > b ? a : b);
            final reasons = _reasons(enemy, damage, base.statuses);
            final plain = CombatLoadout(
              weapon: weapon,
              profile: profile,
              buildTier: buildTier,
              enhancementLevel: route?.maxLevel ?? 0,
              route: route,
              projectile: projectile,
              flavor: base.element,
            );
            out.add(
              CombatRecommendation(
                loadout: plain,
                damage: damage,
                reasons: reasons,
              ),
            );
            if (profile.shieldCompatible && bestShield != null) {
              final shield = items[bestShield.id];
              if (shield != null) {
                final shieldTier = buildTier > bestShield.tier
                    ? buildTier
                    : bestShield.tier;
                out.add(
                  CombatRecommendation(
                    loadout: CombatLoadout(
                      weapon: weapon,
                      profile: profile,
                      buildTier: shieldTier,
                      enhancementLevel: route?.maxLevel ?? 0,
                      route: route,
                      projectile: projectile,
                      shield: shield,
                      flavor: base.element,
                    ),
                    damage: damage,
                    reasons: [
                      ...reasons,
                      const RecommendationReason(
                        RecommendationReasonKind.shield,
                        'shield',
                        positive: true,
                      ),
                    ],
                    defensiveUtility:
                        1 - (bestShield.blockDamageMultiplier ?? 1),
                  ),
                );
              }
            }
          }
        }
      }
    }
    out.sort(_compare);
    return _deduplicate(out);
  }

  CombatDamageState _bestDamage(
    CombatWeaponProfile profile,
    EnhancementRouteOutcome? route,
    ProjectileItem? projectile,
    int tier,
  ) {
    if (projectile != null) return _bestAttackState(projectile.attack);
    if (route != null && route.attacks.isNotEmpty) {
      final best = route.attacks.reduce(
        (a, b) =>
            (a.projectedDamage ?? -1) >= (b.projectedDamage ?? -1) ? a : b,
      );
      final target = profile.tierTargets
          .where((value) => value.tier == tier)
          .firstOrNull;
      return CombatDamageState(
        damage: best.projectedDamage == null
            ? null
            : best.projectedDamage! + (target?.damageBonus ?? 0),
        physical: best.physical,
        element: best.element,
      );
    }
    final state = profile.attacks
        .map(_bestAttackState)
        .reduce((a, b) => (a.damage ?? -1) >= (b.damage ?? -1) ? a : b);
    final target = profile.tierTargets
        .where((value) => value.tier == tier)
        .firstOrNull;
    return CombatDamageState(
      damage: state.damage == null
          ? null
          : state.damage! + (target?.damageBonus ?? 0),
      physical: state.physical,
      element: state.element,
      stun: state.stun,
      poise: state.poise,
      statuses: state.statuses,
    );
  }

  CombatDamageState _bestAttackState(CombatAttackProfile attack) => [
    attack.base,
    attack.charged,
    attack.perfect,
  ].reduce((a, b) => (a.damage ?? -1) >= (b.damage ?? -1) ? a : b);

  List<RecommendationReason> _reasons(
    Enemy enemy,
    DamageCalculationResult damage,
    List<String> statuses,
  ) => [
    for (final type in damage.appliedTypes)
      if ([
        ...enemy.damageWeaknesses,
        ...enemy.elementalWeaknesses,
      ].any((value) => value.type == type))
        RecommendationReason(
          RecommendationReasonKind.weakness,
          type,
          positive: true,
        )
      else if (enemy.resistancesV2.any((value) => value.type == type))
        RecommendationReason(
          RecommendationReasonKind.resistance,
          type,
          positive: false,
        ),
    if (damage.immune)
      const RecommendationReason(
        RecommendationReasonKind.immunity,
        'immune',
        positive: false,
      ),
    for (final zone in damage.zones.where(
      (value) => value.compatible && value.modifier > 1,
    ))
      RecommendationReason(
        RecommendationReasonKind.weakPoint,
        zone.part,
        positive: true,
      ),
    for (final status in statuses)
      RecommendationReason(
        RecommendationReasonKind.status,
        status,
        positive: true,
      ),
  ];

  int _compare(CombatRecommendation a, CombatRecommendation b) {
    final best = (b.damage.bestDamage ?? -1).compareTo(
      a.damage.bestDamage ?? -1,
    );
    if (best != 0) return best;
    final general = (b.damage.generalDamage ?? -1).compareTo(
      a.damage.generalDamage ?? -1,
    );
    if (general != 0) return general;
    final statusesB = b.reasons
        .where((value) => value.kind == RecommendationReasonKind.status)
        .length;
    final statusesA = a.reasons
        .where((value) => value.kind == RecommendationReasonKind.status)
        .length;
    final statuses = statusesB.compareTo(statusesA);
    if (statuses != 0) return statuses;
    return b.defensiveUtility.compareTo(a.defensiveUtility);
  }

  List<CombatRecommendation> _deduplicate(List<CombatRecommendation> values) {
    final seen = <String>{};
    return values
        .where((value) {
          final loadout = value.loadout;
          final key =
              '${loadout.weapon.id}|${loadout.buildTier}|${loadout.route?.tag}|${loadout.projectile?.id}|${loadout.shield?.id}';
          return seen.add(key);
        })
        .toList(growable: false);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
