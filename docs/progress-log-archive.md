# casaList — Progress Log Archive

Older Progress Log entries rotated out of `CLAUDE.md` to keep the inline log lean.

Newest on top, same format as the inline Progress Log.

When `CLAUDE.md`'s Progress Log hits 6 entries, move the oldest paragraph from there into the top of this file.

---

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
