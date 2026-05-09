import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/local_storage.dart';

enum MonetizationActionResult {
  launchedPurchaseFlow,
  startedRestore,
  alreadyOwned,
  storeUnavailable,
  productUnavailable,
  unsupportedPlatform,
  failed,
}

class MonetizationController {
  MonetizationController._();

  static final MonetizationController instance = MonetizationController._();

  static const String removeAdsProductIdAndroid = 'no_ads_aphidex';
  static const String removeAdsProductIdIos = 'com.byteshark.aphidex.no_ads';
  static const String _kAdsRemoved = 'monetization_ads_removed';

  static const String adMobAppIdAndroid =
      'ca-app-pub-4936553988627836~8729320683';
  static const String adMobAppIdIos = 'ca-app-pub-4936553988627836~4005814918';
  static const String bannerAdUnitIdAndroid =
      'ca-app-pub-4936553988627836/2887691866';
  static const String bannerAdUnitIdIos =
      'ca-app-pub-4936553988627836/8804891629';
  static const String interstitialAdUnitIdAndroid =
      'ca-app-pub-4936553988627836/1256194779';
  static const String interstitialAdUnitIdIos =
      'ca-app-pub-4936553988627836/8012508533';
  static const String nativeAdUnitIdAndroid =
      'ca-app-pub-4936553988627836/4940199620';
  static const String nativeAdUnitIdIos =
      'ca-app-pub-4936553988627836/9856907393';
  static const String appOpenAdUnitIdAndroid =
      'ca-app-pub-4936553988627836/9657428973';

  static const String _testBannerAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/9214589741';

  final ValueNotifier<bool> adsRemoved = ValueNotifier<bool>(false);
  final ValueNotifier<bool> storeAvailable = ValueNotifier<bool>(false);
  final ValueNotifier<ProductDetails?> removeAdsProduct =
      ValueNotifier<ProductDetails?>(null);
  final ValueNotifier<bool> isBusy = ValueNotifier<bool>(false);

  bool _initialized = false;

  bool get isAdsSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get isStoreSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get isSupportedPlatform => isStoreSupportedPlatform;

  bool get shouldShowAds => isAdsSupportedPlatform && !adsRemoved.value;

  String? get currentRemoveAdsProductId {
    if (kIsWeb) {
      return null;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return removeAdsProductIdAndroid;
      case TargetPlatform.iOS:
        return removeAdsProductIdIos;
      default:
        return null;
    }
  }

  Set<String> get knownRemoveAdsProductIds => {
    removeAdsProductIdAndroid,
    removeAdsProductIdIos,
  };

  String get bannerAdUnitId {
    if (kDebugMode) {
      return _testBannerAdUnitIdAndroid;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return bannerAdUnitIdIos;
    }
    return bannerAdUnitIdAndroid;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    adsRemoved.value = LocalStorage.getBool(_kAdsRemoved, fallback: false);

    if (!isAdsSupportedPlatform) {
      return;
    }

    await MobileAds.instance.initialize();
    if (!isStoreSupportedPlatform) {
      return;
    }

    InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_) => isBusy.value = false,
    );
    await refreshStore();
  }

  Future<void> refreshStore() async {
    if (!isStoreSupportedPlatform) {
      storeAvailable.value = false;
      removeAdsProduct.value = null;
      return;
    }

    final productId = currentRemoveAdsProductId;
    if (productId == null) {
      storeAvailable.value = false;
      removeAdsProduct.value = null;
      return;
    }

    final inAppPurchase = InAppPurchase.instance;
    final available = await inAppPurchase.isAvailable();
    storeAvailable.value = available;
    if (!available) {
      removeAdsProduct.value = null;
      return;
    }

    final response = await inAppPurchase.queryProductDetails({
      productId,
    });
    if (response.error != null || response.productDetails.isEmpty) {
      removeAdsProduct.value = null;
      return;
    }
    removeAdsProduct.value = response.productDetails.first;
  }

  Future<MonetizationActionResult> buyRemoveAds() async {
    if (!isStoreSupportedPlatform) {
      return MonetizationActionResult.unsupportedPlatform;
    }
    if (adsRemoved.value) {
      return MonetizationActionResult.alreadyOwned;
    }
    if (!storeAvailable.value) {
      await refreshStore();
      if (!storeAvailable.value) {
        return MonetizationActionResult.storeUnavailable;
      }
    }

    final product = removeAdsProduct.value;
    if (product == null) {
      await refreshStore();
      if (removeAdsProduct.value == null) {
        return MonetizationActionResult.productUnavailable;
      }
    }

    final purchaseParam = PurchaseParam(
      productDetails: removeAdsProduct.value!,
    );

    isBusy.value = true;
    final launched = await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
    if (!launched) {
      isBusy.value = false;
      return MonetizationActionResult.failed;
    }
    return MonetizationActionResult.launchedPurchaseFlow;
  }

  Future<MonetizationActionResult> restoreRemoveAds() async {
    if (!isStoreSupportedPlatform) {
      return MonetizationActionResult.unsupportedPlatform;
    }
    if (!storeAvailable.value) {
      await refreshStore();
      if (!storeAvailable.value) {
        return MonetizationActionResult.storeUnavailable;
      }
    }

    isBusy.value = true;
    await InAppPurchase.instance.restorePurchases();
    return MonetizationActionResult.startedRestore;
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!knownRemoveAdsProductIds.contains(purchase.productID)) {
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          adsRemoved.value = true;
          await LocalStorage.setBool(_kAdsRemoved, true);
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          break;
        case PurchaseStatus.pending:
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
    isBusy.value = false;
  }

  static Set<String> get persistentKeys => {_kAdsRemoved};
}
