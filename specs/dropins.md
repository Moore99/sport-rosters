# Drop-in Sessions

## What It Does
Allows non-roster players (and roster members) to sign up for individual events without being permanently on the team. Supports a waitlist when the session is full. Admins can auto-generate balanced teams from the signup list. Waitlisted players are notified when a spot opens.

## User-Facing Behaviour
| Action | Who |
|--------|-----|
| Sign up for a drop-in session | Any signed-in user (team member or not) |
| Join the waitlist (when full) | Any signed-in user |
| Withdraw from session or waitlist | Signed-up player |
| View signups and waitlist | Any signed-in user |
| Auto-generate balanced teams from signups (rewarded ad gates this) | Team admin |
| Notify spares when roster is short | Team admin (via spares screen) |

Drop-in is only available on events where the parent team has `dropInEnabled = true` and the event type is `'dropIn'`.

## Data Model

### `dropInSessions/{sessionId}` (doc ID = eventId)
| Field | Type | Notes |
|-------|------|-------|
| `sessionId` | String | = eventId |
| `eventId` | String | |
| `teamId` | String | |
| `signups` | List\<String\> | Confirmed player UIDs |
| `waitlist` | List\<String\> | Ordered queue; first element is next to be promoted |
| `generatedTeams` | List\<List\<String\>\> | Balanced team assignments (list of UID lists, one per team) |
| `createdAt` | Timestamp | |

## Firestore Rules
- Any signed-in user can **read** drop-in sessions.
- Team admins create and fully manage sessions.
- Players may only toggle their own UID in `signups` or `waitlist` arrays — they cannot modify `generatedTeams` or other players' entries.
- **Null resource guard required**: the doc may not exist before the first signup. Rule allows creation with the player's own UID as the only signup.
- The first player to sign up may create the session document if the admin hasn't pre-created it.

## Business Logic

### Signup
1. If `signups.length < event.maxPlayers`: add UID to `signups` via `FieldValue.arrayUnion`.
2. If full: add UID to `waitlist` via `FieldValue.arrayUnion`.

### Withdrawal
Handled via Firestore transaction (atomic):
1. Remove UID from `signups` or `waitlist`.
2. If removed from `signups` and `waitlist` is non-empty: remove the first waitlist UID and add it to `signups`.
3. Trigger `notifyWaitlistPromotion` Cloud Function for the promoted player.

### Auto-Generate Balanced Teams
- Takes the confirmed `signups` list.
- Balances using player `weightKg` values (Dragon Boating) or rankings (other sports) if available; falls back to random shuffle.
- Splits into N teams; stores result in `generatedTeams`.
- Rewarded ad gate: admin must watch ad before result is committed (bypassed if `adFree = true`).

## Cloud Functions
- **`notifyWaitlistPromotion`** (callable) — sends FCM to the newly promoted player: "Good news — a spot opened up for [Event]."
- **`notifySpares`** (callable, admin-only) — see `spares.md`. Separate from drop-in waitlist but used in conjunction when the roster is short.

## Key Decisions
- **Doc ID = eventId** — one session per event. Clean join between event and session data without a query.
- **Waitlist is an ordered array**, not a subcollection. First element = next in queue. This works at the scale of typical sports teams (< 100 signups); would need rethinking at large scale.
- **Withdrawal is a transaction**, not two separate array operations, to prevent race conditions where two players withdraw simultaneously and both promote the same waitlist member.
- **Any signed-in user can sign up**, not just team members. This is intentional — drop-in is designed for open sessions where non-roster players participate. The team admin controls capacity via `maxPlayers`.
- **`generatedTeams` is stored on the session doc** (not a separate collection) because it is transient — re-generating overwrites it, and it's only meaningful in the context of that session.

## Future / Deferred
- **Drop-in player profiles** — non-roster drop-in players have a full `users/` doc but no team membership. There's no way for an admin to see a drop-in player's history across sessions.
- **Session fee / payment tracking** — no payment collection for drop-in fees. Common in recreational leagues; would require Stripe or similar integration.
- **Recurring drop-in** — drop-in sessions are per-event. If a team runs weekly open sessions, the admin must sign up each week manually.
- **Public drop-in discovery** — sessions are only visible to users who have the team ID. A public-facing discovery page was not built.
- **Weight/ranking fallback in balancing** — if players have no weight or ranking data, the generator falls back to random shuffle. A more principled fallback (e.g., historical attendance balance) was not implemented.
