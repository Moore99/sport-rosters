# Compliance (GDPR + PIPEDA)

## What It Does
Satisfies Canadian (PIPEDA) and European (GDPR) requirements for user data: right of access (data export), right to erasure (account deletion cascade), data minimization, consent, and privacy policy / terms of service.

## User-Facing Behaviour
| Action | Who |
|--------|-----|
| Export personal data (JSON download) | Any signed-in user |
| Delete account (full cascade) | Any signed-in user |
| View Privacy Policy | Anyone (in-app + web) |
| View Terms of Service | Anyone (in-app + web) |
| View Accessibility Statement | Anyone (in-app + web) |
| Opt out of push notifications | Any signed-in user (Profile screen) |

## Data Export (`exportUserData`)

Cloud Function returns a JSON object with:
- `profile` — name, email, phone, weightKg (excludes `fcmToken`, `adFree`)
- `teams` — team memberships with role (player/admin)
- `availabilityRecords` — all event RSVPs (eventId, teamId, response, updatedAt)
- `dropInParticipations` — drop-in sessions joined (sessionId, eventId, teamId)

Not included in export: rankings (coach-private, not the user's data), announcements (team data, not personal), notifications (ephemeral).

Caller must be authenticated as the requesting user (`request.auth.uid` = the exported user). No admin can export another user's data via this function.

## Account Deletion Cascade (`deleteAccount`)

Executes in order to satisfy foreign key–like integrity:

1. **Availability** (collection group query by userId) — deletes all RSVP docs
2. **Rankings** (per team) — deletes `teams/{teamId}/rankings/{uid}` for each team
3. **Player Preferences** (per team) — deletes `teams/{teamId}/playerPreferences/{uid}`
4. **Drop-in signups** — removes uid from `dropInSessions.signups` arrays
5. **Team arrays** — removes uid from `teams.players` and `teams.admins`
6. **Join requests** — deletes any pending `joinRequests/{uid}` docs
7. **User document** — deletes `users/{uid}`
8. **Firebase Auth account** — deletes auth record

All steps use batch writes or `FieldValue.arrayRemove` for atomicity within each step. Steps are sequential, not wrapped in a single transaction (Firestore transactions cannot span collection groups).

**Not deleted**: events created by the admin (team events remain), lineups, announcements. These are team assets, not personal data.

## Data Minimization
- `phone` and `photoUrl` — optional fields, collected only on explicit user action (separate UI flows, not part of registration).
- `weightKg` — optional, user-entered. Used only for Dragon Boating balance.
- `fcmToken` — necessary for push notifications; cleared on sign-out.
- No personal data logged to Crashlytics.

## Consent
- Push notification permission is requested explicitly with an explanatory prompt before the OS dialog.
- Optional profile fields (phone, photo, weight) are shown with purpose text explaining why the data is collected.
- No pre-ticked consent boxes anywhere.

## Firestore Region
**northamerica-northeast2 (Toronto)** — selected for PIPEDA compliance (data residency in Canada).

## Legal Screens
| Screen | Route | URL |
|--------|-------|-----|
| Privacy Policy | `/privacy` | https://moore99.github.io/sport-rosters/privacy |
| Terms of Service | `/terms` | https://moore99.github.io/sport-rosters/terms |
| Delete Account | `/delete-account` | https://moore99.github.io/sport-rosters/delete-account |
| Accessibility | `/accessibility` | In-app screen |

Android pages served from GitHub Pages (`docs/` folder, `moore99/sport-rosters` repo). iOS uses the nuclear-motd.com combined privacy policy (still live). The nuclear-motd.com/sports-rostering/* paths are dead — do not link to them.

## Key Decisions
- **Soft-delete removed** — `users/{uid}.deleted` field exists on the model but the actual deletion cascade uses hard deletes via the Cloud Function. The soft-delete approach was considered (mark deleted, Cloud Function cascades async) but the hard cascade is simpler and fully synchronous from the user's perspective.
- **Rankings excluded from data export** — rankings are coach assessments, not the player's personal data. The player has no right of access to another person's private notes about them under GDPR (legitimate interests of the controller). Legal advice recommended exclusion.
- **No data retention schedules** — events, availability, and lineups are retained indefinitely. A retention policy (e.g., delete events older than 2 years) was considered but deferred.
- **PIPEDA over GDPR as primary framework** — the app targets Canadian recreational sports. GDPR compliance is layered on top to cover any EU users, but PIPEDA drives the architectural decisions (data residency, consent model).

## Future / Deferred
- **Data retention schedules** — automatically delete events/availability older than N years. Reduces storage costs and limits exposure.
- **Consent audit log** — no record of when a user granted or revoked consent. Required in some GDPR interpretations for high-risk processing.
- **DSAR (Data Subject Access Request) workflow** — currently fully self-serve via the export function. If the app grows, a formal DSAR intake and response tracking process may be needed.
- **Cookie/tracking consent** — AdMob uses device identifiers for ad targeting. The current app relies on Google's consent mechanisms within the AdMob SDK. A proper consent management platform (CMP) would be needed for EU App Store distribution.
- **Right to rectification workflow** — users can update their own data (name, email, phone) but there is no formal "correction request" flow for data held by the team (e.g., a player disputes their ranking, or their name was entered incorrectly by an admin).
- **Branded email domain** — password reset and (future) invite emails come from Firebase's default domain. A branded domain (e.g., `noreply@sportrosters.com`) would reduce spam classification and improve trust.
