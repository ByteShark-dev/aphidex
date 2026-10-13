import 'dart:async';

import 'package:flutter/material.dart';

import '../data/content_repositories.dart';
import '../data/effect_catalog.dart';
import '../data/entity_asset_resolver.dart';
import '../data/equipment_presentation.dart';
import '../data/enemy_repository.dart';
import '../data/ui_mapper.dart';
import '../models/equipment.dart';
import '../models/combat_recommendation.dart';
import '../models/location.dart';
import '../widgets/icon_badge.dart';
import 'map_screen.dart';
import 'enemy_detail_screen.dart';

String _projectileGroupKey(String id) {
  if (id.contains('Splinter')) return 'splinter';
  if (id.startsWith('GreatArrow')) return 'great_arrow';
  if (id.startsWith('Arrow')) return 'arrow';
  if (id.startsWith('Paintball')) return 'paintball';
  return 'other';
}

class EquipmentLibraryScreen extends StatefulWidget {
  const EquipmentLibraryScreen({
    super.key,
    this.embedded = false,
    this.initialEquipmentId,
    this.initialProjectileId,
  });

  final bool embedded;
  final String? initialEquipmentId;
  final String? initialProjectileId;

  @override
  State<EquipmentLibraryScreen> createState() => _EquipmentLibraryScreenState();
}

class _EquipmentLibraryScreenState extends State<EquipmentLibraryScreen> {
  int _category = 0;
  bool _openedInitial = false;

  String get _language => Localizations.localeOf(context).languageCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(_t('Equipment', 'Equipo', 'Снаряжение')),
      ),
      body: FutureBuilder<EquipmentCatalog>(
        future: EquipmentRepository.load(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${_t('Could not load equipment', 'No se pudo cargar el equipo', 'Не удалось загрузить снаряжение')}: ${snapshot.error}',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final catalog = snapshot.data!;
          _openInitialOnce(catalog);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                      value: 0,
                      label: Text(_t('Weapons', 'Armas', 'Оружие')),
                      icon: const Icon(Icons.gavel),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text(_t('Armor', 'Armaduras', 'Броня')),
                      icon: const Icon(Icons.shield),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text(_t('Trinkets', 'Amuletos', 'Талисманы')),
                      icon: const Icon(Icons.auto_awesome),
                    ),
                  ],
                  selected: {_category},
                  onSelectionChanged: (value) =>
                      setState(() => _category = value.first),
                ),
              ),
              Expanded(child: _buildCategory(catalog)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategory(EquipmentCatalog catalog) {
    if (_category == 1) {
      final setPieceIds = catalog.armorSets.expand((set) => set.pieces).toSet();
      final individualPieces = catalog.items
          .where(
            (item) =>
                item.domain == EquipmentDomain.armor &&
                !setPieceIds.contains(item.id),
          )
          .toList(growable: false);
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final set in catalog.armorSets)
            _EquipmentCard(
              title: set.name.resolve(_language),
              subtitle:
                  '${set.pieces.length} ${_t('pieces', 'piezas', 'части')}',
              icon: EntityAssetResolver.resolveArmorSet(set).asset,
              onTap: () => _showSet(set, catalog),
            ),
          if (individualPieces.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _t('Individual pieces', 'Piezas individuales', 'Отдельные части'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final item in individualPieces)
              _EquipmentCard(
                title: item.name.resolve(_language),
                subtitle: [
                  EquipmentPresentation.slotLabel(item.slot, _language),
                  if (item.tier != null)
                    '${_t('Tier', 'Nivel', 'Уровень')} ${item.tier}',
                ].where((text) => text.isNotEmpty).join(' · '),
                icon: EntityAssetResolver.resolveEquipment(item).asset,
                onTap: () => _showItem(item),
              ),
          ],
        ],
      );
    }
    if (_category == 0) {
      return FutureBuilder<CombatRecommendationCatalog>(
        future: CombatRecommendationRepository.load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildWeaponsAndAmmunition(catalog, snapshot.data!);
        },
      );
    }
    final domain = _category == 0 ? null : EquipmentDomain.trinket;
    final items = catalog.items
        .where((item) {
          if (domain == null) {
            return item.domain == EquipmentDomain.weapon ||
                item.domain == EquipmentDomain.shield;
          }
          return item.domain == domain;
        })
        .toList(growable: false);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _EquipmentCard(
          title: item.name.resolve(_language),
          subtitle: [
            EquipmentPresentation.typeLabel(item.normalizedType, _language),
            if (item.normalizedSubtype != item.normalizedType)
              EquipmentPresentation.subtypeLabel(
                item.normalizedSubtype,
                _language,
              ),
            if (item.tier != null)
              '${_t('Tier', 'Nivel', 'Уровень')} ${item.tier}',
            if (item.acquisition.unresolved)
              _t(
                'Acquisition unresolved',
                'Adquisición no resuelta',
                'Получение не определено',
              ),
          ].join(' · '),
          icon: EntityAssetResolver.resolveEquipment(item).asset,
          onTap: () => _showItem(item),
        );
      },
    );
  }

  Widget _buildWeaponsAndAmmunition(
    EquipmentCatalog catalog,
    CombatRecommendationCatalog combat,
  ) {
    final equipment = catalog.items
        .where(
          (item) =>
              item.domain == EquipmentDomain.weapon ||
              item.domain == EquipmentDomain.shield,
        )
        .toList(growable: false);
    final weaponGroups = <String, List<EquipmentItem>>{};
    for (final item in equipment) {
      weaponGroups.putIfAbsent(_weaponGroupKey(item), () => []).add(item);
    }
    final projectileGroups = <String, List<ProjectileItem>>{};
    for (final projectile in combat.projectiles) {
      projectileGroups
          .putIfAbsent(_projectileGroupKey(projectile.id), () => [])
          .add(projectile);
    }
    for (final values in weaponGroups.values) {
      values.sort(
        (a, b) =>
            a.name.resolve(_language).compareTo(b.name.resolve(_language)),
      );
    }
    for (final values in projectileGroups.values) {
      values.sort((a, b) {
        final tier = a.tier.compareTo(b.tier);
        return tier != 0 ? tier : a.id.compareTo(b.id);
      });
    }
    const weaponOrder = <String>[
      'ranged',
      'one_handed',
      'two_handed',
      'shield',
      'extra',
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final key in weaponOrder)
          if (weaponGroups[key]?.isNotEmpty ?? false)
            _EquipmentFolderCard(
              title: _weaponGroupLabel(key),
              subtitle: _folderCount(weaponGroups[key]!.length),
              icon: _folderIcon(key),
              onTap: () => _showEquipmentGroup(
                _weaponGroupLabel(key),
                weaponGroups[key]!,
              ),
            ),
        if (projectileGroups.isNotEmpty)
          _EquipmentFolderCard(
            title: _t('Ammunition', 'Munición', 'Боеприпасы'),
            subtitle: _t(
              'Grouped by family',
              'Agrupada por familia',
              'Сгруппировано по семейству',
            ),
            icon: Icons.inventory_2_outlined,
            onTap: () => _showProjectileGroups(projectileGroups),
          ),
      ],
    );
  }

  String _weaponGroupKey(EquipmentItem item) {
    if (item.domain == EquipmentDomain.shield) return 'shield';
    final subtype = item.normalizedSubtype;
    if (subtype == 'bow' || subtype == 'staff') return 'ranged';
    if (subtype == 'special' || subtype == 'fists') return 'extra';
    if (item.twoHanded == true) return 'two_handed';
    if (item.twoHanded == false) return 'one_handed';
    return 'extra';
  }

  String _weaponGroupLabel(String key) => switch (key) {
    'ranged' => _t(
      'Ranged weapons',
      'Armas a distancia',
      'Дальнобойное оружие',
    ),
    'one_handed' => _t(
      'One-handed weapons',
      'Armas de una mano',
      'Одноручное оружие',
    ),
    'two_handed' => _t(
      'Two-handed weapons',
      'Armas de dos manos',
      'Двуручное оружие',
    ),
    'shield' => _t('Shields', 'Escudos', 'Щиты'),
    _ => _t('Extras', 'Extras', 'Дополнительно'),
  };

  IconData _folderIcon(String key) => switch (key) {
    'ranged' => Icons.architecture_outlined,
    'one_handed' => Icons.hardware_outlined,
    'two_handed' => Icons.construction_outlined,
    'shield' => Icons.shield_outlined,
    _ => Icons.extension_outlined,
  };

  String _folderCount(int count) =>
      '$count ${_t('items', 'objetos', 'предметов')}';

  Future<void> _showEquipmentGroup(String title, List<EquipmentItem> items) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => _LibraryGroupSheet(
          title: title,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
              return _EquipmentCard(
                title: item.name.resolve(_language),
                subtitle: [
                  EquipmentPresentation.subtypeLabel(
                    item.normalizedSubtype,
                    _language,
                  ),
                  if (item.tier != null)
                    '${_t('Tier', 'Nivel', 'Уровень')} ${item.tier}',
                ].where((value) => value.isNotEmpty).join(' · '),
                icon: EntityAssetResolver.resolveEquipment(item).asset,
                onTap: () {
                  Navigator.pop(sheetContext);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _showItem(item);
                  });
                },
              );
            },
          ),
        ),
      );

  Future<void> _showProjectileGroups(
    Map<String, List<ProjectileItem>> groups,
  ) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final keys = groups.keys.toList()..sort();
      return _LibraryGroupSheet(
        title: _t('Ammunition', 'Munición', 'Боеприпасы'),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final key in keys)
              _EquipmentFolderCard(
                title: _projectileGroupLabel(key),
                subtitle: _folderCount(groups[key]!.length),
                icon: Icons.folder_outlined,
                onTap: () {
                  Navigator.pop(sheetContext);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _showProjectileGroup(
                        _projectileGroupLabel(key),
                        groups[key]!,
                      );
                    }
                  });
                },
              ),
          ],
        ),
      );
    },
  );

  Future<void> _showProjectileGroup(
    String title,
    List<ProjectileItem> projectiles,
  ) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _LibraryGroupSheet(
      title: title,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: projectiles.length,
        itemBuilder: (_, index) {
          final projectile = projectiles[index];
          return _EquipmentCard(
            title: _projectileLabel(projectile.id),
            subtitle: [
              '${_t('Tier', 'Nivel', 'Уровень')} ${projectile.tier}',
              _projectileDamageLabel(projectile),
            ].join(' · '),
            icon: projectile.icon,
            onTap: () {
              Navigator.pop(sheetContext);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _showProjectile(projectile);
              });
            },
          );
        },
      ),
    ),
  );

  String _projectileDamageLabel(ProjectileItem projectile) {
    final attack = [
      projectile.attack.base,
      projectile.attack.charged,
      projectile.attack.perfect,
    ].reduce((a, b) => (a.damage ?? -1) >= (b.damage ?? -1) ? a : b);
    final type = attack.element ?? attack.physical;
    return type == null
        ? _t('Damage unknown', 'Daño desconocido', 'Урон неизвестен')
        : EquipmentPresentation.effectLabel(type, _language);
  }

  String _projectileGroupLabel(String key) => switch (key) {
    'arrow' => _t('Arrows', 'Flechas', 'Стрелы'),
    'great_arrow' => _t('Great arrows', 'Flechas grandes', 'Большие стрелы'),
    'paintball' => _t('Paintballs', 'Bolas de pintura', 'Шарики с краской'),
    'splinter' => _t(
      'Splinter shots',
      'Flechas de astilla',
      'Осколочные выстрелы',
    ),
    _ => _t('Other ammunition', 'Otra munición', 'Другие боеприпасы'),
  };

  String _projectileLabel(String id) {
    const es = <String, String>{
      'Arrow': 'Flecha',
      'ArrowCrow': 'Flecha de cuervo',
      'ArrowEMP': 'Flecha PEM',
      'ArrowGas': 'Flecha de gas',
      'ArrowHealing': 'Flecha curativa',
      'ArrowLips': 'Flecha Lips',
      'ArrowMint': 'Flecha fresca',
      'ArrowPoison': 'Flecha venenosa',
      'ArrowPollen': 'Flecha de polen',
      'ArrowSour': 'Flecha agria',
      'ArrowSpicy': 'Flecha picante',
      'ArrowSplinter': 'Flecha de astilla',
      'ArrowSplinterGas': 'Flecha de astilla gaseosa',
      'ArrowUnderwater': 'Flecha subacuática',
      'GreatArrowCrow': 'Flecha grande de cuervo',
      'GreatArrowLips': 'Flecha grande Lips',
      'GreatArrowMint': 'Flecha grande fresca',
      'GreatArrowSour': 'Flecha grande agria',
      'GreatArrowSpicy': 'Flecha grande picante',
      'GreatArrowVenom': 'Flecha grande venenosa',
      'PaintballBlue': 'Bola de pintura azul',
      'PaintballGreen': 'Bola de pintura verde',
      'PaintballOrange': 'Bola de pintura naranja',
      'PaintballPurple': 'Bola de pintura morada',
      'PaintballRed': 'Bola de pintura roja',
      'PaintballWash': 'Bola de pintura de lavado',
      'PaintballYellow': 'Bola de pintura amarilla',
      'SplinterShot': 'Flecha de astilla',
      'SplinterShotMint': 'Flecha de astilla fresca',
      'SplinterShotSour': 'Flecha de astilla agria',
      'SplinterShotSpicy': 'Flecha de astilla picante',
    };
    const en = <String, String>{
      'Arrow': 'Arrow',
      'ArrowCrow': 'Crow Arrow',
      'ArrowEMP': 'EMP Arrow',
      'ArrowGas': 'Gas Arrow',
      'ArrowHealing': 'Healing Arrow',
      'ArrowLips': 'Lips Arrow',
      'ArrowMint': 'Fresh Arrow',
      'ArrowPoison': 'Poison Arrow',
      'ArrowPollen': 'Pollen Arrow',
      'ArrowSour': 'Sour Arrow',
      'ArrowSpicy': 'Spicy Arrow',
      'ArrowSplinter': 'Splinter Arrow',
      'ArrowSplinterGas': 'Gas Splinter Arrow',
      'ArrowUnderwater': 'Underwater Arrow',
      'GreatArrowCrow': 'Great Crow Arrow',
      'GreatArrowLips': 'Great Lips Arrow',
      'GreatArrowMint': 'Great Fresh Arrow',
      'GreatArrowSour': 'Great Sour Arrow',
      'GreatArrowSpicy': 'Great Spicy Arrow',
      'GreatArrowVenom': 'Great Venom Arrow',
      'PaintballBlue': 'Blue Paintball',
      'PaintballGreen': 'Green Paintball',
      'PaintballOrange': 'Orange Paintball',
      'PaintballPurple': 'Purple Paintball',
      'PaintballRed': 'Red Paintball',
      'PaintballWash': 'Wash Paintball',
      'PaintballYellow': 'Yellow Paintball',
      'SplinterShot': 'Splinter Arrow',
      'SplinterShotMint': 'Fresh Splinter Arrow',
      'SplinterShotSour': 'Sour Splinter Arrow',
      'SplinterShotSpicy': 'Spicy Splinter Arrow',
    };
    // No official RU strings were supplied by the projectile extractor. Keep
    // the stable, readable English fallback rather than inventing translations.
    return switch (_language) {
      'es' => es[id] ?? EquipmentPresentation.cleanIdentifier(id),
      'en' => en[id] ?? EquipmentPresentation.cleanIdentifier(id),
      _ => en[id] ?? EquipmentPresentation.cleanIdentifier(id),
    };
  }

  void _openInitialOnce(EquipmentCatalog catalog) {
    if (_openedInitial ||
        (widget.initialEquipmentId == null &&
            widget.initialProjectileId == null)) {
      return;
    }
    _openedInitial = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final projectileId = widget.initialProjectileId;
      if (projectileId != null) {
        unawaited(_openProjectileInitial(projectileId));
        return;
      }
      final query = widget.initialEquipmentId!.toLowerCase();
      final item = catalog.items.cast<EquipmentItem?>().firstWhere(
        (value) => value!.id.toLowerCase() == query,
        orElse: () => null,
      );
      if (item != null) {
        setState(() {
          _category = item.domain == EquipmentDomain.armor
              ? 1
              : item.domain == EquipmentDomain.trinket
              ? 2
              : 0;
        });
        _showItem(item);
        return;
      }
      final set = catalog.armorSets.cast<ArmorSet?>().firstWhere(
        (item) =>
            item!.id.toLowerCase().contains(query) ||
            item.name.en.toLowerCase().contains(query) ||
            (query.contains('diving') &&
                item.name.en.toLowerCase().contains('diving')),
        orElse: () => null,
      );
      if (set != null) {
        setState(() => _category = 1);
        _showSet(set, catalog);
      }
    });
  }

  Future<void> _openProjectileInitial(String id) async {
    final combat = await CombatRecommendationRepository.load();
    if (!mounted) return;
    final projectile = combat.projectiles.cast<ProjectileItem?>().firstWhere(
      (value) => value?.id.toLowerCase() == id.toLowerCase(),
      orElse: () => null,
    );
    if (projectile != null) _showProjectile(projectile);
  }

  Future<void> _showItem(EquipmentItem item) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => _EquipmentDetailSheet(
      item: item,
      language: _language,
      mapAction: item.locations.isEmpty
          ? null
          : () => MapNavigation.open(
              context,
              MapOpenRequest(
                target: MapTarget(MapTargetType.equipment, item.id),
                filter: MapFilter(
                  type: MapTargetType.equipment,
                  targetId: item.id,
                ),
                focus: MapFocus(preferredLayer: item.locations.first.layer),
              ),
            ),
    ),
  );

  Future<void> _showProjectile(ProjectileItem projectile) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) =>
            _ProjectileDetailSheet(projectile: projectile, language: _language),
      );

  Future<void> _showSet(ArmorSet set, EquipmentCatalog catalog) {
    final pieces = catalog.items
        .where((item) => set.pieces.contains(item.id))
        .toList();
    final locations = pieces.expand((item) => item.locations).toList();
    final locatedPiece = pieces.cast<EquipmentItem?>().firstWhere(
      (item) => item!.locations.isNotEmpty,
      orElse: () => null,
    );
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => _ArmorSetDetailSheet(
        set: set,
        pieces: pieces,
        language: _language,
        onPieceTap: (piece) {
          Navigator.pop(sheetContext);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showItem(piece);
          });
        },
        mapAction: locations.isEmpty || locatedPiece == null
            ? null
            : () => MapNavigation.open(
                context,
                MapOpenRequest(
                  target: MapTarget(MapTargetType.equipment, locatedPiece.id),
                  filter: MapFilter(
                    type: MapTargetType.equipment,
                    targetId: locatedPiece.id,
                  ),
                  focus: MapFocus(preferredLayer: locations.first.layer),
                ),
              ),
      ),
    );
  }

  String _t(String en, String es, String ru) => switch (_language) {
    'es' => es,
    'ru' => ru,
    _ => en,
  };
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: SizedBox.square(
        dimension: 48,
        child: icon.isEmpty
            ? const Icon(Icons.inventory_2_outlined)
            : Image.asset(
                icon,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.inventory_2_outlined),
              ),
      ),
      title: Text(title),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _EquipmentFolderCard extends StatelessWidget {
  const _EquipmentFolderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: SizedBox.square(
        dimension: 48,
        child: Icon(
          icon,
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _LibraryGroupSheet extends StatelessWidget {
  const _LibraryGroupSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .7,
    minChildSize: .42,
    maxChildSize: .94,
    builder: (context, controller) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

class _EquipmentDetailSheet extends StatelessWidget {
  const _EquipmentDetailSheet({
    required this.item,
    required this.language,
    this.mapAction,
  });

  final EquipmentItem item;
  final String language;
  final VoidCallback? mapAction;

  String _t(String en, String es, String ru) => switch (language) {
    'es' => es,
    'ru' => ru,
    _ => en,
  };

  @override
  Widget build(BuildContext context) {
    final icon = EntityAssetResolver.resolveEquipment(item).asset;
    final slot = EquipmentPresentation.slotLabel(item.slot, language);
    final protection = (item.raw['protection'] as Map? ?? const {})
        .cast<String, dynamic>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 64,
                  child: icon.isEmpty
                      ? const Icon(Icons.inventory_2_outlined, size: 42)
                      : Image.asset(
                          icon,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.inventory_2_outlined, size: 42),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item.name.resolve(language),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  key: const ValueKey('close-equipment-detail'),
                  tooltip: _t('Close', 'Cerrar', 'Закрыть'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final row in <String, String>{
              _t('Type', 'Tipo', 'Тип'): EquipmentPresentation.typeLabel(
                item.normalizedType,
                language,
              ),
              _t(
                'Subtype',
                'Subtipo',
                'Подтип',
              ): EquipmentPresentation.subtypeLabel(
                item.normalizedSubtype,
                language,
              ),
              if (item.tier != null)
                _t('Tier', 'Nivel', 'Уровень'): '${item.tier}',
              if (slot.isNotEmpty) _t('Slot', 'Ranura', 'Слот'): slot,
              if (item.twoHanded != null)
                _t('Hands', 'Manos', 'Хват'): item.twoHanded!
                    ? _t('Two handed', 'Dos manos', 'Двуручный')
                    : _t('One handed', 'Una mano', 'Одноручный'),
              if (item.canBlock != null)
                _t('Blocking', 'Bloqueo', 'Блокирование'): item.canBlock!
                    ? _t('Available', 'Disponible', 'Доступно')
                    : _t('Not available', 'No disponible', 'Недоступно'),
              if (item.durability != null)
                _t('Durability', 'Durabilidad', 'Прочность'): _number(
                  item.durability!,
                ),
              if (item.combat.critChance != null)
                _t(
                  'Critical chance',
                  'Probabilidad crítica',
                  'Шанс критического удара',
                ): '${_number(item.combat.critChance! * 100)}%',
              if (item.combat.blockDamageMultiplier != null)
                _t(
                  'Block damage multiplier',
                  'Multiplicador de daño al bloquear',
                  'Множитель урона при блокировании',
                ): _number(
                  item.combat.blockDamageMultiplier!,
                ),
              if (item.combat.blockStaminaCost != null)
                _t(
                  'Block stamina cost',
                  'Coste de aguante al bloquear',
                  'Расход выносливости при блокировании',
                ): _number(
                  item.combat.blockStaminaCost!,
                ),
              if (item.combat.blockStaminaRegenMultiplier != null)
                _t(
                  'Block stamina regeneration',
                  'Regeneración de aguante al bloquear',
                  'Восстановление выносливости при блокировании',
                ): _number(
                  item.combat.blockStaminaRegenMultiplier!,
                ),
              if (item.combat.ammoAttackSlots != null &&
                  item.combat.ammoAttackSlots! > 0)
                _t('Ammo modes', 'Modos de munición', 'Режимы боеприпасов'):
                    '${item.combat.ammoAttackSlots}',
              if (protection['flatDamageReductionRaw'] is num)
                _t('Defense', 'Defensa', 'Защита'): _number(
                  (protection['flatDamageReductionRaw'] as num).toDouble(),
                ),
            }.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${row.key}: ${row.value}'),
              ),
            if (item.attacks.isNotEmpty) ...[
              const Divider(),
              Text(
                _t('Attack profiles', 'Perfiles de ataque', 'Профили атаки'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...item.attacks.asMap().entries.map(
                (entry) => _EquipmentAttackCard(
                  attack: entry.value,
                  ordinal: entry.key + 1,
                  language: language,
                ),
              ),
            ],
            if (item.effectRelations.isNotEmpty || item.effects.isNotEmpty) ...[
              const Divider(),
              Text(
                _t(
                  'Verified effects',
                  'Efectos verificados',
                  'Подтверждённые эффекты',
                ),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (item.effectRelations.isNotEmpty)
                ..._uniqueEffectRelations(item.effectRelations).map(
                  (relation) => _EquipmentEffectRelationCard(
                    relation: relation,
                    language: language,
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.effects.map((effect) {
                    final effectType = normalizedTechnicalEffectId(effect);
                    return Chip(
                      avatar: IconBadge.asset(
                        assetName: UiMapper.effectIcon(effectType),
                        size: 18,
                        padding: EdgeInsets.zero,
                      ),
                      label: Text(
                        EquipmentPresentation.effectLabel(effect, language),
                      ),
                    );
                  }).toList(),
                ),
            ],
            FutureBuilder<CombatRecommendationCatalog>(
              future: CombatRecommendationRepository.load(),
              builder: (context, snapshot) {
                final catalog = snapshot.data;
                if (catalog == null) return const SizedBox.shrink();
                final weapon = catalog.weapons
                    .cast<CombatWeaponProfile?>()
                    .firstWhere(
                      (value) => value?.id == item.id,
                      orElse: () => null,
                    );
                final shield = catalog.shields
                    .cast<CombatShieldProfile?>()
                    .firstWhere(
                      (value) => value?.id == item.id,
                      orElse: () => null,
                    );
                final ammo = catalog.projectiles
                    .where((value) => value.launcherIds.contains(item.id))
                    .toList(growable: false);
                final compatibleWeapons = shield == null
                    ? const <CombatWeaponProfile>[]
                    : catalog.weapons
                          .where((value) => value.shieldCompatible)
                          .toList(growable: false);
                if (weapon == null && shield == null) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(),
                    Text(
                      _t(
                        'Advanced upgrades and compatibility',
                        'Mejoras y compatibilidad avanzadas',
                        'Улучшения и совместимость',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (weapon != null && weapon.tierTargets.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'Reachable Tiers',
                          'Niveles alcanzables',
                          'Доступные уровни',
                        ),
                      ),
                      for (final target in weapon.tierTargets)
                        Text(
                          '• ${_t('Tier', 'Nivel', 'Уровень')} ${target.tier}'
                          '${target.damageBonus == null ? '' : ' · +${_number(target.damageBonus!)} ${_t('damage', 'daño', 'урона')}'}'
                          '${target.costItem == null ? '' : ' · ${target.costItem} ×${target.costAmount ?? '?'}'}',
                        ),
                    ],
                    if (weapon != null && weapon.routes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_t('Maximum Enhancement', 'Mejora máxima', 'Максимальное улучшение')}: +${catalog.maxEnhancementLevel}',
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: weapon.routes
                            .map(
                              (route) => Chip(
                                label: Text(
                                  '${EquipmentPresentation.upgradeRoute(route.tag, language)} +${route.maxLevel}',
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (ammo.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'Compatible ammunition',
                          'Munición compatible',
                          'Совместимые боеприпасы',
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: ammo
                            .map(
                              (value) => Chip(
                                avatar: value.icon.isEmpty
                                    ? const Icon(Icons.arrow_outward, size: 16)
                                    : Image.asset(
                                        value.icon,
                                        width: 22,
                                        height: 22,
                                      ),
                                label: Text(
                                  EquipmentPresentation.cleanIdentifier(
                                    value.id,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (compatibleWeapons.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'Compatible weapons',
                          'Armas compatibles',
                          'Совместимое оружие',
                        ),
                      ),
                      Text(
                        '${compatibleWeapons.length} ${_t('verified one-handed weapons', 'armas de una mano verificadas', 'подтверждённых одноручных оружий')}',
                      ),
                    ],
                  ],
                );
              },
            ),
            const Divider(),
            Text(
              _t('Acquisition', 'Adquisición', 'Получение'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (item.acquisition.unresolved)
              Text(
                _t(
                  'Acquisition details are not yet verified.',
                  'Los datos de adquisición todavía no están verificados.',
                  'Данные о получении ещё не подтверждены.',
                ),
              )
            else ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.acquisition.methods
                    .map(
                      (method) => Chip(
                        label: Text(
                          EquipmentPresentation.acquisitionMethod(
                            method,
                            language,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              ...item.acquisition.recipes.map(
                (recipe) => _RecipeCard(recipe: recipe, language: language),
              ),
              if (item.acquisition.lootSourceReferences.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _t('Dropped by', 'Lo suelta', 'Выпадает из'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ...item.acquisition.lootSourceReferences.map(
                  (source) => OutlinedButton.icon(
                    icon: source.cardAsset.isEmpty
                        ? const Icon(Icons.pets_outlined)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.asset(
                              source.cardAsset,
                              width: 34,
                              height: 34,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.pets_outlined),
                            ),
                          ),
                    label: Text(
                      _t(
                        'Open creature card',
                        'Abrir ficha de criatura',
                        'Открыть карточку существа',
                      ),
                    ),
                    onPressed: () async {
                      final entries = await EnemyRepository.loadGame(
                        source.game,
                        language,
                      );
                      final entry = entries.cast<dynamic>().firstWhere(
                        (candidate) => candidate.id == source.creatureId,
                        orElse: () => null,
                      );
                      if (entry == null || !context.mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EnemyDetailScreen(
                            summary: entry,
                            initialGame: source.game,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
            if (item.repair.isNotEmpty) ...[
              const Divider(),
              Text(
                _t('Repair', 'Reparación', 'Ремонт'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              ...item.repair.map(
                (ingredient) => Text(
                  '• ${EquipmentPresentation.cleanIdentifier(ingredient.itemId)} ×${ingredient.count}',
                ),
              ),
            ],
            if (item.upgradeRoutes.isNotEmpty) ...[
              const Divider(),
              Text(
                _t('Upgrade routes', 'Rutas de mejora', 'Пути улучшения'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.upgradeRoutes
                    .map(
                      (route) => Chip(
                        label: Text(
                          EquipmentPresentation.upgradeRoute(route, language),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (mapAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  mapAction!();
                },
                icon: const Icon(Icons.map),
                label: Text(_t('Open map', 'Abrir mapa', 'Открыть карту')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _number(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);
}

class _ArmorSetDetailSheet extends StatelessWidget {
  const _ArmorSetDetailSheet({
    required this.set,
    required this.pieces,
    required this.language,
    required this.onPieceTap,
    this.mapAction,
  });

  final ArmorSet set;
  final List<EquipmentItem> pieces;
  final String language;
  final ValueChanged<EquipmentItem> onPieceTap;
  final VoidCallback? mapAction;

  String _t(String en, String es, String ru) => switch (language) {
    'es' => es,
    'ru' => ru,
    _ => en,
  };

  @override
  Widget build(BuildContext context) {
    final resolution = EntityAssetResolver.resolveArmorSet(set);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 72,
                  child: Image.asset(resolution.asset, fit: BoxFit.contain),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        set.name.resolve(language),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${pieces.length} ${_t('pieces', 'piezas', 'части')}',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('close-armor-set-detail'),
                  tooltip: _t('Close', 'Cerrar', 'Закрыть'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (resolution.source == 'primary_piece_fallback') ...[
              const SizedBox(height: 8),
              Text(
                _t(
                  'Representative image: verified primary piece.',
                  'Imagen representativa: pieza principal verificada.',
                  'Представительное изображение: основная проверенная часть.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (set.tiers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${_t('Tiers', 'Niveles', 'Уровни')}: ${set.tiers.join(', ')}',
              ),
            ],
            if (set.effects.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                _t('Set effects', 'Efectos del set', 'Эффекты комплекта'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: set.effects
                    .map(
                      (effect) => Chip(
                        avatar: IconBadge.asset(
                          assetName: UiMapper.effectIcon(
                            normalizedTechnicalEffectId(effect),
                          ),
                          size: 18,
                          padding: EdgeInsets.zero,
                        ),
                        label: Text(
                          EquipmentPresentation.effectLabel(effect, language),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const Divider(height: 28),
            Text(
              _t('Pieces', 'Piezas', 'Части'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...pieces.map(
              (piece) => Card(
                child: ListTile(
                  leading: SizedBox.square(
                    dimension: 44,
                    child: Image.asset(
                      EntityAssetResolver.resolveEquipment(piece).asset,
                      fit: BoxFit.contain,
                    ),
                  ),
                  title: Text(piece.name.resolve(language)),
                  subtitle: Text(
                    EquipmentPresentation.slotLabel(piece.slot, language),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onPieceTap(piece),
                ),
              ),
            ),
            if (mapAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  mapAction!();
                },
                icon: const Icon(Icons.map),
                label: Text(_t('Open map', 'Abrir mapa', 'Открыть карту')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProjectileDetailSheet extends StatelessWidget {
  const _ProjectileDetailSheet({
    required this.projectile,
    required this.language,
  });

  final ProjectileItem projectile;
  final String language;

  String _t(String en, String es, String ru) => switch (language) {
    'es' => es,
    'ru' => ru,
    _ => en,
  };

  String _number(double? value) => value == null
      ? _t('Unknown', 'Desconocido', 'Неизвестно')
      : value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final attack = projectile.attack;
    final best = [
      attack.base,
      attack.charged,
      attack.perfect,
    ].reduce((a, b) => (a.damage ?? -1) >= (b.damage ?? -1) ? a : b);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 64,
                  child: Image.asset(
                    projectile.icon,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.arrow_outward, size: 42),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    EquipmentPresentation.cleanIdentifier(projectile.id),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: _t('Close', 'Cerrar', 'Закрыть'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('${_t('Tier', 'Nivel', 'Уровень')}: ${projectile.tier}'),
            Text(
              '${_t('Family', 'Familia', 'Семейство')}: ${projectile.family}',
            ),
            Text(
              '${_t('Best damage', 'Mejor daño', 'Лучший урон')}: ${_number(best.damage)}',
            ),
            if (best.physical != null)
              Text(
                '${_t('Damage type', 'Tipo de daño', 'Тип урона')}: ${EquipmentPresentation.effectLabel(best.physical!, language)}',
              ),
            if (best.element != null)
              Text(
                '${_t('Element', 'Elemento', 'Элемент')}: ${EquipmentPresentation.effectLabel(best.element!, language)}',
              ),
            if (projectile.launcherIds.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                _t(
                  'Compatible launchers',
                  'Lanzadores compatibles',
                  'Совместимые пусковые устройства',
                ),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(projectile.launcherIds.join(' · ')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Attack profiles often repeat an identical verified effect. The library is
/// about the equipment, so present each effect once instead of repeating the
/// same card for every combo/profile row.
List<EquipmentEffectRelation> _uniqueEffectRelations(
  List<EquipmentEffectRelation> relations,
) {
  final byEffect = <String, EquipmentEffectRelation>{};
  for (final relation in relations) {
    final id = effectCatalogIdForTechnicalType(relation.effectId);
    final current = byEffect[id];
    // Prefer an inherent/equipped relation over an attack-only duplicate; it
    // describes the broadest source-backed availability for the same effect.
    if (current == null ||
        (current.origin == 'attack' && relation.origin != 'attack')) {
      byEffect[id] = relation;
    }
  }
  return byEffect.values.toList(growable: false);
}

class _EquipmentEffectRelationCard extends StatelessWidget {
  const _EquipmentEffectRelationCard({
    required this.relation,
    required this.language,
  });

  final EquipmentEffectRelation relation;
  final String language;

  String _t(String en, String es, String ru) => switch (language) {
    'es' => es,
    'ru' => ru,
    _ => en,
  };

  @override
  Widget build(BuildContext context) {
    final effectId = effectCatalogIdForTechnicalType(relation.effectId);
    final entry = effectCatalogEntryById(effectId);
    final values = <String>[
      _originLabel(relation.origin),
      if (relation.activation != null && relation.activation!.isNotEmpty)
        '${_t('Activation', 'Activación', 'Активация')}: ${EquipmentPresentation.cleanIdentifier(relation.activation!)}',
      if (relation.value != null)
        '${_t('Value', 'Valor', 'Значение')}: ${_number(relation.value!)}',
      if (relation.duration != null && relation.duration! > 0)
        '${_t('Duration', 'Duración', 'Длительность')}: ${_number(relation.duration!)} s',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: IconBadge.asset(
          assetName: UiMapper.effectIcon(effectId),
          size: 24,
          padding: EdgeInsets.zero,
        ),
        title: Text(
          entry?.name.resolve(language) ??
              EquipmentPresentation.effectLabel(relation.effectId, language),
        ),
        subtitle: Text(values.join(' · ')),
      ),
    );
  }

  String _originLabel(String origin) => switch (origin) {
    'upgrade' => _t('Upgrade route', 'Ruta de mejora', 'Путь улучшения'),
    'attack' => _t(
      'Attack-applied',
      'Aplicado por ataque',
      'Накладывается атакой',
    ),
    _ => _t('Equipped', 'Equipado', 'Экипировано'),
  };

  String _number(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(2);
}

class _EquipmentAttackCard extends StatelessWidget {
  const _EquipmentAttackCard({
    required this.attack,
    required this.ordinal,
    required this.language,
  });

  final EquipmentAttack attack;
  final int ordinal;
  final String language;

  String _t(String en, String es, String ru) => switch (language) {
    'es' => es,
    'ru' => ru,
    _ => en,
  };

  String _number(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final values = <String>[
      if (attack.damage != null)
        '${_t('Damage', 'Daño', 'Урон')}: ${_number(attack.damage!)}',
      if (attack.chargedDamage != null)
        '${_t('Charged', 'Cargado', 'Заряженный')}: ${_number(attack.chargedDamage!)}',
      if (attack.perfectChargedDamage != null)
        '${_t('Perfect charged', 'Carga perfecta', 'Идеальный заряд')}: ${_number(attack.perfectChargedDamage!)}',
      if (attack.stun != null) 'Stun: ${_number(attack.stun!)}',
      if (attack.poiseDamage != null)
        '${_t('Poise', 'Postura', 'Стойкость')}: ${_number(attack.poiseDamage!)}',
      if (attack.pushback != null && attack.pushback != 0)
        '${_t('Pushback', 'Empuje', 'Отбрасывание')}: ${_number(attack.pushback!)}',
      if (attack.stamina != null)
        '${_t('Stamina', 'Aguante', 'Выносливость')}: ${_number(attack.stamina!)}',
      if (attack.chargedStamina != null)
        '${_t('Charged stamina', 'Aguante cargado', 'Выносливость заряда')}: ${_number(attack.chargedStamina!)}',
      if (attack.range != null)
        '${_t('Range', 'Alcance', 'Дальность')}: ${_number(attack.range!)}',
      if (attack.chargedRange != null && attack.chargedRange != 0)
        '${_t('Charged range', 'Alcance cargado', 'Дальность заряда')}: ${_number(attack.chargedRange!)}',
      if (attack.chargeTime != null && attack.chargeTime != 0)
        '${_t('Charge time', 'Tiempo de carga', 'Время заряда')}: ${_number(attack.chargeTime!)} s',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_t('Profile', 'Perfil', 'Профиль')} $ordinal',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (values.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: values.map(Text.new).toList(),
              ),
            ],
            if (attack.physical != null || attack.element != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  if (attack.physical != null) _effectChip(attack.physical!),
                  if (attack.element != null) _effectChip(attack.element!),
                ],
              ),
            ],
            if (attack.statusEffects.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: attack.statusEffects
                    .map((effect) => _effectChip(effect.id))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _effectChip(String raw) {
    final effectType = normalizedTechnicalEffectId(raw);
    return Chip(
      avatar: IconBadge.asset(
        assetName: UiMapper.effectIcon(effectType),
        size: 18,
        padding: EdgeInsets.zero,
      ),
      label: Text(EquipmentPresentation.effectLabel(raw, language)),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.language});

  final EquipmentRecipe recipe;
  final String language;

  String _t(String en, String es, String ru) => switch (language) {
    'es' => es,
    'ru' => ru,
    _ => en,
  };

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 10),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            EquipmentPresentation.stationLabel(recipe.station, language),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (recipe.requirements.isEmpty)
            Text(
              _t(
                'Materials not listed',
                'Materiales no listados',
                'Материалы не указаны',
              ),
            )
          else
            ...recipe.requirements.map(
              (ingredient) => Text(
                '• ${EquipmentPresentation.cleanIdentifier(ingredient.itemId)} ×${ingredient.count}',
              ),
            ),
        ],
      ),
    ),
  );
}
