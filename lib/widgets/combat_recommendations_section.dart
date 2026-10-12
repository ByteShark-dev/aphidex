import 'package:flutter/material.dart';

import '../controllers/combat_recommendation_preferences_controller.dart';
import '../controllers/tutorial_controller.dart';
import '../data/content_repositories.dart';
import '../data/entity_asset_resolver.dart';
import '../models/combat_recommendation.dart';
import '../models/enemy.dart';
import '../models/equipment.dart';
import '../screens/equipment_library_screen.dart';
import '../services/recommendation_engine.dart';
import 'fallback_asset_image.dart';

class CombatRecommendationsSection extends StatefulWidget {
  final Enemy enemy;
  final TutorialTargetScope tutorialTargetScope;

  const CombatRecommendationsSection({
    super.key,
    required this.enemy,
    this.tutorialTargetScope = TutorialTargetScope.inlineDetail,
  });

  @override
  State<CombatRecommendationsSection> createState() =>
      _CombatRecommendationsSectionState();
}

class _CombatRecommendationsSectionState
    extends State<CombatRecommendationsSection> {
  late Future<List<CombatRecommendation>> _future;
  bool _expanded = false;
  int? _selectedTier;

  String get _language => Localizations.localeOf(context).languageCode;
  String _t(String en, String es, String ru) => _language == 'es'
      ? es
      : _language == 'ru'
      ? ru
      : en;

  @override
  void initState() {
    super.initState();
    if (widget.enemy.game != 'g2') {
      _future = Future.value(const []);
      return;
    }
    CombatRecommendationPreferencesController.instance.load();
    _future = _load();
  }

  Future<List<CombatRecommendation>> _load() async {
    final values = await Future.wait([
      CombatRecommendationRepository.load(),
      EquipmentRepository.load(),
    ]);
    return RecommendationEngine(
      combat: values[0] as CombatRecommendationCatalog,
      equipment: values[1] as EquipmentCatalog,
    ).recommend(widget.enemy);
  }

  Future<void> _expand() async {
    final preferences = CombatRecommendationPreferencesController.instance;
    if (!preferences.onboardingShown.value) {
      var count = preferences.weaponRecommendationCount.value;
      final selected = await showModalBottomSheet<int>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(
                    'Combat recommendations',
                    'Recomendaciones de combate',
                    'Боевые рекомендации',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    'Choose how many builds Aphidex should show. You can change this later in Settings.',
                    'Elige cuántas configuraciones mostrará Aphidex. Puedes cambiarlo después en Configuración.',
                    'Выберите количество сборок. Позже это можно изменить в настройках.',
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: _t(
                    'Weapons shown',
                    'Armas mostradas',
                    'Показано оружия',
                  ),
                  value: '$count',
                  child: Slider(
                    value: count.toDouble(),
                    min: 3,
                    max: 8,
                    divisions: 5,
                    label: '$count',
                    onChanged: (value) =>
                        setSheetState(() => count = value.round()),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, count),
                    child: Text(
                      _t(
                        'Show recommendations',
                        'Mostrar recomendaciones',
                        'Показать рекомендации',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (selected == null) return;
      await preferences.setCount(selected);
      await preferences.markOnboardingShown();
    }
    if (mounted) setState(() => _expanded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enemy.game != 'g2') return const SizedBox.shrink();
    return FutureBuilder<List<CombatRecommendation>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: SizedBox(height: 24),
            ),
          );
        }
        final all = snapshot.data ?? const <CombatRecommendation>[];
        if (all.isEmpty) return const SizedBox.shrink();
        final availableTiers =
            all.map((value) => value.loadout.buildTier).toSet().toList()
              ..sort();
        final filtered = _selectedTier == null
            ? all
                  .where(
                    (value) => value.loadout.buildTier <= widget.enemy.tier,
                  )
                  .toList()
            : all
                  .where((value) => value.loadout.buildTier == _selectedTier)
                  .toList();
        final fallback = filtered.isEmpty ? all : filtered;
        final limit = _expanded
            ? CombatRecommendationPreferencesController
                  .instance
                  .weaponRecommendationCount
                  .value
            : 1;
        return KeyedSubtree(
          key: TutorialController.instance.keyFor(
            tutorialAnchorDetailRecommendations,
            scope: widget.tutorialTargetScope,
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _t(
                            'Recommended weapons',
                            'Armas recomendadas',
                            'Рекомендуемое оружие',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: _expanded
                            ? _t('Collapse', 'Contraer', 'Свернуть')
                            : _t('Expand', 'Expandir', 'Развернуть'),
                        onPressed: _expanded
                            ? () => setState(() => _expanded = false)
                            : _expand,
                        icon: Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                        ),
                      ),
                    ],
                  ),
                  if (_expanded) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<int?>(
                        segments: [
                          ButtonSegment(
                            value: null,
                            label: Text(_t('Top', 'Principales', 'Лучшие')),
                          ),
                          for (final tier in availableTiers)
                            ButtonSegment(
                              value: tier,
                              label: Text(
                                '${_t('Tier', 'Nivel', 'Уровень')} $tier',
                              ),
                            ),
                        ],
                        selected: {_selectedTier},
                        onSelectionChanged: (value) =>
                            setState(() => _selectedTier = value.first),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  for (final recommendation in fallback.take(limit))
                    _RecommendationCard(
                      recommendation: recommendation,
                      language: _language,
                      onTap: () => _showDetails(recommendation),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDetails(CombatRecommendation value) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => _RecommendationDetails(
          recommendation: value,
          language: _language,
          onEquipmentTap: (id) {
            Navigator.pop(sheetContext);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EquipmentLibraryScreen(initialEquipmentId: id),
              ),
            );
          },
        ),
      );
}

class _RecommendationCard extends StatelessWidget {
  final CombatRecommendation recommendation;
  final String language;
  final VoidCallback onTap;

  const _RecommendationCard({
    required this.recommendation,
    required this.language,
    required this.onTap,
  });

  String _t(String en, String es, String ru) => language == 'es'
      ? es
      : language == 'ru'
      ? ru
      : en;

  @override
  Widget build(BuildContext context) {
    final loadout = recommendation.loadout;
    final color = switch (recommendation.damage.effectiveness) {
      EffectivenessLevel.excellent => Colors.green,
      EffectivenessLevel.strong => Colors.lightGreen,
      EffectivenessLevel.neutral => Colors.amber,
      EffectivenessLevel.weak => Colors.orange,
      EffectivenessLevel.ineffective => Colors.red,
      EffectivenessLevel.unknown => Colors.grey,
    };
    final bestZone = recommendation.damage.zones
        .where((value) => value.compatible)
        .fold<ZoneResult?>(
          null,
          (best, value) =>
              best == null || (value.damage ?? 0) > (best.damage ?? 0)
              ? value
              : best,
        );
    return Semantics(
      button: true,
      label:
          '${loadout.weapon.name.resolve(language)}, ${_t('Tier', 'Nivel', 'Уровень')} ${loadout.buildTier}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: .55)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: FallbackAssetImage.asset(
                  assetName: EntityAssetResolver.resolveEquipment(
                    loadout.weapon,
                  ).asset,
                  fallbackAssetName:
                      'assets/global/Creaturecard_Proximamente.webp',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loadout.weapon.name.resolve(language),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      [
                        '${_t('Tier', 'Nivel', 'Уровень')} ${loadout.buildTier}',
                        _effectivenessLabel(
                          recommendation.damage.effectiveness,
                        ),
                        if (bestZone != null)
                          '${_t('Aim', 'Objetivo', 'Цель')}: ${_humanize(bestZone.part)}',
                      ].join(' · '),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        if (loadout.route != null)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              _humanize(loadout.route!.tag.split('.').last),
                            ),
                          ),
                        if (loadout.projectile != null)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.arrow_outward, size: 15),
                            label: Text(_humanize(loadout.projectile!.id)),
                          ),
                        if (loadout.shield != null)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.shield, size: 15),
                            label: Text(loadout.shield!.name.resolve(language)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _effectivenessLabel(EffectivenessLevel value) => switch (value) {
    EffectivenessLevel.excellent => _t('Excellent', 'Excelente', 'Отлично'),
    EffectivenessLevel.strong => _t('Strong', 'Fuerte', 'Сильно'),
    EffectivenessLevel.neutral => _t('Effective', 'Eficaz', 'Эффективно'),
    EffectivenessLevel.weak => _t('Weak', 'Débil', 'Слабо'),
    EffectivenessLevel.ineffective => _t(
      'Ineffective',
      'Ineficaz',
      'Неэффективно',
    ),
    EffectivenessLevel.unknown => _t('Unknown', 'Desconocido', 'Неизвестно'),
  };
}

class _RecommendationDetails extends StatelessWidget {
  final CombatRecommendation recommendation;
  final String language;
  final ValueChanged<String> onEquipmentTap;

  const _RecommendationDetails({
    required this.recommendation,
    required this.language,
    required this.onEquipmentTap,
  });

  String _t(String en, String es, String ru) => language == 'es'
      ? es
      : language == 'ru'
      ? ru
      : en;

  @override
  Widget build(BuildContext context) {
    final value = recommendation;
    final loadout = value.loadout;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .72,
      minChildSize: .45,
      maxChildSize: .94,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          Text(
            loadout.weapon.name.resolve(language),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '${_t('Build Tier', 'Nivel de configuración', 'Уровень сборки')}: ${loadout.buildTier} · Enhancement +${loadout.enhancementLevel}',
          ),
          if (loadout.route != null)
            Text(
              '${_t('Route', 'Ruta', 'Путь')}: ${_humanize(loadout.route!.tag)}',
            ),
          const SizedBox(height: 14),
          _metric(
            _t(
              'Estimated general damage',
              'Daño general estimado',
              'Расчётный общий урон',
            ),
            value.damage.generalDamage,
          ),
          _metric(
            _t(
              'Best-zone damage',
              'Daño en la mejor zona',
              'Урон по лучшей зоне',
            ),
            value.damage.bestDamage,
          ),
          if (value.damage.zones.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _t('Hit zones', 'Zonas de impacto', 'Зоны попадания'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final zone in value.damage.zones)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 3),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      color: zone.compatible
                          ? Colors.green.withValues(alpha: .18)
                          : Colors.grey.withValues(alpha: .12),
                      child: Column(
                        children: [
                          Text(
                            _humanize(zone.part),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(zone.damage?.toStringAsFixed(1) ?? '?'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            _t(
              'Why this build',
              'Por qué esta configuración',
              'Почему эта сборка',
            ),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          for (final reason in value.reasons)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                reason.positive
                    ? Icons.add_circle_outline
                    : Icons.remove_circle_outline,
                color: reason.positive ? Colors.green : Colors.orange,
              ),
              title: Text(_reason(reason)),
            ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.gavel),
            title: Text(loadout.weapon.name.resolve(language)),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => onEquipmentTap(loadout.weapon.id),
          ),
          if (loadout.projectile != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.arrow_outward),
              title: Text(_humanize(loadout.projectile!.id)),
            ),
          if (loadout.shield != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shield),
              title: Text(loadout.shield!.name.resolve(language)),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => onEquipmentTap(loadout.shield!.id),
            ),
        ],
      ),
    );
  }

  Widget _metric(String label, double? value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Text(
      value?.toStringAsFixed(1) ?? _t('Unknown', 'Desconocido', 'Неизвестно'),
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );

  String _reason(RecommendationReason reason) => switch (reason.kind) {
    RecommendationReasonKind.weakness =>
      '${_t('Exploits weakness', 'Aprovecha la debilidad', 'Использует слабость')}: ${_humanize(reason.value)}',
    RecommendationReasonKind.resistance =>
      '${_t('Affected by resistance', 'Afectada por resistencia', 'Снижено сопротивлением')}: ${_humanize(reason.value)}',
    RecommendationReasonKind.immunity => _t(
      'The target is immune to a component',
      'El objetivo es inmune a un componente',
      'Цель невосприимчива к компоненту',
    ),
    RecommendationReasonKind.weakPoint =>
      '${_t('Compatible weak point', 'Punto débil compatible', 'Подходящее слабое место')}: ${_humanize(reason.value)}',
    RecommendationReasonKind.status =>
      '${_t('Applies status', 'Aplica estado', 'Накладывает эффект')}: ${_humanize(reason.value)}',
    RecommendationReasonKind.shield => _t(
      'Adds defensive utility without increasing damage',
      'Añade utilidad defensiva sin aumentar el daño',
      'Добавляет защиту без увеличения урона',
    ),
    RecommendationReasonKind.unknown => _t(
      'Some data remains unknown',
      'Algunos datos siguen sin conocerse',
      'Некоторые данные неизвестны',
    ),
  };
}

String _humanize(String value) => value
    .replaceAll(RegExp(r'[_:.]+'), ' ')
    .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
    .trim();
