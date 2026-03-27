import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/config/app_config.dart';
import '../../teams/presentation/providers/teams_provider.dart';

// ── Ad-free flag ───────────────────────────────────────────────────────────────
// Derived from Firestore user profile — survives reinstall.

final adFreeProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProfileProvider).valueOrNull?.adFree ?? false;
});

// ── IAP Notifier ───────────────────────────────────────────────────────────────

enum IapState { idle, loading, purchasing, success, error }

class IapStatus {
  final IapState state;
  final String?  message;
  const IapStatus(this.state, [this.message]);
}

class IapNotifier extends StateNotifier<IapStatus> {
  StreamSubscription<List<PurchaseDetails>>? _sub;

  IapNotifier() : super(const IapStatus(IapState.idle)) {
    _listenPurchases();
  }

  void _listenPurchases() {
    _sub = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchases,
      onError: (e) => state = IapStatus(IapState.error, e.toString()),
    );
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != AppConfig.removeAdsSku) continue;

      // IMPORTANT: deliver BEFORE completing — matches nuclear-motd bug fix (build 99)
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final isRestore = purchase.status == PurchaseStatus.restored;
        final validated = await _validateWithServer(purchase, isRestore: isRestore);
        if (validated) {
          state = const IapStatus(IapState.success);
        } else {
          state = const IapStatus(IapState.error,
              'Purchase could not be verified. Please try again.');
        }
      } else if (purchase.status == PurchaseStatus.error) {
        // Do NOT grant adFree on error — only on confirmed purchase/restore
        state = IapStatus(IapState.error, purchase.error?.message ?? 'Purchase failed.');
      }

      await InAppPurchase.instance.completePurchase(purchase);
    }
  }

  /// Sends the receipt/token to the Cloud Function for server-side validation.
  /// The function writes adFree:true to Firestore on success.
  /// Returns true if entitlement was granted.
  Future<bool> _validateWithServer(
    PurchaseDetails purchase, {
    required bool isRestore,
  }) async {
    try {
      final callable = FirebaseFunctions
          .instanceFor(region: 'northamerica-northeast1')
          .httpsCallable('validateIap');

      await callable.call(<String, dynamic>{
        'platform':    Platform.isIOS ? 'ios' : 'android',
        'receiptData': purchase.verificationData.serverVerificationData,
        'productId':   purchase.productID,
        'isRestore':   isRestore,
      });

      return true;
    } on FirebaseFunctionsException catch (e) {
      // permission-denied = store says receipt is invalid
      // internal = transient error — fail open on restore only
      if (isRestore && e.code == 'internal') return true;
      return false;
    } catch (_) {
      // Unexpected error — fail open on restore
      return isRestore;
    }
  }

  Future<void> purchaseRemoveAds() async {
    state = const IapStatus(IapState.loading);

    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      state = const IapStatus(IapState.error, 'Store not available.');
      return;
    }

    final response = await InAppPurchase.instance
        .queryProductDetails({AppConfig.removeAdsSku});

    if (response.notFoundIDs.isNotEmpty || response.productDetails.isEmpty) {
      state = const IapStatus(IapState.error, 'Product not found. Try again later.');
      return;
    }

    final param = PurchaseParam(
      productDetails: response.productDetails.first,
    );

    state = const IapStatus(IapState.purchasing);
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
    // Result arrives via purchaseStream → _handlePurchases
  }

  Future<void> restorePurchases() async {
    state = const IapStatus(IapState.loading);
    await InAppPurchase.instance.restorePurchases();
    // Restored purchases arrive via purchaseStream → _handlePurchases
  }

  void clearError() => state = const IapStatus(IapState.idle);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final iapProvider =
    StateNotifierProvider<IapNotifier, IapStatus>((ref) => IapNotifier());
