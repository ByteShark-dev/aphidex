import 'package:flutter/material.dart';

import '../data/local_storage.dart';

enum LanguagePref { system, es, en, ru }

class LocaleController {
  LocaleController._() {
    preference.value = _fromString(LocalStorage.getString(_key));
  }

  static final LocaleController instance = LocaleController._();

  static const String _key = 'language_pref';
  static const List<String> supportedLanguageCodes = ['es', 'en', 'ru'];

  final ValueNotifier<LanguagePref> preference = ValueNotifier<LanguagePref>(
    LanguagePref.system,
  );

  Locale? get locale {
    switch (preference.value) {
      case LanguagePref.system:
        return null;
      case LanguagePref.es:
        return const Locale('es');
      case LanguagePref.en:
        return const Locale('en');
      case LanguagePref.ru:
        return const Locale('ru');
    }
  }

  Future<void> setLanguage(LanguagePref pref) async {
    preference.value = pref;
    await LocalStorage.setString(_key, _toString(pref));
  }

  static Locale resolveSupportedLocale(Locale? locale) {
    final code = locale?.languageCode.toLowerCase();
    if (supportedLanguageCodes.contains(code)) {
      return Locale(code!);
    }
    return const Locale('en');
  }

  static LanguagePref _fromString(String? value) {
    switch (value) {
      case 'es':
        return LanguagePref.es;
      case 'en':
        return LanguagePref.en;
      case 'ru':
        return LanguagePref.ru;
      default:
        return LanguagePref.system;
    }
  }

  static String _toString(LanguagePref pref) {
    switch (pref) {
      case LanguagePref.system:
        return 'system';
      case LanguagePref.es:
        return 'es';
      case LanguagePref.en:
        return 'en';
      case LanguagePref.ru:
        return 'ru';
    }
  }
}
