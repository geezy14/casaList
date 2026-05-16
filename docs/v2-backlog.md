# Casalist — Version 2 Backlog

Ideas for the next major version. v1.x continues with the staged
1.7 / 1.8 / 1.9 work; v2 is a parallel design track where bigger
reworks and brand-new surfaces collect.

Newest first.

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
