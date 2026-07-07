import 'package:aphidex/controllers/tutorial_controller.dart';
import 'package:aphidex/i18n/app_localizations.dart';
import 'package:aphidex/widgets/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TutorialController.instance.debugResetForTests();
  });

  testWidgets('rapid double next only advances one step', (tester) async {
    final controller = TutorialController.instance;
    controller.debugStartStepForTests(TutorialStep.search);

    controller.next();
    controller.next();

    await tester.pump();
    await tester.pump();

    expect(controller.step, TutorialStep.gamePicker);
  });

  testWidgets('currentTargetRect drops stale anchors after unmount', (
    tester,
  ) async {
    final controller = TutorialController.instance;
    final key = controller.keyFor(tutorialAnchorListSearch);

    controller.debugStartStepForTests(TutorialStep.search);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: TutorialHost(
          child: Scaffold(
            body: Center(child: SizedBox(key: key, width: 24, height: 24)),
          ),
        ),
      ),
    );
    await tester.pump();

    final overlayContext = tester.element(find.byType(TutorialHost));
    expect(controller.currentTargetRect(overlayContext), isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const TutorialHost(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();

    final nextOverlayContext = tester.element(find.byType(TutorialHost));
    expect(controller.currentTargetRect(nextOverlayContext), isNull);
    await controller.syncCurrentTargetVisibility();
    expect(tester.takeException(), isNull);
  });
}
