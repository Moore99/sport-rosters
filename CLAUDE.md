# CLAUDE.md — Sports Rostering App

Read this file first. Reflects the actual current state, not the original spec.

---

## Pending / Next Steps

- **Firebase CocoaPods → SPM (action by Oct 2026)**: Firebase stops publishing to CocoaPods in October 2026. This Flutter app uses Firebase via FlutterFire — no manual migration needed; FlutterFire will handle the SPM transition. Keep FlutterFire packages current (`flutter pub upgrade`) and watch for migration-related package updates before October 2026. Deprecation warnings will appear in `pod install` output starting May 2026.

---

## Running the Application

```bash
flutter run --dart-define=GOOGLE_PLACES_API_KEY_ANDROID=AIzaSyAY590kSYhhKKzu6VVlsA0xO_VcpdNE3DQ --dart-define=GOOGLE_PLACES_API_KEY_IOS=AIzaSyAY590kSYhhKKzu6VVlsA0xO_VcpdNE3DQ
flutter pub get   # After modifying pubspec.yaml
flutter clean     # Often fails on OneDrive repos due to file locking — safe to ignore
flutter doctor
```

**Build APK for Android:**
```bash
flutter build apk --release --dart-define=GOOGLE_PLACES_API_KEY_ANDROID=AIzaSyAY590kSYhhKKzu6VVlsA0xO_VcpdNE3DQ --dart-define=GOOGLE_PLACES_API_KEY_IOS=AIzaSyAY590kSYhhKKzu6VVlsA0xO_VcpdNE3DQ
```

**Build AAB for Play Store:**
```bash
flutter build appbundle --release --dart-define=GOOGLE_PLACES_API_KEY_ANDROID=AIzaSyAY590kSYhhKKzu6VVlsA0xO_VcpdNE3DQ --dart-define=GOOGLE_PLACES_API_KEY_IOS=AIzaSyAY590kSYhhKKzu6VVlsA0xO_VcpdNE3DQ
```
AAB output: `C:\BuildTemp\sports-rostering\app\outputs\bundle\release\app-release.aab`
Note: Flutter reports "failed to produce .aab file" due to the build junction — the file IS there at the path above, ignore the warning.

**Install APK on connected device:**
```bash
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r "C:\BuildTemp\sports-rostering\app\outputs\flutter-apk\app-release.apk"
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell am force-stop com.sportsrostering.app
```

**iOS builds**: No Mac available — all iOS builds via **Codemagic** (cloud CI). Push to GitHub, trigger Codemagic manually.

**Note**: The `build/` directory is a Windows junction pointing to `C:\BuildTemp\sports-rostering` to avoid OneDrive file locking. APK output lands at `C:\BuildTemp\sports-rostering\app\outputs\flutter-apk\app-release.apk`. If the junction is ever lost, recreate with:
```
cmd /c "mklink /J C:\users\john\onedrive\projects\sports-rostering\build C:\BuildTemp\sports-rostering"
```
To force a clean build, delete `C:\BuildTemp\sports-rostering` contents (not the folder itself) then rebuild.

---

## Testing & Code Quality

### Unit tests (no device needed)
```bash
flutter test test/unit/
```
Covers: Team model, Event model, GameResult, BoatConfig, LineupGenerator, AppConfig.
All 64 tests run in ~1 second. Run after any logic change before building.

### Integration tests (deferred)

Integration tests were removed due to Firebase reCAPTCHA blocking cleartext HTTP on physical devices. The reCAPTCHA verification runs in an isolated WebView that ignores Android's network security config, making emulator-only testing impractical without proper cloud device infrastructure.

**When to revisit:**
- Firebase provides a way to disable reCAPTCHA in Console (Email/Password → reCAPTCHA toggle)
- Use **Firebase Test Lab** or **Codemagic** for device-based E2E testing
- Switch to **mock repositories** for UI-only testing (no Firebase)

### Static analysis
```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
```

### Windows `flutter analyze` False Positives
On Windows, you may see false-positive URI errors like:
```
Error: Uri is unavailable — 'dart:html' can't be accessed on this platform.
```
These are pre-existing, non-blocking, and can be ignored. They occur due to platform-specific conditional imports in dependencies. If these become noisy and you need to verify other warnings pass, run:
```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
```
This still catches actual errors.

---

## Architecture Overview

### Stack
- **Flutter 3.x** — Web, Android, iOS
- **Riverpod** (`flutter_riverpod ^2.4.9`) — state management
- **GoRouter** (`go_router ^17.1.0`) — navigation
- **Firebase** — Auth, Firestore, Messaging, Crashlytics, Storage, Analytics, App Check
- **Google AdMob** — banner + interstitial + rewarded ads
- **In-App Purchases** — one-time "Remove Ads"
- **Material 3** — UI toolkit

### No Custom Server
There is no custom backend server. All data goes through Firebase SDKs directly from the Flutter client. AWS SES (email invites) is deferred until a server is available.

---

## File Structure

```
lib/
├── core/
│   ├── config/
│   │   └── app_config.dart          # Firebase config, ad unit IDs, feature flags
│   ├── router/
│   │   └── app_router.dart          # GoRouter — all routes, auth redirect guard
│   ├── theme/
│   │   └── app_theme.dart           # Material 3 color scheme, text styles
│   └── services/
│       ├── auth_service.dart        # Firebase Auth wrapper
│       ├── notification_service.dart # FCM + app badge
│       └── analytics_service.dart   # Firebase Analytics + GoRouter observer
├── features/
│   ├── auth/                        # Login, register, forgot password
│   ├── teams/                       # Team create/join/manage
│   ├── events/                      # Scheduling, availability
│   ├── rankings/                    # Coach-only player rankings (PRIVATE)
│   ├── lineups/                     # Lineup builder (drag-and-drop)
│   ├── dropins/                     # Drop-in session sign-ups
│   ├── admin/                       # System admin tools
│   └── shared/
│       └── widgets/                 # Banner ads, offline indicator, common widgets
└── main.dart
```

Each feature follows the pattern:
```
features/<name>/
  data/          # Firestore repository
  domain/        # Models
  presentation/
    screens/
    providers/
```

---

## Key Business Rules

### Rankings — COACH PRIVATE
- Rankings are stored in the `rankings` Firestore collection.
- **Players cannot read their own rankings or anyone else's.**
- Only team admins (coaches) can read and write rankings.
- Rankings influence lineup auto-generation (admin-only feature).
- NEVER expose rankings in player-facing screens or API responses.

### User Roles
| Role | Capabilities |
|------|-------------|
| System Admin | All teams, all users, sports config, broadcast email |
| Team Admin (Coach) | Schedule, roster approve/deny, rankings (private), lineups, drop-ins |
| Player | View schedule, RSVP availability, drop-in signup, own profile |

---

## Compliance (GDPR + PIPEDA)

### Account Deletion
Full cascade required when a user deletes their account:
`availability` → `rankings` → `lineups` (assignments) → `dropInSessions.signups` → `users`

Use a Cloud Function or Firestore batch write to guarantee atomicity.

### Data Minimization
- `phone` and `photoUrl` are optional — collect only on explicit user action
- Do not log personal data in Crashlytics

### Consent
- Push notification permission requested explicitly with explanation
- Optional profile fields (phone, photo) shown with purpose text

### Required In-App Screens
- `/privacy` — Privacy Policy (must reference GDPR/PIPEDA rights)
- `/terms` — Terms of Service

### Firebase Region
Firestore region: **northamerica-northeast2 (Toronto)** — selected for PIPEDA compliance.

---

## Firestore Security Rules

Rules live in `firestore.rules`. Key constraints:
- Rankings: **team admins ONLY** (read + write) — players denied
- Users: any signed-in user can read (needed for name resolution in rosters/drop-in lists)
- Teams: any signed-in user can read; admins write
- Events: team members read; admins write
- Drop-in signups: player can add/remove only their own UID
- Availability: player writes only their own; signed-in users can read (null resource handled)
- JoinRequests: any signed-in user can read; admins update/delete

**Critical patterns learned:**
- Rules using `resource.data.X` fail with permission-denied when the doc doesn't exist (`resource == null`). Always guard: `resource == null || isTeamMember(resource.data.teamId)`
- Stream providers MUST watch `currentUserProvider` so they restart on sign-out/sign-in. Without this, a stream that gets permission-denied on sign-out stays in error state for the next user. See `teamProvider`, `teamEventsProvider`, `dropInSessionProvider`.
- `FirebaseFirestore.instance.clearPersistence()` on sign-out helps but is unreliable if listeners are still active — the real fix is auth-aware providers.

---

## Riverpod Patterns (from nuclear-motd-mobile)

- Use `StateNotifierProvider` for mutable state
- Use `ref.read(provider.notifier).method()` to invoke actions — do NOT use `ref.invalidate()` on StateNotifierProvider (timing issues)
- Use `ref.watch()` for reactive rebuilds, `ref.read()` for one-time actions
- Use `Future.microtask()` for side effects triggered inside `build()`
- Derived providers (e.g. `unreadCountProvider`) should be plain `Provider<T>` watching upstream state — no API call

---

## AdMob

See `lib/core/config/app_config.dart` for ad unit ID constants. Use test IDs during development:
- Banner test ID: `ca-app-pub-3940256099942544/6300978111`
- Interstitial test ID: `ca-app-pub-3940256099942544/1033173712`
- Rewarded test ID: `ca-app-pub-3940256099942544/5224354917`

Swap to live IDs before Play Store / App Store submission.

---

## IAP — Remove Ads

Product ID: `com.sportsrostering.app.remove_ads` (to be confirmed in Play Console / App Store Connect)

Reuse the corrected IAP flow from nuclear-motd-mobile (build 1.0.2+99):
- `PurchaseStatus.error` must NOT call `setAdsFree(true)`
- Wait for `PurchaseStatus.restored` or `PurchaseStatus.purchased` before granting entitlement
- Store `adFree: true` in Firestore `users` doc (survives reinstall)

---

## iOS-Specific (Critical — from nuclear-motd-mobile)

**iOS 26 SceneDelegate fix is REQUIRED** before any iOS build:
- `AppDelegate.swift` must include an explicit `SceneDelegate` class (inlined, no separate .swift file)
- `Info.plist` must set `UISceneDelegateClassName = $(PRODUCT_MODULE_NAME).SceneDelegate`
- Do NOT set `UISceneDelegateClassName` to `AppDelegate` — causes SIGABRT
- Plugins registered with `flutterEngine`, not `self`
- `Firebase.initializeApp()` called in Dart `main.dart` — do NOT add `FirebaseApp.configure()` to AppDelegate

**iOS Deployment Target:**
- Minimum supported: **iOS 17.0** (as of March 2026, required for Xcode 26 / iOS 26 SDK)
- Set in `ios/Podfile`: `platform :ios, '17.0'`
- Set in `ios/Runner.xcodeproj/project.pbxproj`: `IPHONEOS_DEPLOYMENT_TARGET = 17.0`

---

## Version Management

**Single source of truth: `version.txt`** at repo root (e.g., `1.0.3`).

- `version.txt` — controls the marketing version name for both platforms
- `android/app/build.gradle.kts` reads `versionName` from `version.txt`; `versionCode` from `$BUILD_NUMBER` env var (Codemagic) or falls back to `flutter.versionCode` (local builds)
- `codemagic.yaml` passes `--build-name=$(cat version.txt) --build-number=$BUILD_NUMBER` to `flutter build ipa`
- `pubspec.yaml` version should stay in sync with `version.txt` (used as local build fallback); build number in pubspec is only used for local APK builds

**To release a new version:**
1. Edit `version.txt` (e.g., `1.0.3` → `1.0.4`)
2. Update `pubspec.yaml` version to match (increment build number for local testing)
3. Commit and push → trigger Codemagic for iOS; build APK locally for Android
4. Codemagic auto-increments `$BUILD_NUMBER` for iOS
5. Verify AAB/APK signing key before uploading to Play Store

**Build numbers are now Codemagic-managed** — both platforms use `$BUILD_NUMBER` so they stay aligned across releases.

---

## Development Workflow

### Android Testing
1. `flutter build apk --release --dart-define=GOOGLE_PLACES_API_KEY_ANDROID=AIzaSyAY590kSYhhKKzu6VVlsA0xO_VcpdNE3DQ --dart-define=GOOGLE_PLACES_API_KEY_IOS=AIzaSyAY590kSYhhKKzu6VVlsA0xO_VcpdNE3DQ`
2. `adb install -r build/app/outputs/flutter-apk/app-release.apk`
3. `adb shell am force-stop com.sportsrostering.app`
4. Launch manually; `flutter logs` to monitor

### iOS Release (Codemagic)
1. Bump `version` in `pubspec.yaml`
2. `git add`, `git commit`, `git push origin main`
3. Trigger Codemagic build manually → TestFlight

---

## Resolved Package Versions (as of Phase 0)

These versions were resolved by pub — do not tighten constraints without checking compatibility:

| Package | Resolved Version | Notes |
|---------|-----------------|-------|
| firebase_core | 4.6.0 | |
| firebase_auth | 6.3.0 | |
| cloud_firestore | 6.2.0 | |
| firebase_messaging | ^16.1.1 | ✅ Live — FCM token → Firestore, permission request, foreground/background handlers, spare deep-link routing |
| firebase_crashlytics | ^5.0.7 | ✅ Live — disabled in debug mode |
| firebase_storage | ^13.2.0 | ✅ Live — team logo upload via Cloud Function proxy |
| firebase_analytics | ^12.2.0 | ✅ Live — GoRouter observer, screen tracking |
| firebase_app_check | ^0.4.2 | ✅ Live — enforced on Cloud Functions |
| flutter_riverpod | 2.6.1 | |
| go_router | 17.1.0 | |
| google_mobile_ads | 5.3.1 | |

## iOS Setup Status

`GoogleService-Info.plist` ✅ in place (bundle ID: com.sportsrostering.app)
Android `google-services.json` ✅ in place (includes SHA-1 for Google Sign-In)
Debug SHA-1: `6F:04:08:95:C2:07:C5:AC:6C:AC:51:47:5D:83:16:D6:ED:1B:D5:8F`

**iOS AdMob app ID** — must be added to `ios/Runner/Info.plist` before any iOS build:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>
```
Android AdMob app ID is already in `AndroidManifest.xml` ✅ (test ID — swap before submission)

## Phase Status

| Phase | Feature | Status |
|-------|---------|--------|
| 0 | Project scaffold, pubspec, Firebase wiring | ✅ Done |
| 1 | Auth (Firebase email/password) | ✅ Done |
| 1 | Teams CRUD | ✅ Done |
| 1 | Events / Availability | ✅ Done |
| 1 | Rankings (admin-only) | ✅ Done |
| 1 | Manual lineup builder | ✅ Done |
| 1 | Drop-in sign-ups | ✅ Done |
| 1 | AdMob + Remove Ads IAP | ✅ Done |
| 2 | firebase_messaging + Crashlytics | ✅ Done |
| 2 | Push notifications (FCM token → Firestore, permission request) | ✅ Done |
| 2 | Auto-balanced drop-in teams | ✅ Done |
| 2 | Rewarded ads (gates auto-generate lineup + auto-balance boat seating) | ✅ Done |
| 3 | Player position preferences (per-team, flexible categories) | ✅ Done |
| 3 | Advanced lineup generator (ranking + preference matching) | ✅ Done |
| 3 | PDF/CSV export (lineup PDF, boat seating PDF, availability CSV) | ✅ Done |
| 4 | Multi-admin (co-coach) support | ✅ Done |
| 4 | Dragon Boating + boat balance seating screen | ✅ Done |
| 4 | Player weight field + kg/lbs toggle | ✅ Done |
| 4 | Team logo upload (Firebase Storage) | ✅ Done |
| 4 | Admin push notifications to team (Cloud Function) | ✅ Done |
| 4 | Foreground FCM display via flutter_local_notifications | ✅ Done |
| 4 | App icon (whistle), splash screen, app name "Sport Rosters" | ✅ Done |
| 4 | 21-sport roster with positions + preference categories | ✅ Done |
| 5 | Sub-teams (snake draft, goalie pre-assign, tab UI in lineup screen) | ✅ Done |
| 6 | Server-side IAP validation — iOS + Android enforced via Cloud Function | ✅ Done |
| 6 | Sign in with Apple (App Store requirement when Google Sign-In offered) | ✅ Done |
| 6 | Team logo upload secured via Cloud Function proxy (admin-verified) | ✅ Done |
| 6 | CircleAvatar radii scale with system text size (accessibility) | ✅ Done |
| 6 | Biometric authentication (Face ID / Touch ID / Fingerprint) | ✅ Done |
| 6 | Cloud Functions runtime upgraded to Node.js 22 | ✅ Done |
| 7 | Spares list (team-level standby players, admin notifies when roster short) | ✅ Done |
| 8 | Email verification gate (email/password accounts only) | ✅ Done |
| 8 | Firebase Analytics + GoRouter screen tracking | ✅ Done |
| 8 | Firebase App Check (Cloud Functions enforcement) | ✅ Done |
| 8 | Player attendance history screen | ✅ Done |
| 8 | Change password (email/password accounts, Profile screen) | ✅ Done |
| 8 | Accessibility screen (in-app + website) | ✅ Done |
| 9 | GDPR/PIPEDA data export (`exportUserData` Cloud Function + Profile screen UI) | ✅ Done |
| 9 | Recurring events (weekly/biweekly, batch-created with shared recurrenceGroupId) | ✅ Done |
| 9 | Game results (admin logs score + opponent after a game; shown on event detail) | ✅ Done |
| 9 | Team announcements feed (coach posts, all members read, pin support) | ✅ Done |
| 10 | Event cancellation UX (soft-cancel with orange banner; single or whole series) | ✅ Done |
| 10 | Announce + notify in one step (optional push toggle when posting) | ✅ Done |
| 10 | Recurring series date shift (delta applied to all events; reminder flags cleared) | ✅ Done |
| 10 | Spare self-removal (player leaves spares pool from team detail screen) | ✅ Done |
| 11 | Player lineup position card on event detail screen | ✅ Done |
| 11 | Notification preferences per event type (game/practice/drop-in) in Profile | ✅ Done |
| 11 | Event capacity hard-cap (maxPlayers enforced; EventFullException shown to player) | ✅ Done |
| 11 | Team hide/unhide (eye toggle in AppBar; hidden teams collapsed in Teams list) | ✅ Done |
| 11 | Team archive/restore (admin ⋮ menu; archived teams hidden but not deleted) | ✅ Done |
| 11 | Sports in Firestore (Sport model, SportRepository, sportsProvider with AppConfig fallback) | ✅ Done |
| 11 | Sports admin screen (/admin/sports) for system admins | ✅ Done |
| 11 | LineupGenerator decoupled from AppConfig (sportCategories passed as parameter) | ✅ Done |
| 11 | QR code team join via MobileScanner in Join Team dialog | ✅ Done |
| 11 | AppBar consolidated (team detail: 10+ icons → Events + QR + ⋮ overflow) | ✅ Done |
| 11 | R8 minification enabled (isMinifyEnabled + isShrinkResources + proguard-rules.pro) | ✅ Done |
| 11 | dSYM upload to Crashlytics in Codemagic post-build step | ✅ Done |
| 11 | Help screen fully updated to reflect all current features | ✅ Done |
| 12 | Sport-specific default team icons (SVG, bundled assets, 23 sports) | ✅ Done |
| 12 | deleteTeam Cloud Function (full cascade delete, admin-only) | ✅ Done |
| 12 | eventTypePrefs respected in sendEventReminders Cloud Function | ✅ Done |
| 12 | mutedTeams respected in sendTeamNotification Cloud Function | ✅ Done |
| 13 | Weekly stats email (Cloud Function, every Monday 8am Toronto, Gmail/nodemailer) | ✅ Done |
| 13 | App Stats admin screen (/admin/stats) — tappable cards: users, teams, events (30d) | ✅ Done |
| 13 | getAppStats Cloud Function (systemAdmin-only callable, returns counts + detail lists) | ✅ Done |
| 13 | firebase-functions SDK upgraded 4.9.0 → 7.2.5 | ✅ Done |
| 14 | Flutter Web version — platform guards, landing page, Firebase Hosting | ✅ Done |
| 14 | Google Sign-In on web (signInWithPopup replaces google_sign_in deprecated signIn) | ✅ Done |
| 14 | Apple Sign-In on web (sign_in_with_apple redirect flow, Services ID: com.sportsrostering.app.signin) | ✅ Done |
| 14 | Stripe "Remove Ads" for web — createStripeCheckout + stripeWebhook Cloud Functions | ✅ Done |
| 14 | Rewarded ad gate on web → Stripe checkout (auto-lineup, auto-balance) | ✅ Done |
| 14 | AdSense banner live (publisher: ca-pub-5119215558360251, slot: 8822412340, HtmlElementView) | ✅ Done |
| 14 | Firebase App Check reCAPTCHA v3 on web (site key: 6LdnoBItAAAAABeaZ5ouFtb4SouLyjZ_lWw__CP8) | ✅ Done |
| 14 | Firebase Analytics GA4 measurement ID G-QCX3G9KSPC added to firebase_options.dart web block | ✅ Done |
| 14 | Marketing landing page at `/` (hero, features grid, App Store/Play Store badges) | ✅ Done |
| 14 | Web favicon + PWA icons updated to app whistle icon | ✅ Done |
| 14 | Google + Apple Sign-In added to register screen (matches login screen) | ✅ Done |
| 14 | Stripe price ID price_1TftI8Lc7EXpUmQL7nnnZlIy configured in functions/index.js | ✅ Done |
| 14 | share_plus upgraded ^12 → ^13 (API fix — code already used v13 API); package_info_plus ^9 → ^10 | ✅ Done |

## Current Production Versions

| Platform | Version | Build | Status |
|----------|---------|-------|--------|
| Android (Play Store) | 1.3.0 | 46 | Live |
| iOS (App Store) | 1.3.0 | 46 | Live |
| Web (Firebase Hosting) | 1.3.0 | — | Live at https://sports-rostering.web.app |

## Web Build & Deploy

```bash
# Build (must use --output to bypass Windows junction issue with flutter_assets deletion)
flutter build web --release --output C:\BuildTemp\web-output --dart-define=GOOGLE_PLACES_API_KEY_ANDROID=AIzaSyAY590kSYhhKKzu6VVlsA0xO_VcpdNE3DQ --dart-define=GOOGLE_PLACES_API_KEY_IOS=AIzaSyAY590kSYhhKKzu6VVlsA0xO_VcpdNE3DQ

# Local test
cd C:\BuildTemp\web-output && python -m http.server 8080

# Deploy (firebase.json public: "C:\\BuildTemp\\web-output" — junction not traversable by Firebase CLI)
firebase deploy --only hosting
```

Note: `flutter run -d chrome` fails due to junction — use `flutter build web --output` + local HTTP server for web development.

## Store URLs

| Page | URL |
|------|-----|
| Web App | https://sports-rostering.web.app |
| Privacy Policy (Android) | https://moore99.github.io/sport-rosters/privacy |
| Privacy Policy (iOS) | https://nuclear-motd.com/privacy (combined policy, still live) |
| Terms of Service | https://moore99.github.io/sport-rosters/terms |
| Delete Account | https://moore99.github.io/sport-rosters/delete-account |

**Note:** Android pages are served from GitHub Pages (`docs/` folder, `moore99/sport-rosters` repo). iOS uses the nuclear-motd.com combined privacy policy. The nuclear-motd.com/sports-rostering/* paths are dead (lost in Docker migration — do not use).

---

## Known Issues / Blockers

### Android IAP Validation — ✅ Resolved (2026-04-02)
- `validateIap` Cloud Function fully enforced on both iOS and Android
- Service account `play-iap-validator@sports-rostering.iam.gserviceaccount.com` granted Financial data + Manage orders in Play Console → Users and permissions
- `ANDROID_VALIDATION_ENABLED = true` in `functions/index.js`
- Note: "Setup → API access" no longer exists in Play Console UI — service accounts are now invited via Users and permissions like regular users
- **Secrets already set:** `APPLE_IAP_SHARED_SECRET` ✅, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` ✅

### Google Sign-In — ✅ Resolved (1.0.4 build 8)
- `google-services.json` updated with all 3 fingerprints (debug SHA-1, release SHA-1, Play App Signing SHA-256)
- Google Sign-In working on Play Store installs as of 1.0.4 (8)
- iOS Google Sign-In fix (missing `CFBundleURLTypes` URL scheme) applied in 1.0.3 ✅

### Android minSdk
- Set to `maxOf(flutter.minSdkVersion, 23)` in `android/app/build.gradle.kts`
- Required by `local_auth` (biometrics). Flutter default is 21; biometrics need API 23+.
- A linter/Flutter Gradle plugin upgrade may revert this to `flutter.minSdkVersion` — if builds break, check this line first.

### Google Places Autocomplete — API Key
- **Single key used for both platforms** — set to "No application restrictions" in Google Cloud Console (API restriction: Places API only)
- Both SHA-1s registered in Cloud Console: debug `6F:04:08:95:C2:07:C5:AC:6C:AC:51:47:5D:83:16:D6:ED:1B:D5:8F`, release `1F:0B:6E:08:1D:5F:DB:85:0F:2B:23:48:76:99:A6:BD:77:8F:BE:40`
- **Important**: `google_places_flutter` makes REST HTTP calls from the device — Android app restrictions block it. Key must be set to "None" for app restrictions, restricted by API only.
- Keys injected at build time via `--dart-define=GOOGLE_PLACES_API_KEY_ANDROID=...` and `--dart-define=GOOGLE_PLACES_API_KEY_IOS=...`
- Codemagic: set both `GOOGLE_PLACES_API_KEY_ANDROID` and `GOOGLE_PLACES_API_KEY_IOS` in Keys group
- The location field falls back gracefully to plain text if Places is unavailable (e.g. local `flutter run` without `--dart-define`)

---

## Troubleshooting

### Build Issues

| Issue | Solution |
|-------|----------|
| `flutter clean` fails on OneDrive | Safe to ignore — file locking issue. Delete `C:\BuildTemp\sports-rostering` manually if needed |
| APK not found after build | Check `C:\BuildTemp\sports-rostering\app\outputs\flutter-apk\` (Windows junction path) |
| AAB build says "failed" but file exists | Ignore — Flutter reports this falsely due to build junction. File is at `C:\BuildTemp\sports-rostering\app\outputs\bundle\release\app-release.aab` |
| iOS build fails with SIGABRT | Check `Info.plist` — `UISceneDelegateClassName` must be `$(PRODUCT_MODULE_NAME).SceneDelegate`, NOT `AppDelegate` |
| Biometrics fail on Android | Check `android/app/build.gradle.kts` — `minSdk` must be ≥23 |

### Runtime Issues

| Issue | Solution |
|-------|----------|
| Rankings visible to players | Check Firestore rules — ensure `request.auth.token.teamAdmin == true` before allowing read |
| Stream providers stay in error after sign-out | Ensure providers watch `currentUserProvider` — see Firestore Security Rules section |
| AdMob not showing | Verify app ID in `AndroidManifest.xml` (Android) / `Info.plist` (iOS) matches AdMob console |
| IAP restore not working | Check network — Apple requires active connection for restore requests |
| Places API "invalid key" or "not authorized" | Key must have "No application restrictions" (not Android app) — `google_places_flutter` uses REST, not Android SDK. Restrict by API only (Places API). |
| R8 minification issues | `proguard-rules.pro` in `android/app/`. Crashlytics Gradle plugin auto-uploads mapping. If classes missing at runtime, add `-keep` rules to proguard-rules.pro |
