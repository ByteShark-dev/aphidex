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

  test('curated shared g2 entries keep localized names and structured combat data', () {
    final redWorkerAnt = entry('g2_red_worker_ant');
    final ladybug = entry('g2_ladybug');
    final bee = entry('g2_bee');
    final firefly = entry('g2_firefly');

    expect(redWorkerAnt['name']['es'], 'Hormiga obrera roja');
    expect(
      (redWorkerAnt['damageWeaknesses'] as List)
          .whereType<Map>()
          .any((bonus) => bonus['type'] == 'stabbing'),
      isTrue,
    );

    expect(ladybug['name']['es'], 'Mariquita');
    expect(
      (ladybug['resistancesV2'] as List)
          .whereType<Map>()
          .any((bonus) => bonus['type'] == 'sizzle'),
      isTrue,
    );

    expect(bee['name']['es'], 'Abeja');
    expect(
      (bee['description']['es'] as String).startsWith('Una criatura'),
      isTrue,
    );
    expect(bee['advancedLootTable'], isNotEmpty);

    expect(firefly['name']['es'], 'Luciérnaga');
    expect(
      (firefly['inflictsEffects'] as List).contains('busting'),
      isTrue,
    );
    expect(
      (firefly['description']['en'] as String).startsWith(
        'A Tier 3 neutral firefly',
      ),
      isTrue,
    );
  });

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
      final weakPoints = (entry(id)['weakPoints'] as List).cast<Map<String, dynamic>>();
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

  test('g2 variants inherit the corrected weak points of their base species', () {
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
  });

  test('orchid mantis playground boss entry stays localized and phase-complete', () {
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
      (phases.first['attacks'] as List)
          .whereType<Map>()
          .any((attack) => attack['name']['en'] == 'Combo Slam'),
      isTrue,
    );
    expect(
      (phases[1]['attacks'] as List)
          .whereType<Map>()
          .any((attack) => attack['name']['en'] == 'Ground Shred'),
      isTrue,
    );
    expect(
      (phases[2]['attacks'] as List)
          .whereType<Map>()
          .any((attack) => attack['name']['en'] == 'Double Charged Strike'),
      isTrue,
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
