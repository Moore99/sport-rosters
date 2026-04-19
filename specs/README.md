# Feature Specs

One file per domain. Each spec covers: what it does, user-facing behaviour, data model, Firestore rules, Cloud Functions, key decisions (the *why*), and future/deferred items.

Write or update the relevant spec **before** implementing a feature, and update it after shipping if decisions changed.

| Spec | Domain |
|------|--------|
| [auth.md](auth.md) | Registration, login, email verification, biometrics, Google/Apple sign-in |
| [teams.md](teams.md) | Team creation, join flow, roster management, admin roles, team logo |
| [events-availability.md](events-availability.md) | Event scheduling, RSVP, recurring events, game results |
| [notifications.md](notifications.md) | FCM push notifications, event reminders, team broadcasts, mute controls |
| [rankings.md](rankings.md) | Coach-private player assessments (admin-only) |
| [lineups.md](lineups.md) | Manual and auto-generated lineups, position preferences, sub-teams, dragon boat seating |
| [dropins.md](dropins.md) | Drop-in session signups, waitlist, auto-balanced teams |
| [spares.md](spares.md) | Standby player pool, spare callouts, spare responses |
| [announcements.md](announcements.md) | Team announcement feed, pinning |
| [player-profiles.md](player-profiles.md) | User profile, photo upload, weight, attendance history |
| [monetization.md](monetization.md) | AdMob, Remove Ads IAP, rewarded ad gates, receipt validation |
| [compliance.md](compliance.md) | GDPR/PIPEDA — data export, account deletion cascade, consent, legal screens |
| [infrastructure.md](infrastructure.md) | Stack, routing, Firebase config, CI/CD, cross-cutting patterns |
