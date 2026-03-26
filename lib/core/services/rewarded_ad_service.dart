import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';

/// Loads and shows a rewarded interstitial ad, resolving to true if the user
/// earned a reward (watched enough), false if dismissed early or ad failed.
///
/// In debug mode the ad is skipped and true is returned immediately so the
/// gated feature can be tested without a live ad.
///
/// Fails open on load error — if AdMob can't serve an ad the feature still
/// works rather than permanently blocking free users.
class RewardedAdService {
  RewardedAdService._();

  static String get _adUnitId {
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/6978759866'   // test rewarded interstitial iOS
          : 'ca-app-pub-3940256099942544/5354046379';  // test rewarded interstitial Android
    }
    return Platform.isIOS
        ? AppConfig.rewardedAdUnitIos
        : AppConfig.rewardedAdUnitAndroid;
  }

  static Future<bool> showAndAwaitReward() async {
    if (kDebugMode) return true;

    final completer = Completer<bool>();

    await RewardedInterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
          );
          ad.show(
            onUserEarnedReward: (_, __) {
              if (!completer.isCompleted) completer.complete(true);
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedInterstitialAd failed to load: $error');
          // Fail open so a bad network day doesn't permanently block the feature
          if (!completer.isCompleted) completer.complete(true);
        },
      ),
    );

    return completer.future;
  }
}
