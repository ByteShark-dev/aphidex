import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _corruptFragments = ['ï¿½', 'Ãƒ', 'Ã¢'];

void main() {
  String extractOrchidMantisTextFromMaster() {
    final data =
        (jsonDecode(File('assets/data/enemies_g2.json').readAsStringSync())
                as List)
            .cast<Map<String, dynamic>>();
    final orchid = data.firstWhere(
      (entry) => entry['id'] == 'g2_orchid_mantis',
    );
    return jsonEncode(orchid);
  }

  test('g2 orchid mantis master entry has no mojibake fragments', () {
    final payload = extractOrchidMantisTextFromMaster();
    for (final fragment in _corruptFragments) {
      expect(payload, isNot(contains(fragment)), reason: fragment);
    }
  });

  test('g2 orchid mantis localized details have no mojibake fragments', () {
    for (final language in const ['es', 'en', 'ru']) {
      final payload = File(
        'assets/data/creatures/$language/details/g2_orchid_mantis.json',
      ).readAsStringSync();
      for (final fragment in _corruptFragments) {
        expect(
          payload,
          isNot(contains(fragment)),
          reason: '$language/$fragment',
        );
      }
    }
  });
}
