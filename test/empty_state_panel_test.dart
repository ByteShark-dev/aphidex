import 'package:aphidex/models/game_pick.dart';
import 'package:aphidex/widgets/state_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final testerView = TestWidgetsFlutterBinding.ensureInitialized()
      .platformDispatcher
      .views
      .first;

  setUp(() {
    testerView.physicalSize = const Size(390, 320);
    testerView.devicePixelRatio = 1;
  });

  tearDown(() {
    testerView.resetPhysicalSize();
    testerView.resetDevicePixelRatio();
  });

  testWidgets('state panel stays stable on a short phone layout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 320),
            textScaler: TextScaler.linear(1.25),
            viewInsets: EdgeInsets.only(bottom: 120),
          ),
          child: Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: const Center(
                      child: AphidexStatePanel(
                        gamePick: GamePick.g2,
                        icon: Icons.search_off_rounded,
                        title: 'No results',
                        subtitle:
                            'Try another name or clear the current search to keep browsing the list without layout overflow.',
                        actions: [
                          FilledButton(onPressed: null, child: Text('Clear search')),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No results'), findsOneWidget);
    expect(find.text('Clear search'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
