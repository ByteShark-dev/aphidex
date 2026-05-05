import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/scanner/creature_alias_matcher.dart';
import 'package:aphidex/scanner/creature_scanner_page.dart';
import 'package:aphidex/scanner/creature_scanner_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('aphidex_scanner_');
    Hive.init(hiveDir.path);
    await Hive.openBox('aphidex');
  });

  tearDownAll(() async {
    await Hive.box('aphidex').close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box('aphidex').clear();
  });

  test('alias matcher normalizes accents and prioritizes web entities', () {
    const matcher = CreatureAliasMatcher();

    final mite = matcher.match(
      rawLabels: const ['Ácaro'],
      rawWebEntities: const [],
    );
    expect(mite.matches.first.creatureId, 'lawn_mite');

    final prioritized = matcher.match(
      rawLabels: const ['ladybug'],
      rawWebEntities: const ['black ant'],
    );
    expect(prioritized.matches.first.creatureId, 'black_worker_ant');

    final ladybug = matcher.match(
      rawLabels: const ['mariquita'],
      rawWebEntities: const [],
    );
    expect(ladybug.matches.first.creatureId, 'ladybug');
  });

  test('alias matcher keeps ambiguous spider results out of clear single match', () {
    const matcher = CreatureAliasMatcher();

    final result = matcher.match(
      rawLabels: const ['spider'],
      rawWebEntities: const [],
    );

    expect(result.matches, isNotEmpty);
    expect(
      result.matches.first.creatureId,
      anyOf('orb_weaver', 'wolf_spider'),
    );
    expect(matcher.isClearSingleMatch(result.matches), isFalse);
  });

  test('alias matcher returns earwig variants as suggestions for generic earwig labels', () {
    const matcher = CreatureAliasMatcher();

    final result = matcher.match(
      rawLabels: const ['earwig'],
      rawWebEntities: const [],
    );

    expect(result.matches.map((match) => match.creatureId), contains('pincher_earwig'));
    expect(result.matches.map((match) => match.creatureId), contains('whipper_earwig'));
    expect(matcher.isClearSingleMatch(result.matches), isFalse);
  });

  test('alias matcher resolves scorpion labels to northern scorpion', () {
    const matcher = CreatureAliasMatcher();

    final result = matcher.match(
      rawLabels: const ['scorpion'],
      rawWebEntities: const [],
    );

    expect(result.matches, isNotEmpty);
    expect(result.matches.first.creatureId, 'northern_scorpion');
  });

  test('preferredScannerVariant respects selected game and stored preference', () {
    final g1 = _enemy(
      id: 'g1_black_worker_ant',
      speciesKey: 'black_worker_ant',
      game: 'g1',
      name: 'Black Worker Ant G1',
      tier: 2,
    );
    final g2 = _enemy(
      id: 'g2_black_worker_ant',
      speciesKey: 'black_worker_ant',
      game: 'g2',
      name: 'Black Worker Ant G2',
      tier: 1,
    );

    expect(
      preferredScannerVariant(
        [g1, g2],
        selectedGameScope: scannerGameScopeG1,
      )?.id,
      g1.id,
    );
    expect(
      preferredScannerVariant(
        [g1, g2],
        selectedGameScope: scannerGameScopeG2,
      )?.id,
      g2.id,
    );
    expect(
      preferredScannerVariant(
        [g1, g2],
        selectedGameScope: scannerGameScopeAll,
        storedPreferredGame: 'g1',
      )?.id,
      g1.id,
    );
    expect(
      preferredScannerVariant(
        [g1, g2],
        selectedGameScope: scannerGameScopeAll,
      )?.id,
      g2.id,
    );
  });

  test('resolveScannerMatches filters by selected scope and keeps preview enemy', () {
    final g1 = _enemy(
      id: 'g1_black_worker_ant',
      speciesKey: 'black_worker_ant',
      game: 'g1',
      name: 'Black Worker Ant G1',
    );
    final g2 = _enemy(
      id: 'g2_black_worker_ant',
      speciesKey: 'black_worker_ant',
      game: 'g2',
      name: 'Black Worker Ant G2',
    );

    const rawMatches = [
      CreatureAliasMatch(
        creatureId: 'black_worker_ant',
        displayName: 'Black Worker Ant',
        confidence: 0.92,
        sourceLabels: ['black ant'],
      ),
    ];

    final g1Only = resolveScannerMatches(
      rawMatches: rawMatches,
      allEnemies: [g1, g2],
      selectedGameScope: scannerGameScopeG1,
    );
    expect(g1Only, hasLength(1));
    expect(g1Only.first.previewEnemy.id, g1.id);
    expect(g1Only.first.variants, hasLength(1));

    final both = resolveScannerMatches(
      rawMatches: rawMatches,
      allEnemies: [g1, g2],
      selectedGameScope: scannerGameScopeAll,
    );
    expect(both, hasLength(1));
    expect(both.first.previewEnemy.id, g2.id);
    expect(both.first.variants, hasLength(2));
  });

  testWidgets('scanner page shows loading and no-match message', (tester) async {
    final enemy = _enemy(
      id: 'g2_ladybug',
      speciesKey: 'ladybug',
      game: 'g2',
      name: 'Ladybug G2',
    );

    final completer = Completer<CreatureScannerResult>();
    final service = _FakeScannerService(
      allEnemies: [enemy],
      selectedGameScope: scannerGameScopeG2,
      handler: (_) => completer.future,
    );

    await tester.pumpWidget(
      _buildApp(
        CreatureScannerPage(
          enemies: [enemy],
          selectedGameScope: scannerGameScopeG2,
          serviceOverride: service,
          imagePickerOverride: _fakePicker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take photo'));
    await tester.pump();

    expect(find.text('Analyzing creature…'), findsOneWidget);

    completer.complete(
      const CreatureScannerResult(
        matches: [],
        rawLabels: ['ladybug'],
        rawWebEntities: [],
        hasClearMatch: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'I could not identify this creature. Try again with a clearer image.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('scanner page opens detail directly on clear single match', (
    tester,
  ) async {
    final enemy = _enemy(
      id: 'g2_wolf_spider',
      speciesKey: 'wolf_spider',
      game: 'g2',
      name: 'Wolf Spider G2',
    );
    final match = CreatureScannerMatch(
      creatureId: enemy.speciesKey,
      displayName: enemy.name.resolve('en'),
      confidence: 0.96,
      sourceLabels: const ['wolf spider'],
      variants: [enemy],
      previewEnemy: enemy,
    );

    await tester.pumpWidget(
      _buildApp(
        CreatureScannerPage(
          enemies: [enemy],
          selectedGameScope: scannerGameScopeG2,
          serviceOverride: _FakeScannerService(
            allEnemies: [enemy],
            selectedGameScope: scannerGameScopeG2,
            handler: (_) async => CreatureScannerResult(
              matches: [match],
              rawLabels: const ['wolf spider'],
              rawWebEntities: const [],
              hasClearMatch: true,
            ),
          ),
          imagePickerOverride: _fakePicker,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    await tester.tap(find.text('Take photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Wolf Spider G2'), findsWidgets);
    await tester.pageBack();
    await tester.pump();
  });

  testWidgets('scanner page shows possible creatures when the result is ambiguous', (
    tester,
  ) async {
    final ladybug = _enemy(
      id: 'g2_ladybug',
      speciesKey: 'ladybug',
      game: 'g2',
      name: 'Ladybug G2',
    );
    final bee = _enemy(
      id: 'g2_bee',
      speciesKey: 'bee',
      game: 'g2',
      name: 'Bee G2',
    );

    await tester.pumpWidget(
      _buildApp(
        CreatureScannerPage(
          enemies: [ladybug, bee],
          selectedGameScope: scannerGameScopeG2,
          serviceOverride: _FakeScannerService(
            allEnemies: [ladybug, bee],
            selectedGameScope: scannerGameScopeG2,
            handler: (_) async => CreatureScannerResult(
              matches: [
                CreatureScannerMatch(
                  creatureId: ladybug.speciesKey,
                  displayName: ladybug.name.resolve('en'),
                  confidence: 0.71,
                  sourceLabels: const ['ladybug'],
                  variants: [ladybug],
                  previewEnemy: ladybug,
                ),
                CreatureScannerMatch(
                  creatureId: bee.speciesKey,
                  displayName: bee.name.resolve('en'),
                  confidence: 0.66,
                  sourceLabels: const ['bee'],
                  variants: [bee],
                  previewEnemy: bee,
                ),
              ],
              rawLabels: const ['ladybug', 'bee'],
              rawWebEntities: const [],
              hasClearMatch: false,
            ),
          ),
          imagePickerOverride: _fakePicker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();

    expect(find.text('Possible creatures'), findsOneWidget);
    expect(find.text('Ladybug G2'), findsOneWidget);
    expect(find.text('Bee G2'), findsOneWidget);
    expect(find.text('Open'), findsNWidgets(2));
  });

  testWidgets('scanner asks which game to open when both variants exist and no preference is saved', (
    tester,
  ) async {
    final g1 = _enemy(
      id: 'g1_black_worker_ant',
      speciesKey: 'black_worker_ant',
      game: 'g1',
      name: 'Black Worker Ant G1',
      tier: 2,
    );
    final g2 = _enemy(
      id: 'g2_black_worker_ant',
      speciesKey: 'black_worker_ant',
      game: 'g2',
      name: 'Black Worker Ant G2',
      tier: 1,
    );
    final match = CreatureScannerMatch(
      creatureId: 'black_worker_ant',
      displayName: 'Black Worker Ant',
      confidence: 0.91,
      sourceLabels: const ['black ant'],
      variants: [g1, g2],
      previewEnemy: g2,
    );

    await tester.pumpWidget(
      _buildApp(
        CreatureScannerPage(
          enemies: [g1, g2],
          selectedGameScope: scannerGameScopeAll,
          serviceOverride: _FakeScannerService(
            allEnemies: [g1, g2],
            selectedGameScope: scannerGameScopeAll,
            handler: (_) async => CreatureScannerResult(
              matches: [match],
              rawLabels: const ['black ant'],
              rawWebEntities: const [],
              hasClearMatch: true,
            ),
          ),
          imagePickerOverride: _fakePicker,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    await tester.tap(find.text('Take photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Which version should I open?'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
  });
}

Widget _buildApp(Widget home) {
  return DefaultAssetBundle(
    bundle: _TestAssetBundle(),
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    ),
  );
}

Future<XFile?> _fakePicker(ImageSource source) async {
  return XFile.fromData(
    Uint8List.fromList(const [1, 2, 3, 4]),
    mimeType: 'image/jpeg',
    name: source == ImageSource.camera ? 'camera.jpg' : 'gallery.jpg',
  );
}

Enemy _enemy({
  required String id,
  required String speciesKey,
  required String game,
  required String name,
  int tier = 1,
}) {
  return Enemy(
    order: 1,
    defaultGold: false,
    id: id,
    speciesKey: speciesKey,
    name: LocalizedText(es: name, en: name, ru: name),
    game: game,
    tier: tier,
    danger: 'baja',
    isBoss: false,
    temperament: 'neutral',
    weaknesses: const ['spicy'],
    resistances: const [],
    cardNormal: 'assets/global/Creaturecard_Proximamente.webp',
    cardGold: 'assets/global/Creaturecard_Proximamente.webp',
    photo: 'assets/global/Aphidex_Proximamente.webp',
    health: const HealthInfo(rating: 1, value: 10),
    elementalWeaknesses: const [BonusInfo(type: 'spicy', bonusPct: 25)],
  );
}

class _FakeScannerService extends CreatureScannerService {
  final Future<CreatureScannerResult> Function(XFile file) handler;

  _FakeScannerService({
    required super.allEnemies,
    required super.selectedGameScope,
    required this.handler,
  }) : super(
         provider: const _UnusedRecognitionProvider(),
         matcher: const CreatureAliasMatcher(),
       );

  @override
  Future<CreatureScannerResult> scanFile(XFile file) => handler(file);
}

class _UnusedRecognitionProvider implements CreatureRecognitionProvider {
  const _UnusedRecognitionProvider();

  @override
  Future<CreatureRecognitionPayload> analyzeImageFile(XFile file) {
    throw UnimplementedError('This provider should not be called in tests.');
  }
}

class _TestAssetBundle extends CachingAssetBundle {
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
    return _transparentImage;
  }
}

ByteData _stringData(String value) {
  final bytes = Uint8List.fromList(utf8.encode(value));
  return ByteData.view(bytes.buffer);
}

final ByteData _transparentImage = ByteData.view(
  Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg==',
    ),
  ).buffer,
);
