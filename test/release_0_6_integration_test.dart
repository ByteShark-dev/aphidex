import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  const releaseIds = <String>[
    'g2_centipede',
    'g2_ogre_diving_bell_spider',
    'g2_termite_king',
    'g2_ogre_termite_king',
    'g2_termite_nymph',
    'g2_termite_queen',
    'g2_termite_soldier',
    'g2_orc_termite_soldier',
    'g2_termite_worker',
    'g2_orc_termite_worker',
  ];

  test('Release 0.6 entries exist in every localized catalogue', () {
    for (final language in const ['en', 'es', 'ru']) {
      final index = jsonDecode(
        File('assets/data/creatures/$language/index_g2.json').readAsStringSync(),
      ) as List<dynamic>;
      final ids = index
          .whereType<Map>()
          .map((entry) => entry['id'])
          .toSet();
      expect(ids, containsAll(releaseIds));
      for (final id in releaseIds) {
        expect(
          File('assets/data/creatures/$language/details/$id.json').existsSync(),
          isTrue,
          reason: '$language/$id detail is required by the lazy repository',
        );
      }
    }
  });

  test('unconfirmed Release 0.6 records do not invent encounters or loot', () {
    for (final id in releaseIds) {
      final detail = _json('assets/data/creatures/en/details/$id.json');
      expect(detail['availabilityStatus'], 'implemented_unconfirmed');
      expect(detail['locations'], isEmpty);
      expect(detail['loot'], isEmpty);
      expect(detail['cardNormal'], isEmpty);
      expect(detail['cardGold'], isEmpty);
    }
  });

  test('Centipede and Termite Queen preserve their source boundaries', () {
    final centipede = _json('assets/data/creatures/en/details/g2_centipede.json');
    final queen = _json('assets/data/creatures/en/details/g2_termite_queen.json');
    expect((centipede['health'] as Map)['value'], 9000);
    expect(centipede['technicalId'], 'Centipede');
    expect(queen['isKillable'], isFalse);
    expect(queen['health'], isNull);
    expect(queen['attacks'], isEmpty);
  });

  test('Potato Beetle Buggy has source-backed hatchery data without cards', () {
    final buggy = _json(
      'assets/data/creatures/en/details/g2_buggy_potato_beetle.json',
    );
    final profile = (buggy['buggyProfile'] as Map).cast<String, dynamic>();
    final recipe = (profile['recipe'] as Map).cast<String, dynamic>();
    expect(buggy['id'], 'g2_buggy_potato_beetle');
    expect(buggy['favoriteKey'], 'g2_buggy_potato_beetle');
    expect(profile['technicalId'], 'PotatoBug_Buggy');
    expect(recipe['row'], 'PotatoBugHatch');
    expect(buggy['cardNormal'], isEmpty);
    expect(buggy['cardGold'], isEmpty);
  });

  test('existing buggy identifiers remain unchanged', () {
    final index = jsonDecode(
      File('assets/data/creatures/en/index_g2.json').readAsStringSync(),
    ) as List<dynamic>;
    final ids = index.whereType<Map>().map((entry) => entry['id']).toSet();
    expect(
      ids,
      containsAll(const [
        'g2_buggy_black_soldier_ant',
        'g2_buggy_ladybug',
        'g2_buggy_orb_weaver',
        'g2_buggy_red_soldier_ant',
        'g2_buggy_toe_biter',
      ]),
    );
  });
}
