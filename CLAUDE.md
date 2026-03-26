# CLAUDE.md — Sports Rostering App

Read this file first. Reflects the actual current state, not the original spec.

---

## Running the Application

```bash
flutter run
flutter pub get   # After modifying pubspec.yaml
flutter clean     # Often fails on OneDrive repos due to file locking — safe to ignore
flutter doctor
```

**Build APK for Android:**
```bash
flutter build apk --release
```

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

## Testing

```bash
flutter test
flutter analyze   # Note: shows false-positive URI errors on Windows — pre-existing, non-blocking
```

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

---

## Development Workflow

### Android Testing
1. `flutter build apk --release`
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
| 2 | Rewarded ads | TODO |
| 3 | Player position preferences (per-team, flexible categories) | ✅ Done |
| 3 | Advanced lineup generator (ranking + preference matching) | ✅ Done |
| 3 | PDF/CSV export | TODO |
| 4 | Multi-admin (co-coach) support | ✅ Done |
| 4 | Dragon Boating + boat balance seating screen | ✅ Done |
| 4 | Player weight field + kg/lbs toggle | ✅ Done |
| 4 | Team logo upload (Firebase Storage) | ✅ Done |
| 4 | Admin push notifications to team (Cloud Function) | ✅ Done |
| 4 | Foreground FCM display via flutter_local_notifications | ✅ Done |
| 4 | App icon (whistle), splash screen, app name "Sport Rosters" | ✅ Done |
| 4 | 21-sport roster with positions + preference categories | ✅ Done |
| 5 | Sub-teams (snake draft, goalie pre-assign, tab UI in lineup screen) | ✅ Done |

## Known Issues / Blockers

### Google Places Autocomplete — API Key Invalid
- Key in `AppConfig.googlePlacesApiKey`: `AIzaSyAY590kSYhhKKzu6VVlsA0xO_VcpdNE3DQ`
- App reports "Invalid API key" at runtime
- **To fix**: Go to Google Cloud Console → APIs & Services → Credentials, find this key, and ensure **Places API** (not just Maps SDK) is enabled. Also verify the key has no HTTP referrer restrictions that would block Android/iOS app requests — use Android app restriction (package: `com.sportsrostering.app`) instead.
- The location field falls back gracefully to a plain text field if Places is unavailable.
