import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../controllers/monetization_controller.dart';
import '../i18n/app_localizations.dart';

class InlineBannerAdCard extends StatefulWidget {
  const InlineBannerAdCard({super.key});

  @override
  State<InlineBannerAdCard> createState() => _InlineBannerAdCardState();
}

class _InlineBannerAdCardState extends State<InlineBannerAdCard> {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  double? _lastWidth;
  bool _failed = false;

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadAd(double maxWidth) async {
    final controller = MonetizationController.instance;
    if (!controller.shouldShowAds) {
      return;
    }

    final width = maxWidth.truncate();
    if (width <= 0 || _lastWidth == maxWidth) {
      return;
    }
    _lastWidth = maxWidth;
    _failed = false;

    _bannerAd?.dispose();
    _bannerAd = null;
    _adSize = null;

    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (!mounted || size == null) {
      return;
    }

    final banner = BannerAd(
      size: size,
      adUnitId: controller.bannerAdUnitId,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _adSize = size;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) {
            return;
          }
          setState(() {
            _failed = true;
            _bannerAd = null;
            _adSize = null;
          });
        },
      ),
      request: const AdRequest(),
    );
    unawaited(banner.load());
  }

  @override
  Widget build(BuildContext context) {
    final controller = MonetizationController.instance;
    if (!controller.shouldShowAds || _failed) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            unawaited(_loadAd(constraints.maxWidth));

            if (_bannerAd == null || _adSize == null) {
              return const SizedBox(height: 72);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Text(
                    context.l10n.adLabel,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                SizedBox(
                  width: _adSize!.width.toDouble(),
                  height: _adSize!.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
