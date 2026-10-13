import '../models/combat_recommendation.dart';
import '../models/enemy.dart';
import '../data/effect_catalog.dart';

class DamageCalculationEngine {
  final EffectivenessThresholds thresholds;

  const DamageCalculationEngine(this.thresholds);

  DamageCalculationResult calculate({
    required Enemy enemy,
    required double? baseDamage,
    double? baseDamagePerSecond,
    String? physical,
    String? element,
    String? weaponFamily,
    List<BonusInfo> additionalWeaknesses = const [],
    List<BonusInfo> additionalResistances = const [],
  }) {
    if (baseDamage == null) {
      return const DamageCalculationResult(
        effectiveness: EffectivenessLevel.unknown,
      );
    }
    final types = <String>{
      if (physical != null && physical.isNotEmpty) canonicalEffectId(physical),
      if (element != null && element.isNotEmpty) canonicalEffectId(element),
    };
    var modifier = 1.0;
    var immune = false;
    final weaknesses = _mergeByType([
      ...enemy.damageWeaknesses,
      ...enemy.elementalWeaknesses,
    ], additionalWeaknesses);
    final resistances = _mergeByType(
      enemy.resistancesV2,
      additionalResistances,
    );
    for (final type in types) {
      if (enemy.immunities.map(canonicalEffectId).contains(type)) {
        modifier = 0;
        immune = true;
        break;
      }
      final weakness = weaknesses.where(
        (value) => canonicalEffectId(value.type) == type,
      );
      for (final value in weakness) {
        modifier *= 1 + value.bonusPct / 100;
      }
      for (final value in resistances.where(
        (value) => canonicalEffectId(value.type) == type,
      )) {
        modifier *= (1 - value.bonusPct / 100).clamp(0, 1);
      }
    }
    final general = baseDamage * modifier;
    final generalDamagePerSecond = baseDamagePerSecond == null
        ? null
        : baseDamagePerSecond * modifier;
    final zones = enemy.resolvedWeakPoints
        .map((zone) {
          final acceptedTypes = zone.susceptibleDamageTypes
              .map(canonicalEffectId)
              .toSet();
          final acceptsAny =
              acceptedTypes.isEmpty || acceptedTypes.contains('any');
          final typeMatches = acceptsAny || acceptedTypes.any(types.contains);
          final familyMatches =
              zone.weaponFamilies.isEmpty ||
              (weaponFamily != null &&
                  zone.weaponFamilies.contains(weaponFamily));
          final compatible = typeMatches && familyMatches;
          final zoneModifier = compatible ? (zone.damageMultiplier ?? 1) : 1.0;
          return ZoneResult(
            part: zone.part,
            damage: general * zoneModifier,
            damagePerSecond: generalDamagePerSecond == null
                ? null
                : generalDamagePerSecond * zoneModifier,
            modifier: zoneModifier,
            compatible: compatible,
          );
        })
        .toList(growable: false);
    final best = zones
        .where((zone) => zone.compatible)
        .fold<double?>(
          general,
          (current, zone) =>
              (zone.damage ?? 0) > (current ?? 0) ? zone.damage : current,
        );
    final bestDamagePerSecond = zones
        .where((zone) => zone.compatible)
        .fold<double?>(
          generalDamagePerSecond,
          (current, zone) => (zone.damagePerSecond ?? 0) > (current ?? 0)
              ? zone.damagePerSecond
              : current,
        );
    return DamageCalculationResult(
      generalDamage: general,
      bestDamage: best,
      generalDamagePerSecond: generalDamagePerSecond,
      bestDamagePerSecond: bestDamagePerSecond,
      modifier: modifier,
      effectiveness: thresholds.classify(modifier),
      zones: zones,
      appliedTypes: types.toList(growable: false),
      immune: immune,
    );
  }

  List<BonusInfo> _mergeByType(
    Iterable<BonusInfo> base,
    Iterable<BonusInfo> overrides,
  ) {
    final merged = <String, BonusInfo>{
      for (final value in base) canonicalEffectId(value.type): value,
    };
    for (final value in overrides) {
      merged[canonicalEffectId(value.type)] = value;
    }
    return merged.values.toList(growable: false);
  }
}
