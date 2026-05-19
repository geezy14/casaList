# Casalist Refactor + Stability Review

## Repository

```text
geezy14/casaList
```

## Main Goal

Perform a careful refactor-focused code review and implementation pass.

The goal is to reduce:

- crash risk
- Core Data instability
- CloudKit sync problems
- notification scheduling bugs
- launch freezes
- schema migration risk
- oversized-file maintenance problems

WITHOUT changing:

- user-facing behavior
- family sync architecture
- rewards/points behavior
- reminder behavior
- calendar sync behavior
- current schema compatibility
- existing TestFlight data

This app already has:

- CloudKit sync history
- real shared-family data
- TestFlight users
- production schema dependencies

Be conservative.

Refactor for safety and maintainability, not novelty.

---

# Critical Rules

## Do Not Break CloudKit Sync

Casalist uses:

```swift
NSPersistentCloudKitContainer
```

The app supports:

- private stores
- shared stores
- CKShare-based family sharing

Do not make destructive changes.

---

# DO NOT CHANGE THESE

## CloudKit Container

Do NOT change:

```swift
iCloud.com.gbrown10.casalist
```

---

## Persistent Store Names

Do NOT rename:

```text
Casalist-Private.sqlite
Casalist-Shared.sqlite
Casalist-Local.sqlite
```

---

## Entity Names

Do NOT rename:

```text
Household
FamilyMember
TaskItem
FamilyGoal
ChoreTemplate
FamilyEvent
```

---

## Relationship Names

Do NOT rename:

```text
members
tasks
goals
chores
events
household
```

---

## Current Sharing Architecture

Do NOT remove or redesign:

- CKShare support
- shared store behavior
- preferredTarget household logic
- private/shared store selection
- existing share-root architecture

---

## Existing App Features

Do NOT redesign or remove:

- reminders
- rewards
- family roles
- points
- grocery flow
- maintenance flow
- schedule/calendar flow
- EventKit mirroring
- recurring reminders
- quiet hours
- recap notifications
- location reminders
- role permissions

---

# Schema Safety Rules

## Absolutely Avoid

Do NOT:

- rename entities
- rename attributes
- delete attributes
- change attribute types
- change optional -> non-optional
- change relationship names
- change inverse relationships
- change CloudKit container IDs
- remove fields from the model

---

## If Schema Change Is Required

STOP FIRST.

Before changing schema, provide:

- entity name
- field name
- old type
- new type
- migration behavior
- whether it requires Production CloudKit deployment
- whether the change is additive
- rollback risk

Do not guess on schema.

---

# Current Known Stable Additive Fields

Recent additive fields include:

```text
TaskItem.notifyMode
FamilyEvent.announceHousehold
```

These appear additive-safe because they have defaults.

Verify:

- default values
- UI editing behavior
- notification behavior
- migration behavior
- CloudKit schema assumptions

Do not remove them.

---

# Refactor Area 1 — Core Data Force-Unwrap Crash Risk

## Problem

Several NSManagedObject convenience initializers use:

```swift
NSEntityDescription.entity(forEntityName: ..., in: context)!
```

If the Core Data model fails to load correctly, this crashes the app.

Known files:

```text
TaskItem.swift
FamilyEvent.swift
FamilyMember.swift
```

Possibly additional model files.

---

## Goal

Remove unsafe force unwraps.

Replace them with safer entity-resolution logic.

---

## Requirements

Create a shared helper.

Possible direction:

```swift
enum CoreDataEntityFactory {
    static func entityDescription(
        named name: String,
        in context: NSManagedObjectContext
    ) -> NSEntityDescription {
        guard let entity = NSEntityDescription.entity(forEntityName: name, in: context) else {
            assertionFailure("Missing Core Data entity: \(name)")
            fatalError("Core Data model missing entity: \(name)")
        }
        return entity
    }
}
```

Use the safest practical implementation.

Requirements:

- avoid unexplained crashes
- provide useful diagnostics
- fail in a controlled way if necessary
- avoid returning fake invalid entities

---

## Deliverable

Replace repeated force unwraps with a shared helper.

Add useful logging.

---

# Refactor Area 2 — Startup Blocking Risk

## Problem

`CasaCoreDataStack` currently blocks startup using:

```swift
DispatchGroup.wait()
```

while loading persistent stores.

This can freeze app launch if:

- CloudKit hangs
- store loading stalls
- migrations are slow
- network/setup is delayed

---

## Goal

Reduce or eliminate launch blocking.

---

## Requirements

Refactor store loading state.

Possible direction:

```swift
enum StoreLoadState {
    case loading
    case ready
    case failed(Error)
    case localFallback
}
```

Possible improvements:

- async store readiness
- visible loading state
- visible sync failure state
- timeout handling
- better diagnostics

---

## Important

Do NOT accidentally break launch behavior.

If full async refactor is too risky, stage it:

1. diagnostics
2. visible failure state
3. timeout protection
4. later async loading

---

## Deliverable

Reduce launch freeze risk.

At minimum:

- visible failure state
- detailed logging
- reduced indefinite blocking risk

---

# Refactor Area 3 — Silent Local-Only Fallback Risk

## Problem

If CloudKit stores fail to load, the app silently falls back to:

```text
Casalist-Local.sqlite
```

This makes the app appear functional while sync is broken.

Users may unknowingly create unsynced data.

---

## Goal

Keep fallback if necessary, but make it visible.

---

## Requirements

If local-only fallback activates:

- show visible warning/banner
- expose fallback state from CasaCoreDataStack
- clearly log the failure
- avoid pretending sync still works

Suggested wording:

```text
Sync is temporarily unavailable. Changes made now may not appear on family members’ devices.
```

---

## Deliverable

Visible sync-failure state.

Do NOT silently hide CloudKit failure.

---

# Refactor Area 4 — Notification ID Collision Risk

## Problem

Notification IDs currently use:

```swift
let baseId = "task-\(Int(task.createdAt.timeIntervalSince1970 * 1000))"
```

This can collide when:

- tasks share timestamps
- migrated records have bad dates
- timestamps are duplicated

---

## Goal

Use stable task identity.

---

## Requirements

Use:

```swift
let baseId = "task-\(task.uid)"
```

---

## Migration Requirement

Old pending notifications may still exist.

Implement cleanup compatibility:

- cancel old-format IDs
- cancel new-format IDs
- prevent duplicates
- preserve snooze behavior
- preserve skip-next behavior

---

## Deliverable

Stable notification IDs using task.uid.

---

# Refactor Area 5 — Notification Routing Bug

## Problem

There are two scheduling paths:

```text
scheduleNow(for:)
sync(tasks:)
```

`scheduleNow(for:)` checks:

- notifyMode
- assignee
- local user
- admin status

But `sync(tasks:)` appears to schedule more broadly.

This can cause devices to receive reminders they should not receive.

---

## Goal

Centralize scheduling permission logic.

---

## Requirements

Create a shared function.

Possible direction:

```swift
static func shouldScheduleOnThisDevice(task: TaskItem) -> Bool
```

It should evaluate:

- category
- notifyMode
- assignee
- local username
- admin/owner role
- empty-assignee behavior

---

## Preserve Existing Behavior

```text
notifyMode == "everyone"
```

→ all devices schedule

```text
notifyMode == "admins"
```

→ only admins/owners schedule

Default/empty notifyMode:

→ legacy assignee behavior

Empty assignee:

→ broadcast behavior

---

## Deliverable

Both scheduling paths use identical routing logic.

---

# Refactor Area 6 — NotificationsManager Split

## Problem

`NotificationsManager.swift` is too large and handles many responsibilities.

Current responsibilities include:

- authorization
- scheduling
- routing
- recurrence calculation
- quiet hours
- reminder recap
- weekly recap
- skip occurrence
- upcoming fire queries
- subtitle generation

---

## Goal

Split the file into smaller logical units.

---

## Suggested Split

```text
NotificationsManager.swift
ReminderRouting.swift
ReminderOccurrenceEngine.swift
QuietHours.swift
ReminderRecapScheduler.swift
WeeklyRecapScheduler.swift
ReminderNotificationIDs.swift
```

Use better names if needed.

---

## Requirements

- preserve behavior
- preserve public call sites where possible
- avoid giant rewrite
- move pure utility logic first

---

## Deliverable

Smaller files with stable behavior.

---

# Refactor Area 7 — CasaCoreData.swift Split

## Problem

`CasaCoreData.swift` currently handles:

- model creation
- CloudKit configuration
- store loading
- fallback stores
- schema initialization
- save helpers
- event logging
- relationships
- context helpers
- household selection

This creates maintenance risk.

---

## Goal

Split into smaller focused files.

---

## Suggested Split

```text
CasaCoreDataStack.swift
CasaCoreDataModelFactory.swift
CasaCloudKitEventLogger.swift
CasaStoreLoadState.swift
CasaContextHelpers.swift
HouseholdSelectionHelpers.swift
```

Use actual best structure.

---

## Requirements

Do NOT:

- rename entities
- rename attributes
- reorder model behavior in dangerous ways
- remove schema initialization support
- change store URLs
- change container IDs

---

## Deliverable

Cleaner Core Data stack.

---

# Refactor Area 8 — CasalistCottage.swift Split

## Problem

`CasalistCottage.swift` is extremely large.

It mixes:

- themes
- palettes
- screens
- components
- dashboard logic
- layout variants

---

## Goal

Split into maintainable files.

---

## Suggested Split

```text
CasalistPalette.swift
CasalistTheme.swift
CottageComponents.swift
CottageHomeView.swift
CottageRewardsView.swift
CottageFamilyListView.swift
CottageMyToDoView.swift
CottageDashboardTiles.swift
```

Use actual best structure.

---

## Requirements

Do NOT:

- redesign UI
- rename palette names
- change AppStorage keys
- change theme selection behavior
- alter existing layouts

---

## Deliverable

Smaller UI/theme files.

---

# Refactor Area 9 — Better Save Error Visibility

## Problem

Current save helper:

```swift
do {
    try ctx.save()
} catch {
    NSLog("Casa Core Data save error: \(error)")
    ctx.rollback()
}
```

This prevents crashes but hides failures from the UI.

---

## Goal

Improve visibility of save problems.

---

## Requirements

Possible approaches:

- published error state
- sync warning banner
- NotificationCenter event
- lightweight diagnostics panel
- log file output

Do NOT create noisy UX.

---

## Deliverable

Core Data save failures become diagnosable.

---

# Refactor Area 10 — Verify notifyMode + announceHousehold

## Goal

Verify recent additive fields are fully integrated.

Fields:

```text
TaskItem.notifyMode
FamilyEvent.announceHousehold
```

---

## Verify

Check:

- defaults
- scheduling behavior
- UI editing
- migration assumptions
- CloudKit assumptions
- missing-field handling
- nil/default safety

---

## Deliverable

Confirm whether these fields are safe.

Apply minimal safe fixes only if needed.

---

# Work Style Requirements

## Before Editing

Provide:

- short implementation plan
- files that will change
- risk assessment
- whether schema changes are needed
- whether CloudKit behavior changes

---

## During Editing

Prefer small grouped commits.

Suggested grouping:

1. notification ID fix
2. routing fix
3. Core Data unwrap safety
4. fallback visibility
5. file splitting
6. diagnostics

---

## After Editing

Provide:

- files changed
- summary of changes
- build/test status
- warnings
- manual steps required
- schema notes
- CloudKit deployment notes

---

# DO NOT DO

Do NOT:

- merge profar into main
- modify Profar migration work
- create a new standalone app
- change bundle ID
- change CloudKit container
- remove family sharing
- redesign the app
- change rewards/points logic
- change role permissions unless required for a bug fix
- perform destructive migrations
- delete fields/entities

---

# Acceptance Checklist

The refactor is acceptable when:

- app builds
- existing screens still load
- CloudKit container is unchanged
- schema remains compatible
- notification IDs use task.uid
- old timestamp notifications are cleaned up
- routing logic is centralized
- fallback sync failure is visible
- missing entities produce useful diagnostics
- oversized files are reduced safely
- no destructive migration was introduced

---

# Final Instruction

Be conservative.

This app already has real sync history and TestFlight builds.

If anything is uncertain around:

- Core Data
- CloudKit
- migrations
- shared stores
- CKShare behavior
- notification persistence

STOP and explain before changing it.
