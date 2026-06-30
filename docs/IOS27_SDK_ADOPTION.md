# Casalist — iOS 27 SDK adoption plan

> Grounded analysis of which iOS 27 APIs are worth adopting for Casalist. Every
> line below is backed by a real diff between the iOS 26.4 and iOS 27.0
> swiftinterface files on disk — no memory, no rumor.
>
> **Honesty gate (non-negotiable):** recommend ONLY APIs that appear in the
> installed 27 SDK headers OR Apple's published 27 docs. Each item below is
> tagged `[header]` (verified in the SDK), `[docs]` (verified in Apple docs),
> or `[inferred]` (signature looks right but intent not yet confirmed).
> Re-verify against Apple's WWDC-2026 session docs before shipping.
>
> Companion: cross-app standing order lives at
> `~/.claude/projects/-Users-geezy/memory/reference_new_sdk_adoption.md`.
> FoundationModels-specific guidance:
> `~/.claude/projects/-Users-geezy/memory/reference_fm_reasoning_ios27.md`.

---

## 0. Toolchain state (verified 2026-06-08)

- **Stable (active):** Xcode `26.4.1` at `/Applications/Xcode.app`.
  `xcode-select -p` resolves here. **All TF/Release archives must use this.**
- **Beta (staged):** Xcode `27.0` (build `25183.29.15`) at
  `/Applications/Xcode-beta.app`, containing `iPhoneOS27.0.sdk`.
- **iOS 27 simulator runtime:** NOT yet downloaded. Open Xcode-beta once and
  let it stage, or run `xcodebuild -downloadPlatform iOS` from the beta tooling.

**To enable iOS-27 dev (per task, not permanent):**
```bash
sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer
xcodebuild -version   # expect 27.0
```

**To return to stable before any TF Release archive:**
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

SDK paths used in the diffs below:
- `SDK26 = /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk`
- `SDK27 = /Applications/Xcode-beta.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk`

---

## 1. How the diff was run (reproducible)

```bash
SDK26=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
SDK27=/Applications/Xcode-beta.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk
ARCH=arm64e-apple-ios

for fw in EventKit AppIntents WidgetKit ActivityKit CloudKit FoundationModels Contacts SwiftUI; do
  I26=$SDK26/System/Library/Frameworks/$fw.framework/Modules/$fw.swiftmodule/$ARCH.swiftinterface
  I27=$SDK27/System/Library/Frameworks/$fw.framework/Modules/$fw.swiftmodule/$ARCH.swiftinterface
  echo "=== $fw ==="
  diff "$I26" "$I27" 2>/dev/null | grep -E "^> " | grep -E "public (struct|class|enum|protocol|func|var|static|init|actor)"
done
```

Net new lines per framework (2026-06-08 diff):

| Framework        | New lines | Notes |
|------------------|----------:|-------|
| `FoundationModels` | 2,376 | covered separately in `reference_fm_reasoning_ios27.md` |
| `AppIntents`       | 14,516 | already works on iOS 26 — adopt now, 27 additions are bonus |
| `CloudKit`         |   947 | several Casalist-relevant additions; see §3 |
| `WidgetKit`        |   492 | Liquid Glass surface + push reloads + control widgets |
| `ActivityKit`      |   179 | scheduled-start Live Activities |
| `Contacts`         |    16 | richer change events; mostly low-impact |
| `EventKit`         |    12 | typed `EventStoreChanged` notification |

---

## 2. The recommendations (ranked by ROI for Casalist)

### Tier A — Adopt now, no iOS-27 gate required

**A1. App Intents for Casalist actions** `[docs, iOS 26+]`

The framework already shipped in iOS 26; iOS 27 only expanded it. Casalist
has zero App Intents today — pure greenfield.

Concrete intents to define:
- `CreateChoreIntent(title, points, assignee?)` → calls into the same code
  path `AddTaskView.saveTask` uses.
- `AddOutingIntent(title, startsAt, endsAt?)` → wraps `AddFamilyTripView.save`,
  including the paired-event creation from build `20.3`.
- `MarkChoreDoneIntent(query: TaskItemQuery)` → flips `isCompleted`, awards
  points (uses the existing `FamilyPoints.toggle` logic).
- `RedeemRewardIntent(query: FamilyGoalQuery)` → calls
  `GoalApproval.redeem(_:in:)` for admins.

App Shortcuts phrases (`AppShortcutsProvider`):
- "Add a chore to Casalist"
- "Plan a Casalist outing"
- "Redeem a reward in Casalist"

This is the biggest single UX unlock in the SDK pass — voice + Shortcuts +
Spotlight + the system tap into the core verbs without leaving the app.
**Does not require Xcode 27 or iOS 27.** Should be its own commit.

---

### Tier B — Adopt iOS-27-only, `@available(iOS 27, *)`-gated

**B1. `WidgetTexture.glass` on CasalistWidgets** `[header]`

```
// from iPhoneOS27.0.sdk WidgetKit interface
public struct WidgetTexture : Sendable, Hashable {
    public static let glass: WidgetTexture
    public static let paper: WidgetTexture
}
```

CasalistWidgets currently uses solid backgrounds. On iOS 27 builds, apply
`WidgetTexture.glass` to the widget background for the system Liquid Glass
treatment. iOS 26 path unchanged.

**B2. `TimelineEntryRelevance` + `RelevanceConfiguration`** `[header]`

```
public struct TimelineEntryRelevance : Codable, Hashable {
    public var score: Float
    public var duration: TimeInterval
    public init(score: Float, duration: TimeInterval = 0.0)
}
public struct RelevanceConfiguration<Content> : WidgetConfiguration { … }
```

Mark today's chores, upcoming events, and "redeem ready" goals with high
relevance scores + durations so the system smart-stack ranks Casalist
correctly. The widget's `TimelineEntry.relevance` is the hook.

**B3. `WidgetPushInfo` — push-driven widget reloads** `[header, inferred-on-purpose]`

```
public struct WidgetPushInfo : Sendable { … }
```

Instead of burning timeline budget on regular reloads, push from CloudKit
(or any backend) to refresh the widget only when state actually changed.
Likely paired with `WidgetCenter.reloadTimelines` via push. Confirm against
WWDC-2026 widget session before wiring up.

**B4. ActivityKit scheduled-start Live Activities** `[header]`

```
public static func request(
    attributes: Attributes,
    content: ActivityContent<Activity<Attributes>.ContentState>,
    pushType: PushType? = nil,
    style: ActivityStyle,
    alertConfiguration: AlertConfiguration,
    startDate: Date
) throws -> Activity<Attributes>
```

Today's `StatusPing` Live Activity fires only when the announcement is
posted. With `startDate:`, you can schedule a Live Activity to begin at a
future moment — concretely: schedule the activity to start 60 min before
an outing/event's `startDate` so a "Movie night in 1 hour" pill shows on the
Lock Screen and Dynamic Island without the app being open. The same surface
the announcement banner already uses (`StatusPingLiveActivityBridge`)
extends naturally.

**B5. EventKit typed `EKEventStore.EventStoreChanged`** `[header]`

```
public struct EventStoreChanged : MainActorMessage {
    public static var name: Notification.Name { … }
    public typealias Subject = EKEventStore
}
public static var changed: BaseMessageIdentifier<EventStoreChanged> { … }
```

`ExternalCalendarStore.swift` currently subscribes to the un-typed
`.EKEventStoreChanged` Notification and debounces 600 ms. The typed-message
API is a clean swap. Low risk, low ROI — nice cleanup only.

**B6. CloudKit single-lookup `userIdentity(forEmailAddress:)`** `[header]`

```
@_alwaysEmitIntoClient public func userIdentity(forEmailAddress: String)
    async throws -> CKUserIdentity?
@_alwaysEmitIntoClient public func userIdentity(forPhoneNumber: String)
    async throws -> CKUserIdentity?
public func userIdentities(forEmailAddresses: [String])
    async throws -> [String : CKUserIdentity]
public func allUserIdentitiesFromContacts()
    async throws -> [CKUserIdentity]
```

These replace the verbose `CKFetchShareParticipantsOperation` lookup. If we
ever revisit the pre-targeted invite work (reverted earlier; see
casaCal session notes), this is the cleaner shape. `allUserIdentitiesFromContacts()`
also enables a "Show me which of my Contacts can accept a Casalist invite"
UX without manually entering each address.

---

### Tier C — Skip / hold

**C1. `CKSyncEngine` — DO NOT migrate** `[header]`

```
final public class CKSyncEngine : Sendable { … }
public protocol CKSyncEngineDelegate : AnyObject, Sendable { … }
```

A high-level alternative to hand-rolled `CKSubscription` + change tokens.
Casalist's sharing stack lives on `NSPersistentCloudKitContainer` (Core Data
backed) and the saga to reach the GOLD baseline (see CLAUDE.md "CRITICAL:
multi-user family sharing" + casalist_sync_baseline_rule.md) was load-bearing.

`CKSyncEngine` is **not** a NSPCKC layer — it's a parallel sync API. Adopting
it would mean ripping out the working stack. **Skip indefinitely.** Re-evaluate
only if Apple deprecates NSPCKC.

**C2. FoundationModels** — covered in the dedicated FM doc. Casalist has no
on-device-AI surface today; not a priority for this app.

**C3. Contacts change-event extras** — only useful if Casalist starts pulling
from Contacts. Currently we don't. Skip.

---

## 3. Codebase landing sites (map recommendations to real files)

| Recommendation | File(s) to touch |
|---|---|
| A1: AppIntents | new `casalist/Intents/` directory + `CasalistIntents.swift` registering an `AppShortcutsProvider`. Calls existing `AddTaskView` / `AddFamilyTripView` / `FamilyPoints` / `GoalApproval` code paths. |
| B1: `WidgetTexture.glass` | `CasalistWidgets/*.swift` — background modifier |
| B2: `TimelineEntryRelevance` | each `TimelineEntry` conformer in `CasalistWidgets/` |
| B3: `WidgetPushInfo` | CloudKit subscription + `WidgetCenter` glue, likely in `casalistApp.swift` near share-accept handlers |
| B4: ActivityKit `startDate:` | `StatusPingLiveActivityBridge` + new caller in `NotificationsManager.scheduleEvent` / `AddFamilyTripView.save` (pre-event scheduling) |
| B5: `EventStoreChanged` | `ExternalCalendarStore.swift` |
| B6: `userIdentity(for…)` | only if revisiting pre-targeted invites — would land in a new `InviteService.swift` |

---

## 4. Risks / non-negotiables

- **Every iOS-27-only adoption is `@available(iOS 27, *)`-gated** with an iOS-26
  fallback (or graceful no-op). Don't raise the deployment target.
- **TF/Release archives stay on Xcode 26.4.1.** Switch with `xcode-select`
  before archiving; switch back afterwards. The CloudKit schema gate
  (`Preflight: CloudKit schema gate` Run Script build phase) runs on Release
  and will fail any archive cut against the beta toolchain anyway because
  the diff script paths are stable-only — don't bypass it.
- **No schema changes for any of A–B.** All recommendations above are local
  or pure-UI; none add a Core Data attribute. If a future task adds a
  `@NSManaged` or `attr(...)`, the Dev→Prod deploy rule
  (`casalist_cloudkit_schema_rule.md`) still applies.
- **Sharing/sync baseline is sacred.** B6 (CKContainer identity lookups)
  is the only CloudKit-adjacent change recommended, and it only reads —
  it does NOT touch the dual-store, the dedupe pipeline, or
  `runDedupePipeline`. C1 (CKSyncEngine) is explicitly skipped.

---

## 5. Open questions / things to verify against Apple docs

- **B3 `WidgetPushInfo`** — signature is clear; exact push payload format
  + entitlement requirements need to come from WWDC-2026 widget session
  before wiring.
- **B4 `startDate:`** — does the system actually start the activity at
  `startDate`, or just enqueue it? Confirm with the ActivityKit session.
- **B1 `WidgetTexture.glass`** — confirm how to apply (modifier name) once
  Apple's widget session is published. Header tells us it exists, not
  exactly how to wire it.
- **A1 App Intents** — Apple's iOS 26 docs are sufficient; the iOS 27
  expansion (14k+ new lines) is largely AssistantSchemas + new
  `IndexedEntity` patterns — worth a separate pass once A1 ships.

---

## 6. Suggested execution order

1. **Land A1 (App Intents)** as a stand-alone branch first, since it works
   on the current stable toolchain. Test on iPhone Air via devicectl, then
   ship a TF build. **No iOS 27 dependency.**
2. **Switch toolchain to the beta** and add B1/B2 in CasalistWidgets behind
   `@available(iOS 27, *)`. Test on the Air running iOS 27.
3. Add B4 (scheduled Live Activities) for upcoming outings. Test the
   Lock Screen + Dynamic Island appearance.
4. (Optional) B5 (typed EventStoreChanged), B3 (push reloads) as polish.
5. **Switch back to stable Xcode** before cutting any TF Release archive.

Each step ships independently; nothing in B blocks A1.

---

*Last verified 2026-06-08 against iPhoneOS27.0.sdk in Xcode-beta `27.0 / 25183.29.15`.*
