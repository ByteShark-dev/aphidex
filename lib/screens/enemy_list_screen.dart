import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/favorites_controller.dart';
import '../controllers/gold_controller.dart';
import '../controllers/monetization_controller.dart';
import '../controllers/review_prompt_controller.dart';
import '../controllers/tutorial_controller.dart';
import '../data/enemy_repository.dart';
import '../data/enemy_variants.dart';
import '../data/local_storage.dart';
import '../data/ui_mapper.dart';
import '../i18n/app_localizations.dart';
import '../models/enemy_index_entry.dart';
import '../widgets/icon_badge.dart';
import '../widgets/fallback_asset_image.dart';
import '../widgets/inline_banner_ad_card.dart';
import '../widgets/overflow_marquee_text.dart';
import '../scanner/creature_scanner_page.dart';
import 'enemy_detail_screen.dart';
import 'effect_codex_screen.dart';
import 'settings_screen.dart';

enum SortMode { defaultOrder, name, danger, tier }

enum SortMenuAction { toggleDirection, defaultOrder, name, danger, tier }

enum GamePick { all, g1, g2 }

enum EnemyDisplayGroup {
  neutral,
  buggy,
  orc,
  angry,
  harmless,
  ogrr,
  aggressive,
  peaceful,
  anomaly,
  other,
}

const int _flatInlineAdAfterTile = 16;
const int _minTilesForFlatInlineAd = 22;
const int _sectionInlineAdAfterTile = 6;
const int _minTilesForSectionInlineAd = 11;

Color gameColorForPick(GamePick value) {
  switch (value) {
    case GamePick.all:
      return const Color(0xFF35586E);
    case GamePick.g1:
      return const Color(0xFF5B2B2B);
    case GamePick.g2:
      return const Color(0xFF305941);
  }
}

Color gameAccentForPick(GamePick value) {
  switch (value) {
    case GamePick.all:
      return const Color(0xFF3D8CFF);
    case GamePick.g1:
      return const Color(0xFFD35454);
    case GamePick.g2:
      return const Color(0xFF44A36A);
  }
}

List<Color> gameHeaderGradientForPick(GamePick value, Color background) {
  final base = gameColorForPick(value);
  final accent = gameAccentForPick(value);
  final outer = Color.lerp(background, base, 0.06)!;
  final inner = Color.lerp(background, base, 0.18)!;
  final center = Color.lerp(base, accent, 0.58)!;
  return [outer, inner, center, inner, outer];
}

class EnemyListScreen extends StatefulWidget {
  const EnemyListScreen({super.key});

  @override
  State<EnemyListScreen> createState() => _EnemyListScreenState();
}

class _EnemyListScreenState extends State<EnemyListScreen> {
  SortMode sortMode = SortMode.defaultOrder;
  GamePick gamePick = GamePick.g1;
  bool sortDescending = false;
  String query = '';
  bool filterFavorites = false;
  bool filterGold = false;
  final Set<String> tierFilters = <String>{};
  final Set<String> classFilters = <String>{};
  final Set<String> dangerFilters = <String>{};

  late final TextEditingController _searchController;

  static const _kLegacyFilter = 'ui_filter';
  static const _kFilterFavorites = 'ui_filter_favorites';
  static const _kFilterGold = 'ui_filter_gold';
  static const _kTierFilters = 'ui_filter_tier_filters';
  static const _kClassFilters = 'ui_filter_class_filters';
  static const _kDangerFilters = 'ui_filter_danger_filters';
  static const _kSortMode = 'ui_sort_mode';
  static const _kDescending = 'ui_sort_desc';
  static const _kGamePick = 'ui_game_pick';
  static const _kQuery = 'ui_query';

  late Future<List<EnemyIndexEntry>> enemiesFuture;
  String? _loadedLanguageCode;
  bool _tutorialQueued = false;

  @override
  void initState() {
    super.initState();

    final hasNewFilterState =
        LocalStorage.hasKey(_kFilterFavorites) ||
        LocalStorage.hasKey(_kFilterGold) ||
        LocalStorage.hasKey(_kTierFilters) ||
        LocalStorage.hasKey(_kClassFilters) ||
        LocalStorage.hasKey(_kDangerFilters);
    if (hasNewFilterState) {
      filterFavorites = LocalStorage.getBool(
        _kFilterFavorites,
        fallback: false,
      );
      filterGold = LocalStorage.getBool(_kFilterGold, fallback: false);
      tierFilters.addAll(LocalStorage.getStringSet(_kTierFilters));
      classFilters.addAll(LocalStorage.getStringSet(_kClassFilters));
      dangerFilters.addAll(
        LocalStorage.getStringSet(_kDangerFilters).map(_canonicalDanger),
      );
    } else {
      final legacyFilter = LocalStorage.getInt(_kLegacyFilter, fallback: 0);
      switch (legacyFilter) {
        case 1:
          filterFavorites = true;
          break;
        case 2:
          filterGold = true;
          break;
        case 3:
          tierFilters.add('1');
          break;
        case 4:
          tierFilters.add('2');
          break;
        case 5:
          tierFilters.add('3');
          break;
        case 6:
          tierFilters.add('4');
          break;
        case 7:
          tierFilters.add('boss');
          break;
      }
    }
    sortMode =
        SortMode.values[LocalStorage.getInt(
          _kSortMode,
          fallback: SortMode.defaultOrder.index,
        )];
    sortDescending = LocalStorage.getBool(_kDescending, fallback: false);
    gamePick = GamePick
        .values[LocalStorage.getInt(_kGamePick, fallback: GamePick.g1.index)];
    query = LocalStorage.getString(_kQuery) ?? '';
    _searchController = TextEditingController(text: query);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = context.l10n.languageCode;
    if (_loadedLanguageCode == languageCode) {
      return;
    }
    _loadedLanguageCode = languageCode;
    enemiesFuture = _loadEnemiesForCurrentGame(languageCode);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isGold(EnemyIndexEntry enemy, Set<String> goldIds) =>
      enemy.defaultGold ||
      goldIds.contains(enemy.id) ||
      (enemy.goldLinkId != null && goldIds.contains(enemy.goldLinkId));

  int _displayOrder(EnemyIndexEntry enemy) => enemy.order ?? 999999;

  bool _matchesActiveFilters(
    EnemyIndexEntry enemy,
    Set<String> favoriteIds,
    Set<String> goldIds,
    Set<String> effectiveTierFilters,
    Set<String> effectiveClassFilters,
    Set<String> effectiveDangerFilters,
  ) {
    if (filterFavorites && !favoriteIds.contains(enemy.id)) {
      return false;
    }
    if (filterGold && !_isGold(enemy, goldIds)) {
      return false;
    }
    if (effectiveTierFilters.isNotEmpty) {
      final tierKey = enemy.isBoss ? 'boss' : enemy.tier.toString();
      if (!effectiveTierFilters.contains(tierKey)) {
        return false;
      }
    }
    if (effectiveClassFilters.isNotEmpty) {
      if (!effectiveClassFilters.contains(_groupForEnemy(enemy).name)) {
        return false;
      }
    }
    if (effectiveDangerFilters.isNotEmpty &&
        !effectiveDangerFilters.contains(_canonicalDanger(enemy.danger))) {
      return false;
    }
    return true;
  }

  String _tierLabel(int tier) {
    switch (tier) {
      case 1:
        return 'I';
      case 2:
        return 'II';
      case 3:
        return 'III';
      case 4:
        return 'IV';
      case 5:
        return 'V';
      default:
        return tier.toString();
    }
  }

  _TierFilterOptions _tierFilterOptions(List<EnemyIndexEntry> enemies) {
    final tiers =
        enemies
            .where((enemy) => !enemy.isBoss)
            .map((enemy) => enemy.tier)
            .toSet()
            .toList()
          ..sort();
    final hasBoss = enemies.any((enemy) => enemy.isBoss);
    return _TierFilterOptions(tiers: tiers, hasBoss: hasBoss);
  }

  List<EnemyIndexEntry> _enemiesForCurrentGame(List<EnemyIndexEntry> enemies) {
    switch (gamePick) {
      case GamePick.g1:
        return enemies.where((enemy) => enemy.game == 'g1').toList();
      case GamePick.g2:
        return enemies.where((enemy) => enemy.game == 'g2').toList();
      case GamePick.all:
        return enemies;
    }
  }

  Future<List<EnemyIndexEntry>> _loadEnemiesForCurrentGame(
    String languageCode,
  ) {
    switch (gamePick) {
      case GamePick.g1:
        return EnemyRepository.loadGame('g1', languageCode);
      case GamePick.g2:
        return EnemyRepository.loadGame('g2', languageCode);
      case GamePick.all:
        return EnemyRepository.loadAll(languageCode);
    }
  }

  List<EnemyDisplayGroup> _availableClassGroups(List<EnemyIndexEntry> enemies) {
    final available = enemies.map(_groupForEnemy).toSet();
    return _groupOrder(
      false,
    ).where((group) => available.contains(group)).toList();
  }

  Set<String> _effectiveTierFilters(_TierFilterOptions options) {
    final available = {
      for (final tier in options.tiers) tier.toString(),
      if (options.hasBoss) 'boss',
    };
    return tierFilters.where(available.contains).toSet();
  }

  Set<String> _effectiveClassFilters(List<EnemyDisplayGroup> groups) {
    final available = groups.map((group) => group.name).toSet();
    return classFilters.where(available.contains).toSet();
  }

  Set<String> _effectiveDangerFilters(List<String> dangers) {
    final available = dangers.map(_canonicalDanger).toSet();
    return dangerFilters.where(available.contains).toSet();
  }

  void _syncScopedFilters({
    required Set<String> effectiveTierFilters,
    required Set<String> effectiveClassFilters,
    required Set<String> effectiveDangerFilters,
  }) {
    final tierChanged =
        tierFilters.length != effectiveTierFilters.length ||
        !tierFilters.containsAll(effectiveTierFilters);
    final classChanged =
        classFilters.length != effectiveClassFilters.length ||
        !classFilters.containsAll(effectiveClassFilters);
    final dangerChanged =
        dangerFilters.length != effectiveDangerFilters.length ||
        !dangerFilters.containsAll(effectiveDangerFilters);

    if (!tierChanged && !classChanged && !dangerChanged) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        tierFilters
          ..clear()
          ..addAll(effectiveTierFilters);
        classFilters
          ..clear()
          ..addAll(effectiveClassFilters);
        dangerFilters
          ..clear()
          ..addAll(effectiveDangerFilters);
      });
      unawaited(LocalStorage.setStringSet(_kTierFilters, tierFilters));
      unawaited(LocalStorage.setStringSet(_kClassFilters, classFilters));
      unawaited(LocalStorage.setStringSet(_kDangerFilters, dangerFilters));
    });
  }

  String _tierFilterButtonLabel(
    AppLocalizations l10n,
    Set<String> effectiveTierFilters,
  ) {
    if (effectiveTierFilters.isEmpty) {
      return l10n.filterTiers;
    }

    final labels = <String>[];
    final tierValues =
        effectiveTierFilters.where((value) => value != 'boss').toList()
          ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    for (final value in tierValues) {
      labels.add(_tierLabel(int.parse(value)));
    }
    if (effectiveTierFilters.contains('boss')) {
      labels.add(l10n.filterBoss);
    }
    return labels.isEmpty ? l10n.filterTiers : labels.join(', ');
  }

  void _toggleTierFilter(String value) {
    setState(() {
      if (value == 'clear') {
        tierFilters.clear();
      } else if (!tierFilters.add(value)) {
        tierFilters.remove(value);
      }
    });
    unawaited(LocalStorage.setStringSet(_kTierFilters, tierFilters));
  }

  String _classFilterButtonLabel(
    AppLocalizations l10n,
    List<EnemyDisplayGroup> groups,
    Set<String> effectiveClassFilters,
  ) {
    if (effectiveClassFilters.isEmpty) {
      return l10n.filterClass;
    }
    final labels = groups
        .where((group) => effectiveClassFilters.contains(group.name))
        .map((group) => _groupLabel(group, l10n))
        .toList();
    return labels.isEmpty ? l10n.filterClass : labels.join(', ');
  }

  void _toggleClassFilter(String value) {
    setState(() {
      if (value == 'clear') {
        classFilters.clear();
      } else if (!classFilters.add(value)) {
        classFilters.remove(value);
      }
    });
    unawaited(LocalStorage.setStringSet(_kClassFilters, classFilters));
  }

  Widget _tierFilterButton(
    BuildContext context,
    AppLocalizations l10n,
    _TierFilterOptions options,
    Set<String> effectiveTierFilters,
  ) {
    final label = _tierFilterButtonLabel(l10n, effectiveTierFilters);
    final active = effectiveTierFilters.isNotEmpty;
    return PopupMenuButton<String>(
      key: const ValueKey('tier-filter-menu'),
      tooltip: l10n.filterTiers,
      onSelected: _toggleTierFilter,
      itemBuilder: (_) => [
        PopupMenuItem<String>(value: 'clear', child: Text(l10n.filterTiers)),
        const PopupMenuDivider(),
        for (final tier in options.tiers)
          CheckedPopupMenuItem<String>(
            value: tier.toString(),
            checked: effectiveTierFilters.contains(tier.toString()),
            child: Text(_tierLabel(tier)),
          ),
        if (options.hasBoss)
          CheckedPopupMenuItem<String>(
            value: 'boss',
            checked: effectiveTierFilters.contains('boss'),
            child: Text(l10n.filterBoss),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list, size: 18),
            const SizedBox(width: 6),
            Text(label),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _classFilterButton(
    BuildContext context,
    AppLocalizations l10n,
    List<EnemyDisplayGroup> groups,
    Set<String> effectiveClassFilters,
  ) {
    final label = _classFilterButtonLabel(l10n, groups, effectiveClassFilters);
    final active = effectiveClassFilters.isNotEmpty;
    return PopupMenuButton<String>(
      key: const ValueKey('class-filter-menu'),
      tooltip: l10n.filterClass,
      onSelected: _toggleClassFilter,
      itemBuilder: (_) => [
        PopupMenuItem<String>(value: 'clear', child: Text(l10n.filterClass)),
        const PopupMenuDivider(),
        for (final group in groups)
          CheckedPopupMenuItem<String>(
            value: group.name,
            checked: effectiveClassFilters.contains(group.name),
            child: Text(_groupLabel(group, l10n)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune, size: 18),
            const SizedBox(width: 6),
            Text(label),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _dangerFilterButton(
    BuildContext context,
    AppLocalizations l10n,
    List<String> dangers,
    Set<String> effectiveDangerFilters,
  ) {
    final label = _dangerFilterButtonLabel(l10n, effectiveDangerFilters);
    final active = effectiveDangerFilters.isNotEmpty;
    return PopupMenuButton<String>(
      key: const ValueKey('danger-filter-menu'),
      tooltip: l10n.filterDanger,
      onSelected: _toggleDangerFilter,
      itemBuilder: (_) => [
        PopupMenuItem<String>(value: 'clear', child: Text(l10n.filterDanger)),
        const PopupMenuDivider(),
        for (final danger in dangers)
          CheckedPopupMenuItem<String>(
            value: danger,
            checked: effectiveDangerFilters.contains(danger),
            child: Text(_dangerLabel(danger, l10n)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department, size: 18),
            const SizedBox(width: 6),
            Text(label),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  EnemyDisplayGroup _fallbackGroupFromOrder(String game, int order) {
    if (game == 'g1') {
      if (order >= 101 && order <= 108) return EnemyDisplayGroup.neutral;
      if (order >= 109 && order <= 156) return EnemyDisplayGroup.aggressive;
      if (order >= 157 && order <= 171) return EnemyDisplayGroup.peaceful;
      if (order >= 172 && order <= 175) return EnemyDisplayGroup.anomaly;
    }
    return EnemyDisplayGroup.other;
  }

  EnemyDisplayGroup _groupForEnemy(EnemyIndexEntry enemy) {
    final explicitPeaceful = {
      'g1_red_ant_queen',
      'g1_black_ant_queen',
      'g1_fire_ant_queen',
    };
    final explicitAnomaly = {'g1_infected_ant_queen', 'g1_enemy_infused'};
    final explicitOther = {'g1_enemy_orc'};
    if (explicitPeaceful.contains(enemy.id) ||
        explicitPeaceful.contains(enemy.speciesKey)) {
      return EnemyDisplayGroup.peaceful;
    }
    if (explicitAnomaly.contains(enemy.id) ||
        explicitAnomaly.contains(enemy.speciesKey)) {
      return EnemyDisplayGroup.anomaly;
    }
    if (explicitOther.contains(enemy.id) ||
        explicitOther.contains(enemy.speciesKey)) {
      return EnemyDisplayGroup.other;
    }

    if (enemy.game == 'g2' && enemy.collectionGroup != null) {
      switch (enemy.collectionGroup) {
        case 'neutral':
          return EnemyDisplayGroup.neutral;
        case 'orc':
          return EnemyDisplayGroup.orc;
        case 'angry':
          return EnemyDisplayGroup.aggressive;
        case 'harmless':
          return EnemyDisplayGroup.peaceful;
        case 'ogrr':
          return EnemyDisplayGroup.ogrr;
        case 'buggy':
          return EnemyDisplayGroup.buggy;
        case 'other':
          return EnemyDisplayGroup.other;
      }
    }

    switch (enemy.temperament) {
      case 'neutral':
        return EnemyDisplayGroup.neutral;
      case 'aggressive':
        return EnemyDisplayGroup.aggressive;
      case 'peaceful':
        return EnemyDisplayGroup.peaceful;
      case 'anomaly':
        return EnemyDisplayGroup.anomaly;
      case 'other':
        return EnemyDisplayGroup.other;
      default:
        return _fallbackGroupFromOrder(enemy.game, enemy.order ?? 0);
    }
  }

  List<EnemyDisplayGroup> _groupOrder(bool descending) {
    if (descending) {
      return [
        EnemyDisplayGroup.other,
        EnemyDisplayGroup.anomaly,
        EnemyDisplayGroup.ogrr,
        EnemyDisplayGroup.peaceful,
        EnemyDisplayGroup.aggressive,
        EnemyDisplayGroup.orc,
        EnemyDisplayGroup.buggy,
        EnemyDisplayGroup.neutral,
      ];
    }
    return [
      EnemyDisplayGroup.neutral,
      EnemyDisplayGroup.buggy,
      EnemyDisplayGroup.orc,
      EnemyDisplayGroup.aggressive,
      EnemyDisplayGroup.peaceful,
      EnemyDisplayGroup.ogrr,
      EnemyDisplayGroup.anomaly,
      EnemyDisplayGroup.other,
    ];
  }

  String _groupLabel(EnemyDisplayGroup temperament, AppLocalizations l10n) {
    switch (temperament) {
      case EnemyDisplayGroup.neutral:
        return l10n.groupNeutrals;
      case EnemyDisplayGroup.orc:
        return l10n.groupOrc;
      case EnemyDisplayGroup.buggy:
        return l10n.groupBuggies;
      case EnemyDisplayGroup.angry:
        return l10n.groupAngry;
      case EnemyDisplayGroup.harmless:
        return l10n.groupHarmless;
      case EnemyDisplayGroup.ogrr:
        return l10n.groupOgrr;
      case EnemyDisplayGroup.aggressive:
        return l10n.groupAggressive;
      case EnemyDisplayGroup.peaceful:
        return l10n.groupPeaceful;
      case EnemyDisplayGroup.anomaly:
        return l10n.groupAnomalies;
      case EnemyDisplayGroup.other:
        return l10n.groupOthers;
    }
  }

  int _groupIndex(
    EnemyDisplayGroup temperament,
    List<EnemyDisplayGroup> order,
  ) => order.indexOf(temperament);

  static const List<String> _dangerOrder = [
    'baja',
    'media',
    'intermedia',
    'alta',
    'muy_alta',
    'imposible',
    'imposible_superior',
    'extrema',
    'proximamente',
  ];

  int _dangerRank(String danger) {
    switch (_canonicalDanger(danger)) {
      case 'baja':
        return 1;
      case 'media':
        return 2;
      case 'intermedia':
        return 3;
      case 'alta':
        return 4;
      case 'muy_alta':
        return 5;
      case 'imposible':
        return 6;
      case 'imposible_superior':
        return 7;
      case 'extrema':
        return 8;
      case 'proximamente':
        return 9;
      default:
        return 99;
    }
  }

  List<String> _availableDangers(List<EnemyIndexEntry> enemies) {
    final values = enemies
        .map((enemy) => _canonicalDanger(enemy.danger))
        .toSet()
        .toList();
    values.sort((a, b) => _dangerRank(a).compareTo(_dangerRank(b)));
    return values;
  }

  String _dangerLabel(String danger, AppLocalizations l10n) =>
      l10n.dangerLevelLabel(_canonicalDanger(danger));

  String _canonicalDanger(String danger) {
    switch (danger) {
      case 'imposible_alt':
      case 'imposible_alta':
        return 'imposible_superior';
      default:
        return danger;
    }
  }

  String _dangerFilterButtonLabel(
    AppLocalizations l10n,
    Set<String> effectiveDangerFilters,
  ) {
    if (effectiveDangerFilters.isEmpty) {
      return l10n.filterDanger;
    }
    final labels = _dangerOrder
        .where((danger) => effectiveDangerFilters.contains(danger))
        .map((danger) => _dangerLabel(danger, l10n))
        .toList();
    return labels.isEmpty ? l10n.filterDanger : labels.join(', ');
  }

  void _toggleDangerFilter(String value) {
    setState(() {
      if (value == 'clear') {
        dangerFilters.clear();
      } else {
        final canonical = _canonicalDanger(value);
        if (!dangerFilters.add(canonical)) {
          dangerFilters.remove(canonical);
        }
      }
    });
    unawaited(LocalStorage.setStringSet(_kDangerFilters, dangerFilters));
  }

  String? _storedPreferredGame(String speciesKey) =>
      LocalStorage.getString(_variantPreferenceKey(speciesKey));

  EnemyIndexEntry _selectActiveVariant(
    EnemyIndexListEntry entry,
    List<EnemyIndexEntry> variants, {
    required bool preferG2Default,
  }) {
    final preferredGame = gamePick == GamePick.g1
        ? 'g1'
        : gamePick == GamePick.g2
        ? 'g2'
        : _storedPreferredGame(entry.speciesKey);

    for (final variant in variants) {
      if (variant.game == preferredGame) {
        return variant;
      }
    }

    final preferred = entry.preferredVariant(
      preferredGame: preferredGame,
      preferG2Default: preferG2Default,
    );
    if (variants.contains(preferred)) {
      return preferred;
    }

    if (preferG2Default) {
      for (final variant in variants) {
        if (variant.game == 'g2') {
          return variant;
        }
      }
    }

    return variants.first;
  }

  EnemyIndexEntry _sortSourceEnemy(ResolvedEnemyEntry entry) {
    if (gamePick == GamePick.all) {
      return entry.entry.sortVariant();
    }
    return entry.activeEnemy;
  }

  List<ResolvedEnemyEntry> _applyFilterAndSearch(
    List<EnemyIndexEntry> enemies,
    Set<String> favoriteIds,
    Set<String> goldIds,
    Set<String> effectiveTierFilters,
    Set<String> effectiveClassFilters,
    Set<String> effectiveDangerFilters,
  ) {
    final mergeSharedSpecies = gamePick == GamePick.all;
    final entries = groupEnemyIndexEntries(
      enemies,
      mergeSharedSpecies: mergeSharedSpecies,
    );
    final normalizedQuery = query.trim().toLowerCase();
    final resolved = <ResolvedEnemyEntry>[];

    for (final entry in entries) {
      final visibleVariants = entry.variants.where((enemy) {
        if (gamePick == GamePick.g1) return enemy.game == 'g1';
        if (gamePick == GamePick.g2) return enemy.game == 'g2';
        return true;
      }).toList();

      if (visibleVariants.isEmpty) {
        continue;
      }

      if (normalizedQuery.isNotEmpty) {
        final matchesQuery = visibleVariants.any(
          (enemy) => enemy.name.toLowerCase().contains(normalizedQuery),
        );
        if (!matchesQuery) {
          continue;
        }
      }

      final matchingVariants = visibleVariants
          .where(
            (enemy) => _matchesActiveFilters(
              enemy,
              favoriteIds,
              goldIds,
              effectiveTierFilters,
              effectiveClassFilters,
              effectiveDangerFilters,
            ),
          )
          .toList();
      if (matchingVariants.isEmpty) {
        continue;
      }

      final activeEnemy = _selectActiveVariant(
        entry,
        matchingVariants,
        preferG2Default: mergeSharedSpecies,
      );

      resolved.add(ResolvedEnemyEntry(entry: entry, activeEnemy: activeEnemy));
    }

    resolved.sort((a, b) {
      late final int result;

      switch (sortMode) {
        case SortMode.defaultOrder:
          final order = _groupOrder(sortDescending);
          final aSortEnemy = _sortSourceEnemy(a);
          final bSortEnemy = _sortSourceEnemy(b);
          final aGroup = _groupForEnemy(aSortEnemy);
          final bGroup = _groupForEnemy(bSortEnemy);
          final groupCompare = _groupIndex(
            aGroup,
            order,
          ).compareTo(_groupIndex(bGroup, order));
          if (groupCompare != 0) {
            result = groupCompare;
          } else {
            result = _displayOrder(
              aSortEnemy,
            ).compareTo(_displayOrder(bSortEnemy));
          }
          break;
        case SortMode.name:
          result = a.activeEnemy.name.toLowerCase().compareTo(
            b.activeEnemy.name.toLowerCase(),
          );
          break;
        case SortMode.danger:
          result = _dangerRank(
            a.activeEnemy.danger,
          ).compareTo(_dangerRank(b.activeEnemy.danger));
          break;
        case SortMode.tier:
          if (a.activeEnemy.isBoss != b.activeEnemy.isBoss) {
            result = a.activeEnemy.isBoss ? 1 : -1;
          } else {
            result = a.activeEnemy.tier.compareTo(b.activeEnemy.tier);
          }
          break;
      }

      if (sortMode == SortMode.defaultOrder) {
        return result;
      }
      return sortDescending ? -result : result;
    });

    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final favorites = FavoritesController.instance;
    final gold = GoldController.instance;
    final baseColor = gameColorForPick(gamePick);
    final accentColor = gameAccentForPick(gamePick);
    final headerGradient = gameHeaderGradientForPick(
      gamePick,
      Theme.of(context).scaffoldBackgroundColor,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: headerGradient,
                  stops: const [0, 0.26, 0.5, 0.74, 1],
                ),
              ),
            ),
            IgnorePointer(
              child: Align(
                alignment: const Alignment(0, -0.18),
                child: Container(
                  width: 240,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        accentColor.withValues(alpha: 0.55),
                        accentColor.withValues(alpha: 0.95),
                        accentColor.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.42),
                        blurRadius: 26,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Align(
                alignment: const Alignment(0, 0.9),
                child: Container(
                  width: 320,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        baseColor.withValues(alpha: 0.18),
                        accentColor.withValues(alpha: 0.82),
                        baseColor.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.32),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(l10n.appTitle),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      accentColor.withValues(alpha: 0.2),
                      accentColor.withValues(alpha: 0.92),
                      accentColor.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            key: const ValueKey('open-creature-scanner'),
            icon: const Icon(Icons.center_focus_strong),
            tooltip: l10n.scannerTitle,
            onPressed: () => _openScanner(context),
          ),
          Container(
            key: TutorialController.instance.keyFor(tutorialAnchorListCodex),
            child: IconButton(
              key: const ValueKey('open-effect-codex'),
              icon: const Icon(Icons.menu_book),
              tooltip: l10n.effectCodexTooltip,
              onPressed: () => openEffectCodex(context),
            ),
          ),
          Container(
            key: TutorialController.instance.keyFor(tutorialAnchorListGame),
            child: IconButton(
              icon: const Icon(Icons.videogame_asset),
              tooltip: l10n.chooseGameTooltip,
              onPressed: () => _openGamePicker(context),
            ),
          ),
          Container(
            key: TutorialController.instance.keyFor(tutorialAnchorListSettings),
            child: IconButton(
              key: const ValueKey('open-settings'),
              icon: const Icon(Icons.settings),
              tooltip: l10n.settingsTooltip,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                if (context.mounted) {
                  await ReviewPromptController.instance.registerScreenClose(
                    context,
                  );
                }
              },
            ),
          ),
          Container(
            key: TutorialController.instance.keyFor(tutorialAnchorListSort),
            child: PopupMenuButton<SortMenuAction>(
              key: const ValueKey('open-sort-menu'),
              icon: Icon(sortDescending ? Icons.arrow_downward : Icons.sort),
              onSelected: (mode) {
                switch (mode) {
                  case SortMenuAction.toggleDirection:
                    setState(() => sortDescending = !sortDescending);
                    LocalStorage.setBool(_kDescending, sortDescending);
                    break;
                  case SortMenuAction.defaultOrder:
                    setState(() => sortMode = SortMode.defaultOrder);
                    LocalStorage.setInt(
                      _kSortMode,
                      SortMode.defaultOrder.index,
                    );
                    break;
                  case SortMenuAction.name:
                    setState(() => sortMode = SortMode.name);
                    LocalStorage.setInt(_kSortMode, SortMode.name.index);
                    break;
                  case SortMenuAction.danger:
                    setState(() => sortMode = SortMode.danger);
                    LocalStorage.setInt(_kSortMode, SortMode.danger.index);
                    break;
                  case SortMenuAction.tier:
                    setState(() => sortMode = SortMode.tier);
                    LocalStorage.setInt(_kSortMode, SortMode.tier.index);
                    break;
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: SortMenuAction.toggleDirection,
                  child: Row(
                    children: [
                      Icon(
                        sortDescending
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        sortDescending
                            ? l10n.descendingOrder
                            : l10n.ascendingOrder,
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                CheckedPopupMenuItem(
                  value: SortMenuAction.defaultOrder,
                  checked: sortMode == SortMode.defaultOrder,
                  child: Text(l10n.sortDefaultOrder),
                ),
                PopupMenuItem(
                  value: SortMenuAction.name,
                  child: Text(l10n.sortByName),
                ),
                PopupMenuItem(
                  value: SortMenuAction.danger,
                  child: Text(l10n.sortByDanger),
                ),
                PopupMenuItem(
                  value: SortMenuAction.tier,
                  child: Text(l10n.sortByTier),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: ValueListenableBuilder<Set<String>>(
          valueListenable: gold.gold,
          builder: (context, goldIds, _) {
            return ValueListenableBuilder<Set<String>>(
              valueListenable: favorites.favorites,
              builder: (context, favoriteIds, _) {
                return FutureBuilder<List<EnemyIndexEntry>>(
                  future: enemiesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          '${l10n.errorLoadingJson}\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final enemies = snapshot.data ?? <EnemyIndexEntry>[];
                    if (!_tutorialQueued) {
                      _tutorialQueued = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          TutorialController.instance.maybeStart(
                            context,
                            enemies,
                          );
                        }
                      });
                    }
                    final scopedEnemies = _enemiesForCurrentGame(enemies);
                    final tierOptions = _tierFilterOptions(scopedEnemies);
                    final classOptions = _availableClassGroups(scopedEnemies);
                    final dangerOptions = _availableDangers(scopedEnemies);
                    final effectiveTierFilters = _effectiveTierFilters(
                      tierOptions,
                    );
                    final effectiveClassFilters = _effectiveClassFilters(
                      classOptions,
                    );
                    final effectiveDangerFilters = _effectiveDangerFilters(
                      dangerOptions,
                    );

                    _syncScopedFilters(
                      effectiveTierFilters: effectiveTierFilters,
                      effectiveClassFilters: effectiveClassFilters,
                      effectiveDangerFilters: effectiveDangerFilters,
                    );

                    final filtered = _applyFilterAndSearch(
                      enemies,
                      favoriteIds,
                      goldIds,
                      effectiveTierFilters,
                      effectiveClassFilters,
                      effectiveDangerFilters,
                    );

                    return Column(
                      children: [
                        Padding(
                          key: TutorialController.instance.keyFor(
                            tutorialAnchorListSearch,
                          ),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() => query = value);
                              LocalStorage.setString(_kQuery, value);
                            },
                            decoration: InputDecoration(
                              hintText: l10n.searchEnemyHint,
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: query.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        setState(() => query = '');
                                        _searchController.clear();
                                        LocalStorage.setString(_kQuery, '');
                                      },
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          key: TutorialController.instance.keyFor(
                            tutorialAnchorListFilters,
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                _tierFilterButton(
                                  context,
                                  l10n,
                                  tierOptions,
                                  effectiveTierFilters,
                                ),
                                const SizedBox(width: 8),
                                _classFilterButton(
                                  context,
                                  l10n,
                                  classOptions,
                                  effectiveClassFilters,
                                ),
                                const SizedBox(width: 8),
                                _dangerFilterButton(
                                  context,
                                  l10n,
                                  dangerOptions,
                                  effectiveDangerFilters,
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: const Text('\u2605'),
                                  selected: filterFavorites,
                                  onSelected: (value) {
                                    setState(() => filterFavorites = value);
                                    unawaited(
                                      LocalStorage.setBool(
                                        _kFilterFavorites,
                                        filterFavorites,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: const Text('\u25A0'),
                                  selected: filterGold,
                                  onSelected: (value) {
                                    setState(() => filterGold = value);
                                    unawaited(
                                      LocalStorage.setBool(
                                        _kFilterGold,
                                        filterGold,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListenableBuilder(
                            listenable:
                                MonetizationController.instance.adsRemoved,
                            builder: (context, _) {
                              final showInlineAd =
                                  MonetizationController.instance.shouldShowAds;
                              return sortMode == SortMode.defaultOrder
                                  ? _SectionedEnemyList(
                                      entries: filtered,
                                      favIds: favoriteIds,
                                      goldIds: goldIds,
                                      groupOrder: _groupOrder(sortDescending),
                                      showInlineAd: showInlineAd,
                                      groupFromEntry: (entry) {
                                        return _groupForEnemy(
                                          _sortSourceEnemy(entry),
                                        );
                                      },
                                      groupLabel: (temperament) =>
                                          _groupLabel(temperament, l10n),
                                    )
                                  : _FlatEnemyList(
                                      entries: filtered,
                                      favIds: favoriteIds,
                                      goldIds: goldIds,
                                      showInlineAd: showInlineAd,
                                    );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openGamePicker(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _GamePickerSheet(
        selected: gamePick,
        onPick: (pick) {
          setState(() {
            gamePick = pick;
            enemiesFuture = _loadEnemiesForCurrentGame(
              _loadedLanguageCode ?? context.l10n.languageCode,
            );
          });
          LocalStorage.setInt(_kGamePick, pick.index);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _openScanner(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatureScannerComingSoonPage()),
    );
  }
}

class _FlatEnemyList extends StatelessWidget {
  final List<ResolvedEnemyEntry> entries;
  final Set<String> favIds;
  final Set<String> goldIds;
  final bool showInlineAd;

  const _FlatEnemyList({
    required this.entries,
    required this.favIds,
    required this.goldIds,
    required this.showInlineAd,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <ResolvedEnemyEntry?>[];
    for (var i = 0; i < entries.length; i++) {
      rows.add(entries[i]);
      if (showInlineAd &&
          entries.length >= _minTilesForFlatInlineAd &&
          i + 1 == _flatInlineAdAfterTile) {
        rows.add(null);
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final entry = rows[index];
        if (entry == null) {
          return const InlineBannerAdCard();
        }
        return EnemyTile(entry: entry, favIds: favIds, goldIds: goldIds);
      },
    );
  }
}

class EnemyTile extends StatelessWidget {
  final ResolvedEnemyEntry entry;
  final Set<String> favIds;
  final Set<String> goldIds;

  const EnemyTile({
    super.key,
    required this.entry,
    required this.favIds,
    required this.goldIds,
  });

  @override
  Widget build(BuildContext context) {
    final enemy = entry.activeEnemy;
    final isFavorite = favIds.contains(enemy.id);
    final isGold =
        enemy.defaultGold ||
        goldIds.contains(enemy.id) ||
        (enemy.goldLinkId != null && goldIds.contains(enemy.goldLinkId));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        key: ValueKey('enemy-tile-${entry.entry.speciesKey}'),
        leading: FallbackAssetImage.asset(
          assetName: isGold ? enemy.cardGold : enemy.cardNormal,
          fallbackAssetName: 'assets/global/Creaturecard_Proximamente.webp',
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
        title: Row(
          children: [
            Expanded(
              child: OverflowMarqueeText(
                enemy.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isFavorite)
              const Icon(Icons.star, size: 18, color: Colors.amber),
            if (isGold)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.credit_card,
                  size: 18,
                  color: Color(0xFFFFD54F),
                ),
              ),
          ],
        ),
        subtitle: Wrap(
          spacing: 6,
          children: enemy.weaknesses
              .map(
                (weakness) => IconBadge.asset(
                  assetName: UiMapper.effectIcon(weakness),
                  size: 16,
                  padding: const EdgeInsets.all(3),
                  borderRadius: 10,
                ),
              )
              .toList(),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconBadge.asset(
              assetName: UiMapper.dangerIcon(enemy.danger),
              size: 22,
              padding: const EdgeInsets.all(4),
              borderRadius: 12,
            ),
            const SizedBox(height: 6),
            Image.asset(
              UiMapper.tierIcon(tier: enemy.tier, isBoss: enemy.isBoss),
              width: 26,
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EnemyDetailScreen(
                summary: enemy,
                variantSummaries: entry.entry.variants,
                initialGame: enemy.game,
              ),
            ),
          ).then((_) async {
            if (!context.mounted) {
              return;
            }
            final consumedByAdsPrompt = await MonetizationController.instance
                .registerEnemySheetClose(context);
            if (context.mounted && !consumedByAdsPrompt) {
              await ReviewPromptController.instance.registerScreenClose(
                context,
              );
            }
          });
        },
      ),
    );
  }
}

class _SectionedEnemyList extends StatelessWidget {
  final List<ResolvedEnemyEntry> entries;
  final Set<String> favIds;
  final Set<String> goldIds;
  final List<EnemyDisplayGroup> groupOrder;
  final bool showInlineAd;
  final EnemyDisplayGroup Function(ResolvedEnemyEntry entry) groupFromEntry;
  final String Function(EnemyDisplayGroup temperament) groupLabel;

  const _SectionedEnemyList({
    required this.entries,
    required this.favIds,
    required this.goldIds,
    required this.groupOrder,
    required this.showInlineAd,
    required this.groupFromEntry,
    required this.groupLabel,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <_SectionedEnemyRow>[];

    for (final group in groupOrder) {
      final groupItems = entries
          .where((entry) => groupFromEntry(entry) == group)
          .toList();
      if (groupItems.isEmpty) continue;

      rows.add(_SectionedEnemyRow.header(groupLabel(group)));

      var groupTileCount = 0;
      for (final entry in groupItems) {
        rows.add(_SectionedEnemyRow.entry(entry));
        groupTileCount++;
        if (showInlineAd &&
            groupItems.length >= _minTilesForSectionInlineAd &&
            groupTileCount == _sectionInlineAdAfterTile) {
          rows.add(const _SectionedEnemyRow.ad());
        }
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.isAd) {
          return const InlineBannerAdCard();
        }
        final label = row.headerLabel;
        if (label != null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          );
        }
        return EnemyTile(entry: row.entry!, favIds: favIds, goldIds: goldIds);
      },
    );
  }
}

class _SectionedEnemyRow {
  final String? headerLabel;
  final ResolvedEnemyEntry? entry;
  final bool isAd;

  const _SectionedEnemyRow.header(this.headerLabel)
    : entry = null,
      isAd = false;

  const _SectionedEnemyRow.entry(this.entry) : headerLabel = null, isAd = false;

  const _SectionedEnemyRow.ad() : headerLabel = null, entry = null, isAd = true;
}

class _GamePickerSheet extends StatelessWidget {
  final GamePick selected;
  final ValueChanged<GamePick> onPick;

  const _GamePickerSheet({required this.selected, required this.onPick});

  Color _gameColor(GamePick value) {
    return gameColorForPick(value);
  }

  Widget _button(String text, GamePick value) {
    final isSelected = selected == value;
    final baseColor = _gameColor(value);
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? baseColor
              : baseColor.withValues(alpha: 0.75),
          foregroundColor: Colors.white,
        ),
        onPressed: () => onPick(value),
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              l10n.selectEditionTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _button(l10n.bothGames, GamePick.all),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _button(l10n.groundedOne, GamePick.g1)),
                const SizedBox(width: 8),
                Expanded(child: _button(l10n.groundedTwo, GamePick.g2)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ResolvedEnemyEntry {
  final EnemyIndexListEntry entry;
  final EnemyIndexEntry activeEnemy;

  const ResolvedEnemyEntry({required this.entry, required this.activeEnemy});
}

class _TierFilterOptions {
  final List<int> tiers;
  final bool hasBoss;

  const _TierFilterOptions({required this.tiers, required this.hasBoss});
}

String _variantPreferenceKey(String speciesKey) =>
    'species_variant:$speciesKey';
