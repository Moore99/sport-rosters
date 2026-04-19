# Rankings (Coach-Private Assessments)

## What It Does
Allows team admins (coaches) to rate and annotate players privately. Rankings inform the auto-lineup generator. Players have no visibility into their own ranking or anyone else's. Privacy is enforced at both the Firestore rules layer and the UI layer.

## User-Facing Behaviour
| Action | Who |
|--------|-----|
| View all player rankings for a team | Team admin only |
| Set / update a player's score and notes | Team admin only |
| Use rankings in auto-lineup generation | Team admin only (implicit, via generator) |
| View own ranking | **No one** (not even the player) |

## Data Model

### `teams/{teamId}/rankings/{userId}`
| Field | Type | Notes |
|-------|------|-------|
| `userId` | String | Doc ID |
| `teamId` | String | |
| `score` | double | 0.0–10.0 |
| `notes` | String? | Private coaching notes |
| `updatedAt` | Timestamp | |

Stored as a subcollection of the team, not under `users/`, so access is scoped to team-level admin checks without cross-collection joins.

## Firestore Rules
- **Team admins only** — read and write. The rule explicitly denies everyone else, including the ranked player.
- System admin can read/write all rankings.
- There is **no fallback** — if a Firestore `get()` for a ranking returns permission-denied for a non-admin, that is correct and expected behaviour.

## Key Decisions
- Rankings live in a **subcollection of the team**, not in a top-level collection, so the security rule `isTeamAdmin(teamId)` applies naturally without needing to store the teamId in the doc for rule evaluation.
- Score display: integer when whole (e.g., `7`), one decimal place otherwise (`7.5`). This is a UI formatting choice — the underlying value is always a `double`.
- **No player-facing surface** for rankings anywhere in the app. The rankings screen is only reachable via the admin-only team management flow.
- Rankings are **per-team**, not global. A player can have different scores on different teams (e.g., a casual player on two teams coached by different people).

## Future / Deferred
- **Multiple ranking dimensions** — current model is a single `score` field. A multi-axis model (skating, shooting, positioning for hockey) would give better lineup generation but adds UI complexity.
- **Ranking history** — no audit trail of score changes. If a coach wants to track progression over a season, they currently can't.
- **Ranking methods** — a `rankingMethods/{methodId}` collection exists in the Firestore schema but is not yet used. Originally planned as admin-configurable scoring rubrics.
- **Relative rankings** — current model is absolute (0–10). Relative ranking (stack-ranked list) might produce better lineup generator results for small teams where score inflation/deflation varies by coach.
- **System admin view** — system admin can technically read all rankings but there is no system-admin UI screen for it.
