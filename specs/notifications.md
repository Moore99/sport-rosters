# Notifications

## What It Does
Delivers push notifications (FCM) to team members for upcoming events, team announcements, spare callouts, and last-minute RSVP cancellations. Supports user-level opt-out and per-team muting. Admin participation roles affect reminder copy.

## User-Facing Behaviour
| Notification | Trigger | Recipient |
|-------------|---------|-----------|
| 24h event reminder | Scheduler, ~24h before event | All members not marked unavailable |
| 2h event reminder | Scheduler, ~2h before event | All members not marked unavailable |
| Team announcement | Admin sends from app | All team members |
| Spare callout | Admin triggers from spares screen | All spares for that team |
| RSVP cancellation alert | Player changes to 'no' within 24h | All team admins |
| Waitlist promotion | Drop-in waitlist slot opens | Promoted player only |

Players who opted out globally (`notificationsEnabled = false`) or muted a specific team (`mutedTeams` contains `teamId`) receive nothing for that team.

## Controls Available to Users
- **Global opt-out** — toggle in Profile screen → "Push Notifications" switch. Writes `notificationsEnabled` to `users/{uid}`.
- **Per-team mute** — bell icon in team AppBar. Writes `teamId` to `users/{uid}.mutedTeams` via `FieldValue.arrayUnion/arrayRemove`. When muted, the icon is a filled red `notifications_off`; when active, an outline `notifications_active`. Tooltip states the current state and the action tapping will take.

## Admin Participation & Reminder Copy
`coachOnly` admins (see `teams.md`) receive reminders **without** the RSVP nudge:
- Regular: "Reminder: Practice at 7:00 PM. Have you RSVPed?"
- Coach-only: "Reminder: Practice at 7:00 PM."

`player` and `sometimes` admins receive the full reminder.

## Data Model

### FCM Token
Stored at `users/{uid}.fcmToken`. Set on login via `UserRepository.updateFcmToken()`. Cleared on sign-out via `UserRepository.clearFcmToken()`. Stale tokens are cleaned up opportunistically after each multicast send.

### In-App Inbox
`teamNotifications/{teamId}/messages/{msgId}`:
| Field | Type | Notes |
|-------|------|-------|
| `title` | String | |
| `body` | String | |
| `senderUid` | String | UID of admin, or `'system'` for scheduler reminders |
| `sentAt` | Timestamp | |
| `eventId` | String? | Present when notification relates to an event |

Team members read; all client writes denied (Cloud Function writes only).

## Cloud Functions

### `sendEventReminders` (scheduled, every 60 min)
- Queries `events` where `date` is in the next 25h.
- Skips cancelled events.
- For each event: fetches team doc (for timezone + member list), availability docs (to exclude 'no' RSVPs), and adminRoles (for `coachOnly` exclusions).
- Sends 24h reminder when event is 23–25h away and `reminder24Sent` is false.
- Sends 2h reminder when event is 1.5–2.5h away and `reminder2Sent` is false.
- Sets the flag after sending to prevent duplicates.
- Formats time using `toLocaleTimeString` with the team's IANA timezone.
- Cleans up stale FCM tokens after each multicast batch.
- Persists one inbox message per reminder to `teamNotifications/{teamId}/messages`.

### `sendTeamNotification` (callable, admin-only)
- Params: `{ teamId, title, body, eventId? }`
- Verifies caller is team admin.
- Fetches all member FCM tokens; skips users with `notificationsEnabled = false`.
- Note: per-team mute is **not** checked here (by design — admin broadcasts override mute). Reconsider if users complain.
- Cleans up stale FCM tokens.
- Persists to inbox.

### `notifySpares` (callable, admin-only)
- Params: `{ eventId, teamId, teamName, eventDate, batchSize }`
- Sends to spares pool members for the given team.
- Returns sent count.

### `onAvailabilityChanged` (Firestore trigger on `events/{eventId}/availability/{userId}` update)
- Fires when any availability doc is written.
- Acts only when `after.response === 'no'` and `before.response !== 'no'`.
- Checks event is within the next 24h.
- Fetches cancelling user's name.
- Sends FCM to all team admins (excluding the cancelling user if they are an admin).
- Respects `notificationsEnabled`; does not check per-team mute (admin alert, not a broadcast).

### `notifyWaitlistPromotion` (callable)
- Triggered when drop-in withdrawal promotes a waitlisted player.
- Sends a single FCM to the promoted player.

### `onEventDateChanged` (Firestore trigger on `events/{eventId}` update)
- Clears `reminder24Sent` / `reminder2Sent` when `date` changes so rescheduled events re-trigger reminders.

## Key Decisions
- **Stale token cleanup is opportunistic**, not proactive. Tokens are removed after a failed multicast, not on a schedule. This is fine — stale tokens accumulate only when users reinstall without signing in again.
- **Per-team mute does not affect admin broadcasts** (`sendTeamNotification`). This was a deliberate choice — an admin sending a targeted message should reach everyone. If this causes friction, add a flag to the function call.
- **Reminder deduplication uses flags on the event doc** rather than a separate log collection. Simpler and cheaper, with acceptable risk of double-send on scheduler overlap (window is 2h wide, scheduler runs hourly).
- **Team timezone** is stored on the team doc and used for all time formatting in Cloud Functions. The scheduler runs in UTC; all human-readable times in notifications use `toLocaleTimeString` with the IANA timezone ID.
- **`coachOnly` admins are excluded from the member list sent reminders** via the `adminRoles` subcollection lookup in `sendEventReminders`. They still receive a reminder, just without the RSVP nudge.

## Future / Deferred
- **Notification preferences per event type** — e.g., opt out of practice reminders but keep game reminders. Currently global opt-out or per-team mute only.
- **Admin opt-out of RSVP cancellation alerts** — currently all admins get them. An opt-out toggle in team settings would reduce noise for large teams.
- **Rich notifications** — no images or action buttons in the current payload. FCM supports these; could add "I'm in" / "Can't make it" action buttons directly in the notification.
- **Notification history on device** — inbox only shows what was sent while the app was installed. Older messages are not paginated.
- **Admin broadcast respecting mute** — consider a `respectMute: bool` parameter on `sendTeamNotification` so admins can choose whether to override per-team mutes.
- **Quiet hours** — no server-side quiet hours enforcement. Users rely on OS-level Do Not Disturb.
