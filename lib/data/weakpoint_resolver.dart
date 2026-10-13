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
    // A few anatomical exports retain the generic legacy value "any" while
    // also provide a verified, restrictive weapon-family tag. Do not surface
    // that as "any damage": Bow/crossbow and spear are both the game's
    // piercing (stabbing) families, so this is a safe structural resolution
    // of the accompanying source tags rather than a name-based guess.
    final familyTypes = _typesFromWeaponFamilies(weakpoint.weaponFamilies);
    final effectiveTypes = structuredTypes.isNotEmpty
        ? structuredTypes
        : familyTypes.isNotEmpty && damage == 'any'
        ? familyTypes
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
      effectiveDamage: _damageLabelId(effectiveTypes, damage),
      effectiveDamageTypes: effectiveTypes,
      weaponFamilies: families,
      damageMultiplier: weakpoint.damageMultiplier,
      stunMultiplier: weakpoint.stunMultiplier,
    );
  }

  List<String> _typesFromWeaponFamilies(List<String> families) {
    if (families.isEmpty) return const [];
    const typeByFamily = <String, String>{
      'axe': 'chopping',
      'bow': 'stabbing',
      'crossbow': 'stabbing',
      'dagger': 'stabbing',
      'spear': 'stabbing',
      'sword': 'slashing',
      'thrown_spear': 'stabbing',
    };
    final normalized = families
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (normalized.isEmpty || !normalized.every(typeByFamily.containsKey)) {
      return const [];
    }
    return normalized
        .map((family) => typeByFamily[family]!)
        .toSet()
        .toList(growable: false);
  }

  String _damageLabelId(List<String> types, String fallback) {
    if (types.length == 1) return types.single;
    final values = types.toSet();
    if (values.length == 3 &&
        values.containsAll(const {'chopping', 'slashing', 'stabbing'})) {
      return 'chopping_slashing_stabbing';
    }
    return fallback;
  }
}
