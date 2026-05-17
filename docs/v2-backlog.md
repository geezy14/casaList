# Casalist — Version 2 Backlog

Ideas for the next major version. v1.x continues with the staged
1.7 / 1.8 / 1.9 work; v2 is a parallel design track where bigger
reworks and brand-new surfaces collect.

Newest first.

---

## v2.0 — Apple Watch complication (moved from 1.9, 2026-05-17)

"Next reminder fires in 23 min" on the wrist. Requires a separate
watchOS target in the Xcode project. Likely first surfaces:
- Complication showing next reminder title + countdown
- Complication showing today's task count
- Glanceable family leaderboard (who's leading today)

Bundle with the v2 design refresh so Watch and iPhone ship a cohesive
look at the same time.

---

## v2.0 — iPad app (proposed 2026-05-16)

Ship a real iPad experience alongside iPhone in v2. Today the
target is iPhone-only; running on iPad falls back to a scaled-up
iPhone window which wastes the screen.

Scope:
- Add iPad to the supported device families in the casalist target.
- Adopt `NavigationSplitView` (sidebar + content + detail) for the
  adult shell on regular size class, falling back to today's tab
  layout on compact (iPhone, iPad in Slide Over).
- Sidebar lists the primary tabs (Home, My To-Do, Grocery,
  Schedule, Family, Rewards, Settings). Middle column lists items
  in the selected section. Detail column shows the active reminder
  / task / event.
- Multi-column dashboard — surface today's reminders, upcoming
  events, family agenda side-by-side instead of stacked.
- Keyboard support — `⌘N` new reminder, `⌘F` search, `⌘1..n` jump
  to sidebar section, `Space` to mark done, arrow-key navigation
  in lists.
- Pointer hover states on cards + buttons (already mostly free via
  SwiftUI defaults; needs a polish pass).
- Drag-and-drop between sections (drag a grocery item into a
  reminder, drag a task between family members).
- Stage Manager / external display friendly — resize-aware layouts
  end-to-end. No fixed-width assumptions.
- Widget extension already universal — confirm widget renders on
  iPad home screen at all sizes.
- Live Activities on iPad Lock Screen — confirm parity.

Open question: do we want a Mac (Designed for iPad / Catalyst)
build at the same time? Probably yes-with-caveats — same binary
runs as a window on macOS via "Designed for iPad" with zero extra
work, but a real Catalyst pass would need its own menu bar +
window restoration story. Park the Mac question; iPad-first.

## v2.0 — Notification scheduling rework + Skip-next-occurrence (proposed 2026-05-16)

Today reminder notifications use `UNCalendarNotificationTrigger(repeats: true)` and `UNTimeIntervalNotificationTrigger(repeats: true)` — iOS manages the recurrence internally and delivers on every component match. That works great for "always fires" but means we can't surgically skip a single occurrence.

For a "Skip next" lock-screen action to work cleanly we'd need to rework the scheduler:
- Stop using repeating triggers.
- Instead, schedule the next N occurrences (~7 days worth) as one-shot triggers, refresh on app open + background sync.
- "Skip" then cancels a specific one-shot identifier.

Bonus: this rework also unlocks
- Cancelling specific past-fires that were accidentally scheduled
- Showing the user "next 3 fires" in the edit sheet
- Honoring quiet hours per-occurrence (today the recurring trigger doesn't know about them)
- More accurate notification grouping by time window

Bundled into v2 alongside the other reminder rework so the kid mode + adult mode both get the same upgraded scheduler.

## v2.0 — Kick member flow (proposed 2026-05-16, originally parked 1.5)

Real owner-side member removal. Today's owner-delete is reversed by the joiner's foreground self-heal (`ensureMeInSharedHousehold`) because we don't remove the CKShare participant. Needs:
- `CKShare.removeParticipant` on the kicked member's `userIdentity`
- Soft-delete the local FamilyMember record
- Confirm dialog (this is destructive — the kicked person loses access to everything in the shared zone)
- Optional: keep the soft-deleted record around for X days so the kick is reversible

## v2.0 — Photo sync verification + fix (proposed 2026-05-16)

`FamilyMember.photoBlob` was added to Production schema in 2026-05-16's bundled deploy alongside the location fields. Need to re-verify it actually syncs across Apple IDs now that the field is in Prod — the original 2026-05-14 TODO predicted a schema redeploy would fix it; that's now done but unverified.

If it still doesn't sync after a real two-account test, the bug is deeper (probably in how the inline BYTES field is encoded for shared zones). Possible fallback: switch to a CKAsset path with explicit handling.

## v2.0 — App-icon badge count (proposed 2026-05-16)

Show pending-reminder count on the home-screen Casalist icon via `UNUserNotificationCenter.current().setBadgeCount(_:)`. Update at app launch, on every reminder save/complete, and when notifications fire. Pair with a Settings toggle ("Show reminder count on app icon — On/Off") because some people hate badges.

## v2.0 — Family-wide stats view (proposed 2026-05-16)

Companion to the Personal Stats Card. Household-wide rollup: total chores done this week, who's leading, MVP per category, week-over-week trend. Already have the data; just needs the view.

## v2.0 — Rewards overhaul (proposed 2026-05-16)

The Rewards surface (top-level tab on the adult shell after the 4→2
collapse in 1.x) needs a real design pass. Today it leans on the
goal-request → admin-approve → redemption flow built incrementally
through 1.x, plus a placeholder tray icon on the Family Leaderboard
that's explicitly marked as "don't polish this — it's getting
replaced" (per the user-memory note `casalist_inbox_rework.md`).

Scope is intentionally loose right now — capture the intent so we
don't accidentally polish the placeholder. Specifics get nailed
down when v2 starts.

Known starting points:
- **Points → cash conversion (proposed 2026-05-16)** — Today points
  are abstract — chores award them, rewards cost them, and prices
  are picked ad-hoc by admins at approval time. Layer a real
  conversion rate on top: settings → "1 point = $0.05" (or
  whatever the household decides). Once set:
  - Every reward / prize price displays in BOTH points and dollars
    side by side ("250 pts · $12.50")
  - Kids can see "lifetime earned: $84.20" — a real, motivating
    number instead of just a point total
  - Optional: convert accumulated points into an allowance payout
    on a schedule (weekly Sunday, monthly first-of-month). Admin
    confirms the payout, points zero out (or reduce by paid amount).
    Cash payout is just a record — the actual money handoff
    happens IRL, Casalist just tracks it.
  - Stretch: per-chore "dollar value override" — most chores stay
    on the conversion rate, but a big-deal task (mow the lawn) can
    be priced directly in dollars by the admin and back-converted
    to points at award time.

  Stored on `Household` (single rate per household,
  `pointsToCentsRate: Int` — store as cents per point to avoid
  Double-precision drift). Settings → POINTS section gets a "$
  per point" row. Surface in admin Reward stocking form (live
  preview: "$12.50") and the Prizes catalog tile.

- **Prizes page (catalog of pre-chosen rewards, proposed 2026-05-16)**
  — Today rewards are entirely request-driven: kid asks for X,
  admin sets a price, kid redeems when they hit it. Add a dedicated
  **Prizes page** showing a curated catalog stocked by the owner/
  admin ("$5 — extra screen time hour", "$20 — pick a movie night",
  "$50 — sleepover with a friend"). Family members browse the
  catalog tiles and tap to claim — no approval round trip needed
  because the admin already pre-approved by stocking it. Admin
  still confirms delivery at redemption time.

  **Data model — Option B (locked in)**: separate `Prize` entity
  (Core Data NSManagedObject), NOT a flag on `FamilyGoal`. Prizes
  and personal goals are conceptually different surfaces — keeping
  them in different tables means no list-screen accidentally mixes
  them up, and Prize can grow fields personal goals don't need
  (stock count, expiration date, hide/retire state, scoping rules)
  without bloating FamilyGoal. Schema fields (initial sketch):
  `uid`, `title`, `cost` (Int), `emoji` / `imageData`, `createdBy`
  (admin name), `scopeMemberUid` (nil = household-wide, else the
  member who can claim), `sortIndex`, `isHidden`, `isRetired`,
  `household` (relationship), `deletedAt`. Plus a way to track
  claims — either a `PrizeClaim` join table OR re-use the existing
  redemption flow on FamilyGoal by creating a goal from a prize at
  claim time.

  UI: new "Prizes" surface (likely a tab or a top-bar shortcut in
  the Rewards screen). Admin sees a stocking view with add/edit/
  reorder/hide. Members see a grid of tiles; tap to claim, locked
  state shown if they can't afford it yet. Catalog items can be
  household-wide (anyone can claim) or per-member (Donovan only).
- Rework the inbox/tray icon on the Leaderboard (placeholder today)
- Smoother goal request flow — fewer taps, better request-context
  capture, optional photo / reason at request time
- Better admin-side approval UX — bulk approve, quick price-set,
  history of past approvals
- Visualize redemption progress (you're 70% to your goal) more
  prominently than today's mini-progress bars
- Kid view of "what I'm working toward" — a single hero goal vs
  the current shelf of all goals

## v2.0 — Starfield (kid mode) overhaul (proposed 2026-05-16)

Today: kid-mode "starfield" UI auto-activates for FamilyMembers
with `role == .kid`. Full-screen alt to the adult shell with
big-tap chore tiles, goal shelf, "MY WINS" log, "Ask for a reward"
submit flow, confetti + haptic on every completion.

It works but the design is from a single sprint in TF 4.0 and
hasn't been revisited since. v2 is the natural moment to do a
proper redesign — possibly something more game-like, more reward-
driven, with progression mechanics that age up gracefully (a
5-year-old's "tap the sparkle" vs a 12-year-old's "see your stats"
shouldn't be the same screen).

Capture the intent — specifics TBD.

Known starting points:
- Age-aware UI variants (younger kids vs tweens)
- Better integration with the Personal Stats Card concept above —
  kids' wins log evolves into their personal card
- Animations / micro-interactions that feel rewarding without
  being annoying after the 100th chore
- Theme/palette options ("space" vs "ocean" vs "garden") so the
  kid can make it their own
- Pair with the Rewards overhaul above — the kid's goal shelf
  should connect to the redesigned reward flow

---

## v2.0 — Personal Stats Card (proposed 2026-05-16)

Inspired by casabills' "Personal Card" — a baseball-card-style
trophy view that surfaces a household member's contribution stats
across the lifetime of their Casalist use. Replaces the current
photo-edit-only flow on the dashboard greeting card with a richer
personal view.

### Trigger

Tap your photo on the greeting card on the dashboard (today this
opens `ProfilePhotoSheet`). The new flow:

1. Tap photo → opens `PersonalCardView` (full-screen, baseball-card
   aesthetic).
2. Edit Photo accessible as a secondary action button inside the
   card (top-right ellipsis menu or similar).

### Sections

Same shape as casabills' card so the visual language is consistent
across Geezy's apps.

**STATS & AWARDS (top row, 4 hero stats)**
- All-time **tasks completed** — sum of TaskItems with completedAt
  attributed to me
- All-time **bills paid** equivalent → maybe **chores completed**
  (subset of tasks where category != "reminders")
- **AVG** — completion rate (completed / assigned) or some other
  rate-style number
- **MVP Category** — most-completed category (Chores / Reminders /
  Grocery / Events / Home / Maintenance)

**SPLITS (current year)**
- Tasks done this year
- Points earned this year
- Goals redeemed this year

**PROJECTIONS (year-end pace)**
- At current pace, projected year-end completions
- Projected total points
- Projected balance / outstanding reward requests

### Data layer

Casalist already has most of this:
- `FamilyMember.points` (live counter)
- `TaskItem.completedAt` + `TaskItem.category` (lifetime activity)
- `TaskItem.completionCount` (recurring task tracking)
- `ReminderStreak` (already has current + best per reminder; needs
  aggregation across all reminders for "best streak ever" stat)
- `FamilyGoal` redemption history (`isRedeemed` + `redeemedAt`)
- `FamilyMember.createdAt` ("OPENING DAY" / member-since)
- `FamilyProgress` (existing per-member progress tracking)

Computations are local — no schema changes needed. Just a stats
rollup view model that walks the existing fetched records.

### Bonus: share-as-image

Render the card to UIImage → ActivityViewController → family
members iMessage each other their cards. Casabills has this pattern
working; lift the implementation.

### Visual

- Hero image / centerpiece: user's photo (the "octopus" equivalent
  in this app could be a personalized Casalist avatar or the
  user's actual photo enlarged + blurred behind the stats).
- Match Casalist's vivid palette (don't use casabills' purple —
  Casalist's peach / coral / sky / butter / lavender).
- Big numbers, heavy weights, lots of tracking on labels (casabills
  card has very strong typographic hierarchy that we should match).

### Open questions

- Card aspect ratio — casabills' is portrait phone-sized. Match
  that, or make it square for easier sharing?
- "Hero image" — user's photo, or a Casalist mascot? Casabills'
  octopus is great because the app has a clear character; Casalist
  doesn't have a mascot yet.
- Does it need a printable / share-ready version that strips
  Casalist branding so it doesn't feel like an ad?
