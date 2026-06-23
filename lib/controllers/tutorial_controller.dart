import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/effect_catalog.dart';
import '../data/enemy_repository.dart';
import '../data/local_storage.dart';
import '../data/ui_mapper.dart';
import '../i18n/app_localizations.dart';
import '../models/enemy.dart';
import '../models/enemy_index_entry.dart';
import '../screens/effect_codex_screen.dart';
import '../screens/enemy_detail_screen.dart';
import 'review_prompt_controller.dart';

const String tutorialAnchorListSearch = 'tutorial-list-search';
const String tutorialAnchorListGame = 'tutorial-list-game';
const String tutorialAnchorListFilters = 'tutorial-list-filters';
const String tutorialAnchorListSort = 'tutorial-list-sort';
const String tutorialAnchorListSettings = 'tutorial-list-settings';
const String tutorialAnchorListCodex = 'tutorial-list-codex';
const String tutorialAnchorDetailSummary = 'tutorial-detail-summary';
const String tutorialAnchorDetailVariant = 'tutorial-detail-variant';
const String tutorialAnchorDetailEffects = 'tutorial-detail-effects';

String tutorialAnchorDetailEffect(String effectId) =>
    'tutorial-detail-effect-$effectId';

String tutorialAnchorEffectCard(String effectId) =>
    'tutorial-effect-card-$effectId';

String tutorialAnchorEffectEquipment(String effectId) =>
    'tutorial-effect-equipment-$effectId';

enum TutorialStep {
  search,
  gamePicker,
  filters,
  sort,
  settings,
  codex,
  detailSummary,
  detailVariant,
  detailEffects,
  detailEffect,
  codexCard,
  codexEquipment,
}

bool _isValidTutorialEnemy(Enemy enemy) {
  if (enemy.photo.trim().isEmpty) {
    return false;
  }

  final hasDetails =
      enemy.health != null ||
      enemy.elementalWeaknesses.isNotEmpty ||
      enemy.damageWeaknesses.isNotEmpty ||
      enemy.resistancesV2.isNotEmpty ||
      enemy.resolvedWeakPoints.isNotEmpty ||
      enemy.weaknesses.isNotEmpty ||
      enemy.resistances.isNotEmpty;

  return hasDetails && tutorialEffectIdsForEnemy(enemy).isNotEmpty;
}

List<String> tutorialEffectIdsForEnemy(Enemy enemy) {
  final ids = <String>[];

  void addId(String rawId) {
    final canonicalId = canonicalEffectId(rawId);
    if (effectCatalogEntryById(canonicalId) == null) {
      return;
    }
    if (!ids.contains(canonicalId)) {
      ids.add(canonicalId);
    }
  }

  for (final item in enemy.weaknesses) {
    addId(item);
  }
  for (final item in enemy.resistances) {
    addId(item);
  }
  for (final bonus in enemy.elementalWeaknesses) {
    addId(bonus.type);
  }
  for (final bonus in enemy.damageWeaknesses) {
    addId(bonus.type);
  }
  for (final bonus in enemy.resistancesV2) {
    addId(bonus.type);
  }
  for (final weakPoint in enemy.resolvedWeakPoints) {
    for (final effectId in UiMapper.susceptibleDamageEffectIds(
      weakPoint.susceptibleDamage,
    )) {
      addId(effectId);
    }
  }

  return ids;
}

List<String> tutorialEffectIdsForEnemySummary(EnemyIndexEntry enemy) {
  final ids = <String>[];

  void addId(String rawId) {
    final canonicalId = canonicalEffectId(rawId);
    if (effectCatalogEntryById(canonicalId) == null) {
      return;
    }
    if (!ids.contains(canonicalId)) {
      ids.add(canonicalId);
    }
  }

  for (final item in enemy.weaknesses) {
    addId(item);
  }
  for (final item in enemy.resistances) {
    addId(item);
  }

  return ids;
}

Enemy? pickTutorialEnemy(List<Enemy> enemies, {Random? random}) {
  final candidates = enemies.where(_isValidTutorialEnemy).toList();

  if (candidates.isEmpty) {
    return null;
  }

  final picker = random ?? Random();
  return candidates[picker.nextInt(candidates.length)];
}

List<Enemy>? pickTutorialEnemyVariants(List<Enemy> enemies, {Random? random}) {
  final grouped = <String, List<Enemy>>{};
  for (final enemy in enemies.where(_isValidTutorialEnemy)) {
    grouped.putIfAbsent(enemy.speciesKey, () => <Enemy>[]).add(enemy);
  }

  final sharedCandidates = grouped.values
      .where(
        (variants) => variants.map((enemy) => enemy.game).toSet().length > 1,
      )
      .map((variants) {
        variants.sort((a, b) {
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
        return variants;
      })
      .toList();

  if (sharedCandidates.isNotEmpty) {
    final picker = random ?? Random();
    return sharedCandidates[picker.nextInt(sharedCandidates.length)];
  }

  final fallback = pickTutorialEnemy(enemies, random: random);
  if (fallback == null) {
    return null;
  }
  return [fallback];
}

bool _isValidTutorialEnemySummary(EnemyIndexEntry enemy) {
  final hasDetails =
      enemy.health != null ||
      enemy.weaknesses.isNotEmpty ||
      enemy.resistances.isNotEmpty;

  return hasDetails && tutorialEffectIdsForEnemySummary(enemy).isNotEmpty;
}

EnemyIndexEntry? pickTutorialEnemySummary(
  List<EnemyIndexEntry> enemies, {
  Random? random,
}) {
  final candidates = enemies.where(_isValidTutorialEnemySummary).toList();

  if (candidates.isEmpty) {
    return null;
  }

  final picker = random ?? Random();
  return candidates[picker.nextInt(candidates.length)];
}

List<EnemyIndexEntry>? pickTutorialEnemySummaryVariants(
  List<EnemyIndexEntry> enemies, {
  Random? random,
}) {
  final grouped = <String, List<EnemyIndexEntry>>{};
  for (final enemy in enemies.where(_isValidTutorialEnemySummary)) {
    grouped.putIfAbsent(enemy.speciesKey, () => <EnemyIndexEntry>[]).add(enemy);
  }

  final sharedCandidates = grouped.values
      .where(
        (variants) => variants.map((enemy) => enemy.game).toSet().length > 1,
      )
      .map((variants) {
        variants.sort((a, b) {
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
        return variants;
      })
      .toList();

  if (sharedCandidates.isNotEmpty) {
    final picker = random ?? Random();
    return sharedCandidates[picker.nextInt(sharedCandidates.length)];
  }

  final fallback = pickTutorialEnemySummary(enemies, random: random);
  if (fallback == null) {
    return null;
  }
  return [fallback];
}

class TutorialController extends ChangeNotifier {
  TutorialController._();

  static final TutorialController instance = TutorialController._();
  static const String completionKey = 'tutorial_completed';

  final Map<String, GlobalKey> _anchorKeys = {};

  bool _autoStartChecked = false;
  bool _promptVisible = false;
  TutorialStep? _step;
  EnemyIndexEntry? _demoEnemy;
  List<EnemyIndexEntry> _demoVariants = const [];
  String? _demoEffectId;

  TutorialStep? get step => _step;
  bool get isActive => _step != null;
  String? get demoEnemyId => _demoEnemy?.id;
  String? get demoEffectId => _demoEffectId;

  GlobalKey keyFor(String id) =>
      _anchorKeys.putIfAbsent(id, () => GlobalKey(debugLabel: id));

  String? tutorialEffectIdForEnemy(String enemyId) {
    if (_demoEnemy?.id != enemyId) {
      return null;
    }
    return _demoEffectId;
  }

  Rect? currentTargetRect(BuildContext overlayContext) {
    final anchorId = _currentAnchorId;
    if (anchorId == null) {
      return null;
    }

    final targetContext = _anchorKeys[anchorId]?.currentContext;
    if (targetContext == null) {
      return null;
    }

    final targetBox = targetContext.findRenderObject();
    final overlayBox = overlayContext.findRenderObject();
    if (targetBox is! RenderBox ||
        overlayBox is! RenderBox ||
        !targetBox.attached ||
        !overlayBox.attached) {
      return null;
    }

    final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    return topLeft & targetBox.size;
  }

  Future<void> maybeStart(
    BuildContext context,
    List<EnemyIndexEntry> enemies,
  ) async {
    if (_autoStartChecked || isActive || _promptVisible) {
      return;
    }
    _autoStartChecked = true;

    if (LocalStorage.getBool(completionKey, fallback: false)) {
      return;
    }

    final shouldStart = await _showIntroPrompt(context);
    if (!shouldStart) {
      await LocalStorage.setBool(completionKey, true);
      return;
    }

    await _start(enemies);
  }

  Future<void> startFromSettings() async {
    final navigator = ReviewPromptController.navigatorKey.currentState;
    if (navigator == null || isActive) {
      return;
    }

    final languageCode = navigator.context.l10n.languageCode;
    navigator.popUntil((route) => route.isFirst);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final enemies = await EnemyRepository.loadAll(languageCode);
    await _start(enemies, force: true);
  }

  Future<void> next() async {
    switch (_step) {
      case TutorialStep.search:
        _setStep(TutorialStep.gamePicker);
        return;
      case TutorialStep.gamePicker:
        _setStep(TutorialStep.filters);
        return;
      case TutorialStep.filters:
        _setStep(TutorialStep.sort);
        return;
      case TutorialStep.sort:
        _setStep(TutorialStep.settings);
        return;
      case TutorialStep.settings:
        _setStep(TutorialStep.codex);
        return;
      case TutorialStep.codex:
        await _openDemoEnemy();
        _setStep(TutorialStep.detailSummary);
        return;
      case TutorialStep.detailSummary:
        if (_demoVariants.length > 1) {
          _setStep(TutorialStep.detailVariant);
          return;
        }
        _setStep(TutorialStep.detailEffects);
        return;
      case TutorialStep.detailVariant:
        _setStep(TutorialStep.detailEffects);
        return;
      case TutorialStep.detailEffects:
        _setStep(TutorialStep.detailEffect);
        return;
      case TutorialStep.detailEffect:
        await _openDemoCodex();
        _setStep(TutorialStep.codexCard);
        return;
      case TutorialStep.codexCard:
        _setStep(TutorialStep.codexEquipment);
        return;
      case TutorialStep.codexEquipment:
        await finish();
        return;
      case null:
        return;
    }
  }

  Future<void> back() async {
    switch (_step) {
      case TutorialStep.search:
      case null:
        return;
      case TutorialStep.gamePicker:
        _setStep(TutorialStep.search);
        return;
      case TutorialStep.filters:
        _setStep(TutorialStep.gamePicker);
        return;
      case TutorialStep.sort:
        _setStep(TutorialStep.filters);
        return;
      case TutorialStep.settings:
        _setStep(TutorialStep.sort);
        return;
      case TutorialStep.codex:
        _setStep(TutorialStep.settings);
        return;
      case TutorialStep.detailSummary:
        await _popRouteIfPossible();
        _setStep(TutorialStep.codex);
        return;
      case TutorialStep.detailVariant:
        _setStep(TutorialStep.detailSummary);
        return;
      case TutorialStep.detailEffects:
        if (_demoVariants.length > 1) {
          _setStep(TutorialStep.detailVariant);
        } else {
          _setStep(TutorialStep.detailSummary);
        }
        return;
      case TutorialStep.detailEffect:
        _setStep(TutorialStep.detailEffects);
        return;
      case TutorialStep.codexCard:
        await _popRouteIfPossible();
        _setStep(TutorialStep.detailEffect);
        return;
      case TutorialStep.codexEquipment:
        _setStep(TutorialStep.codexCard);
        return;
    }
  }

  Future<void> skip() => _close(markCompleted: true);

  Future<void> finish() => _close(markCompleted: true);

  void debugResetForTests() {
    _autoStartChecked = false;
    _step = null;
    _demoEnemy = null;
    _demoVariants = const [];
    _demoEffectId = null;
    _anchorKeys.clear();
    _promptVisible = false;
    notifyListeners();
  }

  Future<void> _start(
    List<EnemyIndexEntry> enemies, {
    bool force = false,
  }) async {
    if (isActive) {
      return;
    }
    if (!force && LocalStorage.getBool(completionKey, fallback: false)) {
      return;
    }

    final variants = pickTutorialEnemySummaryVariants(enemies);
    if (variants == null || variants.isEmpty) {
      return;
    }

    var enemy = variants.first;
    for (final item in variants) {
      if (item.game == 'g2') {
        enemy = item;
        break;
      }
    }
    final effectIds = tutorialEffectIdsForEnemySummary(enemy);
    if (effectIds.isEmpty) {
      return;
    }

    _demoEnemy = enemy;
    _demoVariants = variants;
    _demoEffectId = effectIds.first;
    _setStep(TutorialStep.search);
  }

  Future<bool> _showIntroPrompt(BuildContext context) async {
    _promptVisible = true;
    try {
      final l10n = context.l10n;
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.tutorialPromptTitle),
          content: Text(l10n.tutorialPromptBody),
          actions: [
            TextButton(
              key: const ValueKey('tutorial-prompt-skip'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.tutorialPromptSkipAction),
            ),
            FilledButton(
              key: const ValueKey('tutorial-prompt-start'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.tutorialPromptStartAction),
            ),
          ],
        ),
      );
      return result ?? false;
    } finally {
      _promptVisible = false;
    }
  }

  void _setStep(TutorialStep value) {
    _step = value;
    notifyListeners();
  }

  Future<void> _openDemoEnemy() async {
    final navigator = ReviewPromptController.navigatorKey.currentState;
    final enemy = _demoEnemy;
    if (navigator == null || enemy == null) {
      return;
    }

    unawaited(
      navigator.push(
        MaterialPageRoute(
          builder: (_) => EnemyDetailScreen(
            summary: enemy,
            variantSummaries: _demoVariants,
            initialGame: enemy.game,
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _openDemoCodex() async {
    final context = ReviewPromptController.navigatorKey.currentContext;
    final effectId = _demoEffectId;
    if (context == null || effectId == null) {
      return;
    }

    unawaited(openEffectCodex(context, initialEffectId: effectId));
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _popRouteIfPossible() async {
    final navigator = ReviewPromptController.navigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) {
      return;
    }
    navigator.pop();
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<void> _close({required bool markCompleted}) async {
    if (markCompleted) {
      await LocalStorage.setBool(completionKey, true);
    }

    _step = null;
    _demoEnemy = null;
    _demoVariants = const [];
    _demoEffectId = null;
    notifyListeners();

    final navigator = ReviewPromptController.navigatorKey.currentState;
    navigator?.popUntil((route) => route.isFirst);
  }

  String? get _currentAnchorId {
    switch (_step) {
      case TutorialStep.search:
        return tutorialAnchorListSearch;
      case TutorialStep.gamePicker:
        return tutorialAnchorListGame;
      case TutorialStep.filters:
        return tutorialAnchorListFilters;
      case TutorialStep.sort:
        return tutorialAnchorListSort;
      case TutorialStep.settings:
        return tutorialAnchorListSettings;
      case TutorialStep.codex:
        return tutorialAnchorListCodex;
      case TutorialStep.detailSummary:
        return tutorialAnchorDetailSummary;
      case TutorialStep.detailVariant:
        return _demoVariants.length > 1 ? tutorialAnchorDetailVariant : null;
      case TutorialStep.detailEffects:
        return tutorialAnchorDetailEffects;
      case TutorialStep.detailEffect:
        final effectId = _demoEffectId;
        return effectId == null ? null : tutorialAnchorDetailEffect(effectId);
      case TutorialStep.codexCard:
        final effectId = _demoEffectId;
        return effectId == null ? null : tutorialAnchorEffectCard(effectId);
      case TutorialStep.codexEquipment:
        final effectId = _demoEffectId;
        return effectId == null
            ? null
            : tutorialAnchorEffectEquipment(effectId);
      case null:
        return null;
    }
  }
}
