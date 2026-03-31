# CLAUDE.md — Sports Rostering App

Read this file first. Reflects the actual current state, not the original spec.

---

## Running the Application

```bash
flutter run --dart-define=GOOGLE_PLACES_API_KEY=AIzaSyAY590kSYhhKKzu6VVlsA0xO_VcpdNE3DQ
flutter pub get   # After modifying pubspec.yaml
flutter clean     # Often fails on OneDrive repos due to file locking — safe to ignore
flutter doctor
```

**Build APK for Android:**
```bash
flutter build apk --release --dart-define=GOOGLE_PLACES_API_KEY=AIzaSyAY590kSYhhKKzu6VVlsA0xO_VcpdNE3DQ
```

**Build AAB for Play Store:**
```bash
flutter build appbundle --release --dart-define=GOOGLE_PLACES_API_KEY=AIzaSyAY590kSYhhKKzu6VVlsA0xO_VcpdNE3DQ
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

```bash
flutter test
flutter analyze   # Lint + static analysis
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
- **Firebase** — Auth, Firestore, Messaging, Crashlytics, Storage
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
│       └── notification_service.dart # FCM + app badge
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

**ALWAYS bump version before building for release** — both for Play Store and TestFlight.

- Format: `major.minor.patch+build` (e.g., `1.0.1+4`)
- **Play Store**: Requires a new `versionCode` (build number) for each upload
- **TestFlight**: Requires a new build number for each upload

**Before any release build:**
1. Check current version in `pubspec.yaml`
2. Increment the build number (+1 from previous)
3. Commit before building
4. Verify AAB/APK signing key before uploading to Play Store

---

## Development Workflow

### Android Testing
1. `flutter build apk --release --dart-define=GOOGLE_PLACES_API_KEY=AIzaSyAY590kSYhhKKzu6VVlsA0xO_VcpdNE3DQ`
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
| firebase_messaging | deferred | Conflicts with auth at current versions — add Phase 2 |
| firebase_crashlytics | deferred | Add Phase 2 alongside messaging |
| firebase_storage | deferred | Add Phase 2 for profile photos |
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
| 6 | Server-side IAP validation — iOS enforced, Android deferred (Play Console API access blocked) | ⚠️ Partial |
| 6 | Sign in with Apple (App Store requirement when Google Sign-In offered) | ✅ Done |
| 6 | Team logo upload secured via Cloud Function proxy (admin-verified) | ✅ Done |
| 6 | CircleAvatar radii scale with system text size (accessibility) | ✅ Done |
| 6 | Biometric authentication (Face ID / Touch ID / Fingerprint) | ✅ Done |
| 6 | Cloud Functions runtime upgraded to Node.js 22 | ✅ Done |
| 7 | Spares list (team-level standby players, admin notifies when roster short) | ✅ Done |

## Known Issues / Blockers

### Android IAP Validation — Play Console API Access Blocked
- `validateIap` Cloud Function deployed ✅ — iOS validation fully enforced ✅
- Android validation currently **fails open** (grants entitlement without server verification)
- Root cause: `Setup → API access` not visible in Play Console despite being account owner
- `ANDROID_VALIDATION_ENABLED = false` in `functions/index.js` — flip to `true` once fixed
- **To fix (try in order):**
  1. Enable **Google Play Android Developer API** in Google Cloud Console → APIs & Services → Library
  2. Try direct URL: `https://play.google.com/console/u/1/developers/6842817044785591935/setup/api-access`
  3. Try logging in as `u/0` (primary Google account) — `u/1` accounts sometimes have restricted access
  4. Contact Google Play developer support if none of the above work
- **Risk while deferred:** Low — requires rooted device + App Check bypass to exploit. One-time low-price IAP makes fraud economically unattractive.
- **Secrets already set:** `APPLE_IAP_SHARED_SECRET` ✅, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` ✅

### Android minSdk
- Set to `maxOf(flutter.minSdkVersion, 23)` in `android/app/build.gradle.kts`
- Required by `local_auth` (biometrics). Flutter default is 21; biometrics need API 23+.
- A linter/Flutter Gradle plugin upgrade may revert this to `flutter.minSdkVersion` — if builds break, check this line first.

### Google Places Autocomplete — API Key
- Key is injected at build time via `--dart-define=GOOGLE_PLACES_API_KEY=...` (no longer hardcoded in source)
- Codemagic injects it from the `Keys` environment group (`GOOGLE_PLACES_API_KEY`)
- Key is restricted in Google Cloud Console to Android app (`com.sportsrostering.app`) + Places API only
- SHA-1 registered in Cloud Console: `6F:04:08:95:C2:07:C5:AC:6C:AC:51:47:5D:83:16:D6:ED:1B:D5:8F`
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
