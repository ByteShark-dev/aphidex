import 'dart:io';

import 'package:aphidex/controllers/app_reset_controller.dart';
import 'package:aphidex/controllers/creature_kill_count_controller.dart';
import 'package:aphidex/controllers/favorites_controller.dart';
import 'package:aphidex/controllers/gold_controller.dart';
import 'package:aphidex/controllers/locale_controller.dart';
import 'package:aphidex/controllers/player_display_name_controller.dart';
import 'package:aphidex/controllers/theme_controller.dart';
import 'package:aphidex/controllers/tutorial_controller.dart';
import 'package:aphidex/data/aphidex_view_state.dart';
import 'package:aphidex/data/creature_card_state.dart';
import 'package:aphidex/data/local_storage.dart';
import 'package:aphidex/models/creature_card_support.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('aphidex_app_reset_');
    Hive.init(hiveDir.path);
    await Hive.openBox('aphidex');
  });

  tearDownAll(() async {
    await Hive.box('aphidex').close();
  });

  setUp(() async {
    await Hive.box('aphidex').clear();
    await FavoritesController.instance.reset();
    await GoldController.instance.reset();
    TutorialController.instance.resetRuntimeState();
  });

  test(
    'wipeForFreshStart clears runtime state and bumps the app revision',
    () async {
      await FavoritesController.instance.toggle('g2_wasp');
      await GoldController.instance.setProgress(
        const _ResetTestCardCarrier(id: 'g2_wasp'),
        CreatureCardProgress.gold,
      );
      await ThemeController.instance.setTheme(ThemePref.dark);
      await LocaleController.instance.setLanguage(LanguagePref.ru);
      await PlayerDisplayNameController.instance.save('ByteShark');
      await CreatureKillCountController.instance.setCount('g2_wasp', 4);
      await LocalStorage.setBool(TutorialController.completionKey, true);
      await LocalStorage.setString(
        aphidexViewStateStorageKey,
        const AphidexViewState(
          gamePickIndex: 2,
          sortModeIndex: 0,
          sortDescending: false,
          query: 'wasp',
          filterFavorites: true,
          filterGold: true,
          tierFilters: <String>{'3'},
          classFilters: <String>{'orc'},
          dangerFilters: <String>{'alta'},
          selectedSpeciesKey: 'wasp',
          detailEnemyId: 'g2_wasp',
          detailGame: 'g2',
          detailOpen: true,
          listScrollOffset: 48,
        ).toStorageString(),
      );

      final previousRevision = AppResetController.instance.revision.value;
      await AppResetController.instance.wipeForFreshStart();

      expect(AppResetController.instance.revision.value, previousRevision + 1);
      expect(FavoritesController.instance.favorites.value, isEmpty);
      expect(GoldController.instance.progress.value, isEmpty);
      expect(
        LocalStorage.getBool(TutorialController.completionKey, fallback: false),
        isFalse,
      );
      expect(LocalStorage.getString(aphidexViewStateStorageKey), isNull);
      expect(ThemeController.instance.theme.value, ThemePref.system);
      expect(LocaleController.instance.preference.value, LanguagePref.system);
      expect(PlayerDisplayNameController.instance.displayName.value, isEmpty);
      expect(CreatureKillCountController.instance.counts.value, isEmpty);
    },
  );
}

class _ResetTestCardCarrier implements CreatureCardCarrier {
  const _ResetTestCardCarrier({required this.id});

  @override
  final String id;

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
  String? assetForCardVariant(CreatureCardVariant variant) {
    return switch (variant) {
      CreatureCardVariant.normal => 'normal.webp',
      CreatureCardVariant.gold => 'gold.webp',
    };
  }
}
