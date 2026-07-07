import 'package:aphidex/controllers/monetization_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('remove ads product id stays mapped to Android SKU', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(
      MonetizationController.instance.currentRemoveAdsProductId,
      MonetizationController.removeAdsProductIdAndroid,
    );
  });

  test('remove ads product id stays mapped to iOS SKU', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(
      MonetizationController.instance.currentRemoveAdsProductId,
      MonetizationController.removeAdsProductIdIos,
    );
  });

  test('iOS interstitial unit stays mapped to the current App Store slot', () {
    expect(
      MonetizationController.interstitialAdUnitIdIos,
      'ca-app-pub-4936553988627836/3017093887',
    );
  });

  test(
    'interstitial pitch keeps the approved eight-close cadence and 90-second cooldown',
    () {
      final now = DateTime(2026, 5, 30, 12, 0);

      expect(
        MonetizationController.shouldShowInterstitialPrompt(
          closeCount: 8,
          currentTime: now,
          lastPromptAt: null,
          adsRemoved: false,
          promoFlowInProgress: false,
        ),
        isTrue,
      );

      expect(
        MonetizationController.shouldShowInterstitialPrompt(
          closeCount: 7,
          currentTime: now,
          lastPromptAt: null,
          adsRemoved: false,
          promoFlowInProgress: false,
        ),
        isFalse,
      );

      expect(
        MonetizationController.shouldShowInterstitialPrompt(
          closeCount: 16,
          currentTime: now,
          lastPromptAt: now.subtract(const Duration(seconds: 89)),
          adsRemoved: false,
          promoFlowInProgress: false,
        ),
        isFalse,
      );

      expect(
        MonetizationController.shouldShowInterstitialPrompt(
          closeCount: 16,
          currentTime: now,
          lastPromptAt: now.subtract(const Duration(seconds: 90)),
          adsRemoved: false,
          promoFlowInProgress: false,
        ),
        isTrue,
      );
    },
  );

  test(
    'same creature taps do not increase the distinct inspection counter',
    () {
      expect(
        MonetizationController.shouldCountCreatureInspection(
          creatureId: 'g2_wasp',
          lastCreatureId: 'g2_wasp',
          countProgress: true,
        ),
        isFalse,
      );
      expect(
        MonetizationController.shouldCountCreatureInspection(
          creatureId: 'g2_wasp',
          lastCreatureId: 'g2_wolf_spider',
          countProgress: true,
        ),
        isTrue,
      );
      expect(
        MonetizationController.shouldCountCreatureInspection(
          creatureId: 'g2_wasp',
          lastCreatureId: 'g2_wolf_spider',
          countProgress: false,
        ),
        isFalse,
      );
    },
  );
}
