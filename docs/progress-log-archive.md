# casaList — Progress Log Archive

Older Progress Log entries rotated out of `CLAUDE.md` to keep the inline log lean.

Newest on top, same format as the inline Progress Log.

When `CLAUDE.md`'s Progress Log hits 6 entries, move the oldest paragraph from there into the top of this file.

---

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
