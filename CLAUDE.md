# Casalist

## Logging — read first

Every meaningful action you take gets logged in TWO places. Do not skip this.

1. **Global ticker** (one-liner, append as you work):
   `~/.claude/projects/-Users-geezy/memory/replicants_log.md`
   Format: `[crN · YYYY-MM-DD HH:MM · casaList] summary` (≤90 chars).
   Newest at the **bottom**.

2. **Project journal — Progress Log section below** (paragraph, end of session):
   Newest paragraph on **top**. One per session. Terse — what shipped + the key gotcha future-you needs.

**What to log:** TestFlight builds, commits to main, cross-project edits, feature ships/rollbacks, hard-won gotchas. **What to skip:** read-only inspections, single-typo edits, build-only-no-push, anything visible in `git log` anyway.

**Token-bloat prevention:** the Progress Log keeps the latest **5** entries inline. When you add a 6th, move the oldest into `docs/progress-log-archive.md` (newest on top there too). This caps CLAUDE.md size forever. New Claudes read the inline 5 cheaply and grep the archive only when they need deeper history.

Full protocol: `~/.claude/projects/-Users-geezy/memory/claude_replicants.md`.

## Progress Log

> Newest entries on top. Keep this section terse — one paragraph per session
> covering what shipped and what to know going in next time. When this section
> hits 6 entries, rotate the oldest to `docs/progress-log-archive.md`.

### 2026-05-16 — Post-1.5 feature stack staged for next TF (no schema deploy needed)
Long all-night session after 1.5 shipped. Everything below is in
local commits on `main` ready to ship; no TF push yet, per Geezy's
"I'll tell you when" rule. **No schema changes in this batch** so
the next TF can go out without another CloudKit deploy. Highlights:

**Notifications suite (A–D from Geezy's pick list).**
- Daily morning briefing (`NotificationsManager.scheduleDailyBriefing`)
  — once-a-day roll-up of today's chores + events + pending reward
  requests at user-configurable hour
- Quiet hours — non-critical pushes (assignments, reward requests,
  redemptions, grocery activity, status pings) suppressed during a
  user-defined window. Per-task due-date reminders + daily briefing
  bypass the suppression
- Grocery activity push — when another device adds a grocery item,
  this device pushes "🛒 [name] added to the grocery list — [item]"
  via `detectAndNotifyGroceryActivity`. Fix included: dashboard's
  `addInlineItem` was using `allTasks.first?.household` which
  returned nil for empty households and orphaned items — switched
  to `households.preferredTarget`
- Recurring event push — `scheduleEvent(for:)` was a model field
  without a hook. Now wired so daily/weekly/monthly/yearly events
  fire via repeating `UNCalendarNotificationTrigger`
- Reward request push — already shipping pre-session, just confirmed
- Status pings — "Ping family" megaphone button on Family tab top
  bar opens `StatusPingSheet` with 6 quick-send presets (🚗 On my way,
  🛒 At the store, etc.) + custom message. Storage: a TaskItem with
  `category = "statusping"` syncs via CloudKit; receivers fire
  "📣 [sender] — [msg]" pushes via `detectAndNotifyStatusPings`
- All notification toggles re-wired in Settings via
  `NotificationsSettingsSection` (isolated View struct so the iOS 26
  metadata demangler stays happy)

**Custom repeat picker.**
`RepeatRule` struct encodes JSON inside the existing `repeatKind`
string (`custom:{"i":2,"u":"w","d":6}` → every other Friday).
`CustomRepeatPicker` sheet binds interval (1–12) + unit (minutes /
hours / days / weeks / months) + optional weekday. Both
`AddReminderView` and `AddEventView` get a "Custom…" entry that
opens it. Notification scheduler handles all combinations: hours/
minutes use `UNTimeIntervalNotificationTrigger`, days/weeks at
interval 1 use repeating calendar triggers, intervals ≥ 2 are
one-shot calendar triggers that reschedule themselves after firing
(iOS calendar triggers can't do "every N days" repeating natively).

**Task detail polish.**
- 🙋 Claim pill on unassigned chores (next to the 10pt pill in the
  header). Tap → assigns to you, pill vanishes.
- Confetti celebration wired to Mark done in TaskDetailView. The
  static-star ⭐ overlay was rebuilt — `CelebrationOverlay` now
  spawns 20 rotating stars bursting outward via `.onAppear` (the
  original `.onChange(of: visible)` hook never fired because the
  overlay only exists DURING `visible == true`). Pill removed since
  points are already shown in the task header.

**Live location sharing (Option A).**
- Settings → Privacy → "Share my location with family" toggle.
  Uses `CLLocationManager.startUpdatingLocation()` with
  `kCLLocationAccuracyBest` + 10m distanceFilter. Apple's "significant
  changes" mode was too coarse (~500m, two phones in the same house
  showed hundreds of feet apart).
- Writes throttled (≥10m moved OR ≥30s elapsed) to keep battery +
  CloudKit overhead reasonable. Drops bad fixes (negative accuracy,
  stale >10s, accuracy >100m).
- New `FamilyMember` schema fields (`latitude`, `longitude`,
  `locationUpdatedAt`, `isSharingLocation`) — Production CloudKit
  deploy required before TF.
- Family tab → 📍 pin button opens `FamilyMapView` showing every
  sharing member as a pin with avatar + "now / 3m / 2h" age label.
- Info.plist: NSLocationWhenInUseUsageDescription +
  NSLocationAlwaysAndWhenInUseUsageDescription + UIBackgroundModes
  location.

**Manual location ping (Option C) — built then hidden.**
One-shot GPS fix attached to a ping. Push tap → opens Apple Maps
centered on sender's coord. Worked but tap-to-Maps was unreliable
in testing; gated behind `shareLocationEnabled = false` flag in
`StatusPingSheet`. Live-share covers the same use case.

**Apple Calendar link (Option 1+2 — `CalendarLinkService.swift`).**
- Settings → SCHEDULE picks an Apple Calendar via EventKit. Mirror
  push: every FamilyEvent created/edited in Casalist is written as
  an EKEvent in that calendar with the prefix "Casalist:" in notes.
- Read-only display: that calendar's events appear at the bottom of
  Casalist's Schedule view in a "FROM YOUR APPLE CALENDAR 🍎"
  section, color-tinted by the calendar's color. Filtered to drop
  our own mirrors (notes prefix check) so events don't double-up.
- Per-device — each device decides what to mirror via its own
  `calendarLinkID` AppStorage. Mapping (FamilyEvent.uid → EKEvent
  identifier) lives in UserDefaults so CloudKit doesn't have to
  know about EventKit identifiers.
- One-way only by design — deleting from Apple Calendar leaves the
  Casalist event intact. Geezy's explicit call. Reverse-delete
  detector is in the bullpen if we change our mind.
- Info.plist: NSCalendarsFullAccessUsageDescription. iOS 17+ uses
  `requestFullAccessToEvents`; pre-17 falls back to legacy.

**Family tab overhaul.**
- Inline quick-add bar at top (mirrors Grocery)
- AGENDA section — horizontal scrolling tiles, dashboard style
- OUTINGS section — `AddFamilyTripView` creates a parent TaskItem
  (category=family, dueDate set) that nests child items via
  `parentUid`. Per-card inline "Add a task to this outing…" field
- + button now opens the outing creator instead of single-item add
- Everything tap-to-edit via `TaskDetailView`
- Hero badge + dashboard tile share the same "loose unclaimed
  non-trip" filter via `isFamilyUpForGrabs(_:)` — was previously
  off by the outing itself
- Claim semantics: outings + nested items never claimable.
  `canDelete` rule tightened to `iAmAdmin || iAddedIt`

**Announcements (banner on Family tab).**
- Custom announcements get an Expires picker
  (`AnnouncementExpiry` enum: Push-only / 15 min / 1 hr / 4 hr /
  8 hr / until tomorrow). When set, the message shows as a big
  peach→coral gradient banner at the top of every household
  member's Family tab. Auto-disappears at expiry via
  `dueDate > now` filter.
- Sender taps banner (pencil icon affordance) → StatusPingSheet
  opens in edit mode (`init editing:`). Save commits text + new
  expiry; Delete soft-deletes. Receivers can't edit — only the
  original sender.

**Side-quest crash fixes still in scope.**
- `CloudBackup.snapshot` switched from `stack.context` on a global
  queue → `container.newBackgroundContext()` + `.perform`. Apple's
  documented thread-affine context rule.
- Auto-rejoin URL only cleared on permanent CloudKit errors
  (`.unknownItem`, `.permissionFailure`, `.invalidArguments`,
  `.badContainer`, `.participantMayNeedVerification`). Network +
  account-temporarily-unavailable errors preserve it via
  `shouldClearSavedShareURL(after:)`.
- `Nuke ALL local data` dev button now also clears userName +
  householdName so the welcome screen actually shows on reopen.

**Schema deploy needed before TF:** the `FamilyMember` location
fields (latitude / longitude / locationUpdatedAt / isSharingLocation).
Already in Dev (auto-registered via Debug writes); needs Dashboard
"Deploy Schema Changes…" promote to Production. Script:
`scripts/cloudkit-schema-diff.sh` confirms the delta.

### 2026-05-15 — TestFlight 1.5: identity rebuild on CKUserID + crash trio fixed
Long debug session. Started chasing a duplicate "Dakoda" record on the
joiner side that wouldn't dedupe; ended up rebuilding the identity
foundation and fixing two unrelated crashes that had been masquerading
as Settings bugs.

**Headline architectural change**: `FamilyMember` now carries a
`cloudKitUserID` field (the iCloud user record ID via
`CKContainer.userRecordID()` / `CKShare.Metadata.share.currentUserParticipant.userIdentity.userRecordID`).
That ID is stable per-Apple-ID-per-container across app reinstall,
device change, and name changes — confirmed in Apple Forums thread
114322 and verified end-to-end on two physical iCloud accounts.
Dedupe is keyed on it via `FamilyDedupe.mergeByCloudKitUserID`.
Legacy records (synced down from pre-1.5 CloudKit data) get their ID
copied from any stamped same-name same-household sibling via
`mergeLegacyNameDupes` — non-destructive, so no soft-delete sync
ping-pong between devices.

**Two crashes traced via .ips files, neither was where it looked:**

(1) `FRONTBOARD 0x8BADF00D` scene-update watchdog kill — looked like
a Settings crash, was actually the foreground dedupe pipeline calling
`context.save()` on the main `stack.context` which synchronously
triggered a SQLite WAL checkpoint on the shared store's SQLQueue
while CloudKit was also working it. Blocked >10s. Fixed: entire
dedupe pipeline now runs on a private-queue background context via
`runDedupePipeline()` (`container.newBackgroundContext()` +
`.perform`). Lifted from Apple's documented pattern.

(2) `EXC_BAD_ACCESS` stack-guard overflow on iOS 26 in
`SettingsView.developerShareTools.getter` — Swift metadata demangler
ran out of call-stack space walking the generic `TupleView` produced
by inlining ~35 children (5 toggles + 13 actionButtons + dividers +
conditionals) into one VStack body. Fixed: extracted
`DeveloperSettingsSection` into its own file with 7 separate sub-View
structs (`DevStatsBlock`, `DevSchemaBlock`, `DevShareInspectBlock`,
`DevShareResetBlock`, `DevNukeBlock`, `DevOwnerBlock`, `DevWipeBlock`
+ tiny `DevDivider`/`DevInfoRow`/`DevActionRow` primitives). Each
nominal View type bounds its own body's TupleView so the demangler
never recurses deep enough to overflow.

**ChatGPT P1/P2 caught in the same session:**
- CloudBackup was using `stack.context` (main-thread-bound) from
  `DispatchQueue.global` — random crash risk. Fixed: backup runs on
  `container.newBackgroundContext()` via `.perform`.
- `attemptAutoRejoinSavedShare()` was wiping the saved share URL on
  ANY CloudKit fetch error. A single bad-wifi launch could
  permanently brick rejoin. Fixed: only clear on permanent codes
  (`.unknownItem`, `.permissionFailure`, `.participantMayNeedVerification`,
  `.invalidArguments`, `.badContainer`). Transient errors preserve
  the URL — see `shouldClearSavedShareURL(after:)`.

**Test matrix that passes 100% on two physical accounts**
(iPhone Air / geezy + iPhone 15 / dakoda):
1. Fresh nuke → welcome → AirDrop → accept → mirror state, no dupes
2. Joiner reinstall → auto-rejoin via saved URL → same CKUserID
   stamped, no dupes
3. Owner deletes joiner → joiner reopens → restores cleanly, NO
   infinite cycle (the previous version sync-looped delete-restore)
4. Owner nukes + re-invites → identity reconverges via stable
   CKUserID, fresh CKShare, no dupes either side

**Shipping mechanics:**
- Production CloudKit schema deploy (CD_cloudKitUserID + 3 indexes
  on CD_FamilyMember) via Dashboard's "Deploy Schema Changes…"
  driven through Chrome MCP — first time we've done that step
  programmatically rather than by hand.
- 1.5 archive + altool upload via the standard `scripts/...`
  workflow. Build state VALID, en-US "What to Test" notes posted.
- home group auto-distribute is ON, so geoff/Donovan/Dakoda/Lorena
  pick it up automatically once Apple finishes processing.

**Quality of life carried in this build:**
- Daily morning briefing scheduler + Settings toggle (scheduler
  runs, UI is built but unwired pending design pass)
- Quiet hours (suppress non-critical pushes during user-defined
  window — affects `detectAndNotifyAssignments`,
  `detectAndNotifyPendingRequests`, `detectAndNotifyRedemptions`)
- Recurring `FamilyEvent` notification scheduling (model field
  existed, hook was missing — now `scheduleEvent(for:)` wires daily
  / weekly / monthly / yearly via repeating
  `UNCalendarNotificationTrigger`)
- New dev buttons: Dump state to share log, Nuke ALL local data,
  Merge duplicate households, Move me into shared store, Demote me
  to standard, Reset share (owner)
- Share-log rotation at 100KB so the sync-log reader doesn't freeze
- Default palette is now `vivid` on first launch

**Going-in-next-time notes**: there's a real "kick member" flow
still missing — currently owner-side delete is reversed by the
joiner's self-heal because we don't remove the CKShare participant.
Need `share.removeParticipant` + soft-delete + confirm dialog.
Parked.

### 2026-05-15 — TestFlight 1.4: family sharing actually works across Apple IDs
The headline bug, found after hours of "Item Unavailable" recipient
errors, turned out to be one line in `InviteFamilyView.swift`:
`share.publicPermission = .none` combined with `share(_:to: nil)` meant
every CKShare ever sent was locked to participants we never added —
link-based join was impossible by definition. Fix: set `.readWrite` and
explicitly persist the share back via `CKModifyRecordsOperation`
(NSPersistentCloudKitContainer's `share()` saves the initial CKShare
but not subsequent mutations to publicPermission or title). Ancillary
fixes layered on:
(1) joiners always land as `.standard` role — owner stays reserved for
the share creator. Scene delegate auto-create demotes any pre-existing
same-name local FamilyMember so a pre-share owner role can't bleed in;
(2) foreground self-heal `ensureMeInSharedHousehold` — if the device is
joined to a shared household but no live `FamilyMember` matching
`userName` exists in it, restore a soft-deleted one or create a fresh
one in the shared store. Fixes "owner deleted me and now I'm gone";
(3) `addJoinerAsFamilyMember` restores soft-deleted same-name records
instead of bailing — without this, an owner-delete-then-joiner-reinstall
left the joiner invisible everywhere;
(4) `FamilyDedupe.mergeSameNameDupesInHousehold` collapses any same-name
pair within a household, prioritizing the SHARED-store record as
survivor so the surviving "me" actually syncs across devices;
(5) new dev buttons in Settings → DEVELOPER: "Merge duplicate
households", "Move me into shared store", "Demote me to standard",
"Reset share (owner) — delete existing CKShare" — collectively let us
repair edge cases in the field without a code change;
(6) InviteFamilyView button copy is now just "AirDrop" with the
`iphone.radiowaves.left.and.right` SF Symbol. Two-account test on
iPhone Air (geezy) + iPhone 15 (dakoda) passed end-to-end: fresh
AirDrop accepted cleanly, both names visible on both devices, roles
set correctly. Build uploaded via standard "testflight it" flow.

### 2026-05-15 — TestFlight 4.0 shipped: Kid mode + themes + push quartet
Big session. TestFlight build `4.0` (MARKETING_VERSION + CURRENT_PROJECT_VERSION
both bumped from `1`/`3.9` to `4.0`) uploaded with eight major shipping
features: (1) Kid-mode "starfield" UI auto-activates for FamilyMembers
with `role == .kid` — full-screen alt to the adult shell with big-tap
chore tiles, goal shelf, "MY WINS" log, "Ask for a reward" submit flow,
confetti + UINotificationFeedbackGenerator haptic on every completion;
(2) user-selectable theme picker in Settings → Appearance with three
palettes (`ember` default, `vivid`, `anchor`) — each top-level view
declares `@AppStorage("paletteName")` so palette swap propagates
instantly to every screen (without that observer the dashboard stayed
stale until refresh); (3) push notification quartet — task assigned,
reward requested, reward redeemed, weekly Sunday recap — all wired
into `.NSPersistentStoreRemoteChange` and deduped via UserDefaults UID
sets so local saves don't self-notify; (4) WHAT'S NEW feed merges
completions + redemptions, sorted by `completedAt`/`redeemedAt` not
`createdAt`, and shows "X added Y to Z" when a creator assigns to
someone else; (5) goal redesign — requesters write a label + optional
"why" note, admins set the price at approval time in Inbox; (6)
dashboard polish — `Home` tile replaces Maintenance (bundles both
home + maintenance categories with a pill toggle), quick-add chips
with clear-all, admin Mine/Everyone scope toggle on My To-Do,
pull-to-refresh on every ScrollView, collapsed adult shell from 4
tabs to 2 (Home + Rewards); (7) new app icon — AI-generated dark
slate house + checklist composition, prepped via ImageMagick (no
Photoshop) — tight crop, fuzz-bounded `-opaque` to kill checker
pattern, low-fuzz corner floodfill for antialiasing cleanup, alpha
off; (8) celebration overlay reworked — confetti now actually
animates (was rendering already in final state because the overlay
was conditionally inserted into the view tree — fixed with a
separate `confettiFlying` phase driven via `withAnimation` after a
50ms delay so the view exists long enough to animate FROM the
initial state). **Schema deploy Dev → Production** for three new
CloudKit fields (`CD_TaskItem.CD_completedAt`,
`CD_FamilyGoal.CD_note`, `CD_Household.CD_routinesJSON`) executed
via the Chrome MCP browsing the CloudKit Dashboard directly — Geezy
authorized it explicitly so I clicked the Deploy button. Two new
scripts shipped: `scripts/verify-testflight-schema.sh` (cktool-based
preflight check) and `scripts/set_testflight_notes.py` (PyJWT +
urllib, no `requests` dep — posts "What to Test" to the
betaBuildLocalization). Notable gotcha: Apple's `filter[version]=4.0`
in the App Store Connect API matches stale "4" builds — fixed in
the script by fetching recent + exact-string filtering client-side.
DEBUG-gated features still in code for later builds: routines, team
goals, family stats, avatar tier emblems (the LeveledAvatar tier
ring ships; just the corner medal is suppressed on top-bar +
standings).

### 2026-05-14 — Multi-user family sharing actually works (Option A complete)
Two-account share is verified working end-to-end on iPhone Air ↔ iPhone 15
(different Apple IDs). The data layer was rewritten from SwiftData to Core
Data + `NSPersistentCloudKitContainer` with a private store and a shared
store. Sharing routes through Apple's `container.share(_:to:)` + a custom
`CasalistSceneDelegate` that catches CKShare accept callbacks (SwiftUI's
default scene delegate drops them — this was the main misconception).
On accept, a `FamilyMember` is auto-created in the shared household using
the joiner's `userName` AppStorage, so the inviter sees them immediately
with no manual add step. Recipient-side writes now use
`moc.assign(_, toStoreOf: household)` so they land in the shared store
instead of silently falling into the joiner's private store. CloudKit
Production schema was redeployed (added `CD_Household` + `CD_household`
relationship + share-related system fields like `CD_moveReceipt`) via the
Dashboard. App is on dev build with `MARKETING_VERSION=1`,
`CURRENT_PROJECT_VERSION=3.8`. Pushed directly to both phones via
`devicectl` — no TestFlight in the iteration loop per Geezy's preference.
Tag `broken-arrow` (commit `95ed13e`) preserves the pre-rewrite state if
rollback is ever needed. See "CRITICAL: multi-user family sharing" below
for the architecture rules.

## Overview
Casalist is a private family household management app for iOS.

The app is built in SwiftUI and uses:
- Core Data via NSPersistentCloudKitContainer (private + shared stores)
- CloudKit (private + shared database scopes, CKShare-based sharing)
- SF Symbols
- Apple-native UI patterns

Earlier iterations used SwiftData @Model; that approach was abandoned because
SwiftData's `.private` scope is per-Apple-ID and could not deliver the
headline family-sharing feature. See the "Progress Log" entry for 2026-05-14
and the "CRITICAL: multi-user family sharing" section.

## Goals
- Keep the app simple and fast
- Prioritize native iOS design
- Avoid unnecessary complexity
- Build features incrementally

## Coding Style
- Use modular SwiftUI views
- Prefer reusable components
- Keep files reasonably small
- Use clear naming
- Avoid unnecessary comments

## Current Features
- Dashboard
- Task creation
- Grocery list
- Personal task filtering

## Important Files
- `CasalistApp.swift` → app entry point
- `ContentView.swift` → dashboard
- `TaskItem.swift` → data model
- `AddTaskView.swift` → task creation

## Workflow
- Read existing code before modifying architecture
- Preserve CloudKit compatibility
- Prefer editing existing components over creating duplicates

## CRITICAL: multi-user family sharing

**Casalist is a family app where multiple iCloud users need to see the same data.** That requirement is load-bearing — the entire concept of "household" is meaningless if family members each see their own private silo. Any feature that touches FamilyMember, TaskItem, FamilyGoal, ChoreTemplate, or FamilyEvent has to assume those records will be visible to people on different Apple IDs.

### What's wrong today (as of 2026-05-14)

The current data layer uses `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.gbrown10.casalist"))`. **SwiftData's `.private` scope is a per-Apple-ID silo.** It syncs across one user's iPhone + iPad + Mac, but it does NOT share data across users. The "Invite family" flow creates a CKShare on a placeholder `Household` CKRecord in a custom zone — but no SwiftData records ever land in that zone. So when a recipient accepts a share, they get an empty Household record and their own private silo continues unchanged.

This means:
- The owner's family/tasks/goals are invisible to anyone they invite.
- The recipient's family/tasks/goals are invisible to the owner.
- All the "admin can give points" / "role-based permissions" UX is currently single-device theater.

### Why this got built the wrong way the first time

This is the prior Claude (me) writing this section. The mistake was:

1. **Stacking features without validating the foundation.** When Geezy asked for invites, the right move was to stop and ask "does the data layer even support multi-user visibility?" Instead I built a slick `UICloudSharingController` flow on top of SwiftData's per-user-private store and called it done because the UI worked. The UI worked; the data didn't move.
2. **Choosing SwiftData out of consistency instead of capability.** SwiftData was already used for the rest of the app, so I reached for it for the shared data too. SwiftData's CloudKit-sharing surface is still partial and partly undocumented as of iOS 17–18, while `NSPersistentCloudKitContainer` (Core Data) has a battle-tested `share(_:to:)` API that Apple's own apps (Reminders, Notes) use. The right call was to either (a) migrate the shareable models off SwiftData onto Core Data, or (b) use a code-based public-zone scheme. I did neither.
3. **Treating "it compiles and the sheet opens" as proof of correctness.** I didn't test a real cross-iCloud-account accept flow until very late, and when Geezy reported failures I kept patching the symptom (build numbers, `CKSharingSupported`, schema deploys) instead of stepping back to see that the underlying store wasn't shareable in the first place.

If you (future Claude) are about to add ANY feature that touches family data, **read this section first** and don't paper over it with more UI. The data layer needs to be fixed before more invitation/role/sharing features mean anything.

### The two paths forward (Geezy chose one of these on 2026-05-14)

**Option A — Apple-managed shared mailbox.**
Migrate shareable models to `NSPersistentCloudKitContainer` (Core Data) and use `share(_:to:)` to put records into a shared zone. Recipients accept via the standard CKShare flow; their app reads the shared zone. End-to-end private through iCloud, Apple manages permissions. Cost: every `@Query` in the app becomes `@FetchRequest`, every `@Model` becomes an `NSManagedObject`, the schema migration is non-trivial. 4–6 hours of careful work, multiple TestFlight cycles to validate.

**Option B — Household-code via CloudKit Public DB.**
Each household gets a code (UUID or short string). Records live in the CloudKit public database with a `householdID` field. Family members enter the code to "join" — their app subscribes to records matching that ID. No CKShare flow, no Apple-managed permissions. Cost: data is technically readable to anyone who knows the code, so don't put anything sensitive in there. For a chores/groceries/schedule app this is acceptable. 2–3 hours, simpler to debug.

**Both options require ripping out the current InviteFamilyView CKShare flow.** Don't try to layer either approach on top of the existing single-user SwiftData store — that's how we got here.

### Rules for any future "family sharing" work

- Never assume SwiftData's `.private` scope shares data across users. It doesn't.
- Before adding any feature that says "everyone sees", verify with a two-Apple-ID test (Geezy's iPhone Air + iPhone 15) that the data is actually visible on both sides. UI-only validation is not enough.
- If using Option A: the underlying `NSPersistentCloudKitContainer` is what does the work — the SwiftData wrapper just hides it.
- If using Option B: every shareable record must have a `householdID` field, and every Query must filter on it. Records without that field are orphans.
- The `CKSharingSupported = YES` Info.plist key only matters for Option A. Setting it without backing data sharing logic does nothing — it just removes one of the "you need a newer version" errors.
- Xcode's `INFOPLIST_KEY_*` build-setting prefix does NOT honor `CKSharingSupported`. Use an explicit `Info.plist` file at the project root with `INFOPLIST_FILE = Info.plist` and `GENERATE_INFOPLIST_FILE = NO`. (Burned on this; the key was silently dropped in builds 3.2 and 3.3.)

### Rules for every future Claude opening this repo

**Rule 1 — Two-account test is the only proof.**
No family-sharing feature is "done" until Geezy has installed it on two devices logged into two different iCloud accounts and confirmed a record created on device A appears on device B within 30 seconds. "It compiles," "the sheet opens," "the invite sends," and "the build uploads" are not proof. Two-account observation is proof. Don't claim a sharing feature is done without it.

**Rule 2 — Validate the foundation before stacking features.**
Before adding any new family-facing feature (invites, roles, permissions, leaderboards, shared lists, anything that says "everyone sees"), stop and verify the data layer actually shares data. If the data layer is broken, building UI on top of it is theater and makes the eventual fix harder. The first question on any family-feature request is "does the store under this support multi-user visibility?" not "what does the screen look like?"

**Rule 4 — Don't trust prior sessions. Run the 5-minute trust check.**
Future Claudes: assume the data layer is broken for multi-user sharing until you've personally verified it. The 5-minute trust check:

1. **Read the data-layer file.** Find where `ModelContainer` / `ModelConfiguration` / `NSPersistentCloudKitContainer` is set up. Look at the scope:
   - `cloudKitDatabase: .private(...)` → single-user silo. Sharing is broken. Stop.
   - `NSPersistentCloudKitContainer` + `share(_:to:)` calls somewhere → likely Option A. Continue to step 2.
   - `CKContainer.default().publicCloudDatabase` + `householdID` filter on every fetch → likely Option B. Continue to step 2.
2. **Grep for the field that proves the chosen path.**
   - Option A: `share(_:to:)` should appear at least once in the codebase.
   - Option B: every `@Query` / fetch must include a `householdID == X` predicate. Even one unfiltered query leaks data across households — treat that as broken.
3. **Check `replicants_log.md` for a recent "two-account verified" entry.** If the most recent data-layer entry doesn't include explicit two-account verification, the layer is unverified — treat it as broken.
4. **If still unsure, ask Geezy to run the test.** Tell him: "Install on two devices on two iCloud accounts. Create a task on device A. Does it appear on device B within 30 seconds?" Yes = trust. No = broken, stop and report.

The cost of a 5-minute check is far smaller than the cost of stacking 4+ hours of UI on a broken foundation and shipping theater. The prior session (cr2, 2026-05-13) did exactly that. Don't repeat it.

## Dependencies

- **CasaGlassKit** — reusable Swift package for the Casa Glass design system.
  - Repo: https://github.com/geezy14/CasaGlassKit (private)
  - Add via Xcode → File → Add Packages → paste the URL above. Auth uses the GitHub account set up in Xcode → Settings → Accounts (PAT).
  - Import with `import CasaGlassKit`.
  - Provides: `.casaCard()` modifier (the casaglass3 neutral-card chrome), `AppBackgroundView` (gradient or user-picked photo background), `BackgroundImageStore` (photo persistence), 8 built-in gradient presets, `.cardBackground()` view extension.
  - **casaglass3 is the frozen standard.** Do not modify the kit's implementations in place. If different behavior is needed, cut a new version (casaglass4) in a separate commit with its own evolution-doc entry.
  - The kit assumes the host app sets these `@AppStorage` keys: `glassEnabled` (Bool), `customBgEnabled` (Bool), `customBgRevision` (Int), optionally `appBackground` (String).

### Things NOT in CasaGlassKit (build per-app if needed)
- `AppTheme` enum / accent color picker
- `Haptics` helper
- App-specific Casa surfaces (entry sheet, Money Year, etc. — those live in casaBills2)

## Build Target

- Scheme: `casalist`
- Project: `casalist.xcodeproj`
- Bundle ID: `com.gbrown10.casalist`
- Physical devices (both paired wirelessly):
  - **iPhone Air** (primary dev / inviter test device): UDID `9A471194-E5FA-5B11-82F9-178E5612C19C`, device name `geezy`
  - **iPhone 15** (second account / share recipient test device): UDID `62C1F8BD-F78E-523B-929A-CC780C68595B`, device name `iPhone`
- Geezy gets builds on the iPhone 15 via direct Xcode/devicectl push (NOT TestFlight) for the two-account sharing test loop. TestFlight uploads only when explicitly requested.
- Working directory: `/Users/geezy/Documents/casaList`

## Deploy Workflows

### "push it" — wireless deploy to Geezy's iPhone

When Geezy says "push it" (or similar), push to the iPhone Air (primary dev device) from `/Users/geezy/Documents/casaList`:

```bash
xcodebuild -project casalist.xcodeproj -scheme casalist -configuration Debug \
  -destination 'id=9A471194-E5FA-5B11-82F9-178E5612C19C' \
  -derivedDataPath build -allowProvisioningUpdates

xcrun devicectl device install app --device 9A471194-E5FA-5B11-82F9-178E5612C19C \
  build/Build/Products/Debug-iphoneos/casalist.app

xcrun devicectl device process launch --device 9A471194-E5FA-5B11-82F9-178E5612C19C \
  com.gbrown10.casalist
```

### "push both" / "push to 15 too" — also deploy to iPhone 15

When Geezy needs both devices on the same build (always for the two-account sharing test), also push to the iPhone 15 (separate `-derivedDataPath build-iphone15` so the build artifacts don't collide with the iPhone Air ones):

```bash
xcodebuild -project casalist.xcodeproj -scheme casalist -configuration Debug \
  -destination 'id=62C1F8BD-F78E-523B-929A-CC780C68595B' \
  -derivedDataPath build-iphone15 -allowProvisioningUpdates

xcrun devicectl device install app --device 62C1F8BD-F78E-523B-929A-CC780C68595B \
  build-iphone15/Build/Products/Debug-iphoneos/casalist.app

xcrun devicectl device process launch --device 62C1F8BD-F78E-523B-929A-CC780C68595B \
  com.gbrown10.casalist
```

If install/launch fails with "unavailable" or a network timeout, the phone went to sleep or wifi dropped. Retry after a few seconds.

### "testflight it" — archive + upload to TestFlight

When Geezy says "testflight it" (or similar):

1. Commit current changes to `main` (do NOT push to remote unless Geezy explicitly says to push).
2. Bump `CURRENT_PROJECT_VERSION` (build number) in `casalist.xcodeproj/project.pbxproj` — must be higher than the last TestFlight build, never reuse.
3. Write release notes to `testflight-notes-<build>.txt` at the project root (covers What's New + What's Fixed + What to Test).
4. Archive Release config:
   ```bash
   xcodebuild -project casalist.xcodeproj -scheme casalist -configuration Release \
     -destination 'generic/platform=iOS' \
     -archivePath build/casalist.xcarchive archive -allowProvisioningUpdates
   ```
5. Export the IPA using the App Store Connect API key (this is the critical trick — without these flags, export fails because no iOS Distribution cert is in the local keychain):
   ```bash
   xcodebuild -exportArchive \
     -archivePath build/casalist.xcarchive \
     -exportPath build/export \
     -exportOptionsPlist ExportOptions.plist \
     -allowProvisioningUpdates \
     -authenticationKeyID RSZWNZ7YL3 \
     -authenticationKeyIssuerID 69a6de73-6a85-47e3-e053-5b8c7c11a4d1 \
     -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_RSZWNZ7YL3.p8
   ```
   The `-authenticationKey*` flags pull the iOS Distribution cert via the API on the fly. Don't skip them.
6. Upload to App Store Connect:
   ```bash
   xcrun altool --upload-app -f build/export/casalist.ipa -t ios \
     --apiKey RSZWNZ7YL3 --apiIssuer 69a6de73-6a85-47e3-e053-5b8c7c11a4d1
   ```
7. (Optional) Set the "What to Test" notes on the build via the API. Write a small Python script using PyJWT to call the App Store Connect API and PATCH the build's `betaBuildLocalizations` with the contents of `testflight-notes-<build>.txt`. See casaBills2 history for a working `set_testflight_notes.py` template — the auth flow is identical, just swap the bundle ID filter to `com.gbrown10.casalist`.

### ExportOptions.plist

Should live at the project root. Required contents:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>destination</key>
    <string>export</string>
    <key>uploadSymbols</key>
    <true/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>57Z9HL3SZJ</string>
</dict>
</plist>
```

Team ID `57Z9HL3SZJ` is the team that owns the store provisioning profile for `com.gbrown10.*` apps. If a different team owns this app, replace it.

### CloudKit schema deploys (when you change a @Model)

When you add a new `@Model`, add a stored property to one, or rename/remove
fields, the Production CloudKit schema must be updated or sync will silently
fail across devices.

**Full playbook**: `docs/cloudkit-schema-workflow.md`

**Quick check** — does Production match Dev?
```bash
scripts/cloudkit-schema-diff.sh
```

**Quick deploy** (only when the script reports differences):
1. Remove the `com.apple.developer.icloud-container-environment` key from
   `casalist/casalist.entitlements` so Debug builds hit Dev CloudKit.
2. Build/install and exercise each new model on the phone so SwiftData
   writes a record (Dev auto-registers schema from writes).
3. Verify with `scripts/cloudkit-schema-diff.sh` — Dev should now have the
   new types.
4. Open https://icloud.developer.apple.com/dashboard → switch env to
   **Development** → sidebar "Deploy Schema Changes…" → **Deploy**.
5. Restore the entitlement (`Production`) and rebuild.

`cktool import-schema --environment PRODUCTION` does NOT work — only the
Console's "Deploy Schema Changes…" promotes Dev → Prod. The management
token is saved in the keychain via `xcrun cktool save-token --type management`.

### App Store Connect API credentials (shared across all of Geezy's apps)

- **Issuer ID**: `69a6de73-6a85-47e3-e053-5b8c7c11a4d1`
- **Key ID**: `RSZWNZ7YL3`
- **.p8 path**: `~/.appstoreconnect/private_keys/AuthKey_RSZWNZ7YL3.p8`
- **Apple ID**: gbrown10@me.com
- Treat these as credential-adjacent — don't echo into chat unnecessarily.

### Pre-flight checklist for the first TestFlight build of casaList

The first time you "testflight it" for casaList, verify these exist (the next Claude likely won't have built TestFlight for this app yet):

- [ ] App record created in App Store Connect for bundle ID `com.gbrown10.casalist`
- [ ] App Store provisioning profile for `com.gbrown10.casalist` exists under team `57Z9HL3SZJ` (Xcode → automatic signing will create it on first archive if signed in)
- [ ] `ExportOptions.plist` present at project root (see template above)
- [ ] `CURRENT_PROJECT_VERSION` bumped from the previous TestFlight upload

If the export step fails with "No profiles found" or "No signing certificate iOS Distribution found", the `-authenticationKey*` flags are missing or pointing at the wrong key file.