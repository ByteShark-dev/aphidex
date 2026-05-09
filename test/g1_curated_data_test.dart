import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final file = File('assets/data/enemies_g1.json');
  final data = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  Map<String, dynamic> entry(String id) =>
      data.firstWhere((enemy) => enemy['id'] == id);

  const expectedBosses = {
    'g1_assistant_manager',
    'g1_hedge_broodmother',
    'g1_mant',
    'g1_mantis',
    'g1_director_schmector',
    'g1_wasp_queen',
    'g1_infected_broodmother',
  };

  const expectedPhaseCounts = {
    'g1_assistant_manager': 3,
    'g1_hedge_broodmother': 4,
    'g1_mant': 3,
    'g1_mantis': 3,
    'g1_director_schmector': 5,
    'g1_wasp_queen': 3,
    'g1_infected_broodmother': 3,
  };

  test('only real g1 bosses stay flagged as bosses', () {
    final bosses = data
        .where((enemy) => enemy['isBoss'] == true)
        .map((enemy) => enemy['id'] as String)
        .toSet();

    expect(bosses, expectedBosses);
    expect(entry('g1_koi_fish')['isBoss'], isFalse);
    expect(entry('g1_crow')['isBoss'], isFalse);
  });

  test('only real g1 bosses keep boss phases and they match curated counts', () {
    for (final enemy in data) {
      final phaseCount = (enemy['bossPhases'] as List?)?.length ?? 0;
      final id = enemy['id'] as String;

      if (expectedBosses.contains(id)) {
        expect(
          phaseCount,
          expectedPhaseCounts[id],
          reason: '$id should keep its curated phase count',
        );
      } else {
        expect(
          phaseCount,
          0,
          reason: '$id should not keep stray boss phases',
        );
      }
    }
  });

  test('every curated g1 boss phase has metadata and visible combat content', () {
    for (final id in expectedBosses) {
      final phases = (entry(id)['bossPhases'] as List).cast<Map<String, dynamic>>();

      for (final phase in phases) {
        expect((phase['id'] as String?)?.isNotEmpty, isTrue, reason: '$id phase is missing an id');
        expect(phase['label'], isA<Map>(), reason: '$id ${phase['id']} is missing a label');
        expect(phase['summary'], isA<Map>(), reason: '$id ${phase['id']} is missing a summary');

        final attacks = (phase['attacks'] as List?) ?? const [];
        final abilities = (phase['abilities'] as List?) ?? const [];
        expect(
          attacks.isNotEmpty || abilities.isNotEmpty,
          isTrue,
          reason: '$id ${phase['id']} should expose attacks or abilities',
        );
      }
    }
  });

  test('g1 loot sections stay within the app-supported ids', () {
    const allowedSections = {'loot', 'rare', 'passive', 'ng_plus'};

    for (final enemy in data) {
      for (final loot in (enemy['loot'] as List?) ?? const []) {
        expect(
          allowedSections.contains((loot as Map<String, dynamic>)['section']),
          isTrue,
          reason: '${enemy['id']} has unsupported loot section ${loot['section']}',
        );
      }
    }
  });

  test('g1 umbrella entries for O.R.C. and infused creatures stay explanatory', () {
    final orc = entry('g1_enemy_orc');
    final infused = entry('g1_enemy_infused');

    expect(orc['collectionGroup'], 'other');
    expect((orc['abilities'] as List), isNotEmpty);
    expect((orc['attacks'] as List), isEmpty);
    expect(
      orc['description']['en'],
      contains('Project O.R.C.'),
    );

    expect(infused['collectionGroup'], 'anomaly');
    expect((infused['abilities'] as List), isNotEmpty);
    expect((infused['attacks'] as List), isEmpty);
    expect(infused.containsKey('health'), isFalse);
    expect(
      infused['description']['en'],
      contains('New Game+ infused creatures'),
    );
  });

  test('g1 system entries cover raids, MIX.R defenses, JavaMatic, and Spicy Coaltana', () {
    final raids = entry('g1_factional_raids');
    final mixr = entry('g1_mixr_defenses');
    final javamatic = entry('g1_javamatic_cable_defense');
    final coaltana = entry('g1_spicy_coaltana_event');

    expect(raids['isBoss'], isFalse);
    expect(raids['description']['en'], contains('factional raids'));
    expect(
      (raids['abilities'] as List).whereType<Map>().any(
        (ability) => ability['name']['en'] == 'Payback Has Arrived!',
      ),
      isTrue,
    );

    expect(mixr['description']['en'], contains('JavaMatic'));
    expect(
      (mixr['specialTraits'] as List).whereType<Map>().any(
        (trait) => (trait['en'] as String).contains('SUPER MIX.R'),
      ),
      isTrue,
    );

    expect(javamatic['description']['en'], contains('several cables'));
    expect(
      (javamatic['abilities'] as List).whereType<Map>().any(
        (ability) => ability['name']['en'] == 'Multiple Cables',
      ),
      isTrue,
    );

    expect(coaltana['description']['en'], contains('Spicy Coaltana'));
    expect(
      (coaltana['abilities'] as List).whereType<Map>().any(
        (ability) => ability['name']['en'] == 'Ladybird Larva Waves',
      ),
      isTrue,
    );

    for (final event in [raids, mixr, javamatic, coaltana]) {
      expect(
        (event['abilities'] as List).whereType<Map>().any(
          (ability) => ability['name']['en'] == 'Guard Dog Progress',
        ),
        isTrue,
      );
    }
  });

  test('g1 weak points stay aligned with the curated creature table', () {
    const expectedWeakPoints = {
      'g1_ruz_t': {'part': 'back', 'susceptibleDamage': 'any'},
      'g1_tayz_t': {'part': 'back', 'susceptibleDamage': 'any'},
      'g1_bee': {'part': 'eyes', 'susceptibleDamage': 'stabbing_arrows_only'},
      'g1_black_soldier_ant': {
        'part': 'eyes',
        'susceptibleDamage': 'stabbing_arrows_only',
      },
      'g1_black_worker_ant': {
        'part': 'eyes',
        'susceptibleDamage': 'stabbing_arrows_only',
      },
      'g1_fire_soldier_ant': {
        'part': 'eyes',
        'susceptibleDamage': 'stabbing_arrows_only',
      },
      'g1_fire_worker_ant': {
        'part': 'eyes',
        'susceptibleDamage': 'stabbing_arrows_only',
      },
      'g1_mantis': {'part': 'eyes', 'susceptibleDamage': 'stabbing_arrows_only'},
      'g1_red_soldier_ant': {
        'part': 'eyes',
        'susceptibleDamage': 'stabbing_arrows_only',
      },
      'g1_red_worker_ant': {
        'part': 'eyes',
        'susceptibleDamage': 'stabbing_arrows_only',
      },
      'g1_black_ox_beetle': {'part': 'gut', 'susceptibleDamage': 'stabbing'},
      'g1_ladybird': {
        'part': 'legs',
        'susceptibleDamage': 'chopping and slashing',
      },
      'g1_ladybug': {
        'part': 'legs',
        'susceptibleDamage': 'chopping and slashing',
      },
      'g1_roly_poly': {
        'part': 'legs',
        'susceptibleDamage': 'chopping and slashing',
      },
      'g1_sickly_roly_poly': {
        'part': 'legs',
        'susceptibleDamage': 'chopping and slashing',
      },
      'g1_bombardier_beetle': {'part': 'rump', 'susceptibleDamage': 'any'},
    };

    final actualIds = data
        .where((enemy) => enemy['weakPoint'] is Map)
        .map((enemy) => enemy['id'] as String)
        .toSet();

    expect(actualIds, expectedWeakPoints.keys.toSet());

    for (final entryData in expectedWeakPoints.entries) {
      final weakPoint = entry(entryData.key)['weakPoint'] as Map<String, dynamic>;
      expect(weakPoint['part'], entryData.value['part'], reason: entryData.key);
      expect(
        weakPoint['susceptibleDamage'],
        entryData.value['susceptibleDamage'],
        reason: entryData.key,
      );
    }
  });
}
