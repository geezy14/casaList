# Refactor Status — 2026-05-19

Snapshot after the 10-area review in `docs/CLAUDE_REFACTOR_REVIEW.md`.
6 of 10 areas shipped to `main`; 4 are intentionally deferred under
the sync-baseline rule. Nothing in this round has been pushed to
TestFlight — the most recent TF is **3.0 (5)**, predating these
commits.

## Shipped

| Area | Commit | Surface | Notes |
|---|---|---|---|
| 4 — Notification ID migration | `e51e8b3` | scheduling | `notificationBaseId(for:)` is uid-based; `legacyNotificationBaseId(for:)` cleans up the old timestamp ids on every schedule pass |
| 5 — Reminder routing in `sync(tasks:)` | `e51e8b3` | scheduling | `sync(tasks:)` now honors `shouldDeviceScheduleReminder` like `scheduleNow` already did |
| 9 — Silent save failure publication | `e51e8b3` | data layer | `CasaCoreDataStack` is `ObservableObject` with `@Published var lastSaveError`; posts `.casaCoreDataSaveDidFail` |
| 10 — `notifyMode` + `announceHousehold` audit | `e51e8b3` | verification | confirmed both attrs are fully wired (model, defaults, UI, schedulers, Production schema) |
| 3 — Local-only fallback visibility | `7cc503f` | data layer | `@Published var isLocalFallback`; coral `LocalFallbackBanner` pinned to top safe-area |
| 1 — Entity-lookup force-unwrap safety | `35f76d4` | data layer | `CasaEntity.resolve(_:in:)` replaces 5 `NSEntityDescription.entity(...)!` sites with a `preconditionFailure` carrying the entity name |
| (this round) Stability polish | — | data layer + UI | `CasaShareLog.append(_:)` helper, save failures mirrored to `share-log.txt`, `SaveErrorBanner` UI |

## Deferred (under the sync-baseline rule)

The CLAUDE.md sync-baseline rule says: TF 2.2 / 2.5 / 3.0 (2) are the
known-good baselines, and changes that can affect CloudKit sync, launch
ordering, Core Data store loading, CKShare acceptance, notification
dedupe keys, or layout rendering need **TF Release proof on Air +
iPhone 15** before merging. The following four areas all cross that
line and were left alone this round:

| Area | Why deferred |
|---|---|
| 2 — Parallelize / defer startup `.task` work | `HouseholdProvisioner.reconcile` + `attemptAutoRejoinSavedShare` + `NotificationsManager.syncFromContext` run sequentially today; the ordering is load-bearing for CKShare dedupe and for the iCloud-KV warm-up. Re-ordering is exactly the 2.4 → 2.5 regression class. |
| 6 — Split `NotificationsManager.swift` (1,306 lines) | Pure code moves require `private` → `internal` for ~12 helpers; the dedupe-key constants are deduplication state. Wrong copy = duplicate or missed pushes, only visible after a day of real usage. |
| 7 — Split `CasaCoreData.swift` | Holds the persistent-store descriptions, CK container options, and the schema-gate-adjacent code. Any reorder of `loadPersistentStores` / `automaticallyMergesChangesFromParent` is a sync-baseline change. |
| 8 — Split `CasalistCottage.swift` (9,352 lines) | The entire UI tree. Nested types lose their qualifier when extracted, `fileprivate` view helpers need access widening, and the 4-layout `@AppStorage("appLayout")` switching is tightly woven. Easy to silently break a layout variant. |

## Files Changed (this stability round)

- `casalist/CasaShareLog.swift` (new) — central `share-log.txt` appender
- `casalist/CasaCoreData.swift` — CK event observer, local-fallback path,
  and `save()` failure all route through `CasaShareLog.append`
- `casalist/CoreDataEntityLookup.swift` — same
- `casalist/SaveErrorBanner.swift` (new) — banner observing `lastSaveError`
- `casalist/casalistApp.swift` — `.modifier(SaveErrorBannerOverlay())`
  attached to `CasalistCottage.Root()`

## Save Calls Replaced / Behavior Changes

- **`CasaCoreDataStack.save()`**: now appends `"SAVE FAILED: …"` to
  `share-log.txt` in addition to `NSLog` + `@Published` + Notification.
  No change to the rollback semantics.
- **CK event observer**: same field-log payload as before, but routed
  through `CasaShareLog.append` (which uses a serial queue, so
  concurrent CK events no longer race the FileHandle).
- **Local-fallback path**: now mirrors to `share-log.txt` (added today
  in 7cc503f; this round refactored it onto the helper).
- **`CasaEntity.resolve`**: now mirrors to `share-log.txt` via the
  helper.
- **`SaveErrorBanner`**: new — shows a coral top-safe-area warning
  ("Couldn't save change — <description>") for 6 seconds when
  `lastSaveError` flips non-nil. Tap dismisses early. Sits below
  `LocalFallbackBanner` if both happen to be active.

Net behavior changes: zero on the hot path. Save failures and entity
crashes that were already happening get a new line in `share-log.txt`,
and save failures now produce a visible UI banner instead of just an
NSLog + invisible published value.

## Risky Areas Intentionally Skipped

- Startup ordering refactor (Area 2)
- `CasaCoreData.swift` split (Area 7)
- `NotificationsManager.swift` split (Area 6)
- `CasalistCottage.swift` split (Area 8)
- `runDedupePipeline` (the load-bearing background-context pattern that
  was reverted from `performBackgroundTask` in TF 2.5)
- Remote-change debounce window (2-second pipe)
- CloudKit container env / store descriptions
- Schema-gate Run Script build phase

## Recommended TestFlight Checklist (when ready to ship)

This batch is conservative but it does ship a new banner that subscribes
to `CasaCoreDataStack`. Worth verifying on both devices before calling
it safe:

1. **Two-account sync still works.** Create a TaskItem on iPhone Air,
   verify it appears on iPhone 15 within 30s. (TF 2.5 baseline test —
   if this regresses, runDedupePipeline was disturbed.)
2. **Two-account CKShare still works.** Have the recipient device
   leave the household, re-invite, accept. Owner's tasks should
   become visible to the recipient.
3. **Local-fallback banner.** Toggle airplane mode + restart app at
   least once with the iCloud account signed out → the coral
   "Sync is unavailable" banner should appear at the top.
4. **Save-failure banner.** No easy way to force a save failure in
   normal use; smoke-test by adding/editing a few entities and
   confirming the banner does NOT appear during normal happy-path
   saves. (If it appears, `lastSaveError` is leaking a stale error.)
5. **Notification ids didn't regress.** Schedule a recurring chore
   (daily), let it fire once, mark it done from the lock-screen,
   confirm the next occurrence reschedules. Then schedule a one-shot
   reminder, confirm it fires once and doesn't duplicate.
6. **Reminder routing.** Create a reminder assigned to a specific
   family member. On the assignee's device, the local notification
   should fire. On other devices it should NOT fire.
7. **Entity-lookup helper.** Smoke-test creation paths for TaskItem,
   FamilyMember, FamilyGoal, FamilyEvent, ChoreTemplate. If anything
   crashes with "Casa: missing Core Data entity …" the model
   shipped without a required entity — would have been a silent
   force-unwrap crash before.
8. **Schema gate intact.** Run `bash scripts/cloudkit-schema-diff.sh`
   before archiving — should report Production matches Development.

Sync-baseline reminder: changes that touch `runDedupePipeline`, the
remote-change debounce, store descriptions, or the schema gate need
**TF Release** proof on Air + iPhone 15 — Debug and simulator do not
count.
