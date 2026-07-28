# Microsoft Store Listing — Sport Rosters

---

## Product Identity (reserved in Partner Center)

| Field                      | Value                                                |
| -------------------------- | ---------------------------------------------------- |
| App name                   | Sport Rosters                                        |
| Package/Identity/Name      | KernkraftConsultingInc.SportsRostering               |
| Package/Identity/Publisher | CN=BCB6FFA0-B60B-41E1-BFD5-DA72A34681B1              |
| Publisher display name     | Kernkraft Consulting Inc.                            |
| Package Family Name (PFN)  | KernkraftConsultingInc.SportsRostering_660a73mhqnjyy |
| Store ID                   | 9NMWGL6X028C                                         |
| Category                   | Sports                                               |
| Age rating                 | PEGI 3 / Everyone (matches Play Store rating)        |
| Privacy policy URL         | https://nuclear-motd.com/privacy                     |

---

## What's Different About the Windows Build

The Windows desktop build shares the same Firebase backend (Firestore, Auth, Storage — all
northamerica-northeast2/Toronto) as the mobile and web apps, so teams, events, lineups,
rankings, and drop-ins are fully synced across every platform. A few mobile-only pieces
have no Windows equivalent and are disabled in this build:

| Feature                                                                                       | Status on Windows      | Why                                                             |
| --------------------------------------------------------------------------------------------- | ---------------------- | --------------------------------------------------------------- |
| Core team/roster/schedule/lineup/rankings/drop-ins                                            | ✅ Full support        | Native Firestore/Auth Windows plugins                           |
| Windows Hello lock (biometric-equivalent)                                                     | ✅ Full support        | `local_auth` has a native Windows plugin                        |
| Remove Ads (one-time purchase)                                                                | ✅ Via Stripe Checkout | Same flow already used on the web app                           |
| Account deletion, GDPR data export, team notifications, spare notifications, team logo upload | ✅ Full support        | Routed through the same Cloud Functions as mobile/web           |
| Banner ads                                                                                    | ❌ Not shown           | No AdMob Windows SDK — desktop users see no ads either way      |
| Push notifications                                                                            | ❌ Not available       | No FCM Windows SDK                                              |
| Sign in with Apple                                                                            | ❌ Not available       | No Windows implementation; use email/password or Google Sign-In |
| Crash reporting                                                                               | ❌ Not available       | No Crashlytics Windows SDK                                      |

---

## Short Description (Store listing summary, 200 chars max)

```
Manage your sports team on the desktop — rosters, schedules, lineups, rankings, and drop-ins, synced with your phone and the web.
```

---

## Description (10,000 chars max)

```
Sport Rosters is the all-in-one team management app for coaches and players of any recreational or competitive sport — now on Windows, fully synced with the mobile and web apps.

── FOR COACHES ──

Roster Management
Add players to your team via invite code. Approve or deny join requests. Remove players at any time.

Event Scheduling
Create games, practices, and drop-in sessions with date, time, location, and player minimums. See at a glance who's coming, including recurring weekly/biweekly series.

Lineup Builder
Build your lineup for any event by assigning players to positions. Use the auto-generate feature to fill positions based on player rankings and position preferences.

Player Rankings (Private)
Rate your players on a 1–10 scale — completely private. Players cannot see their own ranking or anyone else's. Rankings feed into lineup auto-generation.

Drop-In Sessions
Running a casual game? Open a drop-in session attached to any event. Players sign up themselves, and "Generate Teams" auto-balances the group with a snake draft algorithm.

Spares List
Keep a standby list of players; notify them in one tap when the roster is short for an event.

Export & Share
Export any lineup or boat seating chart as a PDF, or event attendance as a CSV.

── FOR PLAYERS ──

See Your Schedule
View every upcoming event for all your teams in one place.

RSVP in Seconds
Tap Yes / No / Maybe on any event. Coaches see your response instantly.

Position Preferences
Set your preferred positions per team — the auto-lineup generator respects them.

── FOR EVERYONE ──

Windows Hello
Lock the app behind Windows Hello for a quick, secure return to your teams.

Light & Dark Mode
Fully supports light mode, dark mode, or system default.

Privacy First
All data stored in Canada (Toronto). Full GDPR and PIPEDA compliance. Delete your account and all associated data at any time from Profile → Delete Account.

Synced Everywhere
The exact same account and teams you use on Android, iOS, and the web — sign in once, pick up right where you left off on desktop.

── SUPPORTED SPORTS ──
Hockey · Soccer · Basketball · Baseball · Softball · Volleyball · Football · Lacrosse · Dragon Boating · Curling · and more

Sport Rosters for Windows is free. A one-time "Remove Ads" purchase (processed via Stripe Checkout) syncs across all your devices.
```

---

## What's New (First Windows Release)

```
Sport Rosters is now available on Windows!

• Full team, roster, schedule, and lineup management
• Player rankings and position preferences (coach-only rankings stay private)
• Drop-in sessions with auto-balanced team generation
• Windows Hello app lock
• PDF lineup export and CSV availability export
• Fully synced with the Android, iOS, and web apps
• Light/dark mode
```

---

## Screenshots — Recommended Shots

Capture at 1920×1080 (16:9), both light and dark mode. Store requires at least 1; 4–6 is ideal
for a desktop listing.

1. **Home / Team List** — resized to show the wider desktop layout
2. **Event Schedule** — list of upcoming games/practices
3. **Lineup Screen** — positions filled, auto-generate button visible
4. **Drop-in Screen** — player list + generated team cards
5. **Windows Hello lock screen** (if screenshot-able) or Profile screen showing the toggle
6. **Profile Screen** — theme toggle, teams with roles

Store also accepts a 1920×1080 "hero" promotional image if you want one — optional for the
first submission.

---

## App Icon / Store Logos

Reuse the existing launcher icon (`assets/icons/app_icon.png`). `flutter_launcher_icons`
(windows: generate: true) produces the `.ico` used for the desktop shortcut; the MSIX
package additionally needs Store-sized tiles, which `msix:create` generates automatically
from `logo_path` in `pubspec.yaml`.

---

## Age Ratings Questionnaire

Answer identically to the Play Store submission (see `play_store_listing.md`):

- Violence / sexual content / profanity / controlled substances: No
- User-generated content: Yes (team names, player names), private to team members only
- Personal/sensitive data collected: Yes (name, email) — covered by privacy policy

Expected rating: **PEGI 3 / Everyone**.

---

## Test Account for Microsoft Certification

Same approach as the Play Store test account — provide a pre-populated team so reviewers
can see all features without setup. See `play_store_listing.md` → "Test Account for Google
Review" for the account fields to fill in; reuse the same credentials for both stores if
convenient.

---

## Build & Submit

```bash
flutter build windows --release --dart-define-from-file=env.json
dart run msix:create
```

Produces the signed `.msix` at `build/windows/x64/runner/Release/sport_rosters.msix`
(exact path printed by the `msix:create` command). Upload that file directly in Partner
Center → the reserved "Sport Rosters" product (Store ID `9NMWGL6X028C`) → Packages.

`msix_version` in `pubspec.yaml` must be bumped for every new submission — Partner Center
rejects a version number that's already been submitted, even if the previous submission
was withdrawn.

**Local test-certificate prompt**: `msix:create` asks "Do you want to install the
certificate: test_certificate.pfx?" after packing — this installs a self-signed cert
locally so you can sideload and run the unsigned package for testing. It's interactive
(answer in an actual terminal, not piped/non-interactive) and **not needed for Partner
Center submission** — the Store re-signs the package on ingestion. Answer `N` if you just
want the `.msix` for upload; answer `Y` only if you want to `Add-AppxPackage` it locally
first to sideload-test on this machine.
