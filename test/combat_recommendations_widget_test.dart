import 'dart:io';

import 'package:aphidex/models/enemy.dart';
import 'package:aphidex/widgets/combat_recommendations_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Enemy _enemy(String game) => Enemy.fromJson({
  'id': 'widget_target',
  'speciesKey': 'widget_target',
  'name': {'en': 'Target', 'es': 'Objetivo', 'ru': 'Цель'},
  'game': game,
  'tier': 2,
  'danger': 'medium',
  'isBoss': false,
  'order': 1,
  'defaultGold': false,
  'cardNormal': '',
  'cardGold': '',
  'photo': '',
  'weaknesses': ['stabbing'],
  'resistances': const [],
  'damageWeaknesses': [
    {'type': 'stabbing', 'bonusPct': 50},
  ],
});

void main() {
  testWidgets('Grounded 1 does not render the recommendation section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CombatRecommendationsSection(enemy: _enemy('g1'))),
      ),
    );
    expect(find.text('Recommended weapons'), findsNothing);
  });

  group('Grounded 2 recommendation section', () {
    late Directory temp;

    setUpAll(() async {
      temp = await Directory.systemTemp.createTemp('aphidex-combat-widget');
      Hive.init(temp.path);
      await Hive.openBox('aphidex');
    });

    tearDownAll(() async {
      await Hive.close();
      await temp.delete(recursive: true);
    });

    testWidgets('starts compressed and opens the real 3-8 selector', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CombatRecommendationsSection(enemy: _enemy('g2')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      await tester.pump();
      expect(find.text('Recommended weapons'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Show recommendations'), findsOneWidget);
    });
  });
}
