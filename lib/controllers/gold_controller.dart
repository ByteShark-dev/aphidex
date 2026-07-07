import 'package:flutter/foundation.dart';

import '../data/creature_card_state.dart';
import '../data/local_storage.dart';
import '../models/creature_card_support.dart';

class GoldController {
  GoldController._() {
    reloadFromStorage();
  }

  static final GoldController instance = GoldController._();

  static const String _key = 'gold_cards';

  final ValueNotifier<Set<String>> gold = ValueNotifier<Set<String>>(
    <String>{},
  );
  final ValueNotifier<CreatureCardProgressMap> _progress =
      ValueNotifier<CreatureCardProgressMap>(<String, CreatureCardProgress>{});

  ValueListenable<CreatureCardProgressMap> get progress => _progress;

  bool hasGold(String id) => gold.value.contains(id);

  CreatureCardProgress progressFor(CreatureCardCarrier enemy) {
    return resolveCreatureCardProgress(
      enemy,
      _progress.value,
      legacyGoldIds: gold.value,
    );
  }

  Future<void> toggle(String id) async {
    await toggleLinked([id]);
  }

  Future<void> toggleLinked(Iterable<String?> ids) async {
    final linkedIds = ids
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (linkedIds.isEmpty) {
      return;
    }

    final next = Set<String>.from(gold.value);
    final shouldRemove = linkedIds.any(next.contains);
    if (shouldRemove) {
      next.removeAll(linkedIds);
    } else {
      next.addAll(linkedIds);
    }
    gold.value = next;
    await LocalStorage.setStringSet(_key, next);
  }

  Future<void> reset() async {
    gold.value = <String>{};
    _progress.value = <String, CreatureCardProgress>{};
    await Future.wait([
      LocalStorage.setStringSet(_key, gold.value),
      LocalStorage.setString(
        creatureCardProgressStorageKey,
        encodeCreatureCardProgressMap(_progress.value),
      ),
    ]);
  }

  Future<void> ensureMigrated(Iterable<CreatureCardCarrier> enemies) async {
    if (gold.value.isEmpty) {
      return;
    }

    final next = Map<String, CreatureCardProgress>.from(_progress.value);
    var changed = false;
    for (final enemy in enemies) {
      final key = creatureCardProgressKey(enemy);
      if (next.containsKey(key)) {
        continue;
      }
      final migrated = migrateLegacyCreatureCardProgress(enemy, gold.value);
      if (migrated == CreatureCardProgress.unowned) {
        continue;
      }
      next[key] = migrated;
      changed = true;
    }

    if (!changed) {
      return;
    }

    _progress.value = next;
    await LocalStorage.setString(
      creatureCardProgressStorageKey,
      encodeCreatureCardProgressMap(next),
    );
  }

  Future<CreatureCardProgress> cycle(CreatureCardCarrier enemy) async {
    final next = nextCreatureCardProgress(enemy, progressFor(enemy));
    await setProgress(enemy, next);
    return progressFor(enemy);
  }

  Future<void> setProgress(
    CreatureCardCarrier enemy,
    CreatureCardProgress progress,
  ) async {
    final normalized = normalizeCreatureCardProgress(enemy, progress);
    final next = Map<String, CreatureCardProgress>.from(_progress.value);
    final key = creatureCardProgressKey(enemy);
    if (normalized == CreatureCardProgress.unowned) {
      next.remove(key);
    } else {
      next[key] = normalized;
    }

    final linkedIds = <String>{
      enemy.id.trim(),
      if (enemy.goldLinkId != null) enemy.goldLinkId!.trim(),
    }..removeWhere((value) => value.isEmpty);
    final legacyNext = Set<String>.from(gold.value);
    if (normalized == CreatureCardProgress.gold) {
      legacyNext.addAll(linkedIds);
    } else {
      legacyNext.removeAll(linkedIds);
    }

    _progress.value = next;
    gold.value = legacyNext;
    await Future.wait([
      LocalStorage.setString(
        creatureCardProgressStorageKey,
        encodeCreatureCardProgressMap(next),
      ),
      LocalStorage.setStringSet(_key, legacyNext),
    ]);
  }

  void reloadFromStorage() {
    gold.value = LocalStorage.getStringSet(_key);
    _progress.value = decodeCreatureCardProgressMap(
      LocalStorage.getString(creatureCardProgressStorageKey),
    );
  }
}
