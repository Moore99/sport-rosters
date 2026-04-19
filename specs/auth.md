# Auth

## What It Does
Handles user identity: registration, login, session management, and access gates. Supports three sign-in methods. Enforces email verification for email/password accounts. Offers biometric re-authentication as an in-app lock.

## User-Facing Behaviour
| Action | Who |
|--------|-----|
| Register with email + password | Anyone |
| Sign in with Google | Anyone |
| Sign in with Apple | Anyone (required on iOS when Google is offered) |
| Forgot password (email reset) | Email/password users |
| Email verification gate | Email/password users — must verify before accessing the app |
| Biometric lock (Face ID / Touch ID / Fingerprint) | Any signed-in user, opt-in |
| Change password | Email/password users, from Profile screen |
| Sign out | Any signed-in user |

## Data Model
**Firebase Auth** holds credentials. `users/{userId}` holds app data.

| Field | Type | Notes |
|-------|------|-------|
| `name` | String | Display name |
| `email` | String | |
| `phone` | String? | Optional; explicit consent |
| `photoUrl` | String? | Optional; explicit consent |
| `fcmToken` | String? | Set on login, cleared on sign-out |
| `role` | String | `'player'` \| `'teamAdmin'` \| `'systemAdmin'` |
| `adFree` | bool | IAP entitlement |
| `deleted` | bool | Soft-delete flag for GDPR cascade |
| `createdAt` | Timestamp | |
| `notificationsEnabled` | bool | User-level FCM opt-out |
| `mutedTeams` | List\<String\> | Team IDs where notifications muted |
| `weightKg` | double? | Dragon boat balance; player-editable |

## Firestore Rules
- Any signed-in user can **read** any profile (needed for name resolution in rosters/drop-in lists).
- Users can **update** their own profile.
- Team admins can update only the `teams` field on other users (join/remove operations).
- Users can **delete** their own profile, or system admin can delete any.
- Deletion cascade handled by `deleteAccount` Cloud Function — Firestore rule itself just allows the delete.

## Cloud Functions
- **`deleteAccount`** — callable, auth-gated. Full GDPR/PIPEDA cascade: deletes availability, rankings, playerPreferences, removes from dropInSessions/lineups/team arrays, deletes `users/{uid}` doc, then deletes Firebase Auth account. See `compliance.md`.

## Key Decisions
- Firebase Auth handles credentials; Firestore holds app data. Never duplicate auth state into Firestore (e.g., no `isLoggedIn` field).
- FCM token is cleared on sign-out so stale tokens don't deliver notifications to the wrong user on shared devices.
- Email/password accounts require email verification before accessing the main app. Google and Apple accounts are pre-verified.
- Biometric lock is app-level (local_auth), not server-enforced. It re-prompts on cold launch when enabled. It does not affect Firestore access — it's a UX gate only.
- Google Sign-In uses a singleton instance with an explicit iOS `clientId` — never instantiate per call (causes iOS auth failures).
- Sign in with Apple is required on iOS whenever Google Sign-In is offered (App Store rule).
- `minSdk = 23` on Android (required by `local_auth` for biometrics; Flutter default is 21).

## Future / Deferred
- **Password reset email branding** — resets currently come from a Firebase default domain and land in Gmail spam. Requires a custom domain + Firebase email hosting. Deferred until app has enough uptake to justify a domain purchase.
- **Phone number auth** — field exists on the model (`phone`), collected with explicit consent, but not used as an auth method.
- **Magic link (email link) auth** — considered, not implemented.
- **Session expiry / forced re-auth** — currently no server-enforced session timeout beyond Firebase's defaults.
