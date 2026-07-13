import '../models/enemy.dart';
import '../models/enemy_index_entry.dart';

class CreatureKillTracking {
  const CreatureKillTracking._();

  static const _excludedGroups = {'buggy', 'other'};
  static const _excludedIds = {'g1_crow', 'g2_crow'};

  static bool supports({
    required String id,
    required String game,
    required String? collectionGroup,
    required bool isUnderConstruction,
  }) {
    return (game == 'g1' || game == 'g2') &&
        !isUnderConstruction &&
        !_excludedIds.contains(id) &&
        !_excludedGroups.contains(collectionGroup);
  }

  static bool supportsIndex(EnemyIndexEntry entry) => supports(
    id: entry.id,
    game: entry.game,
    collectionGroup: entry.collectionGroup,
    isUnderConstruction: entry.isUnderConstruction,
  );

  static bool supportsEnemy(Enemy enemy) =>
      enemy.isKillable &&
      supports(
        id: enemy.id,
        game: enemy.game,
        collectionGroup: enemy.collectionGroup,
        isUnderConstruction: enemy.isUnderConstruction,
      );
}
