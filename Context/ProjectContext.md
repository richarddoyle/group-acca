# Group Acca — Project Context

## About the App
Group Acca is an iOS mobile app that allows groups of friends to coordinate group betting (accumulators). Users select teams within a group, a group admin places the bet externally via a betting app, and Group Acca tracks picks, results and performance over time. The app gamifies the experience with leaderboards and stats.

**Tagline:** Bet together. Win together.

---

## Team
- **Richard Doyle (brother)** — lead developer, manages GitHub repo, Apple Developer account (Rudedog-Productions), Supabase backend
- **Adam Doyle** — frontend, design, onboarding, App Store, branding

---

## Tech Stack
- **Language:** Swift / SwiftUI
- **Backend:** Supabase (database + auth)
- **Authentication:** Apple Sign In
- **Push notifications:** Apple Push Notification Service (APNs)
- **Repo:** github.com/richarddoyle/group-acca
- **Bundle ID:** Rudedog-Productions.WeeklyAcca
- **Display name:** Group Acca (internal project name: WeeklyAcca)

---

## Development Setup
- **Mac:** Adam's MacBook Air
- **Code editor:** VS Code
- **iOS build tool:** Xcode
- **AI assistant:** Claude Code (in VS Code terminal)
- **Design tool:** Figma

### Daily Start Routine
1. Open VS Code
2. Open new terminal → `git pull`
3. Switch to Xcode → `Cmd + B` to confirm build succeeds
4. Open Claude Code terminal → `claude` to start working

### End of Session Routine
1. `git status` — check what's changed
2. `git add .` — stage changes
3. `git commit -m "description of changes"`
4. `git push` — push to GitHub
5. Create Pull Request on GitHub for Richard to review

### Branching Strategy
- Always work on a feature branch, never directly on main
- Branch naming: `feature/description-of-work`
- Create PR for Richard to review before merging to main

---

## Project Structure
```
group-acca/
└── WeeklyAcca/
    ├── Assets.xcassets/     — image assets
    ├── Fonts/               — BarlowCondensed-Medium.ttf
    ├── Models/              — data models including Schema.swift
    ├── Services/            — SupabaseService.swift
    ├── supabase/            — database config
    ├── Views/               — all SwiftUI screens
    │   ├── LoginView.swift          — sign in screen
    │   ├── OnboardingView.swift     — new user onboarding
    │   ├── CreateGroupView.swift    — create group screen
    │   ├── DashboardView.swift      — group detail screen
    │   ├── GroupListView.swift      — groups list
    │   ├── GroupLeaderboardView.swift
    │   ├── GroupMembersView.swift
    │   ├── GroupSettingsView.swift
    │   ├── JoinGroupView.swift
    │   ├── MarketSelectionView.swift
    │   ├── MatchesView.swift
    │   ├── MatchSelectionView.swift
    │   ├── ProfileView.swift
    │   ├── StatsView.swift
    │   ├── CreateAccaView.swift
    │   └── AddMonzoUsernameView.swift
    ├── ContentView.swift    — root navigation/routing
    ├── WeeklyAccaApp.swift  — app entry point
    └── Secrets.swift        — API keys (gitignored, never commit)
```

---

## Brand & Design

### Colours
- **Light green:** `#2FAF4F`
- **Mid green:** `#199D46`
- **Dark green:** `#099342`
- **Dark green 2:** `#079241`
- **Navy/Black:** `#071321`
- **App background (light):** `#F2F2F7`
- **App background (dark):** `#000000`
- **Slogan text (light):** `#071321` at 85% opacity
- **Slogan text (dark):** `#F2F2F7`
- **Muted text:** `#64748B`

### Typography
- **Wordmark font:** Barlow Condensed ExtraBold Italic (converted to vectors in Figma)
- **Slogan font:** Barlow Condensed Medium
- **App font registered in Xcode:** BarlowCondensed-Medium.ttf
- **Body/UI font:** System default (SF Pro)

### Assets in Xcode (Assets.xcassets)
- `LightmodeWatermark` — navy GROUP, green ACCA, transparent background
- `DarkmodeWatermark` — white GROUP, green ACCA, transparent background
- `GALogo` — original GA mark
- `AppIcon` — app icon

### Design files
- Figma file: GroupAcca Sign In Screen
- Local design assets: `/Users/adam/Documents/Design Assets/`

---

## Key Features Built
- ✅ Sign in screen — redesigned with Group Acca branding and wordmark
- ✅ Onboarding flow — profile setup, join/create group, coach marks
- ✅ Groups — create, join, view members, leaderboard
- ✅ Accas — create and track group accumulators
- ✅ Matches — live results and fixtures
- ✅ Stats — personal performance tracking
- ✅ Profile — username, photo, Monzo username
- ✅ Push notifications

---

## Database (Supabase)
### Profile model fields
- `id` — UUID (primary key)
- `username` — String (required, max 20 chars)
- `avatar_url` — String? (optional)
- `created_at` — Date
- `apns_token` — String? (push notifications)
- `monzo_username` — String? (optional, for payment deep links)

---

## App Store & Distribution
- **Apple Developer Team:** Rudedog-Productions (Richard's account)
- **TestFlight:** Set up, pending external review
- **Privacy Policy:** https://adamdoyle22.github.io/group-acca-legal
- **Support URL:** https://group-acca.com
- **ICO Registration:** Pending (required before full public launch)

---

## Domain & Email
- **Domains:** group-acca.com and group-acca.co.uk (Namecheap)
- **Email:** hello@group-acca.com (Zoho Mail)
- **Privacy email:** hello@group-acca.com
- **GitHub legal repo:** github.com/adamdoyle22/group-acca-legal

---

## Important Notes
- `Secrets.swift` is gitignored — never commit it. Contains Supabase anon key and API Sports key
- Always run `git pull` before starting work
- Always create a feature branch — never commit directly to main
- Build must succeed (`Cmd + B`) before running or archiving
- Archive requires `Any iOS Device (arm64)` selected in Xcode — not a simulator
- Richard manages all App Store Connect submissions and TestFlight uploads from his Mac

## Claude Code — Prompting Process & Lessons Learned

### Before Writing Any Feature Prompt

1. **Verify external data values first**
   Before hardcoding any strings, IDs, or values that come from 
   an external source (API, database, enum), always ask Claude Code:
   
   "What values does [field] actually contain at runtime? 
   Where do they come from and what file defines them?"
   
   Never assume — confirm the exact values before writing the prompt.
   Lesson learned: competitionPriority array used "Scottish League One" 
   when the API returns "Scottish League 1" — a string mismatch that 
   caused incorrect sort order.

2. **Frame conditions from the viewer's perspective**
   When writing logic about what a user can see or do, always frame 
   the requirement from the perspective of the person viewing the screen,
   not the data on the screen.
   
   Wrong framing: "don't show the icon on rows belonging to the owner"
   Right framing: "only show the icon when the current user IS the owner"
   
   Lesson learned: "row does not belong to the acca owner" mapped to 
   !isAccaOwner which was logically inverted — the icon showed to 
   everyone except the owner instead of only the owner.

3. **Identify all string matches before prompting**
   Any feature involving string comparisons against external data 
   requires source verification first. Check the relevant constants 
   file (e.g. LeagueConstants.swift) and confirm exact string values 
   before including them in a prompt.

### Raising Bugs with Claude Code

Always include all five of these when reporting a bug:

1. **What I did** — exact steps to reproduce
2. **What I expected** — the correct behaviour
3. **What actually happened** — the bug
4. **Relevant data** — specific values, fields or conditions involved
5. **Hypothesis** — your best guess at where the logic is wrong

Ask Claude Code to:
- State the root cause clearly before making any changes
- Confirm the fix before applying it
- Show only the changed lines, not the full file

### After Any Claude Code Changes

1. Always `Cmd + B` to confirm build passes
2. Test the specific conditions defined in requirements — don't just 
   open the app and look around generally
3. Test edge cases explicitly — e.g. viewing as acca owner vs non-owner,
   locked vs open acca, pending vs confirmed selections
```
## Features Built This Session

### Acca Selection Sort & Copy (feature/acca-selection-sort-and-copy)
- Selections in WeekDetailView sorted by: kickoffTime ascending → 
  competition priority (ID-based) → homeTeamName alphabetically
- Sort applied independently to "My Picks" and "Member Picks" sections
- Copy icon (doc.on.doc SF Symbol) added to member picks rows
- Copy icon only visible to the acca owner (week.creatorId == currentUserId)
- Copy icon not shown on acca owner's own rows — they know their pick
- Copy text format: "Home Team v Away Team" (lowercase v, no 's')
  This matches UK betting app search format
- Copy icon shows whenever teamName != "Pending" regardless of lock state

### Competition Priority Order
Defined as Int array in DashboardView.swift using api-sports league IDs.
Never use string matching for league names — multiple competitions share 
the same name across different countries (e.g. "League One" is both 
English and Scottish).

Current priority order:
39=Premier League, 40=Championship, 41=League One, 42=League Two,
179=Scottish Premiership, 180=Scottish Championship,
183=Scottish League One, 184=Scottish League Two,
2=Champions League, 3=Europa League,
1=World Cup, 4=Euro Championship, 960=Euro Championship - Qualification,
32=World Cup - Qualification Europe, 5=UEFA Nations League, 10=Friendlies,
140=La Liga, 78=Bundesliga, 135=Serie A, 61=Ligue 1

### International Competitions Added
Verified directly against api-sports.io dashboard. Exact name strings:
- ID 1   → "World Cup"
- ID 4   → "Euro Championship"
- ID 5   → "UEFA Nations League"
- ID 10  → "Friendlies"
- ID 32  → "World Cup - Qualification Europe"
- ID 960 → "Euro Championship - Qualification"

Adding a new competition requires only one entry in 
LeagueConstants.swift — it automatically appears in the acca 
creation picker, MatchesView, and MatchSelectionView.

---

## Key Model Notes

### Selection (Schema.swift)
- teamName: String — sentinel value "Pending" means no pick made yet
- outcome: String — win/loss result after match. NOT an indicator of 
  whether a pick has been made. All selections are "Pending" until 
  the match is played
- leagueId: Int? — added this session. Populated from 
  fixture.competition.apiId when a pick is saved in MatchSelectionView
- league: String — competition name from API. Do not use for sorting 
  or matching — use leagueId instead

### Acca Owner vs Group Admin
These are different roles — do not confuse them:
- Group admin: SupabaseService.shared.currentUserId == group.adminId
- Acca owner/creator: SupabaseService.shared.currentUserId == week.creatorId
Anyone can create an acca, not just the group admin

### Week Lock State
- week.isOpen: Bool — controls whether picks can be changed
- week.isLocked: Bool — inverse of isOpen
- week.status: WeekStatus enum (pending/won/lost) — overall result
  Lock state and outcome status are separate concerns

---

## Database Notes

### Supabase — selections table
league_id integer column added manually this session.
Nullable to maintain backwards compatibility with existing rows.

### Adding new database columns
Always confirm column exists in Supabase before adding field to 
Swift model. SupabaseService uses .upsert(selection) which 
serialises the full Selection struct — if column doesn't exist 
Supabase returns 42703 error and all selection saves break.
Richard manages Supabase but access has now been granted to Adam.

---

## UX Decisions

### Bet Placement Flow
No bookmaker API integration — group admin places bet manually.
Copy icon helps admin copy fixtures in correct format for betting 
app search. Selections ordered to match typical betting app layout 
(by kick-off time then competition).

### Picture in Picture
Investigated as option for admin to view selections while using 
betting app. Too complex for current stage — logged as future 
enhancement.
```

---

You can paste this directly into `ProjectContext.md` then commit it:
```
git add ProjectContext.md
git commit -m "docs: update project context with session learnings"
git push
---

Once added, commit it:
```
git add ProjectContext.md
git commit -m "docs: add Claude Code prompting process and lessons learned"
git push
---

## How to Start a New Chat with Claude
Paste this at the start of each new chat:

```
I'm building an iOS app called Group Acca with my brother Richard. 
It's a group betting coordination app built in Swift/SwiftUI using 
Supabase as the backend. I'm a beginner developer owning the frontend, 
design and onboarding work.

Repo: github.com/richarddoyle/group-acca
Main views are in WeeklyAcca/Views/
Sign in: LoginView.swift
Onboarding: OnboardingView.swift
Root routing: ContentView.swift

Today I want to work on: [describe your task]
```
