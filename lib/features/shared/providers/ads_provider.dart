import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/config/app_config.dart';
import '../../auth/presentation/providers/auth_provider.dart';
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
  final Ref _ref;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  IapNotifier(this._ref) : super(const IapStatus(IapState.idle)) {
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
        await _grantAdFree();
        state = const IapStatus(IapState.success);
      } else if (purchase.status == PurchaseStatus.error) {
        // Do NOT grant adFree on error — only on confirmed purchase/restore
        state = IapStatus(IapState.error, purchase.error?.message ?? 'Purchase failed.');
      }

      await InAppPurchase.instance.completePurchase(purchase);
    }
  }

  Future<void> _grantAdFree() async {
    final uid = _ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'adFree': true});
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
    StateNotifierProvider<IapNotifier, IapStatus>((ref) => IapNotifier(ref));
