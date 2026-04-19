# Spares

## What It Does
Maintains a team-level standby pool of players who are available to fill in when the roster is short. Players can request to join the spares pool; admins approve or deny. When an event is under-attended, admins notify the spares pool via push notification.

## User-Facing Behaviour
| Action | Who |
|--------|-----|
| Request to join spares pool | Any signed-in user (team member or not) |
| Approve / deny spare request | Team admin |
| Remove a spare from the pool | Team admin |
| Leave the spares pool | Spare (themselves) |
| Add a player directly to spares pool (no request) | Team admin |
| Notify spares pool for an upcoming event | Team admin |
| Respond to spare callout (I'm available / Not available) | Spare |

## Data Model

### `teams/{teamId}/spares/{userId}`
| Field | Type | Notes |
|-------|------|-------|
| `userId` | String | Doc ID |
| `teamId` | String | |
| `joinedAt` | Timestamp | Used for rotation ordering (FIFO) |

### `teams/{teamId}/spareRequests/{userId}`
| Field | Type | Notes |
|-------|------|-------|
| `userId` | String | Doc ID |
| `teamId` | String | |
| `userName` | String | Captured at request time |
| `userEmail` | String | |
| `requestedAt` | Timestamp | |

## Firestore Rules
- Admins read and write the `spares` subcollection.
- Players can create a `spareRequest` for themselves (own UID as doc ID). Players can read or delete their own pending request. Admins manage all requests (approve = delete request + create spare doc; deny = delete request).
- Spares are readable by team admins only (not visible to other roster players).

## Business Logic

### Spare Request Flow
1. Player submits request → `spareRequests/{uid}` doc created.
2. Admin reviews pending requests list.
3. Approve: atomically creates `spares/{uid}` and deletes `spareRequests/{uid}`.
4. Deny: deletes `spareRequests/{uid}` only.

### Spare Callout
Admin triggers from the spares screen for a specific event:
1. Selects a `batchSize` (how many spares to notify — in rotation order by `joinedAt`).
2. Calls `notifySpares` Cloud Function.
3. Spares receive FCM: "You've been called as a spare for [Event] at [time]. Are you available?"

### Spare Response
When a spare taps the notification or responds in-app:
- "Yes" → calls `spareResponds` Cloud Function: sets their availability to 'yes' on the event (idempotent; won't double-add if already set). Does not automatically add them to the roster.
- "No" → no action (or sets availability to 'no' if they respond in-app).

## Cloud Functions
- **`notifySpares`** (callable, admin-only) — params: `{ eventId, teamId, teamName, eventDate, batchSize }`. Fetches the first `batchSize` spares ordered by `joinedAt`, sends FCM to those with valid tokens. Returns `{ sent: N }`.
- **`spareResponds`** (callable) — params: `{ eventId, teamId, userId, isAvailable, maxPlayers }`. Atomically sets availability for the event. If `isAvailable = true` and signups are under capacity, also adds to `dropInSessions.signups` if drop-in is enabled.
- **`notifyWaitlistPromotion`** — tangentially related (promotes drop-in waitlist player). See `dropins.md`.

## Key Decisions
- **Spares are ordered by `joinedAt`** (FIFO). This gives a fair rotation — the spare who has been waiting longest gets called first. The admin can choose `batchSize` to notify more than one at a time.
- **Players can leave the spares pool themselves** via a "Leave" button on the team detail screen (shown when `isAlreadySpare && !isAdmin`). Uses `SparesRepository.leaveSpares()` — a single-doc delete. Firestore rule: `spares/{userId}` delete allows `isSelf(userId)`. After leaving, the spare request button reappears automatically via the live stream.
- **Spare approval is atomic** (batch write: create spare + delete request). This prevents a state where the request is deleted but the spare doc wasn't created, or vice versa.
- **Spare pool is separate from the roster**. Approving a spare request does not add the player to `teams.players`. The admin separately decides to add them to the full roster if they play regularly.
- **Responding "yes" sets availability, not roster membership**. The admin still controls who is in the lineup. This avoids automatic roster changes that the admin hasn't reviewed.

## Future / Deferred
- **Spare rotation tracking** — currently, order is by `joinedAt` (when they joined the pool). A proper rotation would track how many times each spare has been called and rotate by least-recently-called. Requires a `lastCalledAt` field.
- **Spare history** — no record of which events a spare was called for or attended. Useful for fairness auditing.
- **Automatic spare promotion to roster** — if a spare attends X events, an admin could be prompted to add them to the full roster. Not implemented.
- **Global spares pool** — spares are per-team. A city-wide or league-wide pool where admins across teams can call on each other's spares was considered but not built.
