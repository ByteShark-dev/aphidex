import '../models/enemy.dart';
import 'ui_mapper.dart';

class WeakpointPresentation {
  final String region;
  final String iconAsset;
  final String effectiveDamage;

  /// Canonical damage types verified by the extractor.  This must take
  /// precedence over the older human-readable [effectiveDamage] string: some
  /// records say "any" there while their structured fields correctly limit
  /// the weak point to stabbing, chopping, etc.
  final List<String> effectiveDamageTypes;
  final List<String> weaponFamilies;
  final double? damageMultiplier;
  final double? stunMultiplier;

  const WeakpointPresentation({
    required this.region,
    required this.iconAsset,
    required this.effectiveDamage,
    required this.effectiveDamageTypes,
    required this.weaponFamilies,
    required this.damageMultiplier,
    required this.stunMultiplier,
  });
}

abstract interface class WeakpointResolver {
  WeakpointPresentation resolve(WeakPointInfo weakpoint);
}

class AphidexWeakpointResolver implements WeakpointResolver {
  const AphidexWeakpointResolver();

  static const _knownRegions = {
    'abdomen',
    'back',
    'belly',
    'butt',
    'eyes',
    'gut',
    'legs',
    'rump',
    'stinger',
    'tail',
    'vent',
  };

  @override
  WeakpointPresentation resolve(WeakPointInfo weakpoint) {
    final raw = weakpoint.part.trim().toLowerCase();
    final normalized = switch (raw.replaceFirst('weakpoint.', '')) {
      'underbelly' || 'abdomen' => 'belly',
      'butt' => 'rump',
      final value => value,
    };
    final region = _knownRegions.contains(normalized) ? normalized : 'unknown';
    final structuredTypes = weakpoint.susceptibleDamageTypes
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && value != 'any')
        .toSet()
        .toList(growable: false);
    final damage = switch (weakpoint.susceptibleDamage) {
      'stabbing_arrows_only' => 'projectile_piercing',
      final value when value.trim().isNotEmpty => value,
      _ => 'unknown',
    };
    final effectiveTypes = structuredTypes.isNotEmpty
        ? structuredTypes
        : damage == 'unknown'
        ? const <String>[]
        : damage == 'projectile_piercing'
        ? const ['stabbing']
        : UiMapper.susceptibleDamageEffectIds(damage);
    final families = weakpoint.weaponFamilies.isNotEmpty
        ? weakpoint.weaponFamilies
        : damage == 'projectile_piercing'
        ? const ['bow', 'crossbow']
        : const <String>[];
    return WeakpointPresentation(
      region: region,
      iconAsset: UiMapper.weakPointIcon(region),
      effectiveDamage: effectiveTypes.length == 1
          ? effectiveTypes.single
          : damage,
      effectiveDamageTypes: effectiveTypes,
      weaponFamilies: families,
      damageMultiplier: weakpoint.damageMultiplier,
      stunMultiplier: weakpoint.stunMultiplier,
    );
  }
}
