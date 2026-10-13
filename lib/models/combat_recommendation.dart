import 'equipment.dart';

enum EffectivenessLevel {
  unknown,
  ineffective,
  weak,
  neutral,
  strong,
  excellent,
}

class CombatDamageState {
  final double? damage;
  final double? damagePerSecond;
  final String? physical;
  final String? element;
  final double? stun;
  final double? poise;
  final List<String> statuses;

  const CombatDamageState({
    this.damage,
    this.damagePerSecond,
    this.physical,
    this.element,
    this.stun,
    this.poise,
    this.statuses = const [],
  });

  factory CombatDamageState.fromJson(Map<String, dynamic> json) =>
      CombatDamageState(
        damage: (json['damage'] as num?)?.toDouble(),
        damagePerSecond: (json['damagePerSecond'] as num?)?.toDouble(),
        physical: json['physical']?.toString(),
        element: json['element']?.toString(),
        stun: (json['stun'] as num?)?.toDouble(),
        poise: (json['poise'] as num?)?.toDouble(),
        statuses: List<String>.from(json['statuses'] as List? ?? const []),
      );
}

class CombatAttackProfile {
  final String? row;
  final CombatDamageState base;
  final CombatDamageState charged;
  final CombatDamageState perfect;
  final double? stamina;
  final double? intervalSeconds;

  /// Confirmed charge duration. This is used as a nominal shot cadence only
  /// when the source has no hit-to-hit combo interval (for example, ammo).
  final double? chargeTime;

  const CombatAttackProfile({
    this.row,
    required this.base,
    required this.charged,
    required this.perfect,
    this.stamina,
    this.intervalSeconds,
    this.chargeTime,
  });

  factory CombatAttackProfile.fromJson(Map<String, dynamic> json) =>
      CombatAttackProfile(
        row: json['row']?.toString(),
        base: CombatDamageState.fromJson(
          (json['base'] as Map? ?? const {}).cast<String, dynamic>(),
        ),
        charged: CombatDamageState.fromJson(
          (json['charged'] as Map? ?? const {}).cast<String, dynamic>(),
        ),
        perfect: CombatDamageState.fromJson(
          (json['perfect'] as Map? ?? const {}).cast<String, dynamic>(),
        ),
        stamina: (json['stamina'] as num?)?.toDouble(),
        intervalSeconds: (json['intervalSeconds'] as num?)?.toDouble(),
        chargeTime: (json['chargeTime'] as num?)?.toDouble(),
      );
}

class TierUpgradeTarget {
  final int tier;
  final double? damageBonus;
  final double? chargedDamageBonus;
  final double? perfectDamageBonus;
  final double? durability;
  final String? costItem;
  final int? costAmount;

  const TierUpgradeTarget({
    required this.tier,
    this.damageBonus,
    this.chargedDamageBonus,
    this.perfectDamageBonus,
    this.durability,
    this.costItem,
    this.costAmount,
  });

  factory TierUpgradeTarget.fromJson(Map<String, dynamic> json) {
    final cost = (json['cost'] as Map? ?? const {}).cast<String, dynamic>();
    final item = (cost['item'] as Map? ?? const {}).cast<String, dynamic>();
    return TierUpgradeTarget(
      tier: (json['tier'] as num?)?.round() ?? 0,
      damageBonus: (json['damageBonus'] as num?)?.toDouble(),
      chargedDamageBonus: (json['chargedDamageBonus'] as num?)?.toDouble(),
      perfectDamageBonus: (json['perfectChargedDamageBonus'] as num?)
          ?.toDouble(),
      durability: (json['durabilityOverride'] as num?)?.toDouble(),
      costItem: item['row']?.toString(),
      costAmount: (cost['amount'] as num?)?.round(),
    );
  }
}

class EnhancementAttackOutcome {
  final String? row;
  final double? projectedDamage;
  final String? physical;
  final String? element;

  const EnhancementAttackOutcome({
    this.row,
    this.projectedDamage,
    this.physical,
    this.element,
  });

  factory EnhancementAttackOutcome.fromJson(Map<String, dynamic> json) {
    final type = (json['damageType'] as Map? ?? const {})
        .cast<String, dynamic>();
    return EnhancementAttackOutcome(
      row: json['row']?.toString(),
      projectedDamage: (json['projectedDamage'] as num?)?.toDouble(),
      physical: type['physical']?.toString(),
      element: type['element']?.toString(),
    );
  }
}

class EnhancementRouteOutcome {
  final String tag;
  final String mode;
  final int maxLevel;
  final double? increasePercent;
  final List<EnhancementAttackOutcome> attacks;
  final String? projectionStatus;

  const EnhancementRouteOutcome({
    required this.tag,
    required this.mode,
    required this.maxLevel,
    this.increasePercent,
    this.attacks = const [],
    this.projectionStatus,
  });

  factory EnhancementRouteOutcome.fromJson(
    Map<String, dynamic> json,
  ) => EnhancementRouteOutcome(
    tag: json['tag']?.toString() ?? '',
    mode: json['mode']?.toString() ?? 'general',
    maxLevel: (json['maxLevel'] as num?)?.round() ?? 0,
    increasePercent: (json['increasePercent'] as num?)?.toDouble(),
    attacks: (json['attacks'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) =>
              EnhancementAttackOutcome.fromJson(value.cast<String, dynamic>()),
        )
        .toList(growable: false),
    projectionStatus: json['projectionStatus']?.toString(),
  );
}

class CombatWeaponProfile {
  final String id;
  final int tier;
  final bool shieldCompatible;
  final List<CombatAttackProfile> attacks;
  final List<TierUpgradeTarget> tierTargets;
  final List<EnhancementRouteOutcome> routes;

  const CombatWeaponProfile({
    required this.id,
    required this.tier,
    required this.shieldCompatible,
    this.attacks = const [],
    this.tierTargets = const [],
    this.routes = const [],
  });

  factory CombatWeaponProfile.fromJson(Map<String, dynamic> json) {
    final upgrade = (json['tierUpgrade'] as Map? ?? const {})
        .cast<String, dynamic>();
    return CombatWeaponProfile(
      id: json['id']?.toString() ?? '',
      tier: (json['tier'] as num?)?.round() ?? 0,
      shieldCompatible: json['shieldCompatible'] as bool? ?? false,
      attacks: (json['attacks'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (value) =>
                CombatAttackProfile.fromJson(value.cast<String, dynamic>()),
          )
          .toList(growable: false),
      tierTargets: (upgrade['targets'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (value) =>
                TierUpgradeTarget.fromJson(value.cast<String, dynamic>()),
          )
          .toList(growable: false),
      routes: (json['enhancementRoutes'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (value) =>
                EnhancementRouteOutcome.fromJson(value.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

class ProjectileItem {
  final String id;
  final int tier;
  final String family;
  final String icon;
  final CombatAttackProfile attack;
  final List<String> launcherIds;

  const ProjectileItem({
    required this.id,
    required this.tier,
    required this.family,
    required this.icon,
    required this.attack,
    this.launcherIds = const [],
  });

  factory ProjectileItem.fromJson(Map<String, dynamic> json) => ProjectileItem(
    id: json['id']?.toString() ?? '',
    tier: (json['tier'] as num?)?.round() ?? 0,
    family: json['family']?.toString() ?? 'ammo',
    icon: json['icon']?.toString() ?? '',
    attack: CombatAttackProfile.fromJson(
      (json['attack'] as Map? ?? const {}).cast<String, dynamic>(),
    ),
    launcherIds: List<String>.from(json['launcherIds'] as List? ?? const []),
  );
}

class CombatShieldProfile {
  final String id;
  final int tier;
  final double? blockDamageMultiplier;
  final double? blockStaminaCost;

  const CombatShieldProfile({
    required this.id,
    required this.tier,
    this.blockDamageMultiplier,
    this.blockStaminaCost,
  });

  factory CombatShieldProfile.fromJson(Map<String, dynamic> json) =>
      CombatShieldProfile(
        id: json['id']?.toString() ?? '',
        tier: (json['tier'] as num?)?.round() ?? 0,
        blockDamageMultiplier: (json['blockDamageMultiplier'] as num?)
            ?.toDouble(),
        blockStaminaCost: (json['blockStaminaCost'] as num?)?.toDouble(),
      );
}

class EffectivenessThresholds {
  final double excellent;
  final double strong;
  final double neutral;
  final double weak;

  const EffectivenessThresholds({
    required this.excellent,
    required this.strong,
    required this.neutral,
    required this.weak,
  });

  factory EffectivenessThresholds.fromJson(Map<String, dynamic> json) =>
      EffectivenessThresholds(
        excellent: (json['excellent'] as num?)?.toDouble() ?? 1.5,
        strong: (json['strong'] as num?)?.toDouble() ?? 1.15,
        neutral: (json['neutral'] as num?)?.toDouble() ?? .85,
        weak: (json['weak'] as num?)?.toDouble() ?? .5,
      );

  EffectivenessLevel classify(double? modifier) {
    if (modifier == null) return EffectivenessLevel.unknown;
    if (modifier >= excellent) return EffectivenessLevel.excellent;
    if (modifier >= strong) return EffectivenessLevel.strong;
    if (modifier >= neutral) return EffectivenessLevel.neutral;
    if (modifier >= weak) return EffectivenessLevel.weak;
    return EffectivenessLevel.ineffective;
  }
}

class CombatRecommendationCatalog {
  final String qaStatus;
  final int maxEnhancementLevel;
  final EffectivenessThresholds thresholds;
  final List<CombatWeaponProfile> weapons;
  final List<CombatShieldProfile> shields;
  final List<ProjectileItem> projectiles;

  const CombatRecommendationCatalog({
    required this.qaStatus,
    required this.maxEnhancementLevel,
    required this.thresholds,
    required this.weapons,
    required this.shields,
    required this.projectiles,
  });

  factory CombatRecommendationCatalog.fromJson(Map<String, dynamic> json) {
    final manifest = (json['manifest'] as Map? ?? const {})
        .cast<String, dynamic>();
    return CombatRecommendationCatalog(
      qaStatus: manifest['extractorQa']?.toString() ?? 'UNKNOWN',
      maxEnhancementLevel: (json['maxEnhancementLevel'] as num?)?.round() ?? 0,
      thresholds: EffectivenessThresholds.fromJson(
        (manifest['effectivenessThresholds'] as Map? ?? const {})
            .cast<String, dynamic>(),
      ),
      weapons: (json['weapons'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (value) =>
                CombatWeaponProfile.fromJson(value.cast<String, dynamic>()),
          )
          .toList(growable: false),
      shields: (json['shields'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (value) =>
                CombatShieldProfile.fromJson(value.cast<String, dynamic>()),
          )
          .toList(growable: false),
      projectiles: (json['projectiles'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (value) => ProjectileItem.fromJson(value.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }
}

class ZoneResult {
  final String part;
  final double? damage;
  final double? damagePerSecond;
  final double modifier;
  final bool compatible;

  const ZoneResult({
    required this.part,
    this.damage,
    this.damagePerSecond,
    required this.modifier,
    required this.compatible,
  });
}

class DamageCalculationResult {
  final double? generalDamage;
  final double? bestDamage;
  final double? generalDamagePerSecond;
  final double? bestDamagePerSecond;
  final double? modifier;
  final EffectivenessLevel effectiveness;
  final List<ZoneResult> zones;
  final List<String> appliedTypes;
  final bool immune;

  const DamageCalculationResult({
    this.generalDamage,
    this.bestDamage,
    this.generalDamagePerSecond,
    this.bestDamagePerSecond,
    this.modifier,
    required this.effectiveness,
    this.zones = const [],
    this.appliedTypes = const [],
    this.immune = false,
  });
}

enum RecommendationReasonKind {
  weakness,
  resistance,
  immunity,
  weakPoint,
  status,
  shield,
  unknown,
}

class RecommendationReason {
  final RecommendationReasonKind kind;
  final String value;
  final bool positive;

  const RecommendationReason(this.kind, this.value, {required this.positive});
}

class CombatLoadout {
  final EquipmentItem weapon;
  final CombatWeaponProfile profile;
  final int buildTier;
  final int enhancementLevel;
  final EnhancementRouteOutcome? route;
  final ProjectileItem? projectile;
  final EquipmentItem? shield;

  /// Element/flavour actually used in the projected hit, never inferred from
  /// the equipment name.
  final String? flavor;

  const CombatLoadout({
    required this.weapon,
    required this.profile,
    required this.buildTier,
    required this.enhancementLevel,
    this.route,
    this.projectile,
    this.shield,
    this.flavor,
  });
}

class CombatRecommendation {
  final CombatLoadout loadout;
  final DamageCalculationResult damage;
  final List<RecommendationReason> reasons;
  final double defensiveUtility;

  const CombatRecommendation({
    required this.loadout,
    required this.damage,
    this.reasons = const [],
    this.defensiveUtility = 0,
  });
}
