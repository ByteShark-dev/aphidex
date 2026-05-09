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
}
