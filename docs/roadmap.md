# Casalist — Release Roadmap

Source of truth for what's planned, what's staged, and what's shipped. CLAUDE.md's Progress Log is the session-by-session journal; this doc is the forward-looking plan. `docs/v2-backlog.md` is for v2 and beyond.

Newest version at top.

---

## v2.0 — Design refresh + bigger reworks (parked)

The first major version cut since 1.0. Two themes: a visual refresh on **Casa Glass** design language, plus the bigger reworks that have been accumulating in `docs/v2-backlog.md`.

### Casa Glass design language

Adopt the shared `CasaGlassKit` Swift package (used by casabills2) to give Casalist its v2 visual identity. Casaglass3 is the frozen standard — we use what the kit ships, no in-place modifications.

- `AppBackgroundView` at the root for gradient + user-picked photo background (with the 8 built-in gradient presets).
- `.casaCard()` modifier replacing the current `RoundedRectangle(...).fill(P.surface).overlay(stroke)` chrome on every card.
- `BackgroundImageStore` for photo persistence.
- AppStorage keys the kit expects: `glassEnabled` (Bool), `customBgEnabled` (Bool), `customBgRevision` (Int), optionally `appBackground` (String).
- Settings → APPEARANCE gets a "Glass UI" toggle + background photo picker.

Start as a pilot — apply to one or two surfaces first (dashboard tiles, family card) to see how it lands before doing a full sweep. Then full migration.

### Major rework tracks (from v2 backlog)

Detailed in [`docs/v2-backlog.md`](v2-backlog.md):

- **Notification scheduling rework + Skip-next-occurrence** — Swap repeating triggers for rolling one-shots so we can cancel a specific instance. Unlocks Skip, accurate quiet-hours, "next 3 fires" preview.
- **Rewards overhaul** — Replace placeholder inbox tray icon, smoother goal request/approval flow, hero-goal view for kids. Adds a **Prizes page** — a curated catalog of pre-priced rewards stocked by owner/admin (kids browse the page and tap to claim, no approval round trip; admin still confirms delivery). Backed by a new `Prize` Core Data entity. Supports household-wide and per-member scoping. Includes **points → cash conversion** (settings rate like "1 pt = $0.05"; rewards/prizes show both currencies; optional scheduled allowance payouts).
- **Starfield (kid mode) overhaul** — Age-aware variants, integration with Personal Stats Card, theme/palette options.
- **Personal Stats Card** — Baseball-card-style trophy view on dashboard photo tap. Lifetime + season-to-date stats, shareable as image.
- **Family-wide stats view** — Household rollup companion to Personal Card.
- **Kick member flow** — Finish the parked 1.5 work. `share.removeParticipant` + soft-delete + confirm dialog.
- **App-icon badge count** — Pending-reminder count on the home-screen icon.
- **Photo sync verification** — Re-test cross-account FamilyMember.photoBlob sync now that schema is in Prod.

### Tab refinement pass

Designed-up overhaul of the four primary tabs in some v2 build. Each gets the same icon-strip / inline-panel treatment we already gave the reminder authoring sheet in 1.7, plus the Casa Glass design language applied consistently.

- **Home tab** — dashboard layout, tile grid, greeting card, leaderboard mini
- **My To-Do** — task list ergonomics, sectioning, swipe actions, filter chips
- **Grocery** — list grouping, trip headers, inline-add UX, completed/active split
- **Schedule** — see 1.9 7-day grid as the calendar surface; v2 refines the event card visuals + section layout to match Casa Glass

### v2 candidates from original sketch notes

- **AI chat** — Natural-language task creation ("remind me to take the trash out Tuesday at 8") and family Q&A ("when's soccer practice next?"). Probably its own version line within v2, or a feature flag inside 2.0.

---

## v1.9 — Skipped; rolled into v2

All three 1.9 items shipped early or were folded into v2:

- **7-day calendar grid** — shipped in the 1.8 work window (Sat-first day strip on Schedule tab).
- **Global search** — shipped in the 1.8 work window (Home dashboard, hides when all tiles are 0).
- **Apple Watch complication** — moved to v2 backlog. Big lift (separate watchOS target); better bundled with the v2 design refresh.

---

## v1.8 — Live Activities + Widgets (parked)

Both ship together because they share a WidgetKit extension target. One Xcode target add, both surfaces get unlocked.

- **Live Activities** — status pings (and possibly live-location updates) render as live cards on the Lock Screen + Dynamic Island. Stay pinned until expired/dismissed instead of being one-shot pushes that scroll off into Notification Center.
- **Home-screen widgets** — small / medium / large variants. Likely first surfaces:
  - Today's reminders + chores
  - Family leaderboard mini
  - Next event / countdown
  - Grocery list snapshot

---

## v1.7 — Staged on `main`, awaiting TF push

Reminder UX rebuild + several quality-of-life polishes. No additional Production CloudKit schema deploy required (the location quintet was bundled with 1.6's deploy on 2026-05-16).

### Apple Reminders link
- New `ReminderLinkService` (EKEventStore `.reminder` entity), `ReminderSettingsSection` in Settings → REMINDERS, inline-row picker.
- Mirrors Casalist reminders → linked Apple list as EKReminders.
- "FROM YOUR APPLE REMINDERS 🔔" section in the Reminders view shows non-Casalist items from the linked list.

### Reminder authoring rebuild
- **Unified Repeat picker** — old menu+custom-button combo collapsed into one sheet. Preset chips (Hourly / Every 2h / Daily / etc.) + interval × unit × weekday builder. `.year` added to `RepeatRule.Unit`.
- **Icon-strip add/edit sheet** (Apple Reminders pattern) — title field, horizontal chip strip (When / Repeats / Notify / Location / Photo / Tag / Sound / Stop time), inline panels expand below. Edit mode auto-expands every populated chip.

### Reminder feature additions
- **Lock-screen actions** — Mark done / Snooze 15m / Snooze 1h / Snooze until tomorrow.
- **Per-family-member assignee** — only one device fires the local push.
- **Location-based reminders** — `CLCircularRegion` monitoring, arrive/leave choice, slider in feet/miles, mini-map + radius circle.
- **Saved locations** — define Home / Work / School once in Settings, surface as quick-pick chips.
- **Photo attachments** — device-local; thumbnail on the pinned card.
- **Reminder history feed** — clock icon in the Reminders top bar opens sectioned Today / Yesterday / This Week / Older log.
- **Templates** — stacked-squares icon opens picker; "Save as template" at the bottom of the add sheet.
- **Color tags** — 7 colors + None; stripe along the left edge of the pinned card.
- **Drag-to-reorder** — long-press the pinned card → Pin to top / Send to bottom.
- **Streak heatmap** — 30-day grid in the edit sheet for daily/weekly/monthly/yearly cadences.
- **Daily recap push** — Settings → Notifications → toggle + hour picker, default 9 PM.
- **Per-reminder sound toggle** — speaker chip flips sound on/off.
- **Duplicate reminder** — long-press → Duplicate in context menu.
- **Notification grouping** — all reminder pushes share one threadIdentifier so batches collapse in Notification Center.
- **Title autocomplete** — type a prefix, see up to 5 recent matching titles as chips.

### Cross-cutting fixes / polish
- **Household name sync fix** — Settings field now writes to the shared `Household.name`, not local AppStorage.
- **Mute member's pushes** — bell-icon menu per family member in Settings; per-device; honored by status pings + grocery activity.
- **US units** — location radius UI in feet/miles (stored internally as meters for `CLCircularRegion`).
- **Capsule button styling** — Save-as-template, Delete-reminder, photo-panel actions rounded to full capsules.

### Dual-bundle dev setup (also landed in 1.7's work window, not user-facing)
- Debug builds → `com.gbrown10.casalist.dev` with orange DEV banner icon and "Casalist Dev" display name.
- Release stays `com.gbrown10.casalist`; TF workflow unchanged.
- Both bundles share the iCloud container; env split is automatic via config.
- See `CLAUDE.md` "Dual-bundle setup" section for the pbxproj settings + icon regen command + first-time provisioning gotcha.

---

## v1.6 — Shipped 2026-05-16

Live in TestFlight, home group, auto-distributing.

Major surfaces:
- Notifications suite (daily briefing, quiet hours, grocery activity, recurring events, status pings)
- Custom repeat picker (interval × unit × optional weekday)
- Live location sharing (Settings → Privacy toggle + FamilyMapView with member pins)
- Apple Calendar link (mirror push + read-only display)
- Family tab overhaul (agenda tiles, quick-add bar, outings with nested items)
- Announcements with expiry (gradient banner on Family tab)
- Task detail polish (Claim pill, confetti, photo thumbnail)
- Cross-cutting fixes (CloudBackup background-context, auto-rejoin URL preservation on transient errors, Nuke ALL local data clears userName+householdName)

CloudKit Production schema deploy (2026-05-16) bundled the 1.6 FamilyMember location quartet AND the 1.7 TaskItem location quintet. 1.7 needs no additional schema work when it ships.

---

## v1.5 — Shipped 2026-05-15

- Identity rebuild on stable `cloudKitUserID` (per-Apple-ID per-container).
- Dedupe pipeline (`mergeByCloudKitUserID`, `mergeLegacyNameDupes`, `mergeDuplicateMeRecords`).
- Background-context dedupe to avoid SQLite WAL checkpoint blocking the scene-update watchdog (`FRONTBOARD 0x8BADF00D`).
- iOS 26 Swift metadata demangler fix in `DeveloperSettingsSection` (extracted sub-View structs to bound TupleView types).
- 4-scenario two-account test matrix passed (fresh AirDrop / joiner reinstall / owner deletes joiner / owner nuke + reinvite).

---

## v2 backlog

Bigger reworks and brand-new surfaces. See [`docs/v2-backlog.md`](v2-backlog.md). Currently includes:

- **iPad app** — NavigationSplitView shell, multi-column dashboard, keyboard shortcuts, drag-and-drop, Stage Manager friendly
- Notification scheduling rework + Skip-next-occurrence
- Kick member flow (closes the parked 1.5 issue)
- Photo sync verification + fix (FamilyMember.photoBlob)
- App-icon badge count
- Family-wide stats view
- Rewards overhaul
- Starfield (kid mode) overhaul
- Personal Stats Card

---

## Original sketch notes (preserved from earlier roadmap)

Areas the project was originally framed around. Strikethrough = covered by the structured roadmap above; plain = still aspirational.

- ~~recurring bills~~ — sister-app territory (casabills2). Not in Casalist's scope.
- ~~family scheduling~~ — Schedule tab + Calendar grid (v1.9).
- ~~notifications~~ — covered in v1.6 + v1.7.
- **AI chat later** — natural-language task creation, family Q&A ("when's soccer practice next?"). Defer to v2+, possibly its own version line.
- ~~widgets~~ — v1.8.
- ~~Apple Watch support~~ — v1.9 (complication).
- **etc.** — open-ended bucket for ideas as they come up. Drop them in `docs/v2-backlog.md` so they don't get lost.
