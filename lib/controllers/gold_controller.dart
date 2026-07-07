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

  bool needsMigration(Iterable<CreatureCardCarrier> enemies) {
    for (final enemy in enemies) {
      final key = creatureCardProgressKey(enemy);
      final stored = _progress.value[key];
      if (stored != null) {
        final normalized = normalizeCreatureCardProgress(enemy, stored);
        if (normalized != stored) {
          return true;
        }
        continue;
      }

      final legacy = resolveLegacyCreatureCardProgress(
        enemy,
        _progress.value,
        legacyGoldIds: gold.value,
      );
      if (legacy != null) {
        return true;
      }
    }
    return false;
  }

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
    final next = Map<String, CreatureCardProgress>.from(_progress.value);
    var changed = false;
    final normalizedLegacy = <String>{};

    for (final enemy in enemies) {
      final key = creatureCardProgressKey(enemy);
      final stored = next[key];
      if (stored != null) {
        final normalized = normalizeCreatureCardProgress(enemy, stored);
        if (normalized == CreatureCardProgress.unowned) {
          next.remove(key);
        } else if (normalized != stored) {
          next[key] = normalized;
        }
        if (normalized != stored) {
          changed = true;
        }
      } else {
        final migrated = resolveLegacyCreatureCardProgress(
          enemy,
          next,
          legacyGoldIds: gold.value,
        );
        if (migrated != null && migrated != CreatureCardProgress.unowned) {
          next[key] = normalizeCreatureCardProgress(enemy, migrated);
          changed = true;
        }
      }

      final normalized = next[key];
      final aliases = creatureCardLegacyAliases(enemy);
      if (normalized == CreatureCardProgress.gold) {
        normalizedLegacy.add(enemy.id.trim());
        if (enemy.goldLinkId != null) {
          final linkId = enemy.goldLinkId!.trim();
          if (linkId.isNotEmpty) {
            normalizedLegacy.add(linkId);
          }
        }
      }
      for (final alias in aliases) {
        if (alias == key) {
          continue;
        }
        if (next.remove(alias) != null) {
          changed = true;
        }
      }
    }

    final legacyChanged =
        normalizedLegacy.length != gold.value.length ||
        !normalizedLegacy.containsAll(gold.value) ||
        !gold.value.containsAll(normalizedLegacy);

    if (!changed && !legacyChanged) {
      return;
    }

    _progress.value = next;
    gold.value = normalizedLegacy;
    await LocalStorage.setString(
      creatureCardProgressStorageKey,
      encodeCreatureCardProgressMap(next),
    );
    await LocalStorage.setStringSet(_key, normalizedLegacy);
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
