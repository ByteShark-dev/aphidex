import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final file = File('assets/data/enemies_g2.json');
  final data = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  Map<String, dynamic> entry(String id) =>
      data.firstWhere((enemy) => enemy['id'] == id);

  test('water damage is never stored as an elemental weakness in g2', () {
    for (final enemy in data) {
      final elemental = (enemy['elementalWeaknesses'] as List?) ?? const [];
      expect(
        elemental.whereType<Map>().any((bonus) => bonus['type'] == 'water'),
        isFalse,
        reason: 'water should be treated as damage, not elemental',
      );
    }
  });

  test(
    'curated shared g2 entries keep localized names and structured combat data',
    () {
      final redWorkerAnt = entry('g2_red_worker_ant');
      final ladybug = entry('g2_ladybug');
      final bee = entry('g2_bee');
      final firefly = entry('g2_firefly');

      expect(redWorkerAnt['name']['es'], 'Hormiga obrera roja');
      expect(
        (redWorkerAnt['damageWeaknesses'] as List).whereType<Map>().any(
          (bonus) => bonus['type'] == 'stabbing',
        ),
        isTrue,
      );

      expect(ladybug['name']['es'], 'Mariquita');
      expect(
        (ladybug['resistancesV2'] as List).whereType<Map>().any(
          (bonus) => bonus['type'] == 'sizzle',
        ),
        isTrue,
      );

      expect(bee['name']['es'], 'Abeja');
      expect(
        (bee['description']['es'] as String).startsWith('Una criatura'),
        isTrue,
      );
      expect(bee['advancedLootTable'], isNotEmpty);

      expect(firefly['name']['es'], 'Luciérnaga');
      expect((firefly['inflictsEffects'] as List).contains('busting'), isTrue);
      expect(
        (firefly['description']['en'] as String).startsWith(
          'A Tier 3 neutral firefly',
        ),
        isTrue,
      );
    },
  );

  test('g2 weak points match the curated creature board', () {
    expect(
      entry('g2_baby_garden_snail')['weakPoint'],
      containsPair('susceptibleDamage', 'stabbing_arrows_only'),
    );
    expect(
      entry('g2_garden_snail')['weakPoint'],
      containsPair('susceptibleDamage', 'stabbing_arrows_only'),
    );
    expect(
      entry('g2_praying_mantis_nymph')['weakPoint'],
      containsPair('susceptibleDamage', 'stabbing_bows_and_spears'),
    );
    expect(
      entry('g2_ladybug')['weakPoint'],
      equals({
        'part': 'legs',
        'susceptibleDamage': 'slashing',
        'susceptibleDamageTypes': ['slashing'],
      }),
    );
    expect(
      entry('g2_potato_beetle')['weakPoint'],
      equals({
        'part': 'legs',
        'susceptibleDamage': 'slashing',
        'susceptibleDamageTypes': ['slashing'],
      }),
    );
    expect(
      entry('g2_rust_beetle')['weakPoint'],
      equals({
        'part': 'rump',
        'susceptibleDamage': 'any',
        'susceptibleDamageTypes': ['any'],
      }),
    );
    expect(
      entry('g2_axl')['weakPoint'],
      equals({
        'part': 'rump',
        'susceptibleDamage': 'any',
        'susceptibleDamageTypes': ['any'],
      }),
    );
    expect(
      entry('g2_king_dozer')['weakPoint'],
      equals({
        'part': 'eyes',
        'susceptibleDamage': 'any',
        'susceptibleDamageTypes': ['any'],
      }),
    );
  });

  test('g2 scorpions expose both stinger and rump weak points', () {
    for (final id in [
      'g2_northern_scorpion',
      'g2_northern_scorpion_jr',
      'g2_orc_northern_scorpion',
      'g2_orc_northern_scorpion_jr',
      'g2_ogrr_northern_scorpion',
    ]) {
      final weakPoints = (entry(id)['weakPoints'] as List)
          .cast<Map<String, dynamic>>();
      expect(weakPoints, hasLength(2), reason: id);
      expect(
        weakPoints[0],
        equals({
          'part': 'stinger',
          'susceptibleDamage': 'stabbing',
          'susceptibleDamageTypes': ['stabbing'],
        }),
        reason: id,
      );
      expect(
        weakPoints[1],
        equals({
          'part': 'rump',
          'susceptibleDamage': 'any',
          'susceptibleDamageTypes': ['any'],
        }),
        reason: id,
      );
    }
  });

  test(
    'g2 variants inherit the corrected weak points of their base species',
    () {
      expect(
        entry('g2_orc_red_soldier_ant')['weakPoint'],
        containsPair('susceptibleDamage', 'stabbing_arrows_only'),
      );
      expect(
        entry('g2_orc_bee')['weakPoint'],
        containsPair('susceptibleDamage', 'stabbing_arrows_only'),
      );
      expect(
        entry('g2_orc_black_soldier_ant')['weakPoint'],
        containsPair('susceptibleDamage', 'stabbing_arrows_only'),
      );
      expect(
        entry('g2_orc_praying_mantis_nymph')['weakPoint'],
        containsPair('susceptibleDamage', 'stabbing_bows_and_spears'),
      );
      expect(
        entry('g2_ogrr_praying_mantis_nymph')['weakPoint'],
        containsPair('susceptibleDamage', 'stabbing_bows_and_spears'),
      );
      expect(
        entry('g2_orc_ladybug')['weakPoint'],
        containsPair('susceptibleDamage', 'slashing'),
      );
      expect(
        entry('g2_ogrr_ladybug')['weakPoint'],
        containsPair('susceptibleDamage', 'slashing'),
      );
      expect(
        entry('g2_buggy_ladybug')['weakPoint'],
        containsPair('susceptibleDamage', 'slashing'),
      );
      expect(
        entry('g2_orc_bombardier_beetle')['weakPoint'],
        containsPair('susceptibleDamage', 'any'),
      );
      expect(
        entry('g2_orc_potato_beetle')['weakPoint'],
        containsPair('susceptibleDamage', 'slashing'),
      );
      expect(
        entry('g2_orc_rust_beetle')['weakPoint'],
        containsPair('susceptibleDamage', 'any'),
      );
      expect(
        entry('g2_ogrr_rust_beetle')['weakPoint'],
        containsPair('susceptibleDamage', 'any'),
      );
    },
  );

  test(
    'orchid mantis playground boss entry stays localized and phase-complete',
    () {
      final orchidMantis = entry('g2_orchid_mantis');
      final phases = (orchidMantis['bossPhases'] as List)
          .cast<Map<String, dynamic>>();

      expect(orchidMantis['collectionGroup'], 'other');
      expect(orchidMantis['temperament'], 'aggressive');
      expect(orchidMantis['name']['en'], 'Orchid Mantis');
      expect(
        orchidMantis['respawnInfo']['en'],
        'Depends on the Playground configuration.',
      );
      expect(
        (orchidMantis['combatStats']['attackDamageSummary']['en'] as String)
            .contains('Combo Slam: 120'),
        isTrue,
      );

      expect(phases, hasLength(3));
      expect(phases.first['startsAtHealthPct'], 100);
      expect(
        (phases.first['attacks'] as List).whereType<Map>().any(
          (attack) => attack['name']['en'] == 'Combo Slam',
        ),
        isTrue,
      );
      expect(
        (phases[1]['attacks'] as List).whereType<Map>().any(
          (attack) => attack['name']['en'] == 'Ground Shred',
        ),
        isTrue,
      );
      expect(
        (phases[2]['attacks'] as List).whereType<Map>().any(
          (attack) => attack['name']['en'] == 'Double Charged Strike',
        ),
        isTrue,
      );
    },
  );

  test('masked fighter boss entry keeps its full duel phase structure', () {
    final maskedFighter = entry('g2_masked_fighter');
    final phases = (maskedFighter['bossPhases'] as List)
        .cast<Map<String, dynamic>>();

    expect(maskedFighter['weaknesses'], contains('fresh'));
    expect(
      (maskedFighter['resistancesV2'] as List).whereType<Map>().any(
        (bonus) => bonus['type'] == 'venom',
      ),
      isTrue,
    );
    expect(maskedFighter['combatStats']['health'], 1875);
    expect(phases, hasLength(5));
    expect(phases[1]['trigger']['en'], contains('75%'));
    expect(
      (phases[1]['attacks'] as List).whereType<Map>().any(
        (attack) => attack['name']['en'] == 'Charged Attack',
      ),
      isTrue,
    );
    expect(
      (phases[3]['abilities'] as List).whereType<Map>().any(
        (ability) => ability['name']['en'] == 'Reposition+',
      ),
      isTrue,
    );
  });

  test('roach elites and major roaches keep their real two-phase transitions', () {
    final cockroach = entry('g2_cockroach');
    final orcCockroach = entry('g2_orc_cockroach');
    final cockroachQueen = entry('g2_cockroach_queen');
    final orcCockroachQueen = entry('g2_orc_cockroach_queen');

    expect(cockroach['isBoss'], isFalse);
    expect((cockroach['bossPhases'] as List), hasLength(2));
    expect(
      (cockroach['bossPhases'] as List)[1]['trigger']['en'],
      contains('loses its head'),
    );
    expect(
      (cockroach['combatStats']['attackDamageSummary']['en'] as String),
      contains('Headless Ram: 25'),
    );

    expect(orcCockroach['isBoss'], isFalse);
    expect((orcCockroach['bossPhases'] as List), hasLength(2));

    expect(cockroachQueen['isBoss'], isFalse);
    expect((cockroachQueen['bossPhases'] as List), hasLength(2));

    expect(orcCockroachQueen['isBoss'], isFalse);
    expect((orcCockroachQueen['bossPhases'] as List), hasLength(2));
    expect(
      orcCockroachQueen['description']['en'],
      contains('required elite encounter'),
    );
  });

  test('g2 boss danger tiers match the current community read', () {
    expect(entry('g2_axl')['danger'], 'imposible');
    expect(entry('g2_king_dozer')['danger'], 'imposible_alt');
    expect(entry('g2_orc_broodmother')['danger'], 'imposible_alt');
    expect(entry('g2_masked_stranger')['danger'], 'extrema');
    expect(entry('g2_masked_fighter')['danger'], 'imposible_alt');
    expect(entry('g2_orchid_mantis')['danger'], 'imposible_alta');
  });

  test('heavy g2 non-boss enemies match the current community read', () {
    expect(entry('g2_cockroach_queen')['danger'], 'imposible_alt');
    expect(entry('g2_orc_cockroach_queen')['danger'], 'extrema');
    expect(entry('g2_wasp')['danger'], 'imposible');
    expect(entry('g2_wasp_drone')['danger'], 'imposible_alt');
    expect(entry('g2_pincher_earwig')['danger'], 'imposible');
    expect(entry('g2_whipper_earwig')['danger'], 'imposible_alt');
    expect(entry('g2_rust_beetle')['danger'], 'muy_alta');
  });

  test('g2 system entries document MIX.R and Ice Sickles without faction raids', () {
    final mixr = entry('g2_mixr_defenses');
    final iceSickles = entry('g2_ice_sickles_event');

    expect(mixr['isBoss'], isFalse);
    expect(mixr['description']['en'], contains('Grounded 2 MIX.R events'));
    expect(
      mixr['specialTraits'][0]['en'],
      contains('rather than classic factional raids'),
    );

    expect(iceSickles['description']['en'], contains('Ice Sickles'));
    expect(
      (iceSickles['abilities'] as List).whereType<Map>().any(
        (ability) => ability['name']['en'] == 'Scorpion Waves',
      ),
      isTrue,
    );
    for (final event in [mixr, iceSickles]) {
      expect(
        (event['abilities'] as List).whereType<Map>().any(
          (ability) => ability['name']['en'] == 'Guard Dog Progress',
        ),
        isTrue,
      );
    }
  });

  test('ogrr and late g2 location notes stay aligned to the curated map', () {
    final ogrrCricket = entry('g2_ogrr_cricket');
    final orchidMantis = entry('g2_orchid_mantis');
    final ogrrLadybug = entry('g2_ogrr_ladybug');
    final ogrrWolfSpider = entry('g2_ogrr_wolf_spider');
    final ogrrButterfly = entry('g2_ogrr_blue_butterfly');
    final pincherEarwig = entry('g2_ogrr_pincher_earwig');
    final whipperEarwig = entry('g2_ogrr_whipper_earwig');
    final ogrrRustBeetle = entry('g2_ogrr_rust_beetle');
    final ogrrScorpion = entry('g2_ogrr_northern_scorpion');
    final ogrrWasp = entry('g2_ogrr_wasp');
    final ogrrWaspDrone = entry('g2_ogrr_wasp_drone');

    expect(
      (ogrrCricket['environments'] as List).last['en'],
      'Solar Panel above Pumpkin Patch',
    );
    expect(
      (ogrrCricket['environments'] as List).first['en'],
      'After releasing the O.G.R.Rs. in the Scarecrow Lab',
    );
    expect(
      ogrrCricket['behavior']['es'],
      contains('Su spawn nocturno solo se habilita'),
    );

    expect((orchidMantis['environments'] as List).first['en'], 'Playgrounds');
    expect(
      orchidMantis['behavior']['es'],
      contains('No forma parte del mapa normal'),
    );

    expect(
      (ogrrLadybug['environments'] as List).last['en'],
      'On top of the Picnic Table',
    );
    expect(
      (ogrrWolfSpider['environments'] as List).last['en'],
      'Northern Blueberry Shrubs near the Metal Bench',
    );
    expect(
      (ogrrButterfly['environments'] as List).last['en'],
      'Fallen Ice Cream Truck',
    );

    final pincherEarwigEnvironments = (pincherEarwig['environments'] as List)
        .map((environment) => environment['en'])
        .toList();
    expect(pincherEarwigEnvironments, contains('Inside the Scarecrow Pumpkin'));
    expect(
      pincherEarwigEnvironments,
      contains('Cave between the Statue Shrubs and the Greenhouse'),
    );
    expect(
      pincherEarwig['behavior']['es'],
      contains('comparten los mismos puntos'),
    );

    final whipperEarwigEnvironments = (whipperEarwig['environments'] as List)
        .map((environment) => environment['en'])
        .toList();
    expect(whipperEarwigEnvironments, contains('Inside the Scarecrow Pumpkin'));
    expect(
      whipperEarwigEnvironments,
      contains('Cave between the Statue Shrubs and the Greenhouse'),
    );
    expect(
      whipperEarwig['behavior']['es'],
      contains('comparten los mismos puntos'),
    );

    expect((ogrrRustBeetle['environments'] as List).last['en'], 'Candy Lab');
    expect(
      ogrrRustBeetle['behavior']['es'],
      contains('no depende de la noche'),
    );

    expect(
      (ogrrScorpion['environments'] as List).last['en'],
      'Lime Tree Seed',
    );
    expect(ogrrScorpion['behavior']['es'], contains('no depende de la noche'));

    expect(
      (ogrrWasp['environments'] as List).last['en'],
      'Shelves with Empty Jars near King Dozer',
    );
    expect(
      (ogrrWaspDrone['environments'] as List).last['en'],
      'Shelves with Empty Jars near King Dozer',
    );
    expect(
      ogrrWasp['behavior']['es'],
      contains('Su spawn nocturno solo se habilita'),
    );
    expect(
      ogrrWaspDrone['behavior']['es'],
      contains('Su spawn nocturno solo se habilita'),
    );
  });

  test('special g2 entries keep their intended creature photos', () {
    expect(
      entry('g2_orc_broodmother')['photo'],
      'assets/g2/creatures/photos/ORC_Broodmother.webp',
    );
    expect(
      entry('g2_king_dozer')['photo'],
      'assets/g2/creatures/photos/King_Dozer.webp',
    );
    expect(
      entry('g2_buggy_red_soldier_ant')['photo'],
      'assets/g2/creatures/photos/Buggy_Red_Soldier_Ant.webp',
    );
    expect(
      entry('g2_buggy_orb_weaver')['photo'],
      'assets/g2/creatures/photos/Buggy_Orb_Weaver.webp',
    );
    expect(
      entry('g2_buggy_ladybug')['photo'],
      'assets/g2/creatures/photos/Ladybuggy.webp',
    );
    expect(
      entry('g2_buggy_black_soldier_ant')['photo'],
      'assets/g2/creatures/photos/Buggy_Black_Soldier_Ant.webp',
    );
  });
}
