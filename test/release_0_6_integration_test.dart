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
      final index =
          jsonDecode(
                File(
                  'assets/data/creatures/$language/index_g2.json',
                ).readAsStringSync(),
              )
              as List<dynamic>;
      final ids = index.whereType<Map>().map((entry) => entry['id']).toSet();
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

  test(
    'enriched Release 0.6 records retain unknown encounters but expose resolved loot',
    () {
      for (final id in releaseIds) {
        final detail = _json('assets/data/creatures/en/details/$id.json');
        expect(
          detail['availabilityStatus'],
          const {
                'g2_centipede',
                'g2_ogre_termite_king',
                'g2_termite_nymph',
                'g2_termite_queen',
                'g2_termite_soldier',
                'g2_termite_worker',
              }.contains(id)
              ? 'confirmed'
              : 'implemented_unconfirmed',
        );
        final hasRecoveredSpawn = const {
          'g2_centipede',
          'g2_ogre_termite_king',
          'g2_termite_nymph',
          'g2_termite_queen',
          'g2_termite_soldier',
          'g2_termite_worker',
        }.contains(id);
        expect(detail['locations'], hasRecoveredSpawn ? isNotEmpty : isEmpty);
        expect(
          detail['underConstruction'] == true,
          isNot(hasRecoveredSpawn),
          reason: '$id only receives a difficulty after a confirmed encounter',
        );
        expect(
          detail['danger'],
          hasRecoveredSpawn ? isNot('proximamente') : 'proximamente',
          reason: '$id uses the under-construction difficulty fallback',
        );
        if (id == 'g2_termite_queen') {
          expect(detail['loot'], isEmpty);
        } else {
          expect(detail['loot'], isNotEmpty);
        }
        if (id == 'g2_termite_queen') {
          expect(detail['cardNormal'], isEmpty);
          expect(detail['cardGold'], isNotEmpty);
          expect(detail['hasCreatureCard'], isTrue);
          expect(detail['hasGoldCreatureCard'], isTrue);
        } else {
          expect(detail['cardNormal'], isNotEmpty);
          expect(detail['cardGold'], isNotEmpty);
          expect(File(detail['cardNormal'] as String).existsSync(), isTrue);
          expect(File(detail['cardGold'] as String).existsSync(), isTrue);
        }
        expect(detail['cardEvidence'], isA<Map>());
      }
    },
  );

  test(
    'Skritch and Termite Queen preserve their enriched source boundaries',
    () {
      final centipede = _json(
        'assets/data/creatures/en/details/g2_centipede.json',
      );
      final queen = _json(
        'assets/data/creatures/en/details/g2_termite_queen.json',
      );
      expect((centipede['health'] as Map)['value'], 9000);
      expect(centipede['name'], 'Skritch Centipede');
      expect((centipede['locations'] as List), hasLength(1));
      expect(centipede['description'], isNot(contains('<')));
      expect((centipede['attacks'] as List), hasLength(19));
      expect(centipede['cardEvidence']['normal'], 'T_UI_Tier4_Centipede');
      expect(centipede['technicalId'], 'Centipede');
      expect(queen['isKillable'], isFalse);
      expect(queen['health'], isNull);
      expect(queen['attacks'], isEmpty);
      expect(queen['tier'], 4);
      expect(queen['temperament'], 'peaceful');
      expect(queen['collectionGroup'], 'harmless');
      expect(queen['interactionInfo']['offerings'], hasLength(2));
      expect(queen['interactionInfo']['rewards'], hasLength(1));
    },
  );

  test('Termite Larva is shown with peaceful creatures', () {
    for (final language in const ['en', 'es', 'ru']) {
      final larva = _json(
        'assets/data/creatures/$language/details/g2_termite_nymph.json',
      );
      expect(larva['temperament'], 'peaceful');
      expect(larva['collectionGroup'], 'harmless');
    }
  });

  test('confirmed Release 0.6 locations are projected once to the map', () {
    final map = _json('assets/data/g2/map.json');
    final markers = (map['markers'] as List).cast<Map>();

    final centipedeMarkers = markers
        .where((marker) => marker['targetId'] == 'g2_centipede')
        .toList();
    expect(centipedeMarkers, hasLength(1));
    expect(centipedeMarkers.single['id'], 'release_0_6_centipede_0');

    final queenMarkers = markers
        .where((marker) => marker['targetId'] == 'g2_termite_queen')
        .toList();
    expect(queenMarkers, hasLength(1));
    expect(
      markers.where(
        (marker) => marker['targetId'] == 'g2_ogre_diving_bell_spider',
      ),
      isEmpty,
    );
    for (final marker in [...centipedeMarkers, ...queenMarkers]) {
      expect(marker['u'], isA<num>());
      expect(marker['v'], isA<num>());
      expect(marker['u'], inInclusiveRange(0, 1));
      expect(marker['v'], inInclusiveRange(0, 1));
    }
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

  test(
    'O.G.R.E. diving bell spider exposes its confirmed encounter and shared combat pattern',
    () {
      for (final language in const ['en', 'es', 'ru']) {
        final spider = _json(
          'assets/data/creatures/$language/details/g2_ogre_diving_bell_spider.json',
        );
        expect(spider['availabilityStatus'], 'implemented_unconfirmed');
        expect(spider['underConstruction'], isTrue);
        expect(spider['locations'], isEmpty);
        expect(
          spider['sourceProvenance']['spawn'],
          'extractor_actor_reference_pending_runtime_confirmation',
        );
        expect(spider['behavior'], isNotEmpty);
        expect(spider['interactionWithCreatures'], contains('322'));
        final attacks = spider['attacks'] as List;
        expect(attacks, hasLength(3));
        for (final attack in attacks) {
          expect(attack['tell'], isNotEmpty);
          expect(attack['howToAvoid'], isNotEmpty);
          expect(attack['notes'], isNotEmpty);
        }
      }
    },
  );

  test('Release 0.6 combat stat values match Aphidex integer model fields', () {
    for (final language in const ['en', 'es', 'ru']) {
      for (final id in releaseIds) {
        final stats =
            _json(
                  'assets/data/creatures/$language/details/$id.json',
                )['combatStats']
                as Map;
        for (final field in const [
          'health',
          'stunThreshold',
          'stunCooldownSeconds',
        ]) {
          final value = stats[field];
          expect(
            value,
            anyOf(isNull, isA<int>()),
            reason: '$language/$id $field',
          );
        }
      }
    }
  });

  test('recovered default-combo and death attacks remain visible', () {
    final worker = _json(
      'assets/data/creatures/en/details/g2_termite_worker.json',
    );
    final king = _json('assets/data/creatures/en/details/g2_termite_king.json');
    final workerMoves = (worker['attacks'] as List).map(
      (row) => row['technicalId'],
    );
    final kingMoves = (king['attacks'] as List).map(
      (row) => row['technicalId'],
    );
    expect(workerMoves, contains('TermiteWorkerLunge'));
    expect(kingMoves, contains('TermiteKingSacrifice'));
  });

  test(
    'Centipede encounter support roles and O.G.R.R. flavours are explicit',
    () {
      for (final language in const ['en', 'es', 'ru']) {
        for (final id in const [
          'g2_termite_nymph',
          'g2_termite_worker',
          'g2_termite_soldier',
        ]) {
          final detail = _json(
            'assets/data/creatures/$language/details/$id.json',
          );
          final variants = detail['encounterVariants'] as List;
          expect(variants, hasLength(1));
          expect(variants.single['role'], 'boss_encounter_support');
        }
        for (final id in const [
          'g2_ogre_termite_king',
          'g2_ogre_diving_bell_spider',
        ]) {
          final detail = _json(
            'assets/data/creatures/$language/details/$id.json',
          );
          expect(detail['infusions'], hasLength(3));
        }
      }
    },
  );

  test('Release trinkets use source texture exports and creature cards', () {
    final catalog = _json('assets/data/g2/equipment.json');
    final byId = {
      for (final item in (catalog['items'] as List).cast<Map>())
        item['id']: item,
    };
    for (final id in const ['AccessoryCentipede', 'AccessoryTermite']) {
      final item = byId[id]!;
      expect(File(item['icon'] as String).existsSync(), isTrue);
      final sources = item['acquisition']['lootSourceReferences'] as List;
      expect(sources, isNotEmpty);
      for (final source in sources.cast<Map>()) {
        expect(File(source['cardAsset'] as String).existsSync(), isTrue);
      }
    }
  });

  test('Potato Beetle Buggy inherits the normal Potato Beetle card state', () {
    final buggy = _json(
      'assets/data/creatures/en/details/g2_buggy_potato_beetle.json',
    );
    final profile = (buggy['buggyProfile'] as Map).cast<String, dynamic>();
    final recipe = (profile['recipe'] as Map).cast<String, dynamic>();
    expect(buggy['id'], 'g2_buggy_potato_beetle');
    expect(buggy['favoriteKey'], 'g2_buggy_potato_beetle');
    expect(profile['technicalId'], 'PotatoBug_Buggy');
    expect(recipe['row'], 'PotatoBugHatch');
    final potato = _json(
      'assets/data/creatures/en/details/g2_potato_beetle.json',
    );
    expect(buggy['cardNormal'], potato['cardNormal']);
    expect(buggy['cardGold'], potato['cardGold']);
  });

  test('existing buggy identifiers remain unchanged', () {
    final index =
        jsonDecode(
              File('assets/data/creatures/en/index_g2.json').readAsStringSync(),
            )
            as List<dynamic>;
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

  test('shared G1 termites use the same cross-game species keys', () {
    const expected = {
      'g2_termite_king': 'g1_termite_king',
      'g2_termite_soldier': 'g1_termite_soldier',
      'g2_termite_worker': 'g1_termite_worker',
    };
    for (final entry in expected.entries) {
      final detail = _json(
        'assets/data/creatures/en/details/${entry.key}.json',
      );
      expect(detail['speciesKey'], entry.value);
    }
  });
}
