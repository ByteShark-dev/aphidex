import 'dart:convert';
import 'dart:io';

import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/screens/enemy_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'aphidex_under_construction_',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox('aphidex');
  });

  tearDownAll(() async {
    await Hive.box('aphidex').close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets(
    'orchid mantis shows its under-construction status instead of a danger',
    (tester) async {
      final orchidMantis = Enemy.fromJson({
        'id': 'g2_orchid_mantis',
        'speciesKey': 'orchid_mantis',
        'name': {'es': 'Mantis orquídea', 'en': 'Orchid Mantis'},
        'game': 'g2',
        'tier': 3,
        'danger': 'imposible_superior',
        'underConstruction': true,
        'isBoss': true,
        'order': 287,
        'defaultGold': false,
        'cardNormal': '',
        'cardGold': '',
        'photo': '',
        'weaknesses': <String>[],
        'resistances': <String>[],
      });

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _TestAssetBundle(),
          child: MaterialApp(
            locale: const Locale('es'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: EnemyDetailScreen(enemy: orchidMantis),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('En construcción'), findsNWidgets(2));
      expect(find.text('Imposible Superior'), findsNothing);
    },
  );
}

class _TestAssetBundle extends CachingAssetBundle {
  static const _svg =
      '<svg viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">'
      '<rect width="32" height="32" fill="#ffffff"/></svg>';

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<Object?, Object?>{})!;
    }
    if (key == 'AssetManifest.json') {
      return _stringData('{}');
    }
    if (key == 'FontManifest.json') {
      return _stringData('[]');
    }
    if (key.endsWith('.svg')) {
      return _stringData(_svg);
    }
    return _transparentImage;
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key.endsWith('.svg')) {
      return _svg;
    }
    if (key == 'AssetManifest.json') {
      return '{}';
    }
    if (key == 'FontManifest.json') {
      return '[]';
    }
    return '';
  }
}

ByteData _stringData(String value) {
  final bytes = Uint8List.fromList(utf8.encode(value));
  return ByteData.view(bytes.buffer);
}

final ByteData _transparentImage = ByteData.view(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg==',
  ).buffer,
);
