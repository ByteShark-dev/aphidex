import 'package:aphidex/data/aphidex_view_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'view state serialization round-trips the persisted master-detail data',
    () {
      const state = AphidexViewState(
        gamePickIndex: 2,
        sortModeIndex: 3,
        sortDescending: true,
        query: 'mantis',
        filterFavorites: true,
        filterGold: true,
        tierFilters: {'3', 'boss'},
        classFilters: {'orc', 'boss'},
        dangerFilters: {'alta', 'imposible'},
        selectedSpeciesKey: 'ogrr_wasp',
        detailEnemyId: 'g2_ogrr_wasp',
        detailGame: 'g2',
        detailOpen: true,
        listScrollOffset: 248.5,
      );

      final restored = AphidexViewState.fromStorageString(
        state.toStorageString(),
      );

      expect(restored, isNotNull);
      expect(restored!.version, 1);
      expect(restored.gamePickIndex, state.gamePickIndex);
      expect(restored.sortModeIndex, state.sortModeIndex);
      expect(restored.sortDescending, isTrue);
      expect(restored.query, 'mantis');
      expect(restored.filterFavorites, isTrue);
      expect(restored.filterGold, isTrue);
      expect(restored.tierFilters, {'3', 'boss'});
      expect(restored.classFilters, {'orc', 'boss'});
      expect(restored.dangerFilters, {'alta', 'imposible'});
      expect(restored.selectedSpeciesKey, 'ogrr_wasp');
      expect(restored.detailEnemyId, 'g2_ogrr_wasp');
      expect(restored.detailGame, 'g2');
      expect(restored.detailOpen, isTrue);
      expect(restored.listScrollOffset, 248.5);
    },
  );

  test('invalid persisted state is ignored safely', () {
    expect(AphidexViewState.fromStorageString(''), isNull);
    expect(AphidexViewState.fromStorageString('{oops'), isNull);
    expect(AphidexViewState.fromStorageString('[]'), isNull);
  });
}
