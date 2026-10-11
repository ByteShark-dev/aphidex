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

  test('enriched Release 0.6 records retain unknown encounters but expose resolved loot', () {
    for (final id in releaseIds) {
      final detail = _json('assets/data/creatures/en/details/$id.json');
      expect(detail['availabilityStatus'], 'implemented_unconfirmed');
      expect(detail['locations'], isEmpty);
      if (id == 'g2_termite_queen') {
        expect(detail['loot'], isEmpty);
      } else {
        expect(detail['loot'], isNotEmpty);
      }
      if (id == 'g2_termite_queen') {
        expect(detail['cardNormal'], isEmpty);
        expect(detail['cardGold'], isNotEmpty);
      } else {
        expect(detail['cardNormal'], isNotEmpty);
        expect(detail['cardGold'], isNotEmpty);
        expect(File(detail['cardNormal'] as String).existsSync(), isTrue);
        expect(File(detail['cardGold'] as String).existsSync(), isTrue);
      }
      expect(detail['cardEvidence'], isA<Map>());
    }
  });

  test('Skritch and Termite Queen preserve their enriched source boundaries', () {
    final centipede = _json('assets/data/creatures/en/details/g2_centipede.json');
    final queen = _json('assets/data/creatures/en/details/g2_termite_queen.json');
    expect((centipede['health'] as Map)['value'], 9000);
    expect(centipede['name'], 'Skritch');
    expect(centipede['description'], isNot(contains('<')));
    expect((centipede['attacks'] as List), hasLength(19));
    expect(centipede['cardEvidence']['normal'], 'T_UI_Tier4_Centipede');
    expect(centipede['technicalId'], 'Centipede');
    expect(queen['isKillable'], isFalse);
    expect(queen['health'], isNull);
    expect(queen['attacks'], isEmpty);
    expect(queen['interactionInfo']['offerings'], hasLength(2));
    expect(queen['interactionInfo']['rewards'], hasLength(1));
  });

  test('official EN/ES runtime text is clean and RU is populated', () {
    final en = _json('assets/data/creatures/en/details/g2_termite_nymph.json');
    final es = _json('assets/data/creatures/es/details/g2_termite_nymph.json');
    final ru = _json('assets/data/creatures/ru/details/g2_termite_nymph.json');
    expect(en['name'], 'Termite Larva');
    expect(es['name'], 'Larva de termita');
    expect(ru['name'], 'Личинка термита');
    for (final detail in [en, es, ru]) {
      expect(detail['description'], isNot(contains('<')));
      expect(detail['description'], isNot(contains('--->')));
    }
    final spiderEs = _json(
      'assets/data/creatures/es/details/g2_ogre_diving_bell_spider.json',
    );
    expect(spiderEs['name'], 'Araña campana buceadora I.R.G.O.');
  });

  test('recovered default-combo and death attacks remain visible', () {
    final worker = _json('assets/data/creatures/en/details/g2_termite_worker.json');
    final king = _json('assets/data/creatures/en/details/g2_termite_king.json');
    final workerMoves = (worker['attacks'] as List).map((row) => row['technicalId']);
    final kingMoves = (king['attacks'] as List).map((row) => row['technicalId']);
    expect(workerMoves, contains('TermiteWorkerLunge'));
    expect(kingMoves, contains('TermiteKingSacrifice'));
  });

  test('Potato Beetle Buggy has source-backed hatchery data and no cards', () {
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
