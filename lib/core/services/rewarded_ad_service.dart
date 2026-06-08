import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

/// Loads and shows a rewarded interstitial ad, resolving to true if the user
/// earned a reward (watched enough), false if dismissed early or ad failed.
///
/// **Web:** No rewarded ads exist. Instead, launches Stripe Checkout for the
/// "Remove Ads" one-time purchase and returns false. After the user completes
/// payment the Stripe webhook sets adFree=true in Firestore, and the
/// adFreeProvider picks it up — subsequent calls bypass this gate entirely.
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
          ? 'ca-app-pub-3940256099942544/6978759866' // test rewarded interstitial iOS
          : 'ca-app-pub-3940256099942544/5354046379'; // test rewarded interstitial Android
    }
    return Platform.isIOS
        ? AppConfig.rewardedAdUnitIos
        : AppConfig.rewardedAdUnitAndroid;
  }

  static Future<bool> showAndAwaitReward() async {
    if (kDebugMode) return true;

    // Web: no rewarded ads — gate behind Stripe Remove Ads purchase instead.
    if (kIsWeb) return _launchStripeCheckout();

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

  /// Calls the createStripeCheckout Cloud Function and opens the Stripe
  /// Checkout URL in a new tab. Always returns false so the gated feature
  /// does not run immediately — after the user pays, the Stripe webhook sets
  /// adFree=true in Firestore and the adFreeProvider automatically reflects it.
  static Future<bool> _launchStripeCheckout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('createStripeCheckout');
      final result = await callable.call({
        'userId': uid,
        'returnUrl': Uri.base.toString(),
        'cancelUrl': Uri.base.toString(),
      });
      final checkoutUrl = result.data['url'] as String?;
      if (checkoutUrl == null) return false;

      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Stripe checkout error: $e');
    }

    // Always return false — feature runs only after adFree is set by webhook.
    return false;
  }
}
