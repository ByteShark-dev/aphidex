import 'dart:io';

import 'package:aphidex/controllers/monetization_controller.dart';
import 'package:aphidex/data/aphidex_view_state.dart';
import 'package:aphidex/data/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('startup state logic', () {
    late Directory hiveDir;

    setUpAll(() async {
      hiveDir = await Directory.systemTemp.createTemp(
        'aphidex_startup_state_logic_',
      );
      Hive.init(hiveDir.path);
      await Hive.openBox('aphidex');
    });

    tearDownAll(() async {
      await Hive.box('aphidex').close();
    });

    setUp(() async {
      await Hive.box('aphidex').clear();
      MonetizationController.instance.adsRemoved.value = false;
    });

    test(
      'copyWith can clear detailOpen without losing the selected creature context',
      () {
        const state = AphidexViewState(
          gamePickIndex: 2,
          sortModeIndex: 0,
          sortDescending: false,
          query: '',
          filterFavorites: false,
          filterGold: false,
          tierFilters: <String>{},
          classFilters: <String>{},
          dangerFilters: <String>{},
          selectedSpeciesKey: 'startup_enemy',
          detailEnemyId: 'g2_startup_enemy',
          detailGame: 'g2',
          detailOpen: true,
          listScrollOffset: 12,
        );

        final next = state.copyWith(detailOpen: false);

        expect(next.detailOpen, isFalse);
        expect(next.selectedSpeciesKey, state.selectedSpeciesKey);
        expect(next.detailEnemyId, state.detailEnemyId);
        expect(next.detailGame, state.detailGame);
        expect(next.listScrollOffset, state.listScrollOffset);
      },
    );

    test(
      'monetization local state is available before deferred store initialization',
      () async {
        await LocalStorage.setBool('monetization_ads_removed', true);

        MonetizationController.instance.primeLocalState();

        expect(MonetizationController.instance.adsRemoved.value, isTrue);
      },
    );
  });
}
