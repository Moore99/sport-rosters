import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/app_config.dart';
import '../providers/ads_provider.dart';
import 'adsense_view_factory_stub.dart'
    if (dart.library.html) 'adsense_view_factory_web.dart';

/// Shows a banner ad if the user is not ad-free.
///
/// On mobile: uses AdMob (BannerAd). Manages its own lifecycle.
/// On web: renders an AdSense responsive display unit via HtmlElementView.
///
/// Usage: place at the bottom of any non-critical screen inside a Column.
class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  String get _adUnitId =>
      Platform.isAndroid ? AppConfig.bannerAdUnitAndroid : AppConfig.bannerAdUnitIos;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      registerAdSenseViewFactory(
        AppConfig.adsensePublisherId,
        AppConfig.adsenseBannerAdUnitWeb,
      );
    } else {
      _loadAd();
    }
  }

  void _loadAd() {
    _ad = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (_, error) {
          _ad?.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adFree = ref.watch(adFreeProvider);

    if (adFree) return const SizedBox.shrink();

    if (kIsWeb) {
      return const SizedBox(
        height: 100,
        child: HtmlElementView(viewType: kAdSenseViewType),
      );
    }

    if (!_loaded || _ad == null) return const SizedBox.shrink();

    return SafeArea(
      child: SizedBox(
        width: _ad!.size.width.toDouble(),
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
