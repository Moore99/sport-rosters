# Team Announcements

## What It Does
Provides a per-team feed where admins post messages to all team members. Posts can be pinned to keep important information visible at the top. Members read; only admins can create, edit, or delete.

## User-Facing Behaviour
| Action | Who |
|--------|-----|
| Post announcement | Team admin |
| Edit announcement (title, body, pin status) | Team admin |
| Delete announcement | Team admin |
| Pin / unpin announcement | Team admin |
| Read announcements feed | Team member |

## Data Model

### `teams/{teamId}/announcements/{announcementId}`
| Field | Type | Notes |
|-------|------|-------|
| `announcementId` | String | Firestore auto-ID |
| `teamId` | String | |
| `title` | String | |
| `body` | String | Plain text; no rich text/HTML stored |
| `authorId` | String | UID of posting admin |
| `authorName` | String | Captured at creation time (denormalized) |
| `pinned` | bool | Whether to surface at top of feed |
| `createdAt` | Timestamp | |

## Firestore Rules
- Team members **read** all announcements for their team.
- Team admins **create, update, delete** announcements.
- Update is scoped to `title`, `body`, `pinned` — metadata fields (`authorId`, `authorName`, `createdAt`) are immutable after creation.

## Display Logic
- Feed is ordered by `createdAt` descending (newest first).
- Pinned announcements are sorted to the top client-side (not via a Firestore compound query, to avoid a composite index).
- No pagination currently — all announcements for a team are fetched in a single query. Acceptable for typical team sizes.

## Key Decisions
- **`authorName` is denormalized** at creation time. If the admin later changes their display name, historical announcements still show the name they had when they posted. This is intentional — it's an accurate record.
- **Plain text body** — no markdown or rich text. Keeps the model simple and avoids sanitization complexity. If formatting is needed, consider a lightweight markdown renderer with a strict allowlist.
- **Pinned sorting is client-side** — avoids a composite Firestore index (`pinned DESC, createdAt DESC`). At typical team announcement volumes (< 100 docs), client-side sort is fine.
- **"Notify team" toggle on new posts** — the new announcement dialog includes an opt-in switch that, when enabled, calls `sendTeamNotification` immediately after the announcement is saved. The notification title and body mirror the announcement. Only available on new posts (not edits). Notification failure is silently swallowed — the announcement is always saved regardless.

## Future / Deferred
- **Rich text / markdown** — plain text is limiting for formatting schedules, rules, etc. A simple markdown renderer would help without full HTML complexity.
- **Read receipts** — no tracking of which members have read an announcement. Useful for compliance items ("all players must acknowledge the code of conduct").
- **Scheduled announcements** — post now but make visible at a future time. Not implemented.
- **Comment / reaction system** — one-way broadcast only. A threaded discussion would require significant additional complexity (moderation, notifications per reply, etc.).
- **Pagination** — currently fetches all announcements. For active teams that post frequently, a paginated cursor query would be needed.
