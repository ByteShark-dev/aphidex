import '../models/combat_recommendation.dart';
import '../models/enemy.dart';

class DamageCalculationEngine {
  final EffectivenessThresholds thresholds;

  const DamageCalculationEngine(this.thresholds);

  DamageCalculationResult calculate({
    required Enemy enemy,
    required double? baseDamage,
    String? physical,
    String? element,
    String? weaponFamily,
  }) {
    if (baseDamage == null) {
      return const DamageCalculationResult(
        effectiveness: EffectivenessLevel.unknown,
      );
    }
    final types = <String>{
      if (physical != null && physical.isNotEmpty) physical,
      if (element != null && element.isNotEmpty) element,
    };
    var modifier = 1.0;
    var immune = false;
    for (final type in types) {
      if (enemy.immunities.contains(type)) {
        modifier = 0;
        immune = true;
        break;
      }
      final weakness = [
        ...enemy.damageWeaknesses,
        ...enemy.elementalWeaknesses,
      ].where((value) => value.type == type);
      for (final value in weakness) {
        modifier *= 1 + value.bonusPct / 100;
      }
      for (final value in enemy.resistancesV2.where(
        (value) => value.type == type,
      )) {
        modifier *= (1 - value.bonusPct / 100).clamp(0, 1);
      }
    }
    final general = baseDamage * modifier;
    final zones = enemy.resolvedWeakPoints
        .map((zone) {
          final acceptedTypes = zone.susceptibleDamageTypes;
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
    return DamageCalculationResult(
      generalDamage: general,
      bestDamage: best,
      modifier: modifier,
      effectiveness: thresholds.classify(modifier),
      zones: zones,
      appliedTypes: types.toList(growable: false),
      immune: immune,
    );
  }
}
