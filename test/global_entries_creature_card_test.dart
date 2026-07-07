import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final master =
      (jsonDecode(File('assets/data/enemies_g1.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();
  final index =
      (jsonDecode(
                File(
                  'assets/data/creatures/en/index_g1.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();

  Map<String, dynamic> masterEntry(String id) =>
      master.firstWhere((entry) => entry['id'] == id);
  Map<String, dynamic> indexEntry(String id) =>
      index.firstWhere((entry) => entry['id'] == id);

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
    String expectedDetailPhoto,
  ) {
    final entry = masterEntry(id);
    final listEntry = indexEntry(id);

    expect(entry['cardNormal'], isEmpty, reason: '$id should not fake a card');
    expect(entry['cardGold'], isEmpty, reason: '$id should not fake a card');
    expect(listEntry['hasCreatureCard'], isFalse);
    expect(listEntry['hasGoldCreatureCard'], isFalse);
    expect(listEntry['hasSelectableCardVariants'], isFalse);
    expect(listEntry['listIconAsset'], expectedListIconAsset);

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
      expect(detail['photo'], expectedDetailPhoto, reason: '$language/$id');
    }
  }

  test('g1 global O.R.C. entry stays out of the creature-card system', () {
    expectGlobalEntryWithoutCreatureCard(
      'g1_enemy_orc',
      'assets/g1/creatures/cards/gold/Creaturecardgold_ORC.webp',
      'assets/g1/creatures/photos/ORC.webp',
    );
  });

  test('g1 global infused entry stays out of the creature-card system', () {
    expectGlobalEntryWithoutCreatureCard(
      'g1_enemy_infused',
      'assets/g1/creatures/cards/gold/Creaturecardgold_Infused_Insects.webp',
      'assets/g1/creatures/photos/Infused_Insects.webp',
    );
  });
}
