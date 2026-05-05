import 'package:flutter_test/flutter_test.dart';

import 'package:aphidex/controllers/review_prompt_controller.dart';

void main() {
  group('ReviewPromptController.shouldPromptAfterClose', () {
    final now = DateTime(2026, 4, 16, 12, 0, 0);

    test('prompts on every fifth close', () {
      expect(
        ReviewPromptController.shouldPromptAfterClose(
          closeCount: 5,
          currentTime: now,
          previousCloseAt: now.subtract(const Duration(minutes: 1)),
          lastPromptAt: null,
          isOptedOut: false,
          isDialogVisible: false,
          isPendingStoreReturn: false,
        ),
        isTrue,
      );
    });

    test('prompts after five idle minutes and one close', () {
      expect(
        ReviewPromptController.shouldPromptAfterClose(
          closeCount: 2,
          currentTime: now,
          previousCloseAt: now.subtract(const Duration(minutes: 6)),
          lastPromptAt: null,
          isOptedOut: false,
          isDialogVisible: false,
          isPendingStoreReturn: false,
        ),
        isTrue,
      );
    });

    test('does not prompt during cooldown', () {
      expect(
        ReviewPromptController.shouldPromptAfterClose(
          closeCount: 5,
          currentTime: now,
          previousCloseAt: now.subtract(const Duration(minutes: 6)),
          lastPromptAt: now.subtract(const Duration(minutes: 30)),
          isOptedOut: false,
          isDialogVisible: false,
          isPendingStoreReturn: false,
        ),
        isFalse,
      );
    });

    test('does not prompt when user already opted out', () {
      expect(
        ReviewPromptController.shouldPromptAfterClose(
          closeCount: 10,
          currentTime: now,
          previousCloseAt: now.subtract(const Duration(minutes: 10)),
          lastPromptAt: null,
          isOptedOut: true,
          isDialogVisible: false,
          isPendingStoreReturn: false,
        ),
        isFalse,
      );
    });
  });
}
