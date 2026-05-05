import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aphidex/controllers/locale_controller.dart';
import 'package:aphidex/models/enemy.dart';

void main() {
  group('LocalizedText', () {
    test('resolves requested language and falls back to Spanish', () {
      const text = LocalizedText(es: 'Mariquita', en: 'Ladybug');

      expect(text.resolve('en'), 'Ladybug');
      expect(text.resolve('ru'), 'Mariquita');
      expect(text.resolve('es'), 'Mariquita');
    });
  });

  group('LocaleController', () {
    test('maps unsupported locales to Spanish', () {
      expect(
        LocaleController.resolveSupportedLocale(const Locale('ru')),
        const Locale('ru'),
      );
      expect(
        LocaleController.resolveSupportedLocale(const Locale('de')),
        const Locale('en'),
      );
      expect(LocaleController.resolveSupportedLocale(null), const Locale('en'));
    });
  });
}
