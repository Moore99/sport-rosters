# Google Play Store Listing — Sports Rostering

---

## App Details

| Field | Value |
|-------|-------|
| App name | Sports Rostering |
| Package name | com.sportsrostering.app |
| Developer | Kernkraft Consulting Inc. |
| Category | Sports |
| Content rating | Everyone |
| Privacy policy URL | https://nuclear-motd.com/privacy (or host a dedicated page — see note below) |

---

## Short Description (80 chars max)

```
Manage your sports team — rosters, schedules, lineups, and drop-ins.
```

---

## Full Description (4000 chars max)

```
Sports Rostering is the all-in-one team management app for coaches and players of any recreational or competitive sport.

── FOR COACHES ──

✅ Roster Management
Add players to your team via invite code. Approve or deny join requests. Remove players at any time.

📅 Event Scheduling
Create games, practices, and drop-in sessions with date, time, location, and player minimums. See at a glance who's coming.

📋 Lineup Builder
Build your lineup for any event by assigning players to positions. Use the auto-generate feature to fill positions based on player rankings and position preferences.

🏆 Player Rankings (Private)
Rate your players on a 1–10 scale — completely private. Players cannot see their own ranking or anyone else's. Rankings feed into lineup auto-generation to put the right players in the right spots.

🎯 Player Position Preferences
Players set their preferred positions (per team). The auto-lineup generator respects preferences when filling the lineup, so players end up where they want to be.

👥 Drop-In Sessions
Running a casual game? Open a drop-in session attached to any event. Players sign up themselves. Tap "Generate Teams" to automatically split the group into balanced teams using a snake draft algorithm — no more lopsided games.

📄 Export & Share
Export any lineup as a PDF to share or print before a game. Export event attendance as a CSV for your records.

── FOR PLAYERS ──

🗓 See Your Schedule
View all upcoming events for your teams in one place.

📣 RSVP in Seconds
Tap Yes / No / Maybe on any event. Coaches see your response instantly.

🔔 Push Notifications
Get notified when new events are added or when important updates happen (with your permission).

── FOR EVERYONE ──

🌙 Light & Dark Mode
Fully supports light mode, dark mode, or system default.

🔒 Privacy First
All data stored in Canada (Toronto). Full GDPR and PIPEDA compliance. Delete your account and all associated data at any time from within the app.

💳 Remove Ads
One-time purchase to permanently remove all ads. Syncs across your devices.

── SUPPORTED SPORTS ──
Hockey · Soccer · Basketball · Baseball · Softball · Volleyball · Football · Lacrosse · Curling · and more

Sports Rostering is free to download. Banner ads are shown in the free version. A one-time "Remove Ads" purchase is available.
```

---

## What's New (First Release)

```
Initial release.

• Team management with invite codes and join requests
• Event scheduling with RSVP tracking
• Manual and auto-generated lineups with player rankings
• Player position preferences
• Drop-in sessions with auto-balanced team generation
• PDF lineup export and CSV availability export
• Push notifications
• Light/dark mode
• Remove Ads in-app purchase
```

---

## Screenshots — Recommended Shots (take on a Pixel or similar)

Take these in both light and dark mode. Play Store requires at least 2; 4–8 is ideal.

1. **Home / Team List** — shows a team with sport icon
2. **Event Schedule** — list of upcoming games/practices with dates
3. **Event Detail (Admin)** — showing RSVP summary with Yes/No/Maybe counts
4. **Lineup Screen** — positions filled with player names, auto-generate button visible
5. **Drop-in Screen** — player list + coloured team cards after generation
6. **Profile Screen** — shows theme toggle, teams with roles

Screenshot size: 1080 × 1920 px (portrait) or as captured by device.

---

## Feature Graphic (1024 × 500 px)

Suggested layout (create in Canva or similar):
- Background: dark navy or team-sport green gradient
- Left side: app icon (large, centred vertically)
- Right side: app name "Sports Rostering" in bold white, tagline "Manage your team. Build your lineup." in lighter weight below
- Subtle sport icons (hockey stick, soccer ball, etc.) as background texture

---

## App Icon

Use the existing launcher icon (`assets/icons/`). Ensure a 512 × 512 px version is uploaded to Play Console.

---

## Content Rating Questionnaire Answers

- Violence: No
- Sexual content: No
- Profanity: No
- Controlled substances: No
- User-generated content: Yes (team names, player names) — no public UGC, all within private teams
- Personal/sensitive data collected: Yes (name, email) — covered by privacy policy

Expected rating: **Everyone**

---

## Test Account for Google Review

Provide reviewers with an account that has access to a pre-populated team:

| Field | Value |
|-------|-------|
| Email | (create a dedicated test account e.g. review@sportsrostering.app or use a Gmail) |
| Password | (set a simple password for reviewers) |
| Notes | Account is pre-added to a team as a player. To see admin features, also provide an admin account. |

Pre-populate a test team in Firebase with a few events and availability responses so reviewers can see all features without setup.

---

## Privacy Policy URL Note

Play Store requires a **publicly accessible URL** for the privacy policy — it cannot be in-app only.

**Easiest option:** Add a `/sports-rostering-privacy` page to nuclear-motd.com hosting the privacy policy text from `privacy_screen.dart`.

**Alternative:** Use a free static host (GitHub Pages, Netlify) with a simple HTML page.

The in-app Privacy screen satisfies PIPEDA/GDPR display requirements; the external URL is for Play Store submission only.
