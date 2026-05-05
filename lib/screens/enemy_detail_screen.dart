import 'package:flutter/material.dart';

import '../controllers/favorites_controller.dart';
import '../controllers/gold_controller.dart';
import '../controllers/monetization_controller.dart';
import '../controllers/tutorial_controller.dart';
import '../data/effect_catalog.dart';
import '../data/local_storage.dart';
import '../data/ui_mapper.dart';
import '../i18n/app_localizations.dart';
import '../models/enemy.dart';
import '../widgets/icon_badge.dart';
import '../widgets/inline_banner_ad_card.dart';
import '../widgets/overflow_marquee_text.dart';
import 'effect_codex_screen.dart';

class EnemyDetailScreen extends StatefulWidget {
  final Enemy enemy;
  final List<Enemy>? variants;
  final String? initialGame;

  const EnemyDetailScreen({
    super.key,
    required this.enemy,
    this.variants,
    this.initialGame,
  });

  @override
  State<EnemyDetailScreen> createState() => _EnemyDetailScreenState();
}

class _EnemyDetailScreenState extends State<EnemyDetailScreen> {
  late final List<Enemy> _variants;
  late int _selectedIndex;
  int _selectedPhaseIndex = 0;

  Enemy get _enemy => _variants[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _variants = [...(widget.variants ?? [widget.enemy])];
    _variants.sort((a, b) {
      if (a.game == b.game) {
        return (a.order ?? 999999).compareTo(b.order ?? 999999);
      }
      if (a.game == 'g1') {
        return -1;
      }
      if (b.game == 'g1') {
        return 1;
      }
      return a.game.compareTo(b.game);
    });
    _selectedIndex = _resolveInitialIndex();
  }

  int _resolveInitialIndex() {
    final preferredGame =
        widget.initialGame ??
        LocalStorage.getString(_variantPreferenceKey(widget.enemy.speciesKey)) ??
        widget.enemy.game;

    for (var i = 0; i < _variants.length; i++) {
      if (_variants[i].game == preferredGame) {
        return i;
      }
    }

    return 0;
  }

  bool _isGoldUnlocked(Set<String> goldIds) {
    return _enemy.defaultGold ||
        goldIds.contains(_enemy.id) ||
        (_enemy.goldLinkId != null && goldIds.contains(_enemy.goldLinkId));
  }

  bool _hasV2(Enemy enemy) =>
      enemy.health != null ||
      enemy.elementalWeaknesses.isNotEmpty ||
      enemy.damageWeaknesses.isNotEmpty ||
      enemy.resistancesV2.isNotEmpty ||
      enemy.resolvedWeakPoints.isNotEmpty ||
      enemy.attacks.isNotEmpty;

  bool _hasWikiContent(Enemy enemy) =>
      enemy.description != null ||
      enemy.environments.isNotEmpty ||
      enemy.respawnInfo != null ||
      enemy.combatStats != null ||
      enemy.loot.isNotEmpty ||
      enemy.advancedLootTable.isNotEmpty ||
      enemy.inflictsEffects.isNotEmpty ||
      enemy.inflicts.isNotEmpty ||
      enemy.specialTraits.isNotEmpty ||
      enemy.abilities.isNotEmpty ||
      enemy.behavior != null ||
      enemy.interactionWithPlayer != null ||
      enemy.interactionWithCreatures != null ||
      enemy.strategy != null;

  bool _hasCombatMoves(Enemy enemy) =>
      enemy.abilities.isNotEmpty ||
      enemy.attacks.isNotEmpty ||
      enemy.bossPhases.isNotEmpty;

  void _openEffectDetails(BuildContext context, String effectId) {
    openEffectCodex(context, initialEffectId: effectId);
  }

  Future<void> _selectVariant(String game) async {
    final nextIndex = _variants.indexWhere((enemy) => enemy.game == game);
    if (nextIndex == -1 || nextIndex == _selectedIndex) {
      return;
    }

    await LocalStorage.setString(_variantPreferenceKey(_enemy.speciesKey), game);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedIndex = nextIndex;
      _selectedPhaseIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = l10n.languageCode;
    final favorites = FavoritesController.instance;
    final gold = GoldController.instance;
    final weaknessesV1 = _enemy.weaknesses
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final resistancesV1 = _enemy.resistances
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final normalizedElementalWeaknesses = _enemy.elementalWeaknesses
        .where((bonus) => bonus.type != 'water')
        .toList();
    final normalizedDamageWeaknesses = [
      ..._enemy.damageWeaknesses,
      ..._enemy.elementalWeaknesses.where((bonus) => bonus.type == 'water'),
    ];
    final tutorial = TutorialController.instance;
    final tutorialEffectId = tutorial.tutorialEffectIdForEnemy(_enemy.id);
    final tutorialEffectKey = tutorialEffectId == null
        ? null
        : tutorial.keyFor(tutorialAnchorDetailEffect(tutorialEffectId));
    var tutorialAnchorAssigned = false;

    GlobalKey? consumeTutorialEffectKey(String effectId) {
      if (tutorialEffectKey == null ||
          tutorialAnchorAssigned ||
          tutorialEffectId != effectId) {
        return null;
      }
      tutorialAnchorAssigned = true;
      return tutorialEffectKey;
    }

    return Scaffold(
      appBar: AppBar(
        title: OverflowMarqueeText(
          _enemy.name.resolve(languageCode),
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        actions: [
          ValueListenableBuilder<Set<String>>(
            valueListenable: favorites.favorites,
            builder: (context, favIds, _) {
              final isFavorite = favIds.contains(_enemy.id);
              return IconButton(
                icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                onPressed: () => favorites.toggle(_enemy.id),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_variants.length > 1) ...[
              Container(
                key: tutorial.keyFor(tutorialAnchorDetailVariant),
                child: _VariantSwitcher(
                  selectedGame: _enemy.game,
                  onChanged: _selectVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              key: tutorial.keyFor(tutorialAnchorDetailSummary),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      _enemy.photo,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconBadge.asset(
                        assetName: UiMapper.dangerIcon(_enemy.danger),
                        size: 28,
                        padding: const EdgeInsets.all(5),
                        borderRadius: 13,
                      ),
                      const SizedBox(width: 10),
                      Image.asset(
                        UiMapper.tierIcon(
                          tier: _enemy.tier,
                          isBoss: false,
                        ),
                        width: 36,
                        height: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ValueListenableBuilder<Set<String>>(
                            valueListenable: gold.gold,
                            builder: (context, goldIds, _) {
                              final unlocked = _isGoldUnlocked(goldIds);
                              final canToggle = !_enemy.defaultGold;

                              return InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: canToggle
                                    ? () => gold.toggleLinked([
                                        _enemy.id,
                                        _enemy.goldLinkId,
                                      ])
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      width: 1.5,
                                      color: unlocked
                                          ? const Color(0xFFFFD54F)
                                          : Colors.black12,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.credit_card,
                                        size: 18,
                                        color: unlocked
                                            ? const Color(0xFFFFD54F)
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _enemy.defaultGold
                                              ? l10n.goldDefault
                                              : (unlocked
                                                    ? l10n.goldUnlocked
                                                    : l10n.goldMark),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_enemy.description != null) ...[
              _TextSection(
                title: l10n.descriptionTitle,
                value: _enemy.description!.resolve(languageCode),
              ),
              const SizedBox(height: 18),
            ],
            if (_enemy.health != null) ...[
              _HealthBar(health: _enemy.health!),
              const SizedBox(height: 18),
            ],
            if (_hasV2(_enemy)) ...[
              Container(
                key: tutorial.keyFor(tutorialAnchorDetailEffects),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (normalizedElementalWeaknesses.isNotEmpty) ...[
                      Text(
                        l10n.elementalWeakness,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      _BonusWrap(
                        bonuses: normalizedElementalWeaknesses,
                        tutorialEffectId: tutorialEffectId,
                        tutorialEffectKeyBuilder: consumeTutorialEffectKey,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (normalizedDamageWeaknesses.isNotEmpty) ...[
                      Text(
                        l10n.damageWeakness,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      _BonusWrap(
                        bonuses: normalizedDamageWeaknesses,
                        tutorialEffectId: tutorialEffectId,
                        tutorialEffectKeyBuilder: consumeTutorialEffectKey,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_enemy.resistancesV2.isNotEmpty) ...[
                      Text(
                        l10n.resistancesTitle,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      _BonusWrap(
                        bonuses: _enemy.resistancesV2,
                        dim: true,
                        tutorialEffectId: tutorialEffectId,
                        tutorialEffectKeyBuilder: consumeTutorialEffectKey,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (!_hasV2(_enemy)) ...[
              Container(
                key: tutorial.keyFor(tutorialAnchorDetailEffects),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.weaknessesTitle,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: weaknessesV1
                          .map(
                            (weakness) => Container(
                              key: consumeTutorialEffectKey(weakness),
                              child: InkWell(
                                key: ValueKey(
                                  'effect-legacy-weakness-$weakness',
                                ),
                                borderRadius: BorderRadius.circular(999),
                                onTap: () =>
                                    _openEffectDetails(context, weakness),
                                child: IconBadge.asset(
                                  assetName: UiMapper.effectIcon(weakness),
                                  size: 26,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.resistancesTitle,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: resistancesV1
                          .map(
                            (resistance) => Opacity(
                              opacity: 0.75,
                              child: Container(
                                key: consumeTutorialEffectKey(resistance),
                                child: InkWell(
                                  key: ValueKey(
                                    'effect-legacy-resistance-$resistance',
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: () =>
                                      _openEffectDetails(context, resistance),
                                  child: IconBadge.asset(
                                    assetName: UiMapper.effectIcon(resistance),
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (_enemy.inflictsEffects.isNotEmpty ||
                _enemy.inflicts.isNotEmpty ||
                _enemy.specialTraits.isNotEmpty) ...[
              _InflictsTraitsSection(
                inflictsEffects: _enemy.inflictsEffects,
                inflicts: _enemy.inflicts,
                traits: _enemy.specialTraits,
                l10n: l10n,
                languageCode: languageCode,
              ),
              const SizedBox(height: 18),
            ],
            if (_enemy.resolvedWeakPoints.isNotEmpty) ...[
              Text(
                l10n.weakPointTitle,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _enemy.resolvedWeakPoints.length; i++) ...[
                _WeakPointCard(
                  info: _enemy.resolvedWeakPoints[i],
                  tutorialEffectId: i == 0 ? tutorialEffectId : null,
                  tutorialEffectKeyBuilder: consumeTutorialEffectKey,
                ),
                if (i != _enemy.resolvedWeakPoints.length - 1)
                  const SizedBox(height: 10),
              ],
              const SizedBox(height: 18),
            ],
            if (_enemy.combatStats != null) ...[
              _CombatStatsSection(
                stats: _enemy.combatStats!,
                fallbackHealth: _enemy.health?.value,
                l10n: l10n,
                languageCode: languageCode,
              ),
              const SizedBox(height: 18),
            ],
            if (_enemy.bossPhases.isNotEmpty) ...[
              _BossPhasesSection(
                enemy: _enemy,
                l10n: l10n,
                languageCode: languageCode,
                selectedIndex: _selectedPhaseIndex.clamp(
                  0,
                  _enemy.bossPhases.length - 1,
                ),
                onChanged: (index) =>
                    setState(() => _selectedPhaseIndex = index),
              ),
              const SizedBox(height: 18),
            ],
            if (_enemy.environments.isNotEmpty || _enemy.respawnInfo != null) ...[
              _CollapsibleCardSection(
                title: l10n.environmentRespawnTitle,
                child: _EnvironmentRespawnSection(
                  enemy: _enemy,
                  l10n: l10n,
                  languageCode: languageCode,
                  embedded: true,
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (_enemy.loot.isNotEmpty || _enemy.advancedLootTable.isNotEmpty) ...[
              _CollapsibleCardSection(
                title: l10n.lootTitle,
                child: _LootSection(
                  loot: _enemy.loot,
                  advancedLoot: _enemy.advancedLootTable,
                  l10n: l10n,
                  languageCode: languageCode,
                  embedded: true,
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (_enemy.rewardUnlocks.isNotEmpty) ...[
              _RewardUnlocksSection(
                rewards: _enemy.rewardUnlocks,
                title: l10n.rewardsUnlocksTitle,
                languageCode: languageCode,
              ),
              const SizedBox(height: 18),
            ],
            if (_hasCombatMoves(_enemy) && _enemy.bossPhases.isEmpty) ...[
              _CollapsibleCardSection(
                title: _enemy.abilities.isNotEmpty
                    ? l10n.abilitiesTitle
                    : l10n.attacksTitle,
                child: _enemy.abilities.isNotEmpty
                    ? _AbilitiesSection(
                        abilities: _enemy.abilities,
                        l10n: l10n,
                        languageCode: languageCode,
                        embedded: true,
                      )
                    : _AttackListSection(
                        attacks: _enemy.attacks,
                        embedded: true,
                      ),
              ),
              const SizedBox(height: 18),
            ],
            if (_enemy.behavior != null) ...[
              _TextSection(
                title: l10n.behaviorTitle,
                value: _enemy.behavior!.resolve(languageCode),
              ),
              const SizedBox(height: 18),
            ],
            if (_enemy.interactionWithPlayer != null) ...[
              _TextSection(
                title: l10n.interactionWithPlayerTitle,
                value: _enemy.interactionWithPlayer!.resolve(languageCode),
              ),
              const SizedBox(height: 18),
            ],
            if (_enemy.interactionWithCreatures != null) ...[
              _TextSection(
                title: l10n.interactionWithCreaturesTitle,
                value: _enemy.interactionWithCreatures!.resolve(languageCode),
              ),
              const SizedBox(height: 18),
            ],
            if (_enemy.strategy != null) ...[
              _TextSection(
                title: l10n.strategyTitle,
                value: _enemy.strategy!.resolve(languageCode),
              ),
              const SizedBox(height: 18),
            ],
            if (!_hasWikiContent(_enemy)) ...[
              Text(
                l10n.upcomingTitle,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(l10n.upcomingItems),
            ],
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: MonetizationController.instance.adsRemoved,
              builder: (context, _, child) {
                if (!MonetizationController.instance.shouldShowAds) {
                  return const SizedBox.shrink();
                }
                return child!;
              },
              child: const InlineBannerAdCard(),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantSwitcher extends StatelessWidget {
  final String selectedGame;
  final ValueChanged<String> onChanged;

  const _VariantSwitcher({
    required this.selectedGame,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'g1', label: Text(l10n.groundedOne)),
        ButtonSegment(value: 'g2', label: Text(l10n.groundedTwo)),
      ],
      selected: {selectedGame},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _TextSection extends StatelessWidget {
  final String title;
  final String value;

  const _TextSection({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Text(value),
        ),
      ],
    );
  }
}

class _BossPhasesSection extends StatelessWidget {
  final Enemy enemy;
  final AppLocalizations l10n;
  final String languageCode;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _BossPhasesSection({
    required this.enemy,
    required this.l10n,
    required this.languageCode,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final phases = enemy.bossPhases;
    final phase = phases[selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.bossPhasesTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(phases.length, (index) {
              final item = phases[index];
              return Padding(
                padding: EdgeInsets.only(right: index == phases.length - 1 ? 0 : 8),
                child: ChoiceChip(
                  label: Text(item.label.resolve(languageCode)),
                  selected: index == selectedIndex,
                  onSelected: (_) => onChanged(index),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (phase.startsAtHealthPct != null) ...[
                Text(
                  '${l10n.phaseStartsAtLabel}: ${phase.startsAtHealthPct}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
              ],
              if (phase.trigger != null) ...[
                Text(
                  l10n.phaseTriggerLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(phase.trigger!.resolve(languageCode)),
                const SizedBox(height: 10),
              ],
              if (phase.summary != null) ...[
                Text(
                  l10n.phaseSummaryLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(phase.summary!.resolve(languageCode)),
                const SizedBox(height: 10),
              ],
              if (phase.aggressionChange != null) ...[
                Text(
                  l10n.phaseAggressionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(phase.aggressionChange!.resolve(languageCode)),
                const SizedBox(height: 10),
              ],
              if (phase.newPatterns.isNotEmpty) ...[
                Text(
                  l10n.newPatternsTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ...phase.newPatterns.map(
                  (pattern) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${pattern.resolve(languageCode)}'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (phase.elementalWeaknesses.isNotEmpty) ...[
                Text(
                  l10n.elementalWeakness,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _BonusWrap(bonuses: phase.elementalWeaknesses),
                const SizedBox(height: 10),
              ],
              if (phase.damageWeaknesses.isNotEmpty) ...[
                Text(
                  l10n.damageWeakness,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _BonusWrap(bonuses: phase.damageWeaknesses),
                const SizedBox(height: 10),
              ],
              if (phase.resistancesV2.isNotEmpty) ...[
                Text(
                  l10n.resistancesTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _BonusWrap(bonuses: phase.resistancesV2, dim: true),
                const SizedBox(height: 10),
              ],
              if (phase.inflictsEffects.isNotEmpty || phase.specialTraits.isNotEmpty) ...[
                _InflictsTraitsSection(
                  inflictsEffects: phase.inflictsEffects,
                  inflicts: const [],
                  traits: phase.specialTraits,
                  l10n: l10n,
                  languageCode: languageCode,
                ),
                const SizedBox(height: 10),
              ],
              if (phase.abilities.isNotEmpty) ...[
                _AbilitiesSection(
                  abilities: phase.abilities,
                  l10n: l10n,
                  languageCode: languageCode,
                  embedded: true,
                ),
              ] else if (phase.attacks.isNotEmpty) ...[
                _AttackListSection(attacks: phase.attacks, embedded: true),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RewardUnlocksSection extends StatelessWidget {
  final List<RewardUnlockInfo> rewards;
  final String title;
  final String languageCode;

  const _RewardUnlocksSection({
    required this.rewards,
    required this.title,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            children: rewards
                .map(
                  (reward) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconBadge.asset(
                          assetName: UiMapper.rewardIcon(reward.id),
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reward.name.resolve(languageCode),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (reward.detail != null) ...[
                                const SizedBox(height: 2),
                                Text(reward.detail!.resolve(languageCode)),
                              ],
                            ],
                          ),
                        ),
                        if (reward.amount != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              'x${reward.amount}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _EnvironmentRespawnSection extends StatelessWidget {
  final Enemy enemy;
  final AppLocalizations l10n;
  final String languageCode;
  final bool embedded;

  const _EnvironmentRespawnSection({
    required this.enemy,
    required this.l10n,
    required this.languageCode,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          Text(
            l10n.environmentRespawnTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (enemy.environments.isNotEmpty) ...[
                Text(
                  l10n.environmentsTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: enemy.environments
                      .map(
                        (environment) => Chip(
                          label: Text(environment.resolve(languageCode)),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (enemy.respawnInfo != null) ...[
                if (enemy.environments.isNotEmpty) const SizedBox(height: 12),
                Text(
                  l10n.respawnTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(enemy.respawnInfo!.resolve(languageCode)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CombatStatsSection extends StatelessWidget {
  final CombatStats stats;
  final int? fallbackHealth;
  final AppLocalizations l10n;
  final String languageCode;

  const _CombatStatsSection({
    required this.stats,
    required this.fallbackHealth,
    required this.l10n,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[];
    final healthValue = stats.health ?? fallbackHealth;
    if (healthValue != null) {
      rows.add(MapEntry(l10n.healthTitle, '$healthValue HP'));
    }
    if (stats.stunThreshold != null) {
      rows.add(MapEntry(l10n.stunThresholdLabel, '${stats.stunThreshold}'));
    }
    if (stats.stunCooldownSeconds != null) {
      rows.add(
        MapEntry(
          l10n.stunCooldownLabel,
          '${stats.stunCooldownSeconds} ${l10n.secondsShortLabel}',
        ),
      );
    }
    if (stats.attackDamageSummary != null) {
      rows.add(
        MapEntry(
          l10n.attackDamageLabel,
          stats.attackDamageSummary!.resolve(languageCode),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.statsTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            children: rows
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 132,
                          child: Text(
                            row.key,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(row.value)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _LootSection extends StatelessWidget {
  final List<LootEntry> loot;
  final List<AdvancedLootEntry> advancedLoot;
  final AppLocalizations l10n;
  final String languageCode;
  final bool embedded;

  const _LootSection({
    required this.loot,
    this.advancedLoot = const [],
    required this.l10n,
    required this.languageCode,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<LootEntry>>{};
    for (final entry in loot) {
      grouped.putIfAbsent(entry.section, () => <LootEntry>[]).add(entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          Text(
            l10n.lootTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...grouped.entries
                  .map(
                    (section) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.lootSectionLabel(section.key),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          ...section.value.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(entry.item.resolve(languageCode)),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('${entry.minCount}-${entry.maxCount}'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (advancedLoot.isNotEmpty) ...[
                Text(
                  l10n.advancedLootTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...advancedLoot.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(entry.item.resolve(languageCode))),
                            const SizedBox(width: 8),
                            Text(entry.countLabel),
                            const SizedBox(width: 12),
                            Text('${entry.chancePct}%'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: entry.chancePct.clamp(0, 100) / 100,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        if (entry.notes != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.notes!.resolve(languageCode),
                            style: TextStyle(color: Theme.of(context).hintColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InflictsTraitsSection extends StatelessWidget {
  final List<String> inflictsEffects;
  final List<LocalizedText> inflicts;
  final List<LocalizedText> traits;
  final AppLocalizations l10n;
  final String languageCode;

  const _InflictsTraitsSection({
    required this.inflictsEffects,
    required this.inflicts,
    required this.traits,
    required this.l10n,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final values = [
      ...inflicts.map((item) => item.resolve(languageCode)),
      ...traits.map((item) => item.resolve(languageCode)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.inflictsTraitsTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (inflictsEffects.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: inflictsEffects
                .map(
                  (effectId) => InkWell(
                    key: ValueKey('inflicts-effect-$effectId'),
                    borderRadius: BorderRadius.circular(999),
                    onTap: () =>
                        openEffectCodex(context, initialEffectId: effectId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconBadge.asset(
                            assetName: UiMapper.effectIcon(effectId),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            effectCatalogEntryById(effectId)?.name.resolve(
                                  languageCode,
                                ) ??
                                canonicalEffectId(effectId),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          if (values.isNotEmpty) const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (value) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(value),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _AbilitiesSection extends StatelessWidget {
  final List<AbilityInfo> abilities;
  final AppLocalizations l10n;
  final String languageCode;
  final bool embedded;

  const _AbilitiesSection({
    required this.abilities,
    required this.l10n,
    required this.languageCode,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          Text(l10n.abilitiesTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
        ],
        ...abilities.map(
          (ability) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ability.name.resolve(languageCode),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AbilityFlagChip(
                      label: l10n.blockableLabel,
                      value: ability.blockable,
                      l10n: l10n,
                    ),
                    _AbilityFlagChip(
                      label: l10n.breaksGuardLabel,
                      value: ability.breaksGuard,
                      l10n: l10n,
                    ),
                    _AbilityFlagChip(
                      label: l10n.staggersLabel,
                      value: ability.staggers,
                      l10n: l10n,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(ability.description.resolve(languageCode)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AttackListSection extends StatelessWidget {
  final List<EnemyAttack> attacks;
  final bool embedded;

  const _AttackListSection({
    required this.attacks,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          Text(
            context.l10n.attacksTitle,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
        ],
        ...attacks.map((attack) => _AttackTile(attack: attack)),
      ],
    );
  }
}

class _CollapsibleCardSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _CollapsibleCardSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: ExpansionTile(
        key: PageStorageKey('expand-$title'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        initiallyExpanded: false,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        children: [child],
      ),
    );
  }
}

class _AbilityFlagChip extends StatelessWidget {
  final String label;
  final bool? value;
  final AppLocalizations l10n;

  const _AbilityFlagChip({
    required this.label,
    required this.value,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text('$label: ${l10n.boolLabel(value)}'),
    );
  }
}

class _HealthBar extends StatelessWidget {
  final HealthInfo health;

  const _HealthBar({required this.health});

  Color _ratingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.purple;
      case 5:
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rating = health.rating.clamp(1, 5);
    final fillColor = _ratingColor(rating);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.healthTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final filled = index < rating;
            return Expanded(
              child: Container(
                height: 10,
                margin: EdgeInsets.only(right: index == 4 ? 0 : 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: filled ? fillColor : Colors.black12,
                ),
              ),
            );
          }),
        ),
        if (health.value != null) ...[
          const SizedBox(height: 6),
          Text(
            '${health.value} HP',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ],
      ],
    );
  }
}

String formatBonusLabel(
  AppLocalizations l10n,
  BonusInfo bonus, {
  bool dim = false,
}) {
  if (dim && bonus.bonusPct == 100) {
    return l10n.immuneLabel;
  }

  final sign = dim ? '-' : '+';
  return '$sign${bonus.bonusPct}%';
}

class _BonusWrap extends StatelessWidget {
  final List<BonusInfo> bonuses;
  final bool dim;
  final String? tutorialEffectId;
  final GlobalKey? Function(String effectId)? tutorialEffectKeyBuilder;

  const _BonusWrap({
    required this.bonuses,
    this.dim = false,
    this.tutorialEffectId,
    this.tutorialEffectKeyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: bonuses.map((bonus) {
        final icon = UiMapper.effectIcon(bonus.type);
        return Opacity(
          opacity: dim ? 0.75 : 1,
          child: Container(
            key: tutorialEffectId == null
                ? null
                : tutorialEffectKeyBuilder?.call(bonus.type),
            child: InkWell(
              key: ValueKey(
                'effect-bonus-${dim ? 'resistance' : 'weakness'}-${bonus.type}',
              ),
              borderRadius: BorderRadius.circular(999),
              onTap: () =>
                  openEffectCodex(context, initialEffectId: bonus.type),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconBadge.asset(assetName: icon, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      formatBonusLabel(l10n, bonus, dim: dim),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _WeakPointCard extends StatelessWidget {
  final WeakPointInfo info;
  final String? tutorialEffectId;
  final GlobalKey? Function(String effectId)? tutorialEffectKeyBuilder;

  const _WeakPointCard({
    required this.info,
    this.tutorialEffectId,
    this.tutorialEffectKeyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final partIcon = UiMapper.weakPointIcon(info.part);
    final damageIds = UiMapper.susceptibleDamageEffectIds(
      info.susceptibleDamage,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(partIcon, width: 28, height: 28),
              const SizedBox(width: 10),
              Text(
                l10n.weakPointPartLabel(info.part),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: damageIds
                    .map(
                      (effectId) => Container(
                        key: tutorialEffectId == null
                            ? null
                            : tutorialEffectKeyBuilder?.call(effectId),
                        child: InkWell(
                          key: ValueKey('weakpoint-effect-$effectId'),
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => openEffectCodex(
                            context,
                            initialEffectId: effectId,
                          ),
                          child: IconBadge.asset(
                            assetName: UiMapper.effectIcon(effectId),
                            size: 22,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.susceptibleDamageLabel(info.susceptibleDamage),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttackTile extends StatelessWidget {
  final EnemyAttack attack;

  const _AttackTile({required this.attack});

  String? _resolve(LocalizedText? text, String languageCode) {
    if (text == null) {
      return null;
    }
    final value = text.resolve(languageCode);
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = l10n.languageCode;
    final tell = _resolve(attack.tell, languageCode);
    final howToAvoid = _resolve(attack.howToAvoid, languageCode);
    final notes = _resolve(attack.notes, languageCode);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: ExpansionTile(
        title: Text(
          attack.name.resolve(languageCode),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: attack.tags.isEmpty
            ? null
            : Text(attack.tags.map(l10n.attackTagLabel).join(' \u2022 ')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          if (tell != null) _kv(l10n.attackTell, tell),
          if (howToAvoid != null) _kv(l10n.attackAvoid, howToAvoid),
          if (notes != null) _kv(l10n.attackNotes, notes),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

String _variantPreferenceKey(String speciesKey) => 'species_variant:$speciesKey';
