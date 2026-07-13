import 'dart:io';

import 'package:aphidex/controllers/creature_kill_count_controller.dart';
import 'package:aphidex/data/creature_kill_tracking.dart';
import 'package:aphidex/models/enemy_index_entry.dart';
import 'package:aphidex/models/player_character.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CreatureKillCountController controller;
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('aphidex_kills_');
    Hive.init(hiveDirectory.path);
    await Hive.openBox('aphidex');
    controller = CreatureKillCountController.instance;
  });

  tearDownAll(() async {
    await Hive.box('aphidex').close();
    await hiveDirectory.delete(recursive: true);
  });

  setUp(() async {
    await controller.clearAll();
  });

  test(
    'counts start at zero, clamp values, and persist by stable ID',
    () async {
      expect(controller.getCount('g1_ant'), 0);
      await controller.increment('g1_ant');
      await controller.decrement('g1_ant');
      await controller.decrement('g1_ant');
      expect(controller.getCount('g1_ant'), 0);

      await controller.setCount('g1_ant', -7);
      expect(controller.getCount('g1_ant'), 0);
      await controller.setCount(
        'g1_ant',
        CreatureKillCountController.maxCount + 1,
      );
      expect(
        controller.getCount('g1_ant'),
        CreatureKillCountController.maxCount,
      );

      controller.reloadFromStorage();
      expect(
        controller.getCount('g1_ant'),
        CreatureKillCountController.maxCount,
      );
    },
  );

  test('totals stay scoped to compatible entries of the active game', () async {
    await controller.setCount('g1_ant', 2);
    await controller.setCount('g2_wasp', 3);
    await controller.setCount('g2_buggy', 8);
    final entries = [
      _entry('g1_ant', 'g1'),
      _entry('g2_wasp', 'g2'),
      _entry('g2_buggy', 'g2', group: 'buggy'),
    ];

    expect(controller.totalForGame(AphidexGame.grounded, entries), 2);
    expect(controller.totalForGame(AphidexGame.groundedTwo, entries), 3);
  });

  test(
    'central rule excludes Buggies, global entries, crows, and construction',
    () {
      expect(
        CreatureKillTracking.supportsIndex(_entry('g2_wasp', 'g2')),
        isTrue,
      );
      expect(
        CreatureKillTracking.supportsIndex(
          _entry('g2_buggy', 'g2', group: 'buggy'),
        ),
        isFalse,
      );
      expect(
        CreatureKillTracking.supportsIndex(
          _entry('g2_mixr_defenses', 'g2', group: 'other'),
        ),
        isFalse,
      );
      expect(
        CreatureKillTracking.supportsIndex(_entry('g2_crow', 'g2')),
        isFalse,
      );
      expect(
        CreatureKillTracking.supportsIndex(
          _entry('g2_orchid_mantis', 'g2', underConstruction: true),
        ),
        isFalse,
      );
    },
  );
}

EnemyIndexEntry _entry(
  String id,
  String game, {
  String? group,
  bool underConstruction = false,
}) => EnemyIndexEntry(
  id: id,
  speciesKey: id,
  collectionGroup: group,
  name: id,
  order: 1,
  game: game,
  tier: 1,
  danger: 'baja',
  isUnderConstruction: underConstruction,
  isBoss: false,
  weaknesses: const [],
  resistances: const [],
  defaultGold: false,
  cardNormal: '',
  cardGold: '',
);
