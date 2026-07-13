import 'dart:convert';

import 'local_storage.dart';

class CreatureKillCountRepository {
  const CreatureKillCountRepository._();

  static const profileId = 'default';
  static const storageKey = 'creature_kill_counts_$profileId';

  static Map<String, int> load() {
    try {
      final decoded = jsonDecode(LocalStorage.getString(storageKey) ?? '');
      if (decoded is! Map) {
        return <String, int>{};
      }
      final counts = <String, int>{};
      for (final entry in decoded.entries) {
        final id = entry.key.toString().trim();
        final value = entry.value;
        if (id.isEmpty || value is! num) {
          continue;
        }
        final normalized = value.toInt().clamp(0, 999999);
        if (normalized > 0) {
          counts[id] = normalized;
        }
      }
      return counts;
    } catch (_) {
      return <String, int>{};
    }
  }

  static Future<void> save(Map<String, int> counts) =>
      LocalStorage.setString(storageKey, jsonEncode(counts));

  static Future<void> clear() => LocalStorage.remove(storageKey);
}
