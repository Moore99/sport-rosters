# Player Profiles

## What It Does
Each user has a profile with their display name, optional contact details, optional weight (for Dragon Boating), and a profile photo. Players can view their own attendance history per team. Admins can view any member's profile and attendance history.

## User-Facing Behaviour
| Action | Who |
|--------|-----|
| View and edit own name | Any user |
| Upload / change profile photo | Any user |
| Set weight (kg or lbs toggle) | Any user |
| Set optional phone number | Any user |
| View own attendance history per team | Any user |
| View another member's profile | Team admin |
| View another member's attendance history | Team admin |
| Toggle push notifications on/off | Any user |
| Change password | Email/password users |

## Data Model
Stored in `users/{userId}`. See `auth.md` for the full field list.

Key profile-specific fields:
| Field | Type | Notes |
|-------|------|-------|
| `name` | String | Editable; used throughout the app for display |
| `photoUrl` | String? | Firebase Storage URL |
| `phone` | String? | Optional; not used for auth |
| `weightKg` | double? | Stored in kg; displayed in kg or lbs based on user preference |

### Position Preferences
Stored in `teams/{teamId}/playerPreferences/{userId}`. Per-team, not on the user doc. See `lineups.md`.

## Attendance History
Derived on-demand from the `availability` collection group. The attendance history screen queries:
```
collectionGroup('availability')
  .where('userId', '==', uid)
  .where('teamId', '==', teamId)
  .orderBy('updatedAt', 'desc')
```
Returns all RSVP records for the player on that team. "Attended" is approximated by `response == 'yes'`; there is no check-in mechanism.

## Photo Upload
1. Player selects photo from camera or gallery (`image_picker`).
2. Photo is cropped (`image_cropper` / UCrop on Android).
3. Upload to Firebase Storage at `profile_photos/{userId}.jpg` via `UserRepository.uploadProfilePhoto()` — this is a **direct client upload** (not proxied through a Cloud Function, unlike team logos).
4. Download URL saved to `users/{uid}.photoUrl`.

**Android 15 edge-to-edge note**: UCrop activity bottom toolbar was covered by the nav bar on Android 15 (API 35). Fixed by `values-v35/styles.xml` with `android:windowOptOutEdgeToEdgeEnforcement="true"` applied to `UCropTheme`.

## Weight Unit Toggle
`weightKg` is stored in kg. The UI shows a kg/lbs toggle. Conversion is display-only — the stored value is always kg. The toggle preference is stored in `SharedPreferences` (device-local, not in Firestore).

## Firestore Rules
- Any signed-in user can read any user profile (needed for name resolution across the app).
- Users update their own profile only.
- Team admins can update the `teams` field on other user docs (join/remove flow).

## Key Decisions
- **Profile photos are client-uploaded directly to Firebase Storage**, unlike team logos (which go through a Cloud Function proxy). The rationale: profile photos are user-owned and the storage path is scoped to the user's UID, so Firestore/Storage rules are sufficient to prevent unauthorized overwrites (`profile_photos/{userId}.jpg`). Team logos need admin verification before write, which requires server-side auth.
- **Weight stored in kg always** — avoids the dual-write problem (updating both kg and lbs fields if the user changes units). The lbs preference is purely a display setting.
- **`phone` is optional and not used for auth** — collected only on explicit user action. Not shown unless the user has set it. Covered by GDPR/PIPEDA data minimization.
- **Attendance is derived, not stored** — no dedicated attendance collection. This is correct for current scale; for reporting or aggregations (e.g., "attendance rate this season"), a roll-up Cloud Function would be needed.

## Future / Deferred
- **Attendance check-in (vs RSVP)** — current "attendance" is actually RSVP = 'yes'. There is no mechanism to confirm a player actually showed up. A QR code check-in at the event would close this gap.
- **Attendance rate aggregations** — season-level stats (attended X of Y games) are not computed. Client-side calculation from the full availability history would be slow for active users.
- **Profile visibility controls** — any signed-in user can read any profile. For privacy, a player might want to hide their phone/weight from other players (but not admins). Not implemented.
- **Avatar cropping UX improvements** — UCrop (image_cropper) works but is an older library. Alternatives (`croppy`, `pro_image_editor`) offer better UI but require migration.
- **Social features** — no player-to-player messaging, friend lists, or team-level social graph. Out of scope for a roster tool.
