import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _languages = ['es', 'en', 'ru'];
const _release06Ids = {
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
  'g2_buggy_potato_beetle',
};

const _sourceMissingDanger = {
  'g2_centipede': 'imposible',
  'g2_ogre_diving_bell_spider': 'proximamente',
  'g2_termite_king': 'proximamente',
  'g2_ogre_termite_king': 'imposible',
  'g2_termite_nymph': 'baja',
  'g2_termite_queen': 'baja',
  'g2_termite_soldier': 'alta',
  'g2_termite_worker': 'intermedia',
  'g2_orc_termite_soldier': 'proximamente',
  'g2_orc_termite_worker': 'proximamente',
};

void main() {
  test('new creature JSON uses only the canonical superior-danger key', () {
    for (final path in [
      'assets/data/enemies_g2.json',
      for (final language in _languages)
        'assets/data/creatures/$language/index_g2.json',
      for (final language in _languages)
        ...Directory('assets/data/creatures/$language/details')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.contains('${Platform.pathSeparator}g2_'))
            .map((file) => file.path),
    ]) {
      final contents = File(path).readAsStringSync();
      expect(contents, isNot(contains('imposible_alt')), reason: path);
      expect(contents, isNot(contains('imposible_alta')), reason: path);
    }
  });

  test(
    'g2 localized indexes and details keep IDs and difficulties aligned',
    () {
      final source = _readList('assets/data/enemies_g2.json');
      final sourceById = {
        for (final item in source)
          if (item['enabled'] != false) item['id'] as String: item,
      };

      for (final language in _languages) {
        final index = _readList(
          'assets/data/creatures/$language/index_g2.json',
        );
        expect(index.map((item) => item['id']).toSet(), {
          ...sourceById.keys,
          ..._release06Ids,
        }, reason: '$language index IDs');

        for (final item in index) {
          final id = item['id'] as String;
          final sourceItem = sourceById[id];
          final detail =
              jsonDecode(
                    File(
                      'assets/data/creatures/$language/details/$id.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>;

          if (id.startsWith('g2_buggy_')) {
            expect(item['danger'], 'unknown', reason: '$language/$id');
            expect(detail['danger'], 'unknown', reason: '$language/$id');
            continue;
          }
          if (sourceItem == null) {
            expect(
              item['danger'],
              _sourceMissingDanger[id] ?? 'unknown',
              reason: '$language/$id',
            );
            continue;
          }
          expect(item['danger'], sourceItem['danger'], reason: '$language/$id');
          expect(
            detail['danger'],
            sourceItem['danger'],
            reason: '$language/$id',
          );
          expect(
            detail['underConstruction'] == true,
            sourceItem['underConstruction'] == true,
            reason: '$language/$id',
          );
        }
      }
    },
  );

  test(
    'orchid mantis is under construction rather than a normal difficulty',
    () {
      final source = _readList('assets/data/enemies_g2.json');
      final orchid = source.firstWhere(
        (item) => item['id'] == 'g2_orchid_mantis',
      );

      expect(orchid['underConstruction'], isTrue);
      expect(orchid['danger'], 'proximamente');
    },
  );
}

List<Map<String, dynamic>> _readList(String path) {
  return (jsonDecode(File(path).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
}
