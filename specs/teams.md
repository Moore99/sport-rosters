# Teams & Roster Management

## What It Does
Allows users to create teams, join via Team ID or QR code, manage the roster (approve/deny join requests, promote admins, remove players), and configure team settings. Multi-admin (co-coach) support is built in.

## User-Facing Behaviour
| Action | Who |
|--------|-----|
| Create a team | Any signed-in user (becomes first admin) |
| Join via Team ID | Any signed-in user |
| Join via QR code scan | Any signed-in user |
| Approve / deny join requests | Team admin |
| Promote player to admin | Team admin |
| Remove player from team | Team admin |
| Leave team | Player |
| Edit team settings (name, sport, timezone, player limits, drop-in toggle) | Team admin |
| Upload team logo | Team admin |
| View team roster | Team member |
| Set own admin participation role | Team admin (for themselves only) |

## Data Model

### `teams/{teamId}`
| Field | Type | Notes |
|-------|------|-------|
| `name` | String | |
| `sport` | String | Must be in `AppConfig.defaultSports` |
| `timezone` | String | IANA ID, default `'America/Toronto'` |
| `admins` | List\<String\> | UIDs; first element is creator |
| `players` | List\<String\> | UIDs of non-admin members |
| `minPlayers` | int | Roster minimum (1–maxPlayers) |
| `maxPlayers` | int | Roster maximum (minPlayers–200) |
| `dropInEnabled` | bool | Enables drop-in events for this team |
| `logoUrl` | String? | Firebase Storage download URL |
| `createdAt` | Timestamp | |

### `teams/{teamId}/joinRequests/{userId}`
| Field | Type | Notes |
|-------|------|-------|
| `userId` | String | Doc ID |
| `userName` | String | Captured at request time |
| `userEmail` | String | |
| `status` | String | `'pending'` \| `'approved'` \| `'denied'` |
| `createdAt` | Timestamp | |

Approval is atomic: adds player to `teams.players` + adds `teamId` to `users/{userId}.teams`. Idempotent if the player re-requests.

### `teams/{teamId}/adminRoles/{adminUid}`
| Field | Type | Notes |
|-------|------|-------|
| `participates` | String | `'player'` \| `'coachOnly'` \| `'sometimes'` |

Set by the admin for themselves. Affects lineup inclusion and notification copy. See `lineups.md` and `notifications.md`.

## Firestore Rules
- Any signed-in user can **read** teams (needed for join flow, team selection screens).
- Team admins can **create/update/delete** teams.
- Player roster changes (adding/removing `players` or `teams` arrays) are strictly scoped.
- `joinRequests`: any signed-in user can create their own; admins update/delete; rule handles null resource (doc may not exist before first request).
- `adminRoles`: team members read; admin writes own role only.

## Cloud Functions
- **`uploadTeamLogo`** — callable, `enforceAppCheck: false` (Play Integrity fails on sideloaded APKs). Auth verified via `request.auth.uid`. Caller must be team admin. Accepts base64 JPEG, writes to `team_logos/{teamId}.jpg` via Admin SDK, returns a Firebase download URL using `firebaseStorageDownloadTokens` metadata (avoids `makePublic()` which fails under Uniform Bucket-Level Access Control). Persists `logoUrl` to Firestore.
- **`previewTeam`** — callable, no auth required. Returns `{name, sport}` for a given `teamId`. Used in the join flow so prospective members can verify a team before creating an account.

## Key Decisions
- `admins` and `players` are **separate arrays** (not a single `members` array with a role field). This simplifies Firestore rule checks (`isTeamAdmin` = `admins.hasAny([uid])`) and avoids map-in-array update complexity.
- Team logo upload goes through a Cloud Function proxy — Storage rules deny all direct client writes to `team_logos/`. This prevents any non-admin from overwriting a team logo.
- `timezone` is stored on the team, not derived from the device, so Cloud Functions can format reminder times correctly regardless of where the scheduler runs.
- QR code encodes the full custom URI (`sportsrostering://join/{teamId}`). When the phone camera opens the app via this scheme, GoRouter strips the scheme prefix in a top-level `redirect` and routes to `/join/:teamId`. In-app scanner parses both the full URI and a bare team ID. A `_loading` guard prevents `MobileScanner.onDetect` (which fires continuously) from submitting multiple concurrent join requests before the widget can rebuild.
- Admin participation role (`adminRoles` subcollection) is set per admin at team-creation time via a dialog, and can be changed later from the team settings screen.

## Future / Deferred
- **Email invites** — originally planned (AWS SES), deferred until a custom server exists. Currently share the raw Team ID or QR code.
- **Transfer ownership** — no mechanism to transfer the creator role. Workaround: promote the new owner to admin, remove yourself.
- **Team archiving** — no soft-delete for teams. Deleting a team leaves orphaned events/lineups/rankings. Full cascade delete deferred.
- **Sports in Firestore** — sport list is hardcoded in `app_config.dart`. Phase 2+ plan was to move to a `sports/{sportId}` Firestore collection so system admins can add sports without an app update.
- **Roster import** — no bulk import (CSV/contacts). Players must join individually.
- **Team-level RSVP deadline default** — `rsvpDeadline` is set per event. A team-wide default would reduce admin friction.
