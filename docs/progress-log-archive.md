# casaList — Progress Log Archive

Older Progress Log entries rotated out of `CLAUDE.md` to keep the inline log lean.

Newest on top, same format as the inline Progress Log.

When `CLAUDE.md`'s Progress Log hits 6 entries, move the oldest paragraph from there into the top of this file.

---

### 2026-05-16 — 1.6 + 1.7 + 1.8 all shipped to TF in one day
Marathon all-day session: three TestFlight builds in one day plus the
Production CloudKit schema deploy that unblocked them, the dual-bundle
(Casalist + Casalist Dev) workflow, and the Today's Reminders widget +
Status Ping Live Activities. Highlights: **1.8** (UUID
`608db227-…`) — Today's Reminders widget, Status Ping Live Activities,
native UIColorPicker, Saturday week start; fixed wrong App Group in
entitlements + missing Debug `CODE_SIGN_ENTITLEMENTS` on the widget
extension. **1.7** (UUID `fadda394-…`) — Apple Reminders link, unified
Repeat picker (`.year` added), lock-screen snooze/mark-done
(`REMINDER_FIRE` category + `ReminderActionHandler`), per-member
reminders, location-based reminders (`CLCircularRegion`), saved
locations, icon-strip add-reminder sheet, photo attachments, history
feed, templates, color tags, drag-reorder, streak heatmap, daily recap,
per-reminder sound. **1.6** — location quartet on FamilyMember.
Production schema deploy promoted 1.6's FamilyMember location quartet +
1.7's TaskItem location quintet in one Dashboard pass. Gotchas logged:
Apple `whatsNew` rejects emojis (409 INVALID_TEXT) and caps ~4000 chars
(409 TOO_LONG) — keep notes ASCII + short. (Full detail in git history
of CLAUDE.md.)

### 2026-05-16 — Post-1.5 feature stack staged for next TF (no schema deploy needed)
Long all-night session after 1.5 shipped. Everything below is in
local commits on `main` ready to ship; no TF push yet, per Geezy's
"I'll tell you when" rule. **No schema changes in this batch** so
the next TF can go out without another CloudKit deploy. Highlights:
notifications suite A–D (daily briefing, quiet hours, grocery
activity push, recurring event push, status pings), custom repeat
picker (`RepeatRule` JSON in `repeatKind`), task-detail polish
(claim pill + confetti overlay rebuild), live location sharing
(Option A, `kCLLocationAccuracyBest` + 10m filter, new FamilyMember
location quartet schema), manual location ping (Option C, built then
hidden), Apple Calendar link (`CalendarLinkService` mirror + display,
one-way by design), Family tab overhaul (inline quick-add, agenda
tiles, outings via parentUid, claim/canDelete rules), announcements
banner with expiry, and side-quest crash fixes (`CloudBackup.snapshot`
on a background context, auto-rejoin URL only cleared on permanent
CloudKit errors, Nuke-all also clears userName/householdName).
Schema deploy needed before that TF: the FamilyMember location
fields. (Full detail preserved in git history of CLAUDE.md.)

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
