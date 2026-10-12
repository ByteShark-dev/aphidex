import '../models/enemy.dart';
import 'ui_mapper.dart';

class WeakpointPresentation {
  final String region;
  final String iconAsset;
  final String effectiveDamage;
  final List<String> weaponFamilies;
  final double? damageMultiplier;
  final double? stunMultiplier;

  const WeakpointPresentation({
    required this.region,
    required this.iconAsset,
    required this.effectiveDamage,
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
    final damage = switch (weakpoint.susceptibleDamage) {
      'stabbing_arrows_only' => 'projectile_piercing',
      final value when value.trim().isNotEmpty => value,
      _ => 'unknown',
    };
    final families = weakpoint.weaponFamilies.isNotEmpty
        ? weakpoint.weaponFamilies
        : damage == 'projectile_piercing'
        ? const ['bow', 'crossbow']
        : const <String>[];
    return WeakpointPresentation(
      region: region,
      iconAsset: UiMapper.weakPointIcon(region),
      effectiveDamage: damage,
      weaponFamilies: families,
      damageMultiplier: weakpoint.damageMultiplier,
      stunMultiplier: weakpoint.stunMultiplier,
    );
  }
}
