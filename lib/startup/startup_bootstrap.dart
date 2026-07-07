import 'dart:async';
import 'dart:ui';

import 'package:hive_flutter/hive_flutter.dart';

import '../controllers/favorites_controller.dart';
import '../controllers/gold_controller.dart';
import '../controllers/locale_controller.dart';
import '../controllers/monetization_controller.dart';
import '../controllers/review_prompt_controller.dart';
import '../controllers/theme_controller.dart';
import '../data/aphidex_view_state.dart';
import '../data/enemy_repository.dart';
import '../data/local_storage.dart';
import '../models/enemy_index_entry.dart';
import '../models/game_pick.dart';
import 'startup_profiler.dart';

class StartupBootstrapData {
  const StartupBootstrapData({
    required this.initialEntries,
    required this.languageCode,
    required this.gamePick,
  });

  final List<EnemyIndexEntry> initialEntries;
  final String languageCode;
  final GamePick gamePick;
}

class StartupBootstrap {
  StartupBootstrap._();

  static bool _deferredServicesStarted = false;

  static Future<StartupBootstrapData> loadCriticalPath() async {
    await Hive.initFlutter();
    await Hive.openBox('aphidex');
    StartupProfiler.instance.mark('preferences ready');

    ThemeController.instance;
    StartupProfiler.instance.mark('theme ready');
    LocaleController.instance;
    StartupProfiler.instance.mark('locale ready');
    FavoritesController.instance;
    GoldController.instance;
    ReviewPromptController.instance.initialize();
    StartupProfiler.instance.mark('review prompt ready');
    MonetizationController.instance.primeLocalState();
    StartupProfiler.instance.mark('monetization local state ready');

    final gamePick = _restoreInitialGamePick();
    final languageCode = _resolveInitialLanguageCode();
    final initialEntries = await _loadInitialEntries(
      gamePick: gamePick,
      languageCode: languageCode,
    );

    final gold = GoldController.instance;
    if (gold.needsMigration(initialEntries)) {
      await gold.ensureMigrated(initialEntries);
      StartupProfiler.instance.mark('startup progress migration ready');
    }

    return StartupBootstrapData(
      initialEntries: initialEntries,
      languageCode: languageCode,
      gamePick: gamePick,
    );
  }

  static void startDeferredServices() {
    if (_deferredServicesStarted) {
      return;
    }
    _deferredServicesStarted = true;
    unawaited(
      MonetizationController.instance.initialize().then((_) {
        StartupProfiler.instance.mark('monetization init ready');
      }),
    );
  }

  static Future<List<EnemyIndexEntry>> _loadInitialEntries({
    required GamePick gamePick,
    required String languageCode,
  }) {
    switch (gamePick) {
      case GamePick.g1:
        return EnemyRepository.loadGame('g1', languageCode);
      case GamePick.g2:
        return EnemyRepository.loadGame('g2', languageCode);
      case GamePick.all:
        return EnemyRepository.loadAll(languageCode);
    }
  }

  static GamePick _restoreInitialGamePick() {
    final restored = AphidexViewState.fromStorageString(
      LocalStorage.getString(aphidexViewStateStorageKey),
    );
    final index =
        restored?.gamePickIndex ??
        LocalStorage.getInt('ui_game_pick', fallback: GamePick.g1.index);
    return GamePick.values[index.clamp(0, GamePick.values.length - 1)];
  }

  static String _resolveInitialLanguageCode() {
    final preferredLocale =
        LocaleController.instance.locale ??
        LocaleController.resolveSupportedLocale(
          PlatformDispatcher.instance.locale,
        );
    return LocaleController.resolveSupportedLocale(
      preferredLocale,
    ).languageCode;
  }
}
