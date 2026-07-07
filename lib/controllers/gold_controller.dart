import 'package:flutter/foundation.dart';

import '../data/creature_card_state.dart';
import '../data/local_storage.dart';
import '../models/creature_card_support.dart';

class GoldController {
  GoldController._() {
    gold.value = LocalStorage.getStringSet(_key);
    _syncProgress();
    gold.addListener(_syncProgress);
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
    return resolveCreatureCardProgress(enemy, _progress.value);
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
    await LocalStorage.setStringSet(_key, gold.value);
  }

  Future<void> ensureMigrated(Iterable<CreatureCardCarrier> enemies) async {}

  Future<CreatureCardProgress> cycle(CreatureCardCarrier enemy) async {
    await toggleLinked([enemy.id, enemy.goldLinkId]);
    return progressFor(enemy);
  }

  void _syncProgress() {
    final next = <String, CreatureCardProgress>{};
    for (final id in gold.value) {
      next['g1:$id'] = CreatureCardProgress.gold;
      next['g2:$id'] = CreatureCardProgress.gold;
    }
    _progress.value = next;
  }
}
