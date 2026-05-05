import 'package:flutter/foundation.dart';
import '../data/local_storage.dart';

class GoldController {
  GoldController._() {
    gold.value = LocalStorage.getStringSet(_key);
  }
  static final GoldController instance = GoldController._();

  static const String _key = 'gold_cards';

  final ValueNotifier<Set<String>> gold = ValueNotifier<Set<String>>(
    <String>{},
  );

  bool hasGold(String id) => gold.value.contains(id);

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

    final s = Set<String>.from(gold.value);
    final shouldRemove = linkedIds.any(s.contains);
    if (shouldRemove) {
      s.removeAll(linkedIds);
    } else {
      s.addAll(linkedIds);
    }
    gold.value = s;
    await LocalStorage.setStringSet(_key, s);
  }

  Future<void> reset() async {
    gold.value = <String>{};
    await LocalStorage.setStringSet(_key, gold.value);
  }
}
