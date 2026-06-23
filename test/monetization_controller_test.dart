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
    'interstitial pitch triggers every five detail closes with cooldown',
    () {
      final now = DateTime(2026, 5, 30, 12, 0);

      expect(
        MonetizationController.shouldShowInterstitialPrompt(
          closeCount: 5,
          currentTime: now,
          lastPromptAt: null,
          adsRemoved: false,
          promoFlowInProgress: false,
        ),
        isTrue,
      );

      expect(
        MonetizationController.shouldShowInterstitialPrompt(
          closeCount: 4,
          currentTime: now,
          lastPromptAt: null,
          adsRemoved: false,
          promoFlowInProgress: false,
        ),
        isFalse,
      );

      expect(
        MonetizationController.shouldShowInterstitialPrompt(
          closeCount: 10,
          currentTime: now,
          lastPromptAt: now.subtract(const Duration(minutes: 2)),
          adsRemoved: false,
          promoFlowInProgress: false,
        ),
        isFalse,
      );

      expect(
        MonetizationController.shouldShowInterstitialPrompt(
          closeCount: 10,
          currentTime: now,
          lastPromptAt: now.subtract(const Duration(minutes: 3)),
          adsRemoved: false,
          promoFlowInProgress: false,
        ),
        isTrue,
      );
    },
  );
}
