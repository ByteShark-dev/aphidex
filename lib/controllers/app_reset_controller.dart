import 'package:flutter/foundation.dart';

import '../data/enemy_repository.dart';
import '../data/local_storage.dart';
import 'favorites_controller.dart';
import 'creature_kill_count_controller.dart';
import 'game_selection_controller.dart';
import 'gold_controller.dart';
import 'locale_controller.dart';
import 'monetization_controller.dart';
import 'player_profile_controller.dart';
import 'player_display_name_controller.dart';
import 'theme_controller.dart';
import 'tutorial_controller.dart';

class AppResetController {
  AppResetController._();

  static final AppResetController instance = AppResetController._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<void> wipeForFreshStart() async {
    await LocalStorage.clearAll(
      preserveKeys: MonetizationController.persistentKeys,
    );
    await FavoritesController.instance.reset();
    await GoldController.instance.reset();
    await CreatureKillCountController.instance.clearAllKillCounts();
    GoldController.instance.reloadFromStorage();
    await ThemeController.instance.setTheme(ThemePref.system);
    await LocaleController.instance.setLanguage(LanguagePref.system);
    PlayerProfileController.instance.reloadFromStorage();
    PlayerDisplayNameController.instance.reloadFromStorage();
    GameSelectionController.instance.reloadFromStorage();
    TutorialController.instance.resetRuntimeState();
    // ignore: invalid_use_of_visible_for_testing_member
    EnemyRepository.clearCaches();
    revision.value += 1;
  }
}
