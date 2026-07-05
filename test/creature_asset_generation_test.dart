import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _languages = ['es', 'en', 'ru'];
const _games = ['g1', 'g2'];
const _allowedIndexKeys = {
  'id',
  'speciesKey',
  'game',
  'name',
  'tier',
  'danger',
  'isBoss',
  'order',
  'defaultGold',
  'favoriteKey',
  'goldLinkId',
  'cardNormal',
  'cardGold',
  'weaknesses',
  'resistances',
  'temperament',
  'health',
  'collectionGroup',
};
const _heavyIndexKeys = {
  'photo',
  'description',
  'behavior',
  'interactionWithPlayer',
  'interactionWithCreatures',
  'strategy',
  'attacks',
  'loot',
  'advancedLootTable',
  'abilities',
  'bossPhases',
  'combatStats',
};

void main() {
  test('generated indexes stay lightweight and complete', () {
    for (final language in _languages) {
      var combinedIndexBytes = 0;

      for (final game in _games) {
        final source = _readList('assets/data/enemies_$game.json');
        final indexFile = File(
          'assets/data/creatures/$language/index_$game.json',
        );

        expect(indexFile.existsSync(), isTrue, reason: indexFile.path);
        combinedIndexBytes += indexFile.lengthSync();

        final index = (jsonDecode(indexFile.readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
        expect(index, hasLength(source.length), reason: '$language/$game');

        for (final entry in index) {
          expect(entry.keys.toSet().difference(_allowedIndexKeys), isEmpty);
          expect(entry.keys.toSet().intersection(_heavyIndexKeys), isEmpty);
          expect(entry['name'], isA<String>());
          expect((entry['name'] as String).trim(), isNotEmpty);
        }
      }

      expect(
        combinedIndexBytes,
        lessThan(100 * 1024),
        reason: '$language index payload should stay near the startup target',
      );
    }
  });

  test('generated details are localized and present for every creature', () {
    final sourceIds = <String>{
      for (final game in _games)
        for (final item in _readList('assets/data/enemies_$game.json'))
          item['id'] as String,
    };

    for (final language in _languages) {
      final detailsDir = Directory('assets/data/creatures/$language/details');
      expect(detailsDir.existsSync(), isTrue, reason: detailsDir.path);

      final detailFiles = detailsDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList();
      expect(detailFiles, hasLength(sourceIds.length), reason: language);

      for (final id in sourceIds) {
        final file = File('${detailsDir.path}/$id.json');
        expect(file.existsSync(), isTrue, reason: file.path);

        final detail = jsonDecode(file.readAsStringSync());
        expect(_containsLocalizedMap(detail), isFalse, reason: file.path);
      }
    }
  });

  test('master and generated creature text does not keep mojibake markers', () {
    final files = <File>[
      for (final game in _games) File('assets/data/enemies_$game.json'),
      for (final language in _languages)
        for (final game in _games)
          File('assets/data/creatures/$language/index_$game.json'),
      for (final language in _languages)
        ...Directory(
          'assets/data/creatures/$language/details',
        ).listSync().whereType<File>(),
    ];

    for (final file in files) {
      expect(
        _hasQuestionMarkMojibake(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('spanish localization keeps key accented creature text', () {
    final master = [
      File('assets/data/enemies_g1.json').readAsStringSync(),
      File('assets/data/enemies_g2.json').readAsStringSync(),
    ].join('\n');
    final generated = File(
      'assets/data/creatures/es/details/g2_masked_stranger_orc_waves.json',
    ).readAsStringSync();

    expect(master, contains('daño'));
    expect(master, contains('infusión'));
    expect(master, contains('mutación'));
    expect(master, contains('eliminación'));
    expect(master, isNot(contains('da?o')));
    expect(master, isNot(contains('infusi?n')));
    expect(master, isNot(contains('mutaci?n')));
    expect(master, isNot(contains('eliminaci?n')));

    expect(generated, contains('botín específico'));
    expect(generated, contains('presión'));
    expect(generated, contains('qué criaturas'));
  });
}

List<Map<String, dynamic>> _readList(String path) {
  return (jsonDecode(File(path).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
}

bool _containsLocalizedMap(Object? value) {
  if (value is List) {
    return value.any(_containsLocalizedMap);
  }
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toSet();
    if (keys.isNotEmpty &&
        keys.every(_languages.contains) &&
        keys.any(_languages.contains)) {
      return true;
    }
    return value.values.any(_containsLocalizedMap);
  }
  return false;
}

bool _hasQuestionMarkMojibake(String text) {
  return RegExp(r'[A-Za-z]\?[A-Za-z]|\?[A-Za-z]').hasMatch(text);
}
