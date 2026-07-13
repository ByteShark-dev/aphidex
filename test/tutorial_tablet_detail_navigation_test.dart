import 'dart:io';

import 'package:aphidex/controllers/tutorial_controller.dart';
import 'package:aphidex/layout/app_breakpoints.dart';
import 'package:aphidex/models/enemy_index_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

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
  });

  tearDown(() {
    TutorialController.instance.debugResetForTests();
  });

  test(
    'tablet Skip clears inline detail without creating a temporary route',
    () async {
      final controller = TutorialController.instance;
      controller.debugConfigureDetailTutorialForTests(
        enemy: _tutorialEnemy,
        variants: [_tutorialEnemy],
        effectId: 'gas',
      );
      controller.updateListLayout(
        surface: AppSurfaceSize.expanded,
        isTabletLike: true,
      );
      controller.debugStartStepForTests(TutorialStep.detailSummary);
      await controller.debugOpenDetailTutorialRouteForTests();

      expect(controller.inlineDetailEnemy, same(_tutorialEnemy));
      await controller.skip();
      expect(controller.isActive, isFalse);
      expect(controller.inlineDetailEnemy, isNull);
    },
  );

  testWidgets(
    'minimal tablet harness preserves inline detail and root provider',
    (tester) async {
      final controller = TutorialController.instance;
      final rootValue = ValueNotifier<int>(7);
      addTearDown(rootValue.dispose);
      controller.debugConfigureDetailTutorialForTests(
        enemy: _tutorialEnemy,
        variants: [_tutorialEnemy],
        effectId: 'gas',
      );
      controller.updateListLayout(
        surface: AppSurfaceSize.expanded,
        isTabletLike: true,
      );
      controller.debugStartStepForTests(TutorialStep.detailSummary);
      await controller.debugOpenDetailTutorialRouteForTests();
      await tester.pumpWidget(
        _buildTestApp(
          _RootProvider(value: rootValue, child: const _TabletDetailHarness()),
        ),
      );
      expect(
        find.byKey(
          controller.keyFor(
            tutorialAnchorDetailSummary,
            scope: TutorialTargetScope.inlineDetail,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('root=7'), findsOneWidget);
    },
  );

  test('detail key scopes fail if inline and fullscreen reuse an instance', () {
    final controller = TutorialController.instance;
    final inlineKey = controller.keyFor(
      tutorialAnchorDetailEffects,
      scope: TutorialTargetScope.inlineDetail,
    );
    final fullscreenKey = controller.keyFor(
      tutorialAnchorDetailEffects,
      scope: TutorialTargetScope.fullscreenDetail,
    );

    expect(inlineKey, isNot(same(fullscreenKey)));
  });
}

Widget _buildTestApp(Widget home) {
  return MaterialApp(home: home);
}

class _RootProvider extends InheritedNotifier<ValueNotifier<int>> {
  const _RootProvider({required ValueNotifier<int> value, required super.child})
    : super(notifier: value);

  static ValueNotifier<int> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RootProvider>()!.notifier!;
}

class _TabletDetailHarness extends StatelessWidget {
  const _TabletDetailHarness();

  @override
  Widget build(BuildContext context) {
    final rootValue = _RootProvider.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              const SizedBox(width: 320, child: Text('list')),
              Expanded(
                child: ListenableBuilder(
                  listenable: TutorialController.instance,
                  builder: (context, _) {
                    final controller = TutorialController.instance;
                    final enemy = controller.inlineDetailEnemy;
                    return Column(
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: rootValue,
                          builder: (context, value, _) => Text('root=$value'),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: enemy == null
                              ? const Center(
                                  child: Text('normal inline detail'),
                                )
                              : KeyedSubtree(
                                  key: controller.keyFor(
                                    tutorialAnchorDetailSummary,
                                    scope: TutorialTargetScope.inlineDetail,
                                  ),
                                  child: const Center(
                                    child: Text('tutorial inline detail'),
                                  ),
                                ),
                        ),
                        const SizedBox(
                          key: ValueKey('master-detail-still-mounted'),
                          height: 1,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const EnemyIndexEntry _tutorialEnemy = EnemyIndexEntry(
  id: 'g2_tutorial_enemy',
  speciesKey: 'tutorial_enemy',
  name: 'Tutorial Enemy',
  order: 1,
  game: 'g2',
  tier: 3,
  danger: 'alta',
  isBoss: false,
  weaknesses: ['fresh'],
  resistances: ['gas'],
  defaultGold: false,
  cardNormal: '',
  cardGold: '',
);
