# Current State

_Last updated: 2026-06-10 — after TF 3 (21). Supersedes the old SwiftData-era
draft. For the running per-session history see CLAUDE.md "Progress Log" and
`docs/progress-log-archive.md`._

## Project Status

Casalist is a **shipping** family household-management app, live on TestFlight
at **version 3, build 21** (`MARKETING_VERSION = 3`; integer build counter,
`.1/.2/.3` suffixes for bug-fix builds on top of a feature build). It is well
past prototype — the family-sharing data layer is proven on two iCloud accounts
and the app has gone through 20+ TestFlight cycles.

Built as a native iOS app using:
- **SwiftUI**
- **Core Data via `NSPersistentCloudKitContainer`** (NOT SwiftData — see below)
- **CloudKit** private + shared databases, CKShare-based family sharing
- **CasaGlassKit** (shared design-system Swift package)

### CRITICAL correction vs the old doc: the data layer is Core Data, not SwiftData
The app was migrated off SwiftData because SwiftData's `.private` CloudKit scope
is a per-Apple-ID silo and could not deliver multi-user family sharing. The
shareable models now live on `NSPersistentCloudKitContainer` with a **dual store**
(private + shared) and `container.share(_:to:)`. This is the load-bearing
foundation — see CLAUDE.md "CRITICAL: multi-user family sharing" and
`casalist_sync_baseline_rule.md` before touching anything sync-adjacent.

---

# Implemented & Shipping Features

## Family sharing (the foundation)
- Dual-store NSPCKC: private store + `.shared` store, CKShare invite/accept flow.
- `CKSharingSupported` in a real Info.plist file (the build-setting form silently drops).
- Share accept handler routes into the shared store; stable identity via
  `cloudKitUserID` dedupe; auto-rejoin from a saved share URL in iCloud KV.
- **Verified end-to-end on two iCloud accounts** (iPhone Air / geezy + iPhone 15 / dakoda).

## Tasks, chores & bundles
- Task creation with category, assignee, points, optional **bonus points**, due
  date + optional time, recurrence (daily/weekly/monthly/yearly + custom weekday rules).
- **Chore bundles**: a parent container grouping child chores with a completion
  bonus. Build while unassigned → add chores inline → finalize/assign. Finishing
  the last child **auto-completes the bundle** (drops out of the list, bonus
  awarded once).
- Chore expiration window (Off/1/3/7/14 days) with EXPIRED pill.
- Bundle-aware task detail: open a bundle anywhere (incl. search) to see/add/remove
  its chores, with a running points total; Edit routes to the bundle editor.

## My To-Do
- Personal-only (no "everyone" scope). Layout picker: Classic / Calm / Rings /
  (Kanban hidden). "Bundles in progress" card surfaces drafts for chore-adding.

## Points, levels, seasons, leaderboard
- Wallet (`member.points`, spendable) vs lifetime (`member.lifetimePoints`) vs
  **season** points (lifetime − seasonBaseline, the leaderboard/rank number).
- 60-day rolling season ladder (`GameRulesStore`, envelope-encoded in
  `routinesJSON` + `seasonEpoch` for forced resets). Currently Season 1.
- 3 non-medal tiers (🌱 Sprout / 🔥 Ember / 💎 Diamond); medals reserved for rank.
- Leaderboard: podium + PARTICIPANTS list (alphabetical, stable for give-points),
  per-row **wallet chip** (💰, distinct from the season-points bar), admin +/- adjust.

## Rewards / goals
- Reward requests (kids submit → admins approve). **Approve = redeem**: sets
  `isRedeemed` + debits the wallet (lifetime untouched, so rank is preserved).
- Pending cards show requester avatar/name/wallet + "can't afford" flag.
- One-tap **Redeem** button on in-flight inbox rows (legacy approved-but-not-redeemed).
- Curated redeem catalog (Grid/List/Sheet) + admin REDEEMABLE ITEMS editor.
- Whole-family group goals (`_family` = sum-based milestone). **NEW (staged):**
  "Everyone pitches in" goals (`_everyone` = unlocks when every member hits a
  per-member bar).

## Admin Big Board (admin-only)
- Summary band (chores today / overdue / approvals / points this week).
- TODAY events, OVERDUE chores, THIS WEEK events, REMINDERS section.
- **CHORES per member**: tap a member to expand their full chore list with
  per-chore done/open/overdue status, due-date label, and points.

## Calendar / Schedule
- FamilyEvent model; Schedule tab; Apple Calendar mirror via `CalendarLinkService`
  (opt-in, per-device). Per-event notify audience (Household / Admins / attendee).
- Family outings (Family-category container TaskItems) **tie to the calendar**:
  "Add to Schedule" creates a paired FamilyEvent; supports **multi-day** ranges
  (separate Starts/Ends pickers).

## Notifications
- Local notifications for reminders, events, due chores; weekly recap; **daily
  morning briefing** (now names the first event, top streak, pending requests).
- Announcement banner (StatusPing → household push, 24h or until cleared).
- **Admin completion push**: when a kid finishes a chore on their device, admins
  get a local push (cross-device via the remote-change pipeline; admin-gated,
  self-excluded, chore-categories only, quiet-hours-respected, first-run seeded).
- Orphaned-notification sweep for deleted tasks/chores.

## Other
- Universal search; Streaks & Badges; family map / location sharing; grocery list;
  trips; Settings as a swipe-over page (cog removed); quick-add (+) opens add screen.
- Home Screen + Lock Screen widgets (CasalistWidgets extension).
- Dual-bundle dev/prod setup (`com.gbrown10.casalist.dev` "Casalist Dev" vs
  `com.gbrown10.casalist`).

---

# In Flight (built/staged, NOT yet on TestFlight)

Targeted for **TF 3 (22)** — the "supercharge" batch. All committed-locally or
staged; `origin/main` is current through 3 (21).

- **App Intents v1** — Create chore / Add outing / Mark chore done / Redeem reward
  intents + AppShortcutsProvider phrases (Siri / Shortcuts / Spotlight). Works on
  iOS 26. Files in `casalist/Intents/`.
- **Notification action buttons** — "Mark Done" swipe action on chore pushes.
- **Photo-proof chore completion** — `requiresProof` toggle + `proofImageData`
  capture (`ProofCaptureSheet.swift`). **BLOCKED on schema deploy**: `CD_requiresProof`
  + `CD_proofImageData` + `CD_proofImageData_ckAsset` are imported into **Dev**
  CloudKit but NOT yet deployed Dev→Prod (Console sign-in pending). Must deploy
  before any Release build writes these fields.
- **Richer daily briefing** + **"Everyone" group rewards** — built, staged.

## Blocked
- **Apple Watch companion** (kid + parent) — not built; needs a one-time Xcode
  GUI provisioning pass to create the watch-target App ID before headless builds work.

---

# AI scaffolding (present, unwired)
- `AIService.swift` — a three-tier router (Apple on-device FM / PCC / Claude proxy),
  **BUILT but UNWIRED**, nothing calls it. Forward-looking; cloud tiers stay dark.
- `docs/IOS27_SDK_ADOPTION.md` — grounded iOS-27 API adoption plan (App Intents,
  WidgetKit glass/relevance/push, ActivityKit scheduled-start, EventKit typed
  notifications, CloudKit identity lookups). FoundationModels deferred. Xcode 27
  beta is installed at `/Applications/Xcode-beta.app`; TF/Release stays on 26.4.1.

---

# Architecture Notes
- Modular SwiftUI views; `CasalistCottage.swift` is the large multi-tab root (Home /
  Rewards / MyToDo / Schedule / etc.) — split is parked (Area 8 in the refactor review).
- Core Data model defined in code (`CasaCoreData.swift` via the `attr(...)` helper).
- **Schema rule**: adding `@NSManaged` / `attr(...)` is a CloudKit schema change —
  must deploy Dev→Prod via the Console before the TF that writes it. Enforced by the
  `Preflight: CloudKit schema gate` Release build phase (`scripts/cloudkit-schema-diff.sh`).
- **DON'T touch** `runDedupePipeline` (must stay `newBackgroundContext()` +
  `automaticallyMergesChangesFromParent` + `bg.perform`) — the `performBackgroundTask`
  variant empirically breaks Production CKShare sync.

---

# Near-term Priorities
1. Sign into CloudKit Console → deploy photo-proof schema Dev→Prod → ship TF 3 (22).
2. Unblock + build the Apple Watch companion (provisioning pass first).
3. Decide App Intents depth (iOS-26 path is live-ready now).
4. iPad build backlog (`casalist_ipad_backlog.md`) — parked structural work.
