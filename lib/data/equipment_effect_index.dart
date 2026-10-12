import '../models/equipment.dart';
import 'effect_catalog.dart';

/// A deduplicated, presentation-ready reference to a weapon or shield that
/// supplies an effect. One item may have several [origins] for the same
/// effect (for example, an innate effect plus an optional upgrade route).
class EquipmentEffectMatch {
  final EquipmentItem item;
  final Set<String> origins;

  const EquipmentEffectMatch({required this.item, required this.origins});

  bool get isUpgradeOnly => origins.length == 1 && origins.single == 'upgrade';
}

/// Builds effect-to-equipment references from the source-backed relations in
/// the equipment dataset. Only weapons and shields belong in the effect codex;
/// armor and trinkets retain their own detail views.
class EquipmentEffectIndex {
  final Map<String, List<EquipmentEffectMatch>> _byEffect;

  const EquipmentEffectIndex._(this._byEffect);

  factory EquipmentEffectIndex.fromCatalog(EquipmentCatalog catalog) {
    final grouped = <String, Map<String, _MutableMatch>>{};
    for (final item in catalog.items) {
      if (item.domain != EquipmentDomain.weapon &&
          item.domain != EquipmentDomain.shield) {
        continue;
      }
      for (final relation in item.effectRelations) {
        // The codex explains effects carried by the item or applied by its
        // attacks. Optional upgrade paths are displayed in the equipment
        // sheet, but including them here turns every elemental route into a
        // misleading wall of otherwise unrelated weapons.
        if (relation.origin == 'upgrade') {
          continue;
        }
        final effectId = effectCatalogIdForTechnicalType(relation.effectId);
        if (effectCatalogEntryById(effectId) == null || effectId == 'none') {
          continue;
        }
        final matches = grouped.putIfAbsent(effectId, () => {});
        final match = matches.putIfAbsent(item.id, () => _MutableMatch(item));
        match.origins.add(relation.origin);
      }
    }
    return EquipmentEffectIndex._({
      for (final entry in grouped.entries)
        entry.key:
            (entry.value.values
                .map(
                  (match) => EquipmentEffectMatch(
                    item: match.item,
                    origins: Set.unmodifiable(match.origins),
                  ),
                )
                .toList()
              ..sort((a, b) => a.item.name.en.compareTo(b.item.name.en))),
    });
  }

  List<EquipmentEffectMatch> forEffect(String effectId) => List.unmodifiable(
    _byEffect[effectCatalogIdForTechnicalType(effectId)] ?? const [],
  );
}

class _MutableMatch {
  final EquipmentItem item;
  final Set<String> origins = <String>{};

  _MutableMatch(this.item);
}
