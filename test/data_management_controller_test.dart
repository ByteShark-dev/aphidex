import 'dart:io';

import 'package:aphidex/controllers/creature_kill_count_controller.dart';
import 'package:aphidex/controllers/data_management_controller.dart';
import 'package:aphidex/controllers/favorites_controller.dart';
import 'package:aphidex/controllers/gold_controller.dart';
import 'package:aphidex/controllers/player_display_name_controller.dart';
import 'package:aphidex/controllers/player_profile_controller.dart';
import 'package:aphidex/controllers/tutorial_controller.dart';
import 'package:aphidex/data/aphidex_view_state.dart';
import 'package:aphidex/data/creature_card_state.dart';
import 'package:aphidex/data/local_storage.dart';
import 'package:aphidex/models/creature_card_support.dart';
import 'package:aphidex/models/player_character.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('aphidex_data_management_');
    Hive.init(dir.path);
    await Hive.openBox('aphidex');
  });
  tearDownAll(() => Hive.box('aphidex').close());
  setUp(() async {
    await Hive.box('aphidex').clear();
    await FavoritesController.instance.reset();
    await GoldController.instance.reset();
    await CreatureKillCountController.instance.clearAll();
    PlayerDisplayNameController.instance.reloadFromStorage();
    PlayerProfileController.instance.reloadFromStorage();
  });

  test('selective clears preserve unrelated data', () async {
    await FavoritesController.instance.toggle('g2_wasp');
    await GoldController.instance.setProgress(
      const _Card(),
      CreatureCardProgress.gold,
    );
    await CreatureKillCountController.instance.setCount('g1_ant', 3);
    await DataManagementController.instance.clearFavorites();
    expect(FavoritesController.instance.favorites.value, isEmpty);
    expect(GoldController.instance.progress.value, isNotEmpty);
    expect(CreatureKillCountController.instance.getCount('g1_ant'), 3);
    await DataManagementController.instance.clearCreatureCardProgress();
    expect(GoldController.instance.progress.value, isEmpty);
    expect(CreatureKillCountController.instance.getCount('g1_ant'), 3);
    await DataManagementController.instance.clearKillCounts();
    expect(CreatureKillCountController.instance.counts.value, isEmpty);
  });

  test(
    'profile, filters, and tutorial clear only their stored state',
    () async {
      await PlayerDisplayNameController.instance.save('Xeno');
      await PlayerProfileController.instance.select(
        AphidexGame.grounded,
        'g1_max',
      );
      await PlayerProfileController.instance.select(
        AphidexGame.groundedTwo,
        'g2_hoops',
      );
      await FavoritesController.instance.toggle('g2_wasp');
      await LocalStorage.setString(aphidexViewStateStorageKey, 'state');
      await LocalStorage.setBool(TutorialController.completionKey, true);
      await DataManagementController.instance.clearPlayerProfile();
      expect(PlayerDisplayNameController.instance.displayName.value, isEmpty);
      expect(
        PlayerProfileController.instance.selectedIdFor(AphidexGame.grounded),
        isNull,
      );
      expect(
        PlayerProfileController.instance.selectedIdFor(AphidexGame.groundedTwo),
        isNull,
      );
      expect(FavoritesController.instance.favorites.value, isNotEmpty);
      await DataManagementController.instance.clearFiltersAndNavigation();
      expect(LocalStorage.getString(aphidexViewStateStorageKey), isNull);
      await DataManagementController.instance.clearTutorialProgress();
      expect(LocalStorage.getBool(TutorialController.completionKey), isFalse);
    },
  );
}

class _Card implements CreatureCardCarrier {
  const _Card();
  @override
  String get id => 'g2_card';
  @override
  String get game => 'g2';
  @override
  String? get goldLinkId => null;
  @override
  bool get defaultGold => false;
  @override
  bool get hasCreatureCard => true;
  @override
  bool get hasGoldCreatureCard => true;
  @override
  bool get hasSelectableCardVariants => true;
  @override
  CreatureCardVariant? get defaultCardVariant => CreatureCardVariant.normal;
  @override
  String? assetForCardVariant(CreatureCardVariant variant) => 'card';
}
