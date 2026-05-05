import 'package:hive/hive.dart';

class LocalStorage {
  static Box get _box => Hive.box('aphidex');

  // ---------- Sets (guardados como List<String>) ----------
  static Set<String> getStringSet(String key) {
    final raw = _box.get(key);
    if (raw is List) {
      return raw.map((e) => e.toString()).toSet();
    }
    return <String>{};
  }

  static Future<void> setStringSet(String key, Set<String> value) async {
    await _box.put(key, value.toList());
  }

  static bool hasKey(String key) => _box.containsKey(key);

  // ---------- Strings / bool / int ----------
  static String? getString(String key) => _box.get(key) as String?;
  static Future<void> setString(String key, String value) =>
      _box.put(key, value);

  static bool getBool(String key, {bool fallback = false}) {
    final v = _box.get(key);
    return v is bool ? v : fallback;
  }

  static Future<void> setBool(String key, bool value) => _box.put(key, value);

  static int getInt(String key, {int fallback = 0}) {
    final v = _box.get(key);
    return v is int ? v : fallback;
  }

  static Future<void> setInt(String key, int value) => _box.put(key, value);

  static Future<void> clearAll({Set<String> preserveKeys = const {}}) async {
    final preserved = <String, dynamic>{};
    for (final key in preserveKeys) {
      if (_box.containsKey(key)) {
        preserved[key] = _box.get(key);
      }
    }
    await _box.clear();
    if (preserved.isNotEmpty) {
      await _box.putAll(preserved);
    }
  }
}
