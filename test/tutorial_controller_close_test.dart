import 'dart:io';

import 'package:aphidex/controllers/tutorial_controller.dart';
import 'package:aphidex/data/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp(
      'aphidex_tutorial_close_test_',
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
    TutorialController.instance.debugStartStepForTests(TutorialStep.search);
  });

  test('finish is idempotent and marks the tutorial as completed', () async {
    await TutorialController.instance.finish();
    await TutorialController.instance.finish();

    expect(TutorialController.instance.isActive, isFalse);
    expect(
      LocalStorage.getBool(TutorialController.completionKey, fallback: false),
      isTrue,
    );
  });
}
