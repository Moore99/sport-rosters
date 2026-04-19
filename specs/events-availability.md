# Events & Availability

## What It Does
Admins schedule events (games, practices, drop-in sessions) for a team. Players RSVP with yes/no/maybe. Events can recur weekly or biweekly. Post-game, admins log a result. Admins can copy an event or edit/delete an entire recurring series.

## User-Facing Behaviour
| Action | Who |
|--------|-----|
| Create event (single or recurring) | Team admin |
| Edit event (single or entire series) | Team admin |
| Delete event (single or entire series) | Team admin |
| Copy event (pre-fills form with source event's details) | Team admin |
| Cancel event (single or whole series) | Team admin |
| Restore cancelled event | Team admin |
| Log game result (score + opponent) | Team admin |
| RSVP yes / no / maybe | Team member |
| View event detail (date, location, RSVP counts, result) | Team member |
| View availability breakdown per event | Team member |

## Data Model

### `events/{eventId}`
| Field | Type | Notes |
|-------|------|-------|
| `eventId` | String | Firestore doc ID |
| `teamId` | String | Parent team |
| `type` | String | `'game'` \| `'practice'` \| `'dropIn'` |
| `date` | Timestamp | Start time (stored in UTC) |
| `location` | String | Plain text or Google Places result |
| `minPlayers` | int | |
| `maxPlayers` | int | |
| `allowSignups` | bool | Whether RSVP is open |
| `rsvpDeadline` | Timestamp? | Null = no deadline |
| `notes` | String? | Optional coach notes |
| `numSubTeams` | int | `1` = single roster; `2+` = balanced sub-teams |
| `boatConfig` | Map? | Dragon Boating only — `{numBoats, seatsPerBoat, hasDrummer}` |
| `recurrenceGroupId` | String? | Shared ID across a recurring series |
| `gameResult` | Map? | `{opponentName, ourScore, opponentScore}` — set post-event |
| `cancelled` | bool | Soft-cancel; reminders skip, events list muted with chip, detail shows orange banner. Default `false`; omitted from Firestore when false. |
| `reminder24Sent` | bool | Set by `sendEventReminders` scheduler |
| `reminder2Sent` | bool | Set by `sendEventReminders` scheduler |
| `createdAt` | Timestamp | |

### `events/{eventId}/availability/{userId}`
| Field | Type | Notes |
|-------|------|-------|
| `userId` | String | Doc ID |
| `eventId` | String | Denormalized for rule evaluation |
| `teamId` | String | Denormalized for rule evaluation |
| `response` | String | `'yes'` \| `'no'` \| `'maybe'` |
| `updatedAt` | Timestamp | |

## Firestore Rules
- Team admins create/edit/delete events; team members read.
- Each player writes only their own availability doc (create or update). Team admins can delete any availability doc.
- `resource == null` guard required on availability reads — the doc may not exist before the player first RSVPs.
- `teamId` denormalized into availability docs so rules can call `isTeamMember(resource.data.teamId)` without a nested Firestore `get()`.

## Cloud Functions
- **`sendEventReminders`** (scheduled, every 60 min) — sends 24h and 2h reminder notifications. Tracks via `reminder24Sent` / `reminder2Sent` flags. Respects team timezone, per-user mute settings, and admin participation roles. See `notifications.md`.
- **`onEventDateChanged`** (Firestore trigger on `events/{eventId}` update) — clears `reminder24Sent` / `reminder2Sent` whenever `date` changes, so rescheduled events re-trigger fresh reminders.
- **`onAvailabilityChanged`** (Firestore trigger on `events/{eventId}/availability/{userId}` update) — notifies team admins via FCM when a member's response changes to `'no'` within 24h of the event. See `notifications.md`.

## Key Decisions
- **Reminder flags live on the event doc**, not in a separate collection. Simple and cheap to query; cleared by `onEventDateChanged` on reschedule. Risk: if two scheduler invocations overlap within the window, both could send — acceptable because the scheduler runs hourly and the window is 2h wide (23–25h or 1.5–2.5h).
- **Recurring series** share a `recurrenceGroupId`. Non-date fields (notes, location, etc.) can be batch-updated across the series. Date fields are per-event — you can't shift a whole series' dates after creation; delete and recreate instead.
- **`numSubTeams`** on the event determines whether the lineup screen shows one roster or multiple balanced sub-teams. Setting it to 2+ at event creation time is intentional — you can't split an existing single-roster event after a lineup has been saved.
- **`boatConfig`** is remembered from the most recent Dragon Boating event for that team and pre-fills the create form.
- **Copy event** pre-fills the form with all fields from the source event *except* the date, so the admin only needs to set the new date.
- **Upcoming/past split** is done client-side by comparing `event.date` to `now`. No composite Firestore index required.
- **Cancellation is a soft flag**, not a delete. Members still see the event (marked clearly); admins can restore it. The reminder scheduler skips `cancelled: true` events. Reminder flags (`reminder24Sent`/`reminder2Sent`) are not cleared on cancel — restore + reschedule handles that via `onEventDateChanged`.
- **Recurring series date shift** computes `delta = newDateTime − originalDate` and applies it to every event in the series via a batch write. Reminder flags are cleared on all shifted events so reminders re-fire at the new times. Admins see an info hint in the edit screen explaining this behaviour.
- **`rsvpOpen`** is a computed property: `allowSignups && (rsvpDeadline == null || rsvpDeadline > now)`. The deadline field itself is nullable — null means no deadline.

## Future / Deferred
- **Google Calendar sync** — listed as implemented (Phase last commit message), but the spec details are not captured here. Verify current state in `calendar_sync_service.dart` if it exists.
- **Attendance history** — attendance is derived from `availability` docs with `response = 'yes'`. A dedicated attendance history screen exists (Phase 8) but aggregation is client-side; no server-side roll-up.
- **Event capacity enforcement** — `maxPlayers` exists on the event but RSVP is not hard-capped. Over-committed RSVPs are resolved via lineup selection, not at sign-up time.
- **Location autocomplete** — Google Places autocomplete is wired with platform-specific API keys. Falls back to plain text input if keys are absent (local `flutter run` without `--dart-define`).
