import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final master =
      (jsonDecode(File('assets/data/enemies_g1.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();

  Map<String, dynamic> masterEntry(String id) =>
      master.firstWhere((entry) => entry['id'] == id);

  Map<String, dynamic> detailEntry(String language, String id) {
    return jsonDecode(
          File(
            'assets/data/creatures/$language/details/$id.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
  }

  void expectGlobalEntryWithoutCreatureCard(
    String id,
    String expectedListIconAsset,
  ) {
    final entry = masterEntry(id);

    expect(entry['cardNormal'], isEmpty, reason: '$id should not fake a card');
    expect(entry['cardGold'], isEmpty, reason: '$id should not fake a card');
    expect(entry['hasCreatureCard'], isFalse);
    expect(entry['hasGoldCreatureCard'], isFalse);
    expect(entry['hasSelectableCardVariants'], isFalse);
    expect(entry['listIconAsset'], expectedListIconAsset);
    expect(entry['photo'], expectedListIconAsset);

    for (final language in const ['es', 'en', 'ru']) {
      final detail = detailEntry(language, id);
      expect(detail['cardNormal'], isEmpty, reason: '$language/$id');
      expect(detail['cardGold'], isEmpty, reason: '$language/$id');
      expect(detail['hasCreatureCard'], isFalse, reason: '$language/$id');
      expect(
        detail['hasSelectableCardVariants'],
        isFalse,
        reason: '$language/$id',
      );
      expect(
        detail['listIconAsset'],
        expectedListIconAsset,
        reason: '$language/$id',
      );
      expect(detail['photo'], expectedListIconAsset, reason: '$language/$id');
    }
  }

  test('g1 global O.R.C. entry stays out of the creature-card system', () {
    expectGlobalEntryWithoutCreatureCard(
      'g1_enemy_orc',
      'assets/g1/creatures/photos/ORC.webp',
    );
  });

  test('g1 global infused entry stays out of the creature-card system', () {
    expectGlobalEntryWithoutCreatureCard(
      'g1_enemy_infused',
      'assets/g1/creatures/photos/Infused_Insects.webp',
    );
  });
}
