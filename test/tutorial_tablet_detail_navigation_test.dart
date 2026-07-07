import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aphidex/controllers/review_prompt_controller.dart';
import 'package:aphidex/controllers/tutorial_controller.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/models/enemy_index_entry.dart';
import 'package:aphidex/screens/enemy_detail_screen.dart';
import 'package:aphidex/widgets/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

final TestFlutterView tabletTutorialView =
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  late Future<ByteData?> Function(ByteData?) handler;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp(
      'aphidex_tutorial_tablet_test_',
    );
    Hive.init(hiveDir.path);
    await Hive.openBox('aphidex');
  });

  tearDownAll(() async {
    await Hive.box('aphidex').close();
  });

  setUp(() async {
    await Hive.box('aphidex').clear();
    TutorialController.instance.debugResetForTests();

    handler = (message) async {
      final key = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );

      if (key == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage(<Object?, Object?>{});
      }
      if (key == 'AssetManifest.json') {
        return _stringData('{}');
      }
      if (key == 'FontManifest.json') {
        return _stringData('[]');
      }
      if (key.endsWith('.svg')) {
        return _stringData(_TestAssetBundle.svg);
      }
      return _transparentImage;
    };

    tabletTutorialView.physicalSize = const Size(1366, 1024);
    tabletTutorialView.devicePixelRatio = 1.0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', handler);
  });

  tearDown(() {
    tabletTutorialView.resetPhysicalSize();
    tabletTutorialView.resetDevicePixelRatio();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    TutorialController.instance.debugResetForTests();
  });

  testWidgets(
    'tablet detail tutorial isolates a compact fullscreen route and closes it cleanly',
    (tester) async {
      final controller = TutorialController.instance;
      final g1Enemy = Enemy.fromJson(_tutorialEnemyJson);
      final g2Enemy = Enemy.fromJson(_tutorialEnemyG2Json);
      final g1Summary = EnemyIndexEntry.fromEnemy(g1Enemy, 'en');
      final g2Summary = EnemyIndexEntry.fromEnemy(g2Enemy, 'en');

      controller.debugConfigureDetailTutorialForTests(
        enemy: g2Summary,
        variants: [g1Summary, g2Summary],
        effectId: 'gas',
      );
      controller.debugStartStepForTests(TutorialStep.detailSummary);

      await tester.pumpWidget(
        _buildTestApp(
          _TabletDetailHost(enemy: g2Enemy, variants: [g1Enemy, g2Enemy]),
        ),
      );
      await _pumpReady(tester);

      final navigator = ReviewPromptController.navigatorKey.currentState!;
      final route = MaterialPageRoute<void>(
        builder: (_) => EnemyDetailScreen(
          enemy: g2Enemy,
          variants: [g1Enemy, g2Enemy],
          forceCompactTutorialLayout: true,
        ),
      );
      controller.debugRegisterTutorialDetailRouteForTests(route);
      unawaited(navigator.push(route));
      await _pumpReady(tester);

      final detailFinder = find.byWidgetPredicate(
        (widget) => widget is EnemyDetailScreen,
        skipOffstage: false,
      );
      final detailWidgets = tester.widgetList<EnemyDetailScreen>(detailFinder);
      expect(
        detailWidgets.any((widget) => widget.forceCompactTutorialLayout),
        isTrue,
      );
      expect(
        detailWidgets.any(
          (widget) =>
              !widget.forceCompactTutorialLayout &&
              !widget.tutorialAnchorsEnabled,
        ),
        isTrue,
      );
      expect(controller.tutorialFullscreenMode, isTrue);

      controller.debugResetForTests();
      navigator.pop();
      await _pumpReady(tester);

      expect(controller.tutorialFullscreenMode, isFalse);
      expect(find.byKey(const ValueKey('tutorial-next')), findsNothing);
      expect(find.byType(EnemyDetailScreen), findsOneWidget);
    },
  );
}

Widget _buildTestApp(Widget home) {
  return DefaultAssetBundle(
    bundle: _TestAssetBundle(),
    child: MaterialApp(
      navigatorKey: ReviewPromptController.navigatorKey,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) =>
          TutorialHost(child: child ?? const SizedBox.shrink()),
      home: home,
    ),
  );
}

Future<void> _pumpReady(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
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

class _TestAssetBundle extends CachingAssetBundle {
  static const svg =
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
      return _stringData(svg);
    }
    return _transparentImage;
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key.endsWith('.svg')) {
      return svg;
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

class _TabletDetailHost extends StatelessWidget {
  const _TabletDetailHost({required this.enemy, required this.variants});

  final Enemy enemy;
  final List<Enemy> variants;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const SizedBox(width: 420),
          Expanded(
            child: ListenableBuilder(
              listenable: TutorialController.instance,
              builder: (context, _) {
                return EnemyDetailScreen(
                  enemy: enemy,
                  variants: variants,
                  tutorialAnchorsEnabled:
                      !TutorialController.instance.tutorialFullscreenMode,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final Map<String, dynamic> _tutorialEnemyJson = {
  'id': 'g1_tutorial_enemy',
  'speciesKey': 'tutorial_shared_enemy',
  'name': {
    'es': 'Enemigo tutorial',
    'en': 'Tutorial Enemy',
    'ru': 'Обучающий враг',
  },
  'game': 'g1',
  'tier': 2,
  'danger': 'media',
  'isBoss': false,
  'order': 120,
  'defaultGold': false,
  'cardNormal': 'assets/test/Card.webp',
  'cardGold': 'assets/test/Card_Gold.webp',
  'photo': 'assets/test/Photo.webp',
  'weaknesses': ['salty'],
  'resistances': ['poison'],
  'health': {'rating': 2, 'value': 100},
  'elementalWeaknesses': [
    {'type': 'salty', 'bonusPct': 50},
  ],
  'damageWeaknesses': [
    {'type': 'busting', 'bonusPct': 25},
  ],
  'resistancesV2': [
    {'type': 'gas', 'bonusPct': 100},
  ],
  'weakPoint': {'part': 'back', 'susceptibleDamage': 'chopping and slashing'},
  'attacks': [],
};

final Map<String, dynamic> _tutorialEnemyG2Json = {
  'id': 'g2_tutorial_enemy',
  'speciesKey': 'tutorial_shared_enemy',
  'name': {
    'es': 'Enemigo tutorial',
    'en': 'Tutorial Enemy',
    'ru': 'Обучающий враг',
  },
  'game': 'g2',
  'tier': 3,
  'danger': 'alta',
  'isBoss': false,
  'order': 220,
  'defaultGold': false,
  'cardNormal': 'assets/test/Card.webp',
  'cardGold': 'assets/test/Card_Gold.webp',
  'photo': 'assets/test/Photo.webp',
  'weaknesses': ['fresh'],
  'resistances': ['gas'],
  'health': {'rating': 3, 'value': 150},
  'elementalWeaknesses': [
    {'type': 'fresh', 'bonusPct': 50},
  ],
  'damageWeaknesses': [
    {'type': 'stabbing', 'bonusPct': 25},
  ],
  'resistancesV2': [
    {'type': 'gas', 'bonusPct': 100},
  ],
  'attacks': [],
};
