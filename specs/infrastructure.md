# Infrastructure & Configuration

## What It Does
Covers the shared foundation: tech stack, routing, sports configuration, feature flags, Firebase project setup, CI/CD, and cross-cutting concerns that don't belong to a single feature domain.

## Stack
| Layer | Technology |
|-------|-----------|
| UI | Flutter 3.x, Material 3 |
| State | Riverpod (`flutter_riverpod ^2.4.9`) |
| Navigation | GoRouter (`go_router ^17.1.0`) |
| Database | Cloud Firestore (northamerica-northeast2 / Toronto) |
| Auth | Firebase Auth |
| Push | Firebase Messaging (FCM) |
| Storage | Firebase Storage |
| Functions | Firebase Cloud Functions v2 (Node.js 22) |
| Crash reporting | Firebase Crashlytics (disabled in debug) |
| Analytics | Firebase Analytics + GoRouter observer |
| Security | Firebase App Check (Cloud Functions enforcement) |
| Ads | Google AdMob |
| IAP | `in_app_purchase` plugin + server-side validation |

## Route Structure
```
/login, /register, /forgot-password
/email-verify                     ← gate for unverified email/password users
/biometric-lock                   ← gate when biometric lock is enabled
/home
/teams
  /teams/:teamId
    /teams/:teamId/events/:eventId
      /.../lineup
      /.../dropin
      /.../boat-seating
    /teams/:teamId/rankings
    /teams/:teamId/preferences/:userId
    /teams/:teamId/spares
    /teams/:teamId/announcements
    /teams/:teamId/attendance/:userId
    /teams/:teamId/stats
/join/:teamId                     ← public QR/link join entry point
/profile
/admin                            ← system admin only
/privacy, /terms, /accessibility  ← legal screens
```

Auth redirect guards enforce:
- Unauthenticated users → `/login`
- Email/password users with unverified email → `/email-verify`
- Users with biometric lock enabled → `/biometric-lock` on cold launch

## Sports Configuration
23 sports hardcoded in `app_config.dart`. Each sport has:
- A flat position list
- Named position categories (for preference matching)

Sports: Ice Hockey, Soccer, Basketball, Dragon Boating, Baseball, Softball, Volleyball, Football, Rugby, Lacrosse, Field Hockey, Water Polo, Futsal, Ultimate Frisbee, Curling, Tennis, Badminton, Pickleball, Cricket, Ringette, Sledge Hockey, Wheelchair Basketball, Floorball.

## Feature Flags
All in `app_config.dart` as compile-time constants:
| Flag | Default | Controls |
|------|---------|---------|
| `enableAutoLineup` | `true` | Auto-generate lineup button visibility |
| `enableRewardedAds` | `true` | Rewarded ad gates for premium features |
| `enablePdfExport` | `true` | PDF/CSV export buttons |

## Firebase Project
- **Project ID**: `sports-rostering`
- **Region**: `northamerica-northeast1` (Cloud Functions), `northamerica-northeast2` (Firestore)
- **Bundle ID**: `com.sportsrostering.app`
- **App Check**: enforced on all Cloud Functions except `uploadTeamLogo` and `previewTeam`

## Android SHA Fingerprints (all registered in Firebase + `google-services.json`)
| Type | SHA-1 |
|------|-------|
| Debug keystore | `6F:04:08:95:C2:07:C5:AC:6C:AC:51:47:5D:83:16:D6:ED:1B:D5:8F` |
| Release keystore | `1F:0B:6E:08:1D:5F:DB:85:0F:2B:23:48:76:99:A6:BD:77:8F:BE:40` |
| Play App Signing | `84:DA:D2:9A:20:9E:22:2B:B4:4B:D5:ED:84:10:4D:E6:FD:95:D1:22` |

All three must be present in `google-services.json`. The Play App Signing SHA-1 is required for Google Sign-In to work on Play Store installs.

## CI/CD
- **Android**: built locally → APK or AAB → installed via ADB or uploaded to Play Console manually.
- **iOS**: built via Codemagic (cloud CI) → TestFlight → App Store. Triggered manually on push to `main`. After the IPA is built, a post-build step uploads all dSYMs to Crashlytics via `upload-symbols -gsp ios/Runner/GoogleService-Info.plist`. dSYM files are also saved as Codemagic artifacts.
- **Build output**: `build/` is a Windows junction → `C:\BuildTemp\sports-rostering` to avoid OneDrive file locking.
- **Version source of truth**: `version.txt` at repo root. `pubspec.yaml` stays in sync. Codemagic reads `version.txt` for `--build-name`; `$BUILD_NUMBER` env var sets the build number.

## Riverpod Patterns
- `StateNotifierProvider` for mutable state.
- `ref.read(provider.notifier).method()` for actions — never `ref.invalidate()` on StateNotifierProvider (timing issues).
- `ref.watch()` for reactive rebuilds; `ref.read()` for one-time reads.
- Stream providers **must** watch `currentUserProvider` so they restart on sign-out/sign-in. Without this, a stream in error state (permission-denied on sign-out) stays broken for the next user.
- `Future.microtask()` for side effects triggered inside `build()`.

## Firestore Rule Patterns
- `resource == null` guard always required when a doc may not exist before the first write.
- `teamId` is denormalized into subcollection docs so rules can call `isTeamMember(resource.data.teamId)` without a `get()` call.
- Coach-private data (rankings) uses explicit deny — no fallback to a lower-privilege read.

## Key Decisions
- **No custom backend server** — all data flows through Firebase SDKs directly from the client or via Cloud Functions. AWS SES (email invites) was deferred until a server exists.
- **`enforceAppCheck: false` on `uploadTeamLogo` and `previewTeam`** — Play Integrity rejects requests from sideloaded APKs, which includes development builds installed via ADB. Auth is still enforced on `uploadTeamLogo` via `request.auth.uid`.
- **`minSdk = 23` on Android** — required by `local_auth` (biometrics). Flutter's default is 21. A Gradle plugin upgrade may silently revert this; check `android/app/build.gradle.kts` if biometrics break on old Android versions.
- **iOS minimum deployment target: iOS 17.0** — set in `Podfile` and `project.pbxproj`. Required for Xcode 26 / iOS 26 SDK compatibility.
- **`SceneDelegate` fix is permanent** — `AppDelegate.swift` must include an explicit inlined `SceneDelegate` class. Do not set `UISceneDelegateClassName` to `AppDelegate` (causes SIGABRT).

## Future / Deferred
- **Web support** — Flutter web build exists but is not actively maintained or deployed. Some features (image upload, biometrics) have platform-specific implementations that may not work on web.
- **Sports in Firestore** — moving the hardcoded sports list to a `sports/{sportId}` Firestore collection would allow system admins to add sports without an app update. Planned for Phase 2+, not yet built.
- **Automated CI for Android** — currently Android builds are manual (local `flutter build appbundle`). Codemagic could build both platforms; not configured yet.
- **Crashlytics symbol upload (Android)** — ProGuard/R8 mapping file upload for Android is not configured. If minification is enabled, crash stack traces on Android may be unresolved.
- **Performance monitoring** — Firebase Performance Monitoring is not integrated. Response time and cold start metrics are not tracked.
- **Remote Config** — feature flags are compile-time constants. Firebase Remote Config would allow toggling flags without an app update.
