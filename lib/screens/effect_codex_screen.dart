import 'package:flutter/material.dart';

import '../controllers/tutorial_controller.dart';
import '../data/content_repositories.dart';
import '../data/entity_asset_resolver.dart';
import '../data/effect_catalog.dart';
import '../data/equipment_effect_index.dart';
import '../data/equipment_presentation.dart';
import '../data/ui_mapper.dart';
import '../i18n/app_localizations.dart';
import '../models/equipment.dart';
import 'equipment_library_screen.dart';

Future<void> openEffectCodex(BuildContext context, {String? initialEffectId}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EffectCodexScreen(initialEffectId: initialEffectId),
    ),
  );
}

Future<void> showEffectInfoSheet(
  BuildContext context, {
  required String effectId,
}) async {
  final entry = effectCatalogEntryById(effectId);
  if (entry == null) {
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _EffectInfoSheet(entry: entry),
  );
}

class EffectCodexScreen extends StatefulWidget {
  final String? initialEffectId;
  final bool autoScrollToInitialEffect;
  final Future<EquipmentEffectIndex>? equipmentIndex;
  final void Function(BuildContext context, EquipmentItem item)?
  onOpenEquipment;

  const EffectCodexScreen({
    super.key,
    this.initialEffectId,
    this.autoScrollToInitialEffect = true,
    this.equipmentIndex,
    this.onOpenEquipment,
  });

  @override
  State<EffectCodexScreen> createState() => _EffectCodexScreenState();
}

class _EffectCodexScreenState extends State<EffectCodexScreen> {
  late final String? _highlightedId;
  late final Map<String, GlobalKey> _entryKeys;
  late final Future<EquipmentEffectIndex> _equipmentIndex;

  @override
  void initState() {
    super.initState();
    _highlightedId = widget.initialEffectId == null
        ? null
        : effectCatalogEntryById(widget.initialEffectId!)?.id;
    _entryKeys = {
      for (final entry in effectCatalogEntries) entry.id: GlobalKey(),
    };
    _equipmentIndex =
        widget.equipmentIndex ??
        EquipmentRepository.load().then(EquipmentEffectIndex.fromCatalog);

    if (_highlightedId != null && widget.autoScrollToInitialEffect) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToHighlighted(),
      );
    }
  }

  Future<void> _scrollToHighlighted() async {
    final targetId = _highlightedId;
    if (targetId == null) {
      return;
    }

    final targetContext = _entryKeys[targetId]?.currentContext;
    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.effectCodexTitle)),
      body: FutureBuilder<EquipmentEffectIndex>(
        future: _equipmentIndex,
        builder: (context, snapshot) => SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 12),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.effectCodexSubtitle,
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: 18),
                for (final category in EffectCategory.values) ...[
                  _EffectSection(
                    title: l10n.effectCategoryLabel(category.name),
                    entries: effectCatalogEntries
                        .where((entry) => entry.category == category)
                        .toList(),
                    highlightedId: _highlightedId,
                    entryKeys: _entryKeys,
                    equipmentIndex: snapshot.data,
                    onOpenEquipment: widget.onOpenEquipment,
                  ),
                  const SizedBox(height: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EffectSection extends StatelessWidget {
  final String title;
  final List<EffectCatalogEntry> entries;
  final String? highlightedId;
  final Map<String, GlobalKey> entryKeys;
  final EquipmentEffectIndex? equipmentIndex;
  final void Function(BuildContext context, EquipmentItem item)?
  onOpenEquipment;

  const _EffectSection({
    required this.title,
    required this.entries,
    required this.highlightedId,
    required this.entryKeys,
    required this.equipmentIndex,
    required this.onOpenEquipment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              key: entryKeys[entry.id],
              child: _EffectCard(
                tutorialCardKey: TutorialController.instance.keyFor(
                  tutorialAnchorEffectCard(entry.id),
                  scope: TutorialTargetScope.codex,
                ),
                tutorialEquipmentKey: TutorialController.instance.keyFor(
                  tutorialAnchorEffectEquipment(entry.id),
                  scope: TutorialTargetScope.codex,
                ),
                entry: entry,
                isHighlighted: highlightedId == entry.id,
                equipment: equipmentIndex?.forEffect(entry.id) ?? const [],
                onOpenEquipment: onOpenEquipment,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EffectCard extends StatelessWidget {
  final EffectCatalogEntry entry;
  final bool isHighlighted;
  final GlobalKey tutorialCardKey;
  final GlobalKey tutorialEquipmentKey;
  final List<EquipmentEffectMatch> equipment;
  final void Function(BuildContext context, EquipmentItem item)?
  onOpenEquipment;

  const _EffectCard({
    required this.entry,
    required this.isHighlighted,
    required this.tutorialCardKey,
    required this.tutorialEquipmentKey,
    required this.equipment,
    required this.onOpenEquipment,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = l10n.languageCode;
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = isHighlighted ? colorScheme.primary : Colors.black12;

    return Container(
      key: tutorialCardKey,
      child: AnimatedContainer(
        key: ValueKey('effect-card-${entry.id}'),
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isHighlighted ? 2 : 1),
          color: isHighlighted
              ? colorScheme.primary.withValues(alpha: 0.08)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  UiMapper.effectIcon(entry.id),
                  width: 30,
                  height: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name.resolve(languageCode),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.effectCategoryLabel(entry.category.name),
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(entry.description.resolve(languageCode)),
            const SizedBox(height: 14),
            Container(
              key: tutorialEquipmentKey,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.effectEquipmentTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  if (equipment.isEmpty)
                    Text(
                      _effectText(
                        languageCode,
                        'No weapons or shields are currently linked to this effect.',
                        'Aún no hay armas ni escudos vinculados a este efecto.',
                        'С этим эффектом пока не связаны оружие или щиты.',
                      ),
                    )
                  else ...[
                    const SizedBox(height: 4),
                    ...equipment.map(
                      (match) => _RelatedEquipmentTile(
                        match: match,
                        languageCode: languageCode,
                        onOpenEquipment: onOpenEquipment,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelatedEquipmentTile extends StatelessWidget {
  const _RelatedEquipmentTile({
    required this.match,
    required this.languageCode,
    required this.onOpenEquipment,
  });

  final EquipmentEffectMatch match;
  final String languageCode;
  final void Function(BuildContext context, EquipmentItem item)?
  onOpenEquipment;

  @override
  Widget build(BuildContext context) {
    final item = match.item;
    final icon = EntityAssetResolver.resolveEquipment(item).asset;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: SizedBox.square(
          dimension: 38,
          child: Image.asset(
            icon,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(Icons.inventory_2_outlined),
          ),
        ),
        title: Text(item.name.resolve(languageCode)),
        subtitle: Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            Text(
              EquipmentPresentation.subtypeLabel(
                item.normalizedSubtype,
                languageCode,
              ),
            ),
            for (final origin in match.origins)
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(_effectOriginLabel(origin, languageCode)),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final opener = onOpenEquipment;
          if (opener != null) {
            opener(context, item);
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  EquipmentLibraryScreen(initialEquipmentId: item.id),
            ),
          );
        },
      ),
    );
  }
}

String _effectOriginLabel(String origin, String language) => switch (origin) {
  'upgrade' => _effectText(language, 'Upgrade', 'Mejora', 'Улучшение'),
  'attack' => _effectText(language, 'Attack', 'Ataque', 'Атака'),
  _ => _effectText(language, 'Equipped', 'Equipado', 'Экипировано'),
};

String _effectText(String language, String en, String es, String ru) =>
    switch (language) {
      'es' => es,
      'ru' => ru,
      _ => en,
    };

class _EffectInfoSheet extends StatelessWidget {
  final EffectCatalogEntry entry;

  const _EffectInfoSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = l10n.languageCode;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Image.asset(
                    UiMapper.effectIcon(entry.id),
                    width: 28,
                    height: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name.resolve(languageCode),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.effectCategoryLabel(entry.category.name),
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(entry.description.resolve(languageCode)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final parentContext = navigator.context;
                navigator.pop();
                await openEffectCodex(parentContext, initialEffectId: entry.id);
              },
              icon: const Icon(Icons.menu_book_rounded),
              label: Text(l10n.effectCodexTitle),
            ),
          ),
        ],
      ),
    );
  }
}
