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

> **Versioning rule reminder:** `MARKETING_VERSION` stays put across builds.
> Only `CURRENT_PROJECT_VERSION` bumps per TestFlight upload. See the
> "testflight it" section below for the full rule. **Do not bump
> `MARKETING_VERSION` without Geezy asking.**

### 2026-05-20 — TF 3.0 (7) (8) (9): tier rework, level/economy rebalance, recurring + notification fixes

Long bug-fix + game-design day. Three TFs shipped, all on `main`,
**all local/display/logic — zero schema change, no CloudKit deploy**.
Devices kept in sync via direct `devicectl` dev-build pushes to Air +
iPhone 15 throughout (dev bundle `com.gbrown10.casalist.dev`).

**TF 3.0 (7)** (UUID `593a6f1d`) — recurring quests clear from ACTIVE
QUESTS after completion; Repeats row humanized (was raw
`Custom:{...}` JSON → now "Every weekday" via `RepeatRule.label`);
item URLs on reward requests (both free-form `AddGoalView` + curated
catalog), packed into the existing `FamilyGoal.note` via `GoalLink`
(no schema) + `RedeemableItem.url` in the routinesJSON envelope.

**TF 3.0 (8)** (UUID `e2a803b8`) — no-due-date recurring quests now
clear (completedAt + cadence fallback); repeat-picker instant-close
fixed (sheet was on a Section inside a conditionally-rendered form /
3 stacked `.sheet` mods → moved to top-level + separate `Color.clear`
hosts); custom/weekday recurrence now advances on completion
(`FamilyPoints.nextOccurrence` routed through new
`RepeatRule.nextDate(after:)` — legacy switch only knew daily/weekly,
custom:{} + "weekdays" fell through to default and never rolled);
haptics one-per-completion (was 3 per check-off → tripped iOS's
system haptic throttle, which survives force-quit; collapsed to the
single celebration-overlay haptic).

**TF 3.0 (9)** (UUID `c7b685a2`) — the big game-design rework:
- **Tiers: 5 medal tiers → 3 non-medal tiers** 🌱 Sprout (Lv 1-3) ·
  🔥 Ember (Lv 4-7) · 💎 Diamond (Lv 8-10). Medals (🥉🥈🥇) collided
  with leaderboard placement; now reserved for rank only.
- **Avatar tier matches level**: leaderboard avatars pass an explicit
  `overrideLevel` computed beside the rank label so the ring/emblem
  can't diverge (was showing Bronze for a Level-6 "Achiever").
- **Level curve rebalanced** gentle-early/steep-late, **Legend
  2,700 → 1,300** (`[0,25,60,110,180,280,420,620,940,1300]`) so the
  top number feels reachable to a kid.
- **Reward economy rescaled** to 15-pt base chore: `pointsPerDollar`
  10 → **5** ($70 = 350 pts ≈ 24 chores @15), tiers 50/150/375,
  redeem catalog ~halved, category points capped at 15.
- **One-time household migration**: `HouseholdRulesEnvelope` gained
  `rulesVersion` (JSON in existing routinesJSON, **not a CD attr**);
  on attach, if version < current it rescales rules in place
  (preserves custom items) and stamps the version — runs once per
  household, deterministic so concurrent devices converge. **This is
  how prod households pick up the new economy: automatic on first
  launch of (9).**
- **Orphan event-notification cleanup**: `syncEventsFromContext` now
  cancels pending `event-*` pushes whose uid is no longer a live
  event — fixes a deleted/renamed event ("school out") still firing
  when only "early out" remains. Earlier `cc85d20` dedupe only
  caught dupes with identical title+time; diverged ones slipped.
- Personal Card **share sheet** fixed (2 stacked `.sheet` mods → own
  host); `docs/HOW-CASALIST-WORKS.md` added (points/levels/tiers/
  streaks/badges/economy overview).

**Earlier this session**: shipped TF 3.0 (5)+(6), 6/10 refactor-review
areas, and pointed **geezyg.com apex → Vercel** (disabled Cloudflare
Parking Page, `A @ 76.76.21.21` DNS-only via Chrome MCP; OG card meta
repointed subdomain→apex). See the prior entry.

**Dos/donts going in**:
- **DO** post TF notes immediately after upload — poll the build every
  ~30s until visible, don't pre-schedule a 15-min wakeup (Geezy's call).
- **DO** keep `MARKETING_VERSION = 3`, integer build bumps only.
- **DON'T** assume avatar tier == placement. Tier = level (lifetime
  pts); placement = leaderboard rank. They use different visuals now.
- **DON'T** reach for a Core Data schema change when JSON-in-an-
  existing-field works (GoalLink in `note`, rules+rulesVersion in
  `routinesJSON`) — keeps TFs deploy-free.
- Recurring chore "didn't clear" is almost always one of: never sets
  `isCompleted` (by design — filter on dueDate/cadence), or
  `nextOccurrence` didn't know the cadence. Stale push = orphan, swept
  on launch now.

### 2026-05-19 (PM) — TF 3.0 (5) + (6) shipped, refactor cluster, calendar-event dupe fix, geezyg.com apex live

Continuation day. Shipped two more TFs, landed 6 of 10 refactor-review
areas, fixed a real Production bug, and pointed the marketing site's
apex domain at Vercel.

**TFs shipped**:
- **TF 3.0 (5)** (commit `c4a2f74`) — notification id migration
  (timestamp → uid-based, with legacy-id cleanup sweep), `sync(tasks:)`
  now honors `shouldDeviceScheduleReminder` (was only in `scheduleNow`),
  `CasaCoreDataStack.lastSaveError` published. **Added to the sync
  baseline list** in `casalist_sync_baseline_rule.md`.
- **TF 3.0 (6)** (commit `755d654`) — bug-fix build. Build 5 → 6,
  marketing stays 3 (Geezy chose "version 3 build 6" after I flagged
  that dotted build numbers like `5.0.1` get parsed weirdly by ASC).
  Delivery UUID `ade877ac-d351-4a62-accf-50f0a56a1a92`, notes posted.

**Refactor-review work** (from `docs/CLAUDE_REFACTOR_REVIEW.md`, all
on main, NO sync-surface changes):
- Areas 4/5/9/10 (`e51e8b3`), Area 3 local-fallback banner (`7cc503f`),
  Area 1 `CasaEntity.resolve` entity-lookup safety (`35f76d4`),
  stability round = `CasaShareLog` helper + `SaveErrorBanner` + docs
  (`bb759bc`). **Areas 2, 6, 7, 8 are PAUSED per Geezy** — see
  dos/donts below. `docs/refactor-status-2026-05-19.md` has the full
  ledger + a TF verification checklist.

**Calendar-event dupe fix** (`cc85d20`) — Geezy got TWO pushes for one
event. First theory (Apple Calendar mirror + Casalist both firing) was
WRONG — his screenshot showed both pushes had Casalist's 📣 prefix,
zero from Apple Calendar. Real cause: two distinct `FamilyEvent` rows
(different uids → different `event-<uid>` ids → both fire). Fix:
`syncEventsFromContext` dedupes by `(title|startDate|household)` and
schedules only the survivor (lowest uid string), cancelling loser
pushes; `AddEventView.save()` got an `isSaving` re-entry guard.
Reverted the wrong Apple-Cal suppression from `6726122`. NOTE:
`FamilyEvent` is still NOT in `FamilyDedupe`'s scope — proper row-level
dedupe is a future job needing TF Release proof.

**geezyg.com apex → Vercel** (marketing site, repo
`/Users/geezy/Documents/casalist-web`, Vercel project `casalist-web`,
`prj_s2t4Eyy7MOkFKBy90XNGGc5rXuti`). Repointed OG-card meta tags from
`casalist.geezyg.com` → `https://geezyg.com`, redeployed via `vercel
deploy --prod`, attached apex to the project via `vercel domains add`.
DNS done in Cloudflare via Chrome MCP: **disabled the Cloudflare
Parking Page** (Registrations → geezyg.com → Settings) because the
apex CNAME was auto-managed and couldn't be edited in place, then
added `A @ 76.76.21.21` DNS-only (gray cloud). Gotcha: editing a
parking-page-managed record in the DNS table fails with "generated by
Cloudflare… modify in Registrar configuration" — you MUST disable the
parking page first. All other records (MX, SPF, apple-domain,
_atproto, _vercel, casalist, casabills) left untouched.

**Current rules / dos & donts going in next time**:
- **DO** keep `MARKETING_VERSION = 3`; only bump `CURRENT_PROJECT_VERSION`.
  Use clean integer build numbers (6, 7, 8…) — dotted (`5.0.1`) gets
  mis-parsed by App Store Connect.
- **DO** run `bash scripts/cloudkit-schema-diff.sh` before every TF;
  it's also enforced as a Release build-phase gate.
- **DO** get explicit per-action authorization before live production
  changes (TF upload, DNS edits, prod deploy) — the auto classifier
  blocks them otherwise, and rightly so.
- **DON'T** ship TF without Geezy saying "ship it" / "push to TF" /
  equivalent. A version number choice is NOT a ship order.
- **DON'T** touch the four paused refactor areas without Geezy
  unblocking + TF Release proof: **Area 2** (startup `.task`
  ordering), **Area 6** (`NotificationsManager.swift` split),
  **Area 7** (`CasaCoreData.swift` split), **Area 8**
  (`CasalistCottage.swift` split, 9.3k lines).
- **DON'T** touch the sync baseline surface (`runDedupePipeline`,
  remote-change debounce, Core Data bg-context behavior, CloudKit
  store setup, schema gate) without TF Release proof on Air +
  iPhone 15. Debug/sim sync don't count. TF 2.2(5)/2.5/3.0(2)/3.0(5)
  are the known-good baselines.
- **DON'T** touch the `profar` branch / `geezy14/profar` repo — Codex
  owns it; only acknowledge Profar if Geezy raises it first.
- **DON'T** add `@NSManaged`/`attr(...)` (a schema change) and ship
  without deploying Dev → Prod via the CloudKit Dashboard, or sync
  silently breaks + poisons CKMirroredData (needs delete+reinstall).

### 2026-05-19 — TF 3.0 (3) + (4) shipped: weekly-recurrence fix, search, chore expiration, redeem catalog, Profar moves out

Long day. Two TFs shipped, several feature surfaces opened up, and
Profar moved to its own GitHub repo so Casalist is fully clean.

**Headline ships**:
- **TF 3.0 (3)** (commit `0d78eff`) — Apple Calendar weekly-recurrence
  fix (CalendarLinkService translates `repeatKind` into a real
  `EKRecurrenceRule`; previously every weekly event mirrored as a
  one-shot). EKAuthorizationStatus deprecation cleaned up. New
  Leaderboard Inbox with 3 selectable shapes (Activity / Standings /
  Goals) replacing the universal InboxView on Dashboard / My To-Do /
  Family List. Admin-only CHORE STATS block in Standings showing
  per-member done/assigned + percentage.
- **TF 3.0 (4)** (commit `23b0d80`) — Universal search (magnifying
  glass on Dashboard top bar; grouped results across tasks /
  reminders / events / family / goals; tap a family member to filter
  to their stuff). Chore expiration end-to-end: Settings → Game
  Rules → "Expires after" (Off / 1 / 3 / 7 / 14 days), with the
  EXPIRED pill + struck-through points across rings / digest / calm /
  kanban rows. Recurring chores never expire. Schedule day-strip
  expands recurring events per-day (M/W/F event now visible on all
  three). Event card date badge reflects the tapped day.

**Curated redeem catalog landed post-(4)** (commits `d2d4e82` +
`bc0b63a`, on main, NOT in TF yet) — Rewards tab gets a new REDEEM
section with three shapes (Grid / List / Sheet), pending state on
already-requested items, "Need X more pts" affordability hint, and
Settings → Game Rules → REDEEMABLE ITEMS editor for admins. 10
defaults seeded (screen time, gaming, pick movie / dinner, stay up
late, skip chore, ice cream, store trip, arcade, small toy). Rides
in the existing `Household.routinesJSON` envelope so no schema
change.

**Profar exodus** — the `health-routing-refactor` branch (renamed
`profar`) was pushed to a brand-new `geezy14/profar` repo, then
deleted from casalist origin. The PROFAR_MIGRATION.md handoff doc
went up to geezy14/profar's `main`, and the full source snapshot
sits on `casalist-source` branch for Codex to extract files from.
Casalist main is `git grep -i "profar"` clean. Memory note
`casalist_profar_codex.md` codifies "don't touch the profar repo,
Codex owns it."

**Gotchas worth keeping**:
- App Store Connect's `/v1/builds` `version` field is **CFBundleVersion
  (the build number)**, NOT marketing version. To filter by marketing
  version reliably, request `?include=preReleaseVersion` and match
  the included `preReleaseVersions[].attributes.version` instead. I
  PATCH'd notes onto the wrong (older) build twice before figuring
  this out.
- `cktool import-schema` will push schema changes to Dev CloudKit
  **without** needing the app to actually write a record first. Edit
  the exported `.ckdb`, re-import, and the new fields show up
  immediately. Useful when you want to test the deploy gate workflow
  end-to-end without driving the device UI.
- Catalog "pending" lookup matches on the full label string
  (`"emoji name"`) — keep label formatting consistent between
  `proposeRedeem` and the membership check in
  `myPendingRedeemLabels` or the disabled state silently misses.
- Rebase conflicts when both sides touched the same doc (Geezy wrote
  his version of PROFAR_MIGRATION.md while I wrote mine): preserve
  HEAD verbatim, append my additions at the end. Python one-liner to
  slice out the conflict markers + reattach handled it cleanly.

**Sync baseline rule**: untouched. `runDedupePipeline` still has the
`newBackgroundContext() + automaticallyMergesChangesFromParent` form.
Chore expiration plumbing rides in `Household.routinesJSON` so no
new schema field, no Production CloudKit deploy needed.

### 2026-05-18 (PM) — TF 3.0 (2): 4-layout picker + announceHousehold + new sync baseline

Long evening session that turned the per-tab layout exploration into
a real user-facing setting and shipped two TFs (one expired, one
verified).

**Headline ship**: TF 3.0 (build 2), commit `a39a4fc`. Verified on
Air + iPhone 15 — sync instant across both devices. Added to the
known-good baseline list alongside TF 2.2 (5) and TF 2.5. See
`casalist_sync_baseline_rule.md` for the proof rule.

**Layout picker** in Settings → Appearance with four options:
- **Classic** — restored 2.2 hero/list shapes for Dashboard,
  Reminders (coral pinned tile), Family List (lavender tray),
  Maintenance/Home, Grocery, Schedule
- **Rings** — Apple Fitness rings hero on Dashboard, Reminders,
  Family List, Home, Grocery, Schedule (all 140/104/68)
- **Calm** — roomy text-only headers on every tab (My To-Do
  already had a full calm content variant; other tabs get the
  hero treatment and fall back to their existing lists)
- **Kanban** — full 3-column board for My To-Do (Today / Soon /
  Done), Reminders (Pinned / Today / Hourly), Home (Overdue /
  This week / Done). Other tabs get a kanban-style header only.
  Column width settled at 124pt with 10pt heavy headers + line
  limit so OVERDUE / THIS WEEK fit in one line.

**Schema change & deploy**: added `FamilyEvent.announceHousehold`
(Bool) so admins can broadcast a calendar event to the household
while still color-coding the card for a specific kid. Deployed
Dev → Prod via Chrome MCP. The schema-gate Run Script build phase
is now properly battle-tested — it would have refused the archive
if the deploy was skipped. Workflow proven end-to-end.

**Reminder routing tightened**: `isTargetedAtMe` now returns false
for `notifyMode == "everyone"` and empty-notifyMode-with-no-
assignee. Loose reminders live in the Reminders tab only; My To-Do
gets only assignee-specific or admin-targeted ones.

**Other ships**:
- Pulsing profile chip on Dashboard (rings + calm + kanban
  variants). Taps into Personal Card (chore card). Sonar-ring
  pulse pattern — photo stays still + crisp, no wash.
- Weekday-only (Mon-Fri) repeat option for Schedule events.
  Wires through NotificationsManager via 5 per-weekday triggers,
  reusing the multi-weekday id-suffix scheme.
- Event card now shows attendee avatar (CLAvatar or house glyph
  for household-wide).
- Dashboard simplified everywhere: removed `quickAdd` +
  `stickyAgenda` + `quickAddChips`. Hero → star → tiles →
  What's New only.

**Gotchas I burned time on, future-me read these**:
- App Store Connect API's `version` field on /v1/builds is the
  CFBundleVersion (build number), NOT the marketing version. Use
  `?include=preReleaseVersion` + the included `preReleaseVersions`
  payload to filter by marketing version reliably. I PATCH'd notes
  onto the wrong build twice before figuring this out.
- `cktool import-schema` lets you push schema changes to Dev
  WITHOUT needing the app to write a record first. Useful when
  the user wants the deploy workflow tested without driving the
  UI on Air. Just edit the exported `.ckdb`, add the field,
  re-import.
- Kanban columns: SwiftUI's HStack with `.frame(maxWidth:.infinity)`
  on a child means even the rings stack with `.frame(width:140)`
  can get visually clipped by the screen edge if the parent
  doesn't have enough horizontal padding. The fix on this session
  was `.padding(.leading, 18) + .fixedSize()` on the rings stack
  to give the stroke breathing room. Look at `greetingCardRings`
  if it bites again.

**The sync baseline doc is the new defense**:
`casalist_sync_baseline_rule.md` lists `runDedupePipeline`,
remote-change debounce, Core Data background-context behavior,
CloudKit store setup, and the schema gate as protected surface.
Any change to those needs TF Release proof on Air + iPhone 15.
Debug/simulator don't count. Linked from MEMORY.md.

### 2026-05-18 — TF 2.3 → 2.5 saga: schema gate + DON'T touch runDedupePipeline
Half-day debugging session. Started by shipping idea-A/C/D as
hidden options under a DEBUG design picker; pivoted hard when
sync broke. Walked through TF 2.2 (working) → 2.3 (silently broken,
missing CD_notifyMode in Production) → schema deploy via Chrome MCP →
2.4 (still broken because I "fixed" runDedupePipeline) → 2.5 (revert
restored sync, instant on both devices).

**Headline takeaways for future Claudes:**

1. **DON'T switch `CasalistAppDelegate.runDedupePipeline` from
   `newBackgroundContext() + automaticallyMergesChangesFromParent
   + bg.perform` to `container.performBackgroundTask`.** I theorized
   the original pattern leaked bg-context listeners and would
   eventually starve CloudKit's export queue. The "fix" looked
   clean on paper. Empirically: it **breaks Production CKShare
   exports completely.** Dev still syncs (which made the bug
   invisible until TF). The revert in commit `18db2c4` restored
   instant cross-device sync. Memory note saved at
   `casalist_dont_touch_dedupe_pipeline.md`. Read it before
   touching that function.

2. **CloudKit schema gate is now enforced by an Xcode Run Script
   build phase** (commit `c06731e`). The casalist target's first
   build phase is "Preflight: CloudKit schema gate" — it calls
   `scripts/cloudkit-schema-diff.sh --ci` on Release builds. If
   Production != Development, the **archive fails before code
   signing.** Debug builds skip the check. This problem has
   bitten three times in two days (TF 2.2 calendar sync,
   TF 2.3 notifyMode, plus an earlier name-typo); the rule
   "remember to run the script" failed every time. The build
   itself is the gate now. Bypass via `CASALIST_SKIP_SCHEMA_GATE=1`
   if you genuinely need to (almost never).

3. **CKMirroredData poisoning is a real, separate concern.** When
   TF 2.3 ran against Prod-without-`CD_notifyMode`, every record
   write got rejected and NSPersistentCloudKitContainer marked
   those local mutations as terminal failures. Even after the
   schema deploy fixed Production, the local mirror on each
   device was still poisoned — sync stayed broken until a
   delete + reboot + reinstall on each device cleared the local
   store. Updating over the top is NOT enough. CLAUDE.md spells
   this out near the schema-gate section.

**Other ships from this session** (overshadowed by the sync
saga but still landed):
- Idea-A "Calm" My To-Do layout + bundle editing (rename,
  recategorize, reassign, change bonus points) — main branch,
  hidden behind `myToDoDesign` AppStorage with default "digest"
- Idea-C "Cards" and idea-D "Rings" folded into main as additional
  hidden options under the same picker. Geezy picked D as the
  eventual winner; Family List hero already mirrors D's rings
  style on main
- Profar (HealthKit family wellness module) Phase 1 plumbing
  shipped on `health-routing-refactor` branch behind
  `profarEnabled` AppStorage. Steps + kcal + exercise + sleep
  read end-to-end. Auth re-trigger pattern needed every time we
  add new HKQuantityType identifiers
- Production CloudKit schema deploy (CD_notifyMode +
  CD_ProfarEntry record type, the latter auto-promoted because
  Dashboard's deploy button is all-or-nothing) executed via
  Chrome MCP on icloud.developer.apple.com
- ExportOptions.plist `destination` flipped from `upload` to
  `export` so altool can pick up the IPA. The previous mode was
  the recurring "ExportArchive produced no IPA" gotcha

29 commits pushed to `origin/main` between `682793e` (the bad
bg-context "fix") and `18db2c4` (the revert that fixed Prod).
The schema-gate commit `c06731e` is the load-bearing safety
net going forward.

_(2026-05-16 1.6+1.7+1.8, 2026-05-16 Post-1.5 feature stack, 2026-05-15 TestFlight 1.5, 2026-05-15 TestFlight 1.4, 2026-05-15 TestFlight 4.0, and 2026-05-14 Option A entries rotated to `docs/progress-log-archive.md`)_

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
  com.gbrown10.casalist.dev
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
  com.gbrown10.casalist.dev
```

If install/launch fails with "unavailable" or a network timeout, the phone went to sleep or wifi dropped. Retry after a few seconds.

### Dual-bundle setup (Casalist + Casalist Dev side-by-side)

As of 2026-05-16, Debug and Release builds use DIFFERENT bundle IDs so both can live on the same device:

| Config | Bundle ID | Icon | Display Name | iCloud env |
|---|---|---|---|---|
| **Debug** | `com.gbrown10.casalist.dev` | `AppIcon-Dev` (orange DEV banner) | "Casalist Dev" | Development |
| **Release** | `com.gbrown10.casalist` | `AppIcon` | "Casalist" | Production |

Both bundles share the same iCloud container (`iCloud.com.gbrown10.casalist`); the environment split (Dev vs Prod) is automatic via Apple's default config-driven CloudKit container environment.

Implications:
- `xcodebuild ... -configuration Debug` produces "Casalist Dev" — what `push it` / `push both` deploy. Talks to Dev CloudKit. Family on TF never sees these builds.
- `xcodebuild ... -configuration Release archive` is unchanged; ships as `com.gbrown10.casalist` to TestFlight / App Store. The TF workflow at the bottom of this doc is the same as before.
- The two apps have completely separate local sandboxes — UserDefaults, Documents, photos, history, templates, color tags, saved locations, etc. Dev-side work doesn't bleed into the TF install.
- iCloud KV is shared across both bundles (single Apple ID), so the `lastShareURLKey` auto-rejoin URL is overwritten when you bounce between Dev and TF on the same device. `shouldClearSavedShareURL(after:)` self-heals on `.unknownItem` when a stale-env URL is tried.

Asset: `casalist/Assets.xcassets/AppIcon-Dev.appiconset/AppIcon-Dev-1024.png` (generated via ImageMagick — base icon + orange `rgba(255,140,0,0.92)` banner from y=820 to y=1024 + white "DEV" text in Avenir-Bold 150pt anchored to the bottom-center).

To regenerate the Dev icon if it goes missing:

```bash
cd casalist/Assets.xcassets/AppIcon-Dev.appiconset
magick ../AppIcon.appiconset/AppIcon-1024.png \
  -fill 'rgba(255,140,0,0.92)' -draw 'rectangle 0,820 1024,1024' \
  -fill white -font /System/Library/Fonts/Avenir.ttc -pointsize 150 \
  -gravity South -annotate +0+10 'DEV' \
  AppIcon-Dev-1024.png
```

The Debug build settings (in `casalist.xcodeproj/project.pbxproj`, in the casalist target's Debug XCBuildConfiguration block) that drive the dual-bundle behavior:

```
PRODUCT_BUNDLE_IDENTIFIER = com.gbrown10.casalist.dev;
ASSETCATALOG_COMPILER_APPICON_NAME = "AppIcon-Dev";
INFOPLIST_KEY_CFBundleDisplayName = "Casalist Dev";
DEVELOPMENT_TEAM = 57Z9HL3SZJ;
```

The Release block keeps the original bundle ID, icon (`AppIcon`), no display-name key (defaults to "Casalist"), same team. Don't touch Release.

**First-time provisioning gotcha:** When you first introduce the `.dev` bundle ID, `xcodebuild ... -allowProvisioningUpdates` will fail with errors like *"No Accounts: Add a new account in Accounts settings"* and *"Provisioning profile doesn't include the iCloud capability."* That's because the new App ID doesn't exist yet in your developer team and the CLI can't create it from a cold start. Fix: open Xcode GUI once → Settings → Accounts → sign into the Apple ID that owns team `57Z9HL3SZJ` → reopen the project → casalist target → Signing & Capabilities → click into the Debug section so Xcode auto-creates the App ID with iCloud + Push capabilities + the `iCloud.com.gbrown10.casalist` container attached + a dev provisioning profile. After that one GUI pass, CLI builds work normally.

If Xcode's auto-signing blanks `DEVELOPMENT_TEAM = ""` in the Debug config during the GUI pass (it sometimes does when accounts are flaky), put it back to `DEVELOPMENT_TEAM = 57Z9HL3SZJ;` manually.

### "testflight it" — archive + upload to TestFlight

> **VERSION-BUMPING RULE — read this every time, do not freelance.**
>
> - `MARKETING_VERSION` (user-facing "version", e.g. `2.0`) **DOES NOT BUMP**
>   unless Geezy explicitly says so. Same value across many builds.
> - `CURRENT_PROJECT_VERSION` (Apple's build counter) IS the one that bumps,
>   and only this one. Just needs to be strictly higher than the last upload.
>
> Users see `2.0 (1)`, `2.0 (2)`, `2.0 (3)`... — same version, climbing build.
>
> Decimal build numbers (`2.2`, `2.3`) sometimes get parsed weirdly by Apple's
> API (saw it on 2026-05-17 — a `2.2` upload appeared as `3` in App Store
> Connect). Clean integers (`3`, `4`, `5`...) are safer.
>
> **2026-05-17 incident:** Marketing version got bumped `2.0 → 2.1 → 2.2` in
> a single day for what should have been three builds of `2.0`. Geezy caught
> it and called it theater. Don't repeat.

> **CLOUDKIT SCHEMA GATE — enforced automatically as of 2026-05-18.**
>
> The casalist target has a Run Script build phase ("Preflight: CloudKit
> schema gate") that runs FIRST on every build. In **Release** config it
> calls `scripts/cloudkit-schema-diff.sh --ci`, which exits nonzero if
> Production != Development. That aborts the archive BEFORE code signing.
> Debug builds skip the check (Dev CloudKit auto-registers schema).
>
> Emergency bypass (almost never the right call):
> ```bash
> CASALIST_SKIP_SCHEMA_GATE=1 xcodebuild ... archive ...
> ```
>
> The build phase consumes `scripts/cloudkit-schema-diff.sh` as an
> inputPath so Xcode's user-script sandbox grants read access. Don't
> rename the script without updating the inputPaths entry in pbxproj
> or the gate will fail with a sandbox-deny.
>
> Ad-hoc check (informational, doesn't fail anything):
> ```bash
> bash scripts/cloudkit-schema-diff.sh
> ```
>
> If it does NOT report `✅ Production and Development schemas are identical`,
> **STOP**. Deploy the schema first (see "CloudKit schema deploys" section
> below). Shipping with a Dev/Prod schema mismatch causes silent sync
> failures — CloudKit Production rejects records with unknown fields, and
> no error surfaces until the user notices that items aren't syncing
> across devices. **Worse**: once devices have written rejected records,
> NSPersistentCloudKitContainer marks those local mutations as terminal
> failures. Even after deploying the schema later, those devices need a
> delete-and-reinstall to clear the poisoned CKMirroredData store and
> sync correctly again.
>
> This has bitten three times in two days:
> - **TF 2.2 prep**: `CD_endDate` missing → calendar events stopped syncing
> - **TF 2.3 ship**: `CD_notifyMode` missing → all new tasks/reminders stopped
>   syncing
> - (earlier) field-name typo in 1.x line
>
> Any commit that adds `@NSManaged` to an NSManagedObject subclass OR
> `attr(...)` to `CasaCoreData.swift` IS a schema change. The first build
> from that commit silently registers the field in Dev CloudKit. Production
> stays empty until you explicitly deploy via the Dashboard. The diff
> script catches this; running it is the only reliable defense.

When Geezy says "testflight it" (or similar):

1. Commit current changes to `main` (do NOT push to remote unless Geezy explicitly says to push).
2. **Run `bash scripts/cloudkit-schema-diff.sh`. If diffs exist, STOP — deploy schema first.** (See "CloudKit schema deploys" section below.)
3. Bump `CURRENT_PROJECT_VERSION` (build number) in `casalist.xcodeproj/project.pbxproj` — must be higher than the last TestFlight build, never reuse. **Leave `MARKETING_VERSION` alone unless Geezy explicitly asks.**
4. Write release notes to `testflight-notes-<build>.txt` at the project root (covers What's New + What's Fixed + What to Test).
5. Archive Release config:
   ```bash
   xcodebuild -project casalist.xcodeproj -scheme casalist -configuration Release \
     -destination 'generic/platform=iOS' \
     -archivePath build/casalist.xcarchive archive -allowProvisioningUpdates
   ```
6. Export the IPA using the App Store Connect API key (this is the critical trick — without these flags, export fails because no iOS Distribution cert is in the local keychain):
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
7. Upload to App Store Connect:
   ```bash
   xcrun altool --upload-app -f build/export/casalist.ipa -t ios \
     --apiKey RSZWNZ7YL3 --apiIssuer 69a6de73-6a85-47e3-e053-5b8c7c11a4d1
   ```
8. (Optional) Set the "What to Test" notes on the build via the API. Write a small Python script using PyJWT to call the App Store Connect API and PATCH the build's `betaBuildLocalizations` with the contents of `testflight-notes-<build>.txt`. See casaBills2 history for a working `set_testflight_notes.py` template — the auth flow is identical, just swap the bundle ID filter to `com.gbrown10.casalist`.

   **Keep `testflight-notes-*.txt` PURE ASCII.** Apple's App Store Connect API rejects certain glyphs in the `whatsNew` field with `409 ENTITY_ERROR.ATTRIBUTE.INVALID.INVALID_TEXT`. The filter is inconsistent — some emojis pass, others don't — so the safe rule is `ord(c) <= 127` for every char. Concrete substitutions when writing notes (these are the ones I personally keep typing on autopilot):

   - em dash `—` (U+2014) → `--`
   - en dash `–` (U+2013) → `-`
   - right arrow `→` (U+2192) → `->`
   - curly quotes `‘ ’ “ ”` → `' ' " "`
   - ellipsis `…` → `...`
   - any emoji → drop it or describe it ("warning:" instead of a sign emoji)

   Quick verifier (run before uploading notes):
   ```bash
   python3 -c "p='testflight-notes-1.7.txt'; t=open(p).read(); bad=[(i,c,hex(ord(c))) for i,c in enumerate(t) if ord(c)>127]; print('OK' if not bad else f'FAIL {len(bad)}: {bad[:5]}')"
   ```

   Burned on this for 1.6 (emojis): ⭐ 🌅 🙋 🌙 🍎 📍 📣 📢 🛒 🏡 all rejected. And again on 1.7 prep (em dashes / arrows — Apple may or may not have rejected these but the ASCII-only rule applies regardless). The IPA upload itself is fine in both cases; only the notes PATCH 409s.

   **Length cap too: keep `whatsNew` under ~4000 chars.** Apple's API returns `409 ENTITY_ERROR.ATTRIBUTE.INVALID.TOO_LONG` when the field is too long. 1.7's initial notes hit this at 4673 chars; trimming to 3114 cleared it. Safe target: < 3500 chars. Use the `wc -c testflight-notes-*.txt` check before uploading.

   **Style rule — keep "What's New" short.** Geezy's preference (logged 2026-05-16):
   - Highlight the headline features only. Skip minor bug fixes unless Geezy explicitly asks to call one out.
   - Aim for ~1500–2000 chars max. Testers scan, not read; long notes get ignored.
   - One-line bullet per feature is fine. No need to explain every chip in the icon strip.
   - "What to test" section is welcome (helps your home-group testers focus their feedback), but keep it to 4-6 lines.

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