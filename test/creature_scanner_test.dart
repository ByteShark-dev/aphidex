import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/models/enemy_index_entry.dart';
import 'package:aphidex/scanner/creature_alias_matcher.dart';
import 'package:aphidex/scanner/creature_scanner_page.dart';
import 'package:aphidex/scanner/creature_scanner_service.dart';
import 'package:aphidex/scanner/remote_creature_scanner_service.dart';
import 'package:aphidex/scanner/scanner_image_compressor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  test(
    'alias matcher keeps ambiguous spider results out of clear single match',
    () {
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
    },
  );

  test(
    'alias matcher returns earwig variants as suggestions for generic earwig labels',
    () {
      const matcher = CreatureAliasMatcher();

      final result = matcher.match(
        rawLabels: const ['earwig'],
        rawWebEntities: const [],
      );

      expect(
        result.matches.map((match) => match.creatureId),
        contains('pincher_earwig'),
      );
      expect(
        result.matches.map((match) => match.creatureId),
        contains('whipper_earwig'),
      );
      expect(matcher.isClearSingleMatch(result.matches), isFalse);
    },
  );

  test('alias matcher resolves scorpion labels to northern scorpion', () {
    const matcher = CreatureAliasMatcher();

    final result = matcher.match(
      rawLabels: const ['scorpion'],
      rawWebEntities: const [],
    );

    expect(result.matches, isNotEmpty);
    expect(result.matches.first.creatureId, 'northern_scorpion');
  });

  test(
    'preferredScannerVariant respects selected game and stored preference',
    () {
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
        preferredScannerVariant([
          g1,
          g2,
        ], selectedGameScope: scannerGameScopeG1)?.id,
        g1.id,
      );
      expect(
        preferredScannerVariant([
          g1,
          g2,
        ], selectedGameScope: scannerGameScopeG2)?.id,
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
        preferredScannerVariant([
          g1,
          g2,
        ], selectedGameScope: scannerGameScopeAll)?.id,
        g2.id,
      );
    },
  );

  test(
    'resolveScannerMatches filters by selected scope and keeps preview enemy',
    () {
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
    },
  );

  testWidgets('scanner page shows loading and no-match message', (
    tester,
  ) async {
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

  testWidgets('scanner page explains camera permission denial', (tester) async {
    final enemy = _enemy(
      id: 'g2_ladybug',
      speciesKey: 'ladybug',
      game: 'g2',
      name: 'Ladybug G2',
    );

    await tester.pumpWidget(
      _buildApp(
        CreatureScannerPage(
          enemies: [enemy],
          selectedGameScope: scannerGameScopeG2,
          serviceOverride: _FakeScannerService(
            allEnemies: [enemy],
            selectedGameScope: scannerGameScopeG2,
            handler: (_) async => const CreatureScannerResult(
              matches: [],
              rawLabels: [],
              rawWebEntities: [],
              hasClearMatch: false,
            ),
          ),
          imagePickerOverride: (_) async {
            throw PlatformException(code: 'camera_access_denied');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Camera or photo access was denied. Enable it in system settings to use Scanner Beta.',
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
      displayName: enemy.name,
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

  testWidgets(
    'scanner page shows possible creatures when the result is ambiguous',
    (tester) async {
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
                    displayName: ladybug.name,
                    confidence: 0.71,
                    sourceLabels: const ['ladybug'],
                    variants: [ladybug],
                    previewEnemy: ladybug,
                  ),
                  CreatureScannerMatch(
                    creatureId: bee.speciesKey,
                    displayName: bee.name,
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
    },
  );

  testWidgets(
    'scanner asks which game to open when both variants exist and no preference is saved',
    (tester) async {
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
    },
  );

  testWidgets('remote scanner beta is hidden by default', (tester) async {
    final enemy = _enemy(
      id: 'g2_ladybug',
      speciesKey: 'ladybug',
      game: 'g2',
      name: 'Ladybug G2',
    );

    await tester.pumpWidget(
      _buildApp(
        CreatureScannerPage(
          enemies: [enemy],
          selectedGameScope: scannerGameScopeG2,
          serviceOverride: _FakeScannerService(
            allEnemies: [enemy],
            selectedGameScope: scannerGameScopeG2,
            handler: (_) async => const CreatureScannerResult(
              matches: [],
              rawLabels: [],
              rawWebEntities: [],
              hasClearMatch: false,
            ),
          ),
          imagePickerOverride: _fakePicker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Smart beta analysis'), findsNothing);
  });

  testWidgets('remote scanner beta shows smart analysis controls', (
    tester,
  ) async {
    final enemy = _enemy(
      id: 'g2_ladybug',
      speciesKey: 'ladybug',
      game: 'g2',
      name: 'Ladybug G2',
    );

    await tester.pumpWidget(
      _buildApp(
        CreatureScannerPage(
          enemies: [enemy],
          selectedGameScope: scannerGameScopeG2,
          remoteEnabledOverride: true,
          remoteServiceOverride: _FakeRemoteScannerService(),
          imagePickerOverride: _fakePicker,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollToRemoteAnalyze(tester);

    expect(find.text('Smart Scanner Beta'), findsOneWidget);
    expect(find.text('Smart beta analysis'), findsOneWidget);
    expect(find.text('Beta: it can be wrong.'), findsOneWidget);
    expect(
      find.text(
        'Smart analysis sends the image to a ByteShark server to identify possible creatures.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('remote scanner shows no-token message', (tester) async {
    final enemy = _enemy(
      id: 'g2_ladybug',
      speciesKey: 'ladybug',
      game: 'g2',
      name: 'Ladybug G2',
    );

    await tester.pumpWidget(
      _buildApp(
        CreatureScannerPage(
          enemies: [enemy],
          selectedGameScope: scannerGameScopeG2,
          remoteEnabledOverride: true,
          remoteServiceOverride: _FakeRemoteScannerService(
            scanHandler: (_) async => throw const CreatureScannerException(
              CreatureScannerErrorType.outOfTokens,
            ),
          ),
          imagePickerOverride: _fakePicker,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollToRemoteAnalyze(tester);

    await tester.tap(find.byKey(const ValueKey('scanner-remote-analyze')));
    await tester.pumpAndSettle();

    expect(find.text('No scanner tokens remaining.'), findsOneWidget);
    expect(find.text('Search manually'), findsOneWidget);
    expect(find.text('Try another image'), findsOneWidget);
  });

  testWidgets('remote scanner opens lazy detail from exact candidate id', (
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
      displayName: enemy.name,
      confidence: 0.91,
      sourceLabels: const ['visible markings'],
      variants: [enemy],
      previewEnemy: enemy,
      isExactIdMatch: true,
    );

    await tester.pumpWidget(
      _buildApp(
        CreatureScannerPage(
          enemies: [enemy],
          selectedGameScope: scannerGameScopeG2,
          remoteEnabledOverride: true,
          remoteServiceOverride: _FakeRemoteScannerService(
            scanHandler: (_) async => CreatureScannerResult(
              matches: [match],
              rawLabels: const [],
              rawWebEntities: const [],
              hasClearMatch: true,
              weak: false,
              tokens: _tokens(tokens: 9, usedToday: 1),
            ),
          ),
          imagePickerOverride: _fakePicker,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await _scrollToRemoteAnalyze(tester);

    await tester.tap(find.byKey(const ValueKey('scanner-remote-analyze')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Wolf Spider G2'), findsWidgets);
    await tester.pageBack();
    await tester.pump();
  });

  testWidgets('remote scanner network failure shows recoverable error', (
    tester,
  ) async {
    final enemy = _enemy(
      id: 'g2_ladybug',
      speciesKey: 'ladybug',
      game: 'g2',
      name: 'Ladybug G2',
    );

    await tester.pumpWidget(
      _buildApp(
        CreatureScannerPage(
          enemies: [enemy],
          selectedGameScope: scannerGameScopeG2,
          remoteEnabledOverride: true,
          remoteServiceOverride: _FakeRemoteScannerService(
            scanHandler: (_) async => throw const CreatureScannerException(
              CreatureScannerErrorType.network,
            ),
          ),
          imagePickerOverride: _fakePicker,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollToRemoteAnalyze(tester);

    await tester.tap(find.byKey(const ValueKey('scanner-remote-analyze')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'I could not reach the scanner service. Check your internet and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try another image'), findsOneWidget);
  });

  test('remote scanner filters allowedCreatures by selected scope', () async {
    final g1 = _enemy(
      id: 'g1_ladybug',
      speciesKey: 'ladybug',
      game: 'g1',
      name: 'Ladybug G1',
    );
    final g2 = _enemy(
      id: 'g2_ladybug',
      speciesKey: 'ladybug',
      game: 'g2',
      name: 'Ladybug G2',
    );

    expect(await _capturedAllowedIds(scannerGameScopeG1, [g1, g2]), [
      'g1_ladybug',
    ]);
    expect(await _capturedAllowedIds(scannerGameScopeG2, [g1, g2]), [
      'g2_ladybug',
    ]);
    expect(await _capturedAllowedIds(scannerGameScopeAll, [g1, g2]), [
      'g1_ladybug',
      'g2_ladybug',
    ]);
  });

  test('remote scanner does not show g1 duplicates in g2 scope', () {
    final g1 = _enemy(
      id: 'g1_ladybug',
      speciesKey: 'ladybug',
      game: 'g1',
      name: 'Ladybug G1',
    );
    final g2 = _enemy(
      id: 'g2_ladybug',
      speciesKey: 'ladybug',
      game: 'g2',
      name: 'Ladybug G2',
    );

    final matches = resolveRemoteScannerMatches(
      candidates: const [
        RemoteScannerCandidate(
          id: 'g1_ladybug',
          confidence: 0.95,
          reason: 'round shell and spots',
        ),
        RemoteScannerCandidate(
          id: 'g2_ladybug',
          confidence: 0.90,
          reason: 'round shell and spots',
        ),
      ],
      allEnemies: [g1, g2],
      selectedGameScope: scannerGameScopeG2,
    );

    expect(matches, hasLength(1));
    expect(matches.first.previewEnemy.id, 'g2_ladybug');
    expect(matches.first.variants, hasLength(1));
  });

  test('remote scanner groups equivalent variants in both scope', () {
    final g1 = _enemy(
      id: 'g1_ladybug',
      speciesKey: 'ladybug',
      game: 'g1',
      name: 'Ladybug',
    );
    final g2 = _enemy(
      id: 'g2_ladybug',
      speciesKey: 'ladybug',
      game: 'g2',
      name: 'Ladybug',
    );

    final matches = resolveRemoteScannerMatches(
      candidates: const [
        RemoteScannerCandidate(
          id: 'g1_ladybug',
          confidence: 0.90,
          reason: 'round shell and spots',
        ),
        RemoteScannerCandidate(
          id: 'g2_ladybug',
          confidence: 0.88,
          reason: 'round shell and spots',
        ),
      ],
      allEnemies: [g1, g2],
      selectedGameScope: scannerGameScopeAll,
    );

    expect(matches, hasLength(1));
    expect(matches.first.variants.map((enemy) => enemy.id), [
      'g1_ladybug',
      'g2_ladybug',
    ]);
    expect(matches.first.isExactIdMatch, isFalse);
  });

  test('remote auto-open requires high confidence and clear margin', () {
    final ladybug = _remoteMatch('ladybug', 0.93);
    final bee = _remoteMatch('bee', 0.72);
    final spider = _remoteMatch('wolf_spider', 0.60);

    expect(
      isClearRemoteScannerResult(
        matches: [_remoteMatch('ladybug', 0.90), _remoteMatch('bee', 0.60)],
        weak: false,
        multiCreature: false,
        selectedGameScope: scannerGameScopeG2,
      ),
      isFalse,
    );
    expect(
      isClearRemoteScannerResult(
        matches: [ladybug, _remoteMatch('bee', 0.731), spider],
        weak: false,
        multiCreature: false,
        selectedGameScope: scannerGameScopeG2,
      ),
      isFalse,
    );
    expect(
      isClearRemoteScannerResult(
        matches: [ladybug, bee, spider],
        weak: false,
        multiCreature: false,
        selectedGameScope: scannerGameScopeG2,
      ),
      isTrue,
    );
  });

  test('remote auto-open rejects similar second candidate', () {
    expect(
      isClearRemoteScannerResult(
        matches: [
          _remoteMatch('orc_wasp', 0.98),
          _remoteMatch('ogrr_wasp', 0.70),
        ],
        weak: false,
        multiCreature: false,
        selectedGameScope: scannerGameScopeG2,
      ),
      isFalse,
    );
  });

  test('remote multi-creature result never auto-opens', () {
    expect(
      isClearRemoteScannerResult(
        matches: [_remoteMatch('ladybug', 0.98)],
        weak: true,
        multiCreature: true,
        selectedGameScope: scannerGameScopeG2,
      ),
      isFalse,
    );
  });

  test('remote ranking penalizes ants when strong wing evidence exists', () {
    final fireAnt = _enemy(
      id: 'g2_fire_worker_ant',
      speciesKey: 'fire_worker_ant',
      game: 'g2',
      name: 'Fire Worker Ant',
    );
    final wasp = _enemy(
      id: 'g2_ogrr_wasp',
      speciesKey: 'ogrr_wasp',
      game: 'g2',
      name: 'OGRR Wasp',
      collectionGroup: 'ogrr',
    );

    final matches = resolveRemoteScannerMatches(
      candidates: const [
        RemoteScannerCandidate(
          id: 'g2_fire_worker_ant',
          confidence: 0.96,
          reason: 'wings, flying, yellow black wasp body',
        ),
        RemoteScannerCandidate(
          id: 'g2_ogrr_wasp',
          confidence: 0.70,
          reason: 'wings and stinger, OGRR wasp',
        ),
      ],
      allEnemies: [fireAnt, wasp],
      selectedGameScope: scannerGameScopeG2,
    );

    expect(matches.first.previewEnemy.id, 'g2_ogrr_wasp');
    expect(matches.first.confidence, greaterThan(matches.last.confidence));
  });

  test('remote ranking penalizes beetles when strong wasp evidence exists', () {
    final beetle = _enemy(
      id: 'g2_bombardier_beetle',
      speciesKey: 'bombardier_beetle',
      game: 'g2',
      name: 'Bombardier Beetle',
    );
    final wasp = _enemy(
      id: 'g2_ogrr_wasp',
      speciesKey: 'ogrr_wasp',
      game: 'g2',
      name: 'OGRR Wasp',
      collectionGroup: 'ogrr',
    );

    final matches = resolveRemoteScannerMatches(
      candidates: const [
        RemoteScannerCandidate(
          id: 'g2_bombardier_beetle',
          confidence: 0.80,
          reason: 'clear wings, flying, wasp body and thin waist',
        ),
        RemoteScannerCandidate(
          id: 'g2_ogrr_wasp',
          confidence: 0.70,
          reason: 'clear wings, flying, OGRR wasp body',
        ),
      ],
      allEnemies: [beetle, wasp],
      selectedGameScope: scannerGameScopeG2,
    );

    expect(matches.first.previewEnemy.id, 'g2_ogrr_wasp');
  });

  test('remote ranking penalizes crossed ORC and OGRR evidence', () {
    final orc = _enemy(
      id: 'g2_orc_wolf_spider',
      speciesKey: 'orc_wolf_spider',
      game: 'g2',
      name: 'O.R.C. Wolf Spider',
      collectionGroup: 'orc',
    );
    final ogrr = _enemy(
      id: 'g2_ogrr_wolf_spider',
      speciesKey: 'ogrr_wolf_spider',
      game: 'g2',
      name: 'OGRR Wolf Spider',
      collectionGroup: 'ogrr',
    );

    final matches = resolveRemoteScannerMatches(
      candidates: const [
        RemoteScannerCandidate(
          id: 'g2_orc_wolf_spider',
          confidence: 0.95,
          reason: 'OGRR enhanced wolf spider',
        ),
        RemoteScannerCandidate(
          id: 'g2_ogrr_wolf_spider',
          confidence: 0.78,
          reason: 'OGRR enhanced wolf spider',
        ),
      ],
      allEnemies: [orc, ogrr],
      selectedGameScope: scannerGameScopeAll,
    );

    expect(matches.first.previewEnemy.id, 'g2_ogrr_wolf_spider');
  });

  test('remote scanner keeps ORC and OGRR as distinct candidates', () {
    final orc = _enemy(
      id: 'g2_orc_wasp',
      speciesKey: 'orc_wasp',
      game: 'g2',
      name: 'O.R.C. Wasp',
      collectionGroup: 'orc',
    );
    final ogrr = _enemy(
      id: 'g2_ogrr_wasp',
      speciesKey: 'ogrr_wasp',
      game: 'g2',
      name: 'OGRR Wasp',
      collectionGroup: 'ogrr',
    );

    final matches = resolveRemoteScannerMatches(
      candidates: const [
        RemoteScannerCandidate(
          id: 'g2_orc_wasp',
          confidence: 0.82,
          reason: 'controlled ORC wasp',
        ),
        RemoteScannerCandidate(
          id: 'g2_ogrr_wasp',
          confidence: 0.81,
          reason: 'OGRR wasp',
        ),
      ],
      allEnemies: [orc, ogrr],
      selectedGameScope: scannerGameScopeAll,
    );

    expect(matches, hasLength(2));
    expect(
      matches.map((match) => match.previewEnemy.id),
      containsAll(['g2_orc_wasp', 'g2_ogrr_wasp']),
    );
  });

  test('remote allowedCreatures include compact visual tags', () async {
    final wasp = _enemy(
      id: 'g2_ogrr_wasp',
      speciesKey: 'ogrr_wasp',
      game: 'g2',
      name: 'OGRR Wasp',
      collectionGroup: 'ogrr',
    );

    final allowed = await _capturedAllowedCreatures(scannerGameScopeG2, [wasp]);
    expect(
      allowed.single['visualTags'],
      containsAll(['wasp', 'wings', 'ogrr']),
    );
    expect(
      allowed.single['visualTags'] as List<dynamic>,
      hasLength(lessThanOrEqualTo(12)),
    );
  });

  test('remote service maps structured server errors by code', () async {
    final enemy = _enemy(
      id: 'g2_ladybug',
      speciesKey: 'ladybug',
      game: 'g2',
      name: 'Ladybug G2',
    );
    final service = RemoteCreatureScannerService(
      apiBaseUrl: 'https://scanner.test',
      clientToken: 'client-token',
      allEnemies: [enemy],
      selectedGameScope: scannerGameScopeG2,
      languageCode: 'en',
      deviceIdOverride: 'test-device-12345',
      imageCompressor: const _PassthroughCompressor(),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {
              'code': 'GEMINI_RATE_LIMIT',
              'message': 'Scanner analysis is temporarily busy.',
              'requestId': 'req-123',
            },
          }),
          429,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      service.scanFile(
        XFile.fromData(
          Uint8List.fromList(const [1, 2, 3, 4]),
          mimeType: 'image/jpeg',
          name: 'test.jpg',
        ),
      ),
      throwsA(
        isA<CreatureScannerException>()
            .having(
              (error) => error.type,
              'type',
              CreatureScannerErrorType.serverBusy,
            )
            .having((error) => error.requestId, 'requestId', 'req-123')
            .having(
              (error) => error.serverCode,
              'serverCode',
              'GEMINI_RATE_LIMIT',
            ),
      ),
    );
  });

  testWidgets('remote scanner shows weak and multi-creature guidance', (
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
          remoteEnabledOverride: true,
          remoteServiceOverride: _FakeRemoteScannerService(
            scanHandler: (_) async => CreatureScannerResult(
              matches: [
                CreatureScannerMatch(
                  creatureId: ladybug.speciesKey,
                  displayName: ladybug.name,
                  confidence: 0.86,
                  sourceLabels: const ['multiple creatures visible'],
                  variants: [ladybug],
                  previewEnemy: ladybug,
                  isExactIdMatch: true,
                ),
                CreatureScannerMatch(
                  creatureId: bee.speciesKey,
                  displayName: bee.name,
                  confidence: 0.84,
                  sourceLabels: const ['wings visible'],
                  variants: [bee],
                  previewEnemy: bee,
                  isExactIdMatch: true,
                ),
              ],
              rawLabels: const [],
              rawWebEntities: const [],
              hasClearMatch: false,
              weak: true,
              multiCreature: true,
              tokens: _tokens(tokens: 9, usedToday: 1),
            ),
          ),
          imagePickerOverride: _fakePicker,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollToRemoteAnalyze(tester);

    await tester.tap(find.byKey(const ValueKey('scanner-remote-analyze')));
    await tester.pumpAndSettle();

    expect(find.text('Approximate result'), findsOneWidget);
    expect(
      find.text(
        'The image may contain multiple creatures. Choose the correct match.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try another image'), findsOneWidget);
    expect(find.text('Search manually'), findsOneWidget);
  });

  testWidgets('remote scanner shows specific temporary analysis errors', (
    tester,
  ) async {
    final enemy = _enemy(
      id: 'g2_ladybug',
      speciesKey: 'ladybug',
      game: 'g2',
      name: 'Ladybug G2',
    );

    await tester.pumpWidget(
      _buildApp(
        CreatureScannerPage(
          enemies: [enemy],
          selectedGameScope: scannerGameScopeG2,
          remoteEnabledOverride: true,
          remoteServiceOverride: _FakeRemoteScannerService(
            scanHandler: (_) async => throw const CreatureScannerException(
              CreatureScannerErrorType.analysisTemporary,
              requestId: 'req-analysis-1',
              serverCode: 'GEMINI_TIMEOUT',
            ),
          ),
          imagePickerOverride: _fakePicker,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollToRemoteAnalyze(tester);

    await tester.tap(find.byKey(const ValueKey('scanner-remote-analyze')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The smart analysis failed temporarily. No token was charged.\nDiagnostic ID: req-analysis-1',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('remote token refresh failure does not erase scan candidates', (
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
          remoteEnabledOverride: true,
          remoteServiceOverride: _FakeRemoteScannerService(
            tokenHandler: () async => throw const CreatureScannerException(
              CreatureScannerErrorType.serverBusy,
            ),
            scanHandler: (_) async => CreatureScannerResult(
              matches: [
                CreatureScannerMatch(
                  creatureId: ladybug.speciesKey,
                  displayName: ladybug.name,
                  confidence: 0.88,
                  sourceLabels: const ['round shell'],
                  variants: [ladybug],
                  previewEnemy: ladybug,
                  isExactIdMatch: true,
                ),
                CreatureScannerMatch(
                  creatureId: bee.speciesKey,
                  displayName: bee.name,
                  confidence: 0.76,
                  sourceLabels: const ['yellow black'],
                  variants: [bee],
                  previewEnemy: bee,
                  isExactIdMatch: true,
                ),
              ],
              rawLabels: const [],
              rawWebEntities: const [],
              hasClearMatch: false,
              weak: true,
              tokens: _tokens(tokens: 9, usedToday: 1),
            ),
          ),
          imagePickerOverride: _fakePicker,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollToRemoteAnalyze(tester);

    await tester.tap(find.byKey(const ValueKey('scanner-remote-analyze')));
    await tester.pumpAndSettle();

    expect(find.text('Possible creatures'), findsOneWidget);
    expect(find.text('Ladybug G2'), findsOneWidget);
    expect(find.text('Bee G2'), findsOneWidget);
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

Future<void> _scrollToRemoteAnalyze(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('scanner-remote-analyze')),
    180,
    scrollable: find.byType(Scrollable),
  );
  await tester.pumpAndSettle();
}

EnemyIndexEntry _enemy({
  required String id,
  required String speciesKey,
  required String game,
  required String name,
  int tier = 1,
  String? collectionGroup,
  String? goldLinkId,
}) {
  return EnemyIndexEntry(
    order: 1,
    defaultGold: false,
    id: id,
    speciesKey: speciesKey,
    collectionGroup: collectionGroup,
    name: name,
    game: game,
    tier: tier,
    danger: 'baja',
    isBoss: false,
    temperament: 'neutral',
    weaknesses: const ['spicy'],
    resistances: const [],
    goldLinkId: goldLinkId,
    cardNormal: 'assets/global/Creaturecard_Proximamente.webp',
    cardGold: 'assets/global/Creaturecard_Proximamente.webp',
    health: const HealthInfo(rating: 1, value: 10),
  );
}

CreatureScannerMatch _remoteMatch(String speciesKey, double confidence) {
  final enemy = _enemy(
    id: 'g2_$speciesKey',
    speciesKey: speciesKey,
    game: 'g2',
    name: speciesKey,
  );
  return CreatureScannerMatch(
    creatureId: speciesKey,
    displayName: speciesKey,
    confidence: confidence,
    sourceLabels: const [],
    variants: [enemy],
    previewEnemy: enemy,
    isExactIdMatch: true,
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

class _FakeRemoteScannerService implements RemoteCreatureScannerClient {
  final Future<CreatureScannerResult> Function(XFile file)? scanHandler;
  final Future<RemoteScannerTokenState> Function()? tokenHandler;

  _FakeRemoteScannerService({this.scanHandler, this.tokenHandler});

  @override
  Future<RemoteScannerTokenState> loadTokens() {
    return tokenHandler?.call() ?? Future.value(_tokens());
  }

  @override
  Future<CreatureScannerResult> scanFile(XFile file) {
    return scanHandler?.call(file) ??
        Future.value(
          CreatureScannerResult(
            matches: const [],
            rawLabels: const [],
            rawWebEntities: const [],
            hasClearMatch: false,
            weak: true,
            tokens: _tokens(),
          ),
        );
  }
}

class _PassthroughCompressor implements ScannerImageCompressor {
  const _PassthroughCompressor();

  @override
  Future<XFile> compressFile(XFile file) async => file;
}

class _UnusedRecognitionProvider implements CreatureRecognitionProvider {
  const _UnusedRecognitionProvider();

  @override
  Future<CreatureRecognitionPayload> analyzeImageFile(XFile file) {
    throw UnimplementedError('This provider should not be called in tests.');
  }
}

RemoteScannerTokenState _tokens({int tokens = 10, int usedToday = 0}) {
  return RemoteScannerTokenState(
    plan: 'free',
    tokens: tokens,
    maxTokens: 100,
    dailyRefill: 10,
    dailyLimit: 25,
    usedToday: usedToday,
    usageDate: '2026-06-23',
    lastRefillDate: '2026-06-23',
  );
}

Future<List<String>> _capturedAllowedIds(
  String scope,
  List<EnemyIndexEntry> enemies,
) async {
  final captured = await _capturedAllowedCreatures(scope, enemies);
  return captured.map((item) => item['id'].toString()).toList(growable: false);
}

Future<List<Map<String, dynamic>>> _capturedAllowedCreatures(
  String scope,
  List<EnemyIndexEntry> enemies,
) async {
  var captured = const <Map<String, dynamic>>[];
  final service = RemoteCreatureScannerService(
    apiBaseUrl: 'https://scanner.test',
    clientToken: 'client-token',
    allEnemies: enemies,
    selectedGameScope: scope,
    languageCode: 'en',
    deviceIdOverride: 'test-device-12345',
    imageCompressor: const _PassthroughCompressor(),
    httpClient: MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      captured = (body['allowedCreatures'] as List<dynamic>)
          .cast<Map<dynamic, dynamic>>()
          .map((item) => item.cast<String, dynamic>())
          .toList(growable: false);
      return http.Response(
        jsonEncode({
          'candidates': <Map<String, dynamic>>[],
          'weak': true,
          'multiCreature': false,
          'tokens': {
            'plan': 'free',
            'tokens': 9,
            'maxTokens': 100,
            'dailyRefill': 10,
            'dailyLimit': 25,
            'usedToday': 1,
            'usageDate': '2026-06-23',
            'lastRefillDate': '2026-06-23',
          },
        }),
        200,
      );
    }),
  );

  await service.scanFile(
    XFile.fromData(
      Uint8List.fromList(const [1, 2, 3, 4]),
      mimeType: 'image/jpeg',
      name: 'test.jpg',
    ),
  );
  return captured;
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
  Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg==',
    ),
  ).buffer,
);
