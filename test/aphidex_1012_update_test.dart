import 'dart:convert';
import 'dart:io';

import 'package:aphidex/controllers/tutorial_controller.dart';
import 'package:aphidex/data/local_storage.dart';
import 'package:aphidex/data/ui_mapper.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/screens/enemy_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

final TestFlutterView detailTesterView =
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('aphidex_1012_');
    Hive.init(hiveDir.path);
    await Hive.openBox('aphidex');
  });

  tearDownAll(() async {
    await Hive.box('aphidex').close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box('aphidex').clear();
    await LocalStorage.setBool(TutorialController.completionKey, true);
    detailTesterView.physicalSize = const Size(390, 844);
    detailTesterView.devicePixelRatio = 1.0;
  });

  tearDown(() {
    detailTesterView.resetPhysicalSize();
    detailTesterView.resetDevicePixelRatio();
  });

  test('non-killable entities can omit conventional health', () {
    final enemy = Enemy.fromJson({
      ..._baseEnemy,
      'health': null,
      'isKillable': false,
    });

    expect(enemy.health, isNull);
    expect(enemy.isKillable, isFalse);
    expect(enemy.healthDisplay, HealthDisplayMode.invulnerable);
  });

  testWidgets('empty weakness and resistance sections do not render headings', (
    tester,
  ) async {
    final enemy = Enemy.fromJson({
      ..._baseEnemy,
      'weaknesses': <String>[],
      'resistances': <String>[],
    });

    await tester.pumpWidget(_buildTestApp(EnemyDetailScreen(enemy: enemy)));
    await tester.pumpAndSettle();

    expect(find.text('Weaknesses'), findsNothing);
    expect(find.text('Resistances'), findsNothing);
  });

  testWidgets('invulnerable health renders as not applicable', (tester) async {
    final enemy = Enemy.fromJson({
      ..._baseEnemy,
      'health': null,
      'isKillable': false,
    });

    await tester.pumpWidget(_buildTestApp(EnemyDetailScreen(enemy: enemy)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Health'), 200);
    await tester.pumpAndSettle();

    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Not applicable · invulnerable'), findsOneWidget);
    expect(find.textContaining('HP'), findsNothing);
  });

  testWidgets('event entries can hide health completely', (tester) async {
    final enemy = Enemy.fromJson({
      ..._baseEnemy,
      'health': null,
      'isKillable': false,
      'healthDisplay': 'hidden',
      'description': {'en': 'Event entry'},
    });

    await tester.pumpWidget(_buildTestApp(EnemyDetailScreen(enemy: enemy)));
    await tester.pumpAndSettle();

    expect(find.text('Health'), findsNothing);
    expect(find.text('Not applicable · invulnerable'), findsNothing);
  });

  testWidgets(
    'phone portrait hides creature cards and the detail effect guide button',
    (tester) async {
      final enemy = Enemy.fromJson({
        ..._baseEnemy,
        'weaknesses': ['fresh'],
        'resistances': ['gas'],
      });

      await tester.pumpWidget(
        _buildTestApp(
          EnemyDetailScreen(enemy: enemy),
          locale: const Locale('es'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('creature-card-section')), findsNothing);
      expect(find.text('Tarjeta de criatura'), findsNothing);
      expect(find.byKey(const ValueKey('open-effect-guide')), findsNothing);
    },
  );

  testWidgets(
    'phone landscape still hides creature cards when only width is large',
    (tester) async {
      detailTesterView.physicalSize = const Size(844, 390);

      final enemy = Enemy.fromJson({
        ..._baseEnemy,
        'weaknesses': ['fresh'],
        'resistances': ['gas'],
      });

      await tester.pumpWidget(_buildTestApp(EnemyDetailScreen(enemy: enemy)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('creature-card-section')), findsNothing);
      expect(find.byKey(const ValueKey('open-effect-guide')), findsNothing);
    },
  );

  testWidgets('tablet keeps the creature card block visible', (tester) async {
    detailTesterView.physicalSize = const Size(900, 1280);

    final enemy = Enemy.fromJson({
      ..._baseEnemy,
      'weaknesses': ['fresh'],
      'resistances': ['gas'],
    });

    await tester.pumpWidget(
      _buildTestApp(
        EnemyDetailScreen(enemy: enemy),
        locale: const Locale('es'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('creature-card-section')), findsOneWidget);
    expect(find.text('Tarjeta de criatura'), findsOneWidget);
  });

  test('MIX.R variants share species and favorite keys across games', () {
    final g1 = Enemy.fromJson({
      ..._baseEnemy,
      'id': 'g1_mixr_defenses',
      'speciesKey': 'mixr_defenses',
      'favoriteKey': 'mixr_defenses',
      'name': {'en': 'MIX.R Defenses'},
      'game': 'g1',
      'description': {'en': 'Grounded 1 defense profile'},
    });
    final g2 = Enemy.fromJson({
      ..._baseEnemy,
      'id': 'g2_mixr_defenses',
      'speciesKey': 'mixr_defenses',
      'favoriteKey': 'mixr_defenses',
      'name': {'en': 'MIX.R Defenses'},
      'game': 'g2',
      'description': {'en': 'Grounded 2 defense profile'},
    });

    expect(g1.speciesKey, g2.speciesKey);
    expect(g1.resolvedFavoriteKey, g2.resolvedFavoriteKey);
  });

  testWidgets('O.G.R.R. infusion selector merges combat modifiers', (
    tester,
  ) async {
    final enemy = Enemy.fromJson({
      ..._baseEnemy,
      'id': 'g2_ogrr_test',
      'collectionGroup': 'ogrr',
      'name': {'en': 'O.G.R.R. Test'},
      'inflictsEffects': ['venom'],
      'specialTraits': [
        {'en': 'Base leap still staggers.'},
      ],
      'infusions': [
        {
          'id': 'fresh',
          'name': {'en': 'Fresh'},
          'iconAsset': 'assets/global/effects_damage/Damagetype_Fresh.webp',
          'elementalWeaknesses': [
            {'type': 'sour', 'bonusPct': 50},
          ],
          'resistances': [
            {'type': 'fresh', 'bonusPct': 100},
            {'type': 'chill', 'bonusPct': 100},
            {'type': 'spicy', 'bonusPct': 50},
          ],
          'effects': ['chill'],
          'specialTraits': [
            {'en': 'Base venom still applies on hit.'},
          ],
          'recommendations': {'en': 'Do not rely on fresh damage.'},
          'combatTips': [
            {'en': 'Switch to spicy or a physical backup weapon.'},
          ],
        },
        {
          'id': 'sour',
          'name': {'en': 'Sour'},
          'iconAsset': 'assets/global/effects_damage/Damagetype_Sour.webp',
          'elementalWeaknesses': [
            {'type': 'spicy', 'bonusPct': 50},
          ],
          'resistances': [
            {'type': 'sour', 'bonusPct': 100},
            {'type': 'fresh', 'bonusPct': 50},
            {'type': 'tang_buildup', 'bonusPct': 100},
          ],
          'effects': ['tang_buildup'],
          'specialTraits': [
            {'en': 'Base venom still applies on hit.'},
          ],
          'recommendations': {'en': 'Use spicy pressure.'},
          'combatTips': [
            {'en': 'Drop sour weapons if they are your main answer.'},
          ],
        },
      ],
    });

    await tester.pumpWidget(_buildTestApp(EnemyDetailScreen(enemy: enemy)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Flavor or infusion'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Flavor or infusion'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('effect-bonus-resistance-fresh')),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Do not rely on fresh damage.'), findsOneWidget);
    expect(find.text('Base leap still staggers.'), findsOneWidget);
    expect(find.text('Base venom still applies on hit.'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 700));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Sour'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sour'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('effect-bonus-weakness-spicy')),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Use spicy pressure.'), findsOneWidget);
  });

  testWidgets('lesser mutations render independently from infusions', (
    tester,
  ) async {
    final enemy = Enemy.fromJson({
      ..._baseEnemy,
      'description': {'en': 'Base entry'},
      'lesserMutationsDescription': {
        'en':
            'Infused creatures can gain extra random lesser mutations without guaranteeing every effect at once.',
      },
      'lesserMutations': [
        {'en': 'Extra explosions tied to attacks or close contact.'},
        {'en': 'Candy magic that adds unexpected elemental pressure.'},
      ],
      'infusions': [
        {
          'id': 'spicy',
          'name': {'en': 'Spicy'},
          'iconAsset': 'assets/global/effects_damage/Damagetype_Spicy.webp',
          'elementalWeaknesses': [
            {'type': 'fresh', 'bonusPct': 50},
          ],
        },
      ],
    });

    await tester.pumpWidget(_buildTestApp(EnemyDetailScreen(enemy: enemy)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Lesser mutations'), 200);
    await tester.pumpAndSettle();

    expect(find.text('Lesser mutations'), findsOneWidget);
    expect(
      find.text(
        'Infused creatures can gain extra random lesser mutations without guaranteeing every effect at once.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('\u2022 Extra explosions tied to attacks or close contact.'),
      findsOneWidget,
    );
    expect(
      find.text('\u2022 Candy magic that adds unexpected elemental pressure.'),
      findsOneWidget,
    );
  });

  testWidgets('normal g1 creatures do not show lesser mutations by default', (
    tester,
  ) async {
    final enemy = Enemy.fromJson({
      ..._baseEnemy,
      'id': 'g1_regular_test',
      'game': 'g1',
      'description': {'en': 'Regular grounded creature.'},
    });

    await tester.pumpWidget(_buildTestApp(EnemyDetailScreen(enemy: enemy)));
    await tester.pumpAndSettle();

    expect(find.text('Lesser mutations'), findsNothing);
  });

  test('ogrr and normal creatures resolve the same superior danger asset', () {
    expect(
      UiMapper.dangerIcon('imposible_superior'),
      UiMapper.dangerIcon('imposible_alt'),
    );
    expect(
      UiMapper.dangerIcon('imposible_superior'),
      'assets/global/Imposible_alt.png',
    );
  });

  test('content update data is present in the master files', () {
    final g1 = _readList('assets/data/enemies_g1.json');
    final g2 = _readList('assets/data/enemies_g2.json');

    expect(_entry(g1, 'g1_meaty_gnat')['danger'], 'media');
    expect(g2.where((item) => item['id'] == 'g2_meaty_gnat'), isEmpty);

    final koi = _entry(g1, 'g1_koi_fish');
    expect(koi['health'], isNull);
    expect(koi['isKillable'], isFalse);
    expect(jsonEncode(koi), isNot(contains('500 HP')));

    expect(_entry(g1, 'g1_ladybird')['name']['es'], 'Catarina negra');
    expect(
      _entry(g1, 'g1_ladybird_larva')['name']['es'],
      'Larva de catarina negra',
    );

    expect(_entry(g1, 'g1_mixr_defenses')['speciesKey'], 'mixr_defenses');
    expect(_entry(g2, 'g2_mixr_defenses')['speciesKey'], 'mixr_defenses');
    expect(_entry(g1, 'g1_mixr_defenses')['favoriteKey'], 'mixr_defenses');
    expect(_entry(g2, 'g2_mixr_defenses')['favoriteKey'], 'mixr_defenses');

    final waves = _entry(g2, 'g2_masked_stranger_orc_waves');
    expect(waves['description']['en'], contains('Masked Stranger'));
    expect(waves['weaknesses'], isEmpty);
    expect(waves['resistances'], isEmpty);
    expect(waves['healthDisplay'], 'hidden');
  });

  test('new event image assets exist and are referenced', () {
    const assets = [
      'assets/g1/creatures/photos/Factional_Raids.webp',
      'assets/g1/creatures/photos/MIXR_Defenses_G1.webp',
      'assets/g2/creatures/photos/MIXR_Defenses_G2.webp',
      'assets/g1/creatures/photos/Spicy_Coaltana_Defense.webp',
      'assets/g2/creatures/photos/Ice_Sickles_Defense.webp',
      'assets/g1/creatures/photos/JavaMatic_Cable_Defense.webp',
      'assets/g2/creatures/photos/Masked_Stranger_ORC_Waves.webp',
    ];

    for (final asset in assets) {
      final file = File(asset);
      expect(file.existsSync(), isTrue, reason: asset);
      expect(file.lengthSync(), greaterThan(10 * 1024), reason: asset);
    }

    final serialized = [
      File('assets/data/enemies_g1.json').readAsStringSync(),
      File('assets/data/enemies_g2.json').readAsStringSync(),
    ].join('\n');
    for (final asset in assets) {
      expect(serialized, contains(asset), reason: asset);
    }
  });
}

Widget _buildTestApp(Widget home, {Locale locale = const Locale('en')}) {
  return DefaultAssetBundle(
    bundle: _TestAssetBundle(),
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    ),
  );
}

List<Map<String, dynamic>> _readList(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

Map<String, dynamic> _entry(List<Map<String, dynamic>> data, String id) =>
    data.firstWhere((item) => item['id'] == id);

final ByteData _transparentImage = ByteData.view(
  Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg==',
    ),
  ).buffer,
);

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

const _baseEnemy = {
  'id': 'test_enemy',
  'speciesKey': 'test_enemy',
  'name': {'en': 'Test Enemy'},
  'game': 'g2',
  'tier': 1,
  'danger': 'baja',
  'isBoss': false,
  'order': 1,
  'defaultGold': false,
  'cardNormal': 'assets/global/Creaturecard_Proximamente.webp',
  'cardGold': 'assets/global/Creaturecard_Proximamente.webp',
  'photo': 'assets/global/Aphidex_Proximamente.webp',
  'weaknesses': <String>[],
  'resistances': <String>[],
  'temperament': 'other',
};
