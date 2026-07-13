import '../data/aphidex_view_state.dart';
import '../data/local_storage.dart';
import 'app_reset_controller.dart';
import 'creature_kill_count_controller.dart';
import 'favorites_controller.dart';
import 'game_selection_controller.dart';
import 'gold_controller.dart';
import 'player_display_name_controller.dart';
import 'player_profile_controller.dart';
import 'tutorial_controller.dart';
import '../models/player_character.dart';

class DataManagementController {
  DataManagementController._();

  static final instance = DataManagementController._();

  static const _filterKeys = <String>{
    'ui_filter',
    'ui_filter_favorites',
    'ui_filter_gold',
    'ui_filter_with_kills',
    'ui_filter_without_kills',
    'ui_filter_tier_filters',
    'ui_filter_class_filters',
    'ui_filter_danger_filters',
    'ui_sort_mode',
    'ui_sort_desc',
    'ui_query',
    aphidexViewStateStorageKey,
  };

  Future<void> clearFavorites() => FavoritesController.instance.reset();

  Future<void> clearCreatureCardProgress() => GoldController.instance.reset();

  Future<void> clearKillCounts() =>
      CreatureKillCountController.instance.clearAllKillCounts();

  Future<void> clearPlayerProfile() async {
    await Future.wait([
      PlayerDisplayNameController.instance.save(''),
      PlayerProfileController.instance.clear(AphidexGame.grounded),
      PlayerProfileController.instance.clear(AphidexGame.groundedTwo),
    ]);
  }

  Future<void> clearFiltersAndNavigation() async {
    await Future.wait(_filterKeys.map(LocalStorage.remove));
    await GameSelectionController.instance.reset();
    AppResetController.instance.refreshAppState();
  }

  Future<void> clearTutorialProgress() async {
    await LocalStorage.remove(TutorialController.completionKey);
    TutorialController.instance.resetRuntimeState();
  }

  Future<void> clearAllLocalData() =>
      AppResetController.instance.wipeForFreshStart();
}
