import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/local_storage.dart';
import '../i18n/app_localizations.dart';

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
      'ca-app-pub-4936553988627836/3017093887';
  static const String nativeAdUnitIdAndroid =
      'ca-app-pub-4936553988627836/4940199620';
  static const String nativeAdUnitIdIos =
      'ca-app-pub-4936553988627836/9856907393';
  static const String appOpenAdUnitIdAndroid =
      'ca-app-pub-4936553988627836/9657428973';

  static const String _testBannerAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/9214589741';
  static const String _testInterstitialAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialAdUnitIdIos =
      'ca-app-pub-3940256099942544/4411468910';
  static const int interstitialPromptThreshold = 5;
  static const Duration interstitialPromptCooldown = Duration(minutes: 3);
  static const String _kInterstitialCloseCount =
      'monetization_interstitial_close_count';
  static const String _kInterstitialLastPromptAt =
      'monetization_interstitial_last_prompt_at';
  static const String _kInterstitialLastCreatureId =
      'monetization_interstitial_last_creature_id';

  final ValueNotifier<bool> adsRemoved = ValueNotifier<bool>(false);
  final ValueNotifier<bool> storeAvailable = ValueNotifier<bool>(false);
  final ValueNotifier<ProductDetails?> removeAdsProduct =
      ValueNotifier<ProductDetails?>(null);
  final ValueNotifier<bool> isBusy = ValueNotifier<bool>(false);

  bool _initialized = false;
  bool _interstitialLoadInFlight = false;
  bool _promoFlowInProgress = false;
  InterstitialAd? _interstitialAd;
  DateTime Function() now = DateTime.now;

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

  String get interstitialAdUnitId {
    if (kDebugMode) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _testInterstitialAdUnitIdIos
          : _testInterstitialAdUnitIdAndroid;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return interstitialAdUnitIdIos;
    }
    return interstitialAdUnitIdAndroid;
  }

  static String displayStorePrice(ProductDetails product) {
    final price = product.price.trim();
    final currencyCode = product.currencyCode.trim().toUpperCase();
    final currencySymbol = product.currencySymbol.trim();

    if (price.isEmpty || currencyCode.isEmpty) {
      return price;
    }
    if (currencySymbol == r'$' && !price.toUpperCase().contains(currencyCode)) {
      return '$price $currencyCode';
    }
    return price;
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
    unawaited(_primeInterstitial());
    if (!isStoreSupportedPlatform) {
      return;
    }

    InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_) => isBusy.value = false,
    );
    await refreshStore();
  }

  static bool shouldShowInterstitialPrompt({
    required int closeCount,
    required DateTime currentTime,
    required DateTime? lastPromptAt,
    required bool adsRemoved,
    required bool promoFlowInProgress,
  }) {
    if (adsRemoved || promoFlowInProgress) {
      return false;
    }
    if (closeCount <= 0 || closeCount % interstitialPromptThreshold != 0) {
      return false;
    }
    if (lastPromptAt == null) {
      return true;
    }
    return currentTime.difference(lastPromptAt) >= interstitialPromptCooldown;
  }

  static bool shouldCountCreatureInspection({
    required String? creatureId,
    required String? lastCreatureId,
    required bool countProgress,
  }) {
    if (!countProgress) {
      return false;
    }

    final normalizedCreatureId = creatureId?.trim();
    if (normalizedCreatureId == null || normalizedCreatureId.isEmpty) {
      return false;
    }

    final normalizedLast = lastCreatureId?.trim();
    return normalizedCreatureId != normalizedLast;
  }

  Future<bool> registerCreatureInspectionEvent(
    BuildContext context, {
    required String? creatureId,
    bool countProgress = true,
  }) async {
    if (!shouldShowAds) {
      return false;
    }

    unawaited(_primeInterstitial());
    var closeCount = LocalStorage.getInt(_kInterstitialCloseCount);
    final normalizedCreatureId = creatureId?.trim();
    final lastCreatureId = LocalStorage.getString(_kInterstitialLastCreatureId);
    final didCountInspection = shouldCountCreatureInspection(
      creatureId: normalizedCreatureId,
      lastCreatureId: lastCreatureId,
      countProgress: countProgress,
    );
    if (didCountInspection) {
      closeCount += 1;
      await Future.wait([
        LocalStorage.setInt(_kInterstitialCloseCount, closeCount),
        LocalStorage.setString(
          _kInterstitialLastCreatureId,
          normalizedCreatureId!,
        ),
      ]);
    }
    if (!didCountInspection) {
      return false;
    }

    final currentTime = now();
    final lastPromptMillis = LocalStorage.getInt(_kInterstitialLastPromptAt);
    final lastPromptAt = lastPromptMillis > 0
        ? DateTime.fromMillisecondsSinceEpoch(lastPromptMillis)
        : null;

    if (!shouldShowInterstitialPrompt(
      closeCount: closeCount,
      currentTime: currentTime,
      lastPromptAt: lastPromptAt,
      adsRemoved: adsRemoved.value,
      promoFlowInProgress: _promoFlowInProgress,
    )) {
      return false;
    }

    if (!context.mounted) {
      return false;
    }

    _promoFlowInProgress = true;
    await LocalStorage.setInt(
      _kInterstitialLastPromptAt,
      currentTime.millisecondsSinceEpoch,
    );
    if (!context.mounted) {
      return false;
    }

    try {
      final l10n = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.maybeOf(context);
      final action = await _showRemoveAdsPitch(context);
      if (!context.mounted) {
        return true;
      }

      if (action == _InterstitialPitchAction.removeAds) {
        await _handlePromptPurchase(l10n: l10n, messenger: messenger);
        return true;
      }

      if (!shouldShowAds) {
        return true;
      }

      await _showInterstitialIfAvailable();
      return true;
    } finally {
      _promoFlowInProgress = false;
      unawaited(_primeInterstitial());
    }
  }

  Future<bool> registerEnemySheetClose(
    BuildContext context, {
    String? creatureId,
    bool countProgress = true,
  }) => registerCreatureInspectionEvent(
    context,
    creatureId: creatureId,
    countProgress: countProgress,
  );

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

    final response = await inAppPurchase.queryProductDetails({productId});
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

  Future<void> _primeInterstitial() async {
    if (!shouldShowAds ||
        _interstitialAd != null ||
        _interstitialLoadInFlight ||
        !isAdsSupportedPlatform) {
      return;
    }

    _interstitialLoadInFlight = true;
    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoadInFlight = false;
          _interstitialAd?.dispose();
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (_) {
          _interstitialLoadInFlight = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  Future<void> _showInterstitialIfAvailable() async {
    final ad = _interstitialAd;
    if (ad == null) {
      return;
    }

    _interstitialAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(_primeInterstitial());
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        unawaited(_primeInterstitial());
      },
    );
    await ad.show();
  }

  Future<_InterstitialPitchAction?> _showRemoveAdsPitch(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final product = removeAdsProduct.value;
    final price = product == null ? null : displayStorePrice(product);

    return showDialog<_InterstitialPitchAction>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _RemoveAdsPitchDialog(
        title: l10n.interstitialPitchTitle,
        message: l10n.interstitialPitchMessage(price),
        dismissLabel: l10n.interstitialPitchKeepAdsAction,
        buyLabel: price == null
            ? l10n.removeAdsAction
            : l10n.removeAdsPriceAction(price),
      ),
    );
  }

  Future<void> _handlePromptPurchase({
    required AppLocalizations l10n,
    required ScaffoldMessengerState? messenger,
  }) async {
    final result = await buyRemoveAds();
    final message = switch (result) {
      MonetizationActionResult.alreadyOwned => l10n.adsAlreadyRemovedMessage,
      MonetizationActionResult.storeUnavailable =>
        l10n.adsStoreUnavailableMessage,
      MonetizationActionResult.productUnavailable =>
        l10n.adsProductUnavailableMessage,
      MonetizationActionResult.failed => l10n.adsPurchaseFailedMessage,
      MonetizationActionResult.startedRestore ||
      MonetizationActionResult.launchedPurchaseFlow ||
      MonetizationActionResult.unsupportedPlatform => null,
    };

    if (message != null) {
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  static Set<String> get persistentKeys => {_kAdsRemoved};
}

enum _InterstitialPitchAction { keepAds, removeAds }

class _RemoveAdsPitchDialog extends StatelessWidget {
  const _RemoveAdsPitchDialog({
    required this.title,
    required this.message,
    required this.dismissLabel,
    required this.buyLabel,
  });

  final String title;
  final String message;
  final String dismissLabel;
  final String buyLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_InterstitialPitchAction.keepAds),
          child: Text(dismissLabel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_InterstitialPitchAction.removeAds),
          child: Text(buyLabel),
        ),
      ],
    );
  }
}
