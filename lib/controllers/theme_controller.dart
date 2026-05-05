import 'package:flutter/material.dart';
import '../data/local_storage.dart';

enum ThemePref { system, light, dark }

class ThemeController {
  ThemeController._() {
    final raw = LocalStorage.getString(_key);
    theme.value = _fromString(raw);
  }

  static final ThemeController instance = ThemeController._();

  static const String _key = 'theme_pref';

  final ValueNotifier<ThemePref> theme = ValueNotifier<ThemePref>(
    ThemePref.system,
  );

  ThemeMode get themeMode {
    switch (theme.value) {
      case ThemePref.system:
        return ThemeMode.system;
      case ThemePref.light:
        return ThemeMode.light;
      case ThemePref.dark:
        return ThemeMode.dark;
    }
  }

  Future<void> setTheme(ThemePref pref) async {
    theme.value = pref;
    await LocalStorage.setString(_key, _toString(pref));
  }

  static ThemePref _fromString(String? s) {
    switch (s) {
      case 'light':
        return ThemePref.light;
      case 'dark':
        return ThemePref.dark;
      default:
        return ThemePref.system;
    }
  }

  static String _toString(ThemePref p) {
    switch (p) {
      case ThemePref.system:
        return 'system';
      case ThemePref.light:
        return 'light';
      case ThemePref.dark:
        return 'dark';
    }
  }
}
