import '../models/combat_recommendation.dart';
import '../models/enemy.dart';
import '../models/equipment.dart';
import '../data/effect_catalog.dart';
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
    if (enemy.game != 'g2' || _cannotBeRecommended(enemy)) return const [];
    final underwaterOnly = _isUnderwaterTarget(enemy.id);
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
      if (underwaterOnly && !_isUnderwaterWeapon(profile.id, weapon)) {
        continue;
      }
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
      // Ranged launchers with verified compatible ammunition are never
      // recommended unloaded. This includes the harpoon and Splinter Cannon.
      final ammoOptions = compatibleAmmo.isEmpty
          ? const <ProjectileItem?>[null]
          : compatibleAmmo.cast<ProjectileItem?>();
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
    final target = profile.tierTargets
        .where((value) => value.tier == tier)
        .firstOrNull;
    final state = _comboDamage(profile.attacks, target?.damageBonus ?? 0);
    return CombatDamageState(
      damage: state.damage,
      physical: state.physical,
      element: state.element,
      stun: state.stun,
      poise: state.poise,
      statuses: state.statuses,
    );
  }

  /// A melee profile stores the successive normal strikes in its combo.
  /// Score their extracted base damage together so a bow's single projectile
  /// is not compared with only one hit from a three-strike weapon. A profile
  /// that has no normal hit remains safely represented by its best verified
  /// attack state instead.
  CombatDamageState _comboDamage(
    List<CombatAttackProfile> attacks,
    double tierDamageBonus,
  ) {
    final states = attacks
        .map(
          (attack) => attack.base.damage == null
              ? _bestAttackState(attack)
              : attack.base,
        )
        .toList(growable: false);
    final known = states.where((state) => state.damage != null).toList();
    if (known.isEmpty) return const CombatDamageState();
    final physical = known.first.physical;
    final element = known.first.element;
    // Mixed attack types cannot be reduced to one resistance calculation;
    // retain the best independently resolvable state rather than inventing a
    // combined damage type.
    if (known.any(
      (state) => state.physical != physical || state.element != element,
    )) {
      return known.reduce(
        (a, b) => (a.damage ?? -1) >= (b.damage ?? -1) ? a : b,
      );
    }
    return CombatDamageState(
      damage: known.fold<double>(
        0,
        (sum, state) => sum + state.damage! + tierDamageBonus,
      ),
      physical: physical,
      element: element,
      stun: known.fold<double>(0, (sum, state) => sum + (state.stun ?? 0)),
      poise: known.fold<double>(0, (sum, state) => sum + (state.poise ?? 0)),
      statuses: {
        for (final state in known) ...state.statuses,
      }.toList(growable: false),
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
      if (enemy.resistancesV2.any(
        (value) =>
            canonicalEffectId(value.type) ==
            normalizedTechnicalEffectId(status),
      ))
        RecommendationReason(
          RecommendationReasonKind.resistance,
          normalizedTechnicalEffectId(status),
          positive: false,
        )
      else
        RecommendationReason(
          RecommendationReasonKind.status,
          status,
          positive: true,
        ),
  ];

  int _compare(CombatRecommendation a, CombatRecommendation b) {
    final aResistedProjectile = _isResistedProjectile(a);
    final bResistedProjectile = _isResistedProjectile(b);
    if (aResistedProjectile != bResistedProjectile) {
      return aResistedProjectile ? 1 : -1;
    }
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

  bool _isResistedProjectile(CombatRecommendation value) =>
      value.loadout.projectile != null &&
      (value.damage.effectiveness == EffectivenessLevel.weak ||
          value.damage.effectiveness == EffectivenessLevel.ineffective ||
          value.damage.immune ||
          value.reasons.any(
            (reason) => reason.kind == RecommendationReasonKind.resistance,
          ));

  static const _nonCombatantIds = {
    'g2_crow',
    'g2_garter_snake',
    'g2_termite_queen',
  };

  static bool _cannotBeRecommended(Enemy enemy) =>
      !enemy.isKillable ||
      enemy.buggyProfile != null ||
      _nonCombatantIds.contains(enemy.id) ||
      enemy.id.startsWith('g2_koi_');

  static const _underwaterIds = {
    'g2_tadpole',
    'g2_diving_bell_spider',
    'g2_ogre_diving_bell_spider',
    'g2_toe_biter_leviathan',
    'g2_ogrr_toe_biter_leviathan',
    'g2_water_boatman',
    'g2_pond_jockey',
    'g2_ancient_pond_jockey',
  };

  static bool _isUnderwaterTarget(String id) => _underwaterIds.contains(id);

  static bool _isUnderwaterWeapon(String id, EquipmentItem weapon) =>
      id == 'Harpoon' ||
      id == 'TridentBone' ||
      weapon.normalizedSubtype == 'spear';

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
