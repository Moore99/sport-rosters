# Monetization

## What It Does
The app is free with ads (Google AdMob). A one-time in-app purchase ("Remove Ads") removes all advertising permanently. Certain premium features (auto-generate lineup, auto-balance boat seating) are additionally gated behind rewarded ads, which paying users bypass.

## User-Facing Behaviour
| Action | Who |
|--------|-----|
| See banner ads on key screens | Free users |
| See interstitial ads at certain flow transitions | Free users |
| Watch a rewarded ad to use auto-generate lineup | Free users |
| Watch a rewarded ad to use auto-balance boat seating | Free users |
| Purchase "Remove Ads" (one-time) | Any user |
| Restore purchase on new device | Any user |
| Skip rewarded ads for premium features | Paid users (`adFree = true`) |

## Data Model
`users/{uid}.adFree: bool` — the entitlement flag. Set server-side by the `validateIap` Cloud Function after a verified purchase or restore. Survives reinstall because it's in Firestore, not device storage.

## Ad Units

| Type | Platform | ID (live) | Test ID |
|------|----------|-----------|---------|
| Banner | Android | In `app_config.dart` | `ca-app-pub-3940256099942544/6300978111` |
| Banner | iOS | In `app_config.dart` | `ca-app-pub-3940256099942544/6300978111` |
| Interstitial | Android | In `app_config.dart` | `ca-app-pub-3940256099942544/1033173712` |
| Interstitial | iOS | In `app_config.dart` | `ca-app-pub-3940256099942544/5224354917` |
| Rewarded | Android | In `app_config.dart` | `ca-app-pub-3940256099942544/5224354917` |
| Rewarded | iOS | In `app_config.dart` | `ca-app-pub-3940256099942544/5224354917` |

AdMob app IDs:
- Android: in `AndroidManifest.xml` (swap to live ID before submission)
- iOS: `GADApplicationIdentifier` in `ios/Runner/Info.plist`

## IAP Product
- **Product ID**: `com.sportsrostering.app.remove_ads`
- **Type**: Non-consumable, one-time purchase
- **Stores**: Google Play + App Store Connect

## Cloud Function: `validateIap`
Called by the app after a `PurchaseStatus.purchased` or `PurchaseStatus.restored` event.

**Params**: `{ platform, receiptData, productId, isRestore }`

**iOS validation**: posts to Apple `/verifyReceipt` (production first; falls back to sandbox on status 21007 for TestFlight).

**Android validation**: calls Google Play Developer API (`purchases.products.get`) using a service account. Service account: `play-iap-validator@sports-rostering.iam.gserviceaccount.com`. Credentials stored as Firebase secret `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`. `ANDROID_VALIDATION_ENABLED = true` as of 2026-04-02.

**Failure behaviour**:
- New purchase: fail closed (throw error — user can retry).
- Restore: fail open (grant entitlement — user already paid, transient outage shouldn't penalise them).

**On success**: sets `adFree: true` on `users/{uid}` via Admin SDK. Cannot be spoofed by the client.

**Critical rule**: `PurchaseStatus.error` must **not** call `setAdsFree(true)`. Only `purchased` or `restored` states trigger validation.

## Feature Flags
In `app_config.dart`:
- `enableAutoLineup = true`
- `enableRewardedAds = true`
- `enablePdfExport = true`

These allow disabling features without a code change (toggle the const and rebuild).

## Key Decisions
- **Entitlement in Firestore, not device storage** — `adFree` survives reinstall, device swap, and sign-in on a new device. The server is the source of truth.
- **Server-side receipt validation** — client never self-grants `adFree`. Even restore goes through the Cloud Function.
- **Rewarded ads gate specific features, not paywalled content** — the app is fully functional without ads. Rewarded ads are used for time-saving features (auto-generate) that admins find convenient but don't need. This reduces the "pay or suffer" dynamic.
- **`enforceAppCheck: true` on `validateIap`** — unlike `uploadTeamLogo`, IAP validation keeps App Check enforcement because the financial stakes justify rejecting sideloaded APKs.
- **Android Play Console API access via service account, not OAuth** — the service account is invited via Users and Permissions in Play Console (not via the deprecated "Setup → API access" UI which no longer exists).

## Future / Deferred
- **Subscription model** — current model is a one-time purchase. A subscription (e.g., per team, per month) could unlock admin features beyond ad removal. Would require a subscription product in both stores and server-side subscription status checking.
- **Team-level purchase** — currently `adFree` is per-user. A model where an admin purchases for the whole team (all members go ad-free) is more compelling for team sports but requires different entitlement propagation.
- **In-app purchase for additional sports/positions** — sports config is hardcoded. A "pro sports pack" IAP was considered but not built.
- **Ad frequency capping** — current ad placement is controlled by the SDK. No custom frequency capping logic is implemented.
- **Revenue reporting** — no in-app revenue dashboard. Admob + Play Console + App Store Connect are the sources.
