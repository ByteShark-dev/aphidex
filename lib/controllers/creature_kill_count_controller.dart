import 'package:flutter/foundation.dart';

import '../data/creature_kill_count_repository.dart';
import '../data/creature_kill_tracking.dart';
import '../models/enemy_index_entry.dart';
import '../models/player_character.dart';

class CreatureKillCountController {
  CreatureKillCountController._() {
    reloadFromStorage();
  }

  static final CreatureKillCountController instance =
      CreatureKillCountController._();

  static const maxCount = 999999;
  final ValueNotifier<Map<String, int>> counts =
      ValueNotifier<Map<String, int>>(<String, int>{});

  int getCount(String creatureId) => counts.value[creatureId] ?? 0;

  Future<void> increment(String creatureId) =>
      setCount(creatureId, getCount(creatureId) + 1);

  Future<void> decrement(String creatureId) =>
      setCount(creatureId, getCount(creatureId) - 1);

  Future<void> setCount(String creatureId, int value) async {
    final id = creatureId.trim();
    if (id.isEmpty) {
      return;
    }
    final normalized = value.clamp(0, maxCount);
    final next = Map<String, int>.from(counts.value);
    if (normalized == 0) {
      next.remove(id);
    } else {
      next[id] = normalized;
    }
    counts.value = next;
    await CreatureKillCountRepository.save(next);
  }

  Future<void> clearCreature(String creatureId) => setCount(creatureId, 0);

  Future<void> clearAll() async {
    counts.value = <String, int>{};
    await CreatureKillCountRepository.clear();
  }

  Future<void> clearAllKillCounts() => clearAll();

  int totalForGame(AphidexGame game, Iterable<EnemyIndexEntry> entries) {
    final gameId = game == AphidexGame.grounded ? 'g1' : 'g2';
    return entries
        .where(
          (entry) =>
              entry.game == gameId && CreatureKillTracking.supportsIndex(entry),
        )
        .fold(0, (total, entry) => total + getCount(entry.id));
  }

  void reloadFromStorage() {
    counts.value = CreatureKillCountRepository.load();
  }
}
