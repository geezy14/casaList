# Profar Migration Plan

## Goal

Separate the `profar` branch from Casalist and turn it into its own standalone iOS app named **Profar**.

Profar is currently a HealthKit-focused side project that was created inside the Casalist repository. It should become its own app, with its own project structure, persistence layer, bundle ID, entitlements, and CloudKit container.

## Source Repository

- Repository: `geezy14/casaList`
- Source branch: `profar`
- Profar branch HEAD: `6fda2d3`
- Commit title: `Profar: heart rate shows live reading, not 24h average`

## Critical Rules

- Do **not** modify Casalist `main` as part of the Profar app migration.
- Do **not** merge the `profar` branch directly into Casalist `main`.
- Do **not** reuse the Casalist CloudKit container.
- Do **not** reuse the Casalist Core Data schema.
- Do **not** ship Profar inside Casalist.
- Do **not** remove, rename, or change existing Casalist Core Data / CloudKit entities.
- If a change might affect Casalist sync, Core Data, CloudKit, or schema compatibility, stop and explain before editing.

## Desired Result

Create a standalone iOS app named **Profar**.

The standalone Profar app should:

- Build and run independently in Xcode.
- Use HealthKit for health metrics.
- Preserve the existing Profar health dashboard behavior.
- Preserve the live heart-rate behavior from commit `6fda2d3`.
- Remove Casalist household/task/reward/navigation dependencies.
- Use its own persistence model.
- Use its own bundle ID.
- Use its own HealthKit entitlement.
- Use its own CloudKit container only if sync is needed.

## New App Identity

Recommended app identity:

```text
App name: Profar
Bundle ID: com.gbrown10.profar
CloudKit container, if needed: iCloud.com.gbrown10.profar
Core Data container name: Profar
```

Do **not** use:

```text
iCloud.com.gbrown10.casalist
```

## Files To Inspect On The `profar` Branch

Inspect the `profar` branch and identify all Profar-related files before making changes.

Known Profar files include:

```text
casalist/ProfarEntry.swift
casalist/ProfarHealthService.swift
casalist/ProfarPlaceholderView.swift
casalist/ModulesSettingsSection.swift
```

Also inspect:

```text
casalist/CasaCoreData.swift
casalist/CasalistCottage.swift
casalist/SettingsView.swift
Info.plist
casalist/casalist-Debug.entitlements
casalist/casalist-Release.entitlements
casalist.xcodeproj/project.pbxproj
```

These files may contain Profar hooks, HealthKit permissions, navigation entry points, module toggles, or schema changes.

## Existing Profar Functionality To Preserve

Preserve the Profar functionality already present on the `profar` branch, including:

- HealthKit data fetching.
- Health dashboard UI.
- Daily health stat snapshots.
- Live heart rate behavior.
- Resting heart rate handling.
- Respiratory rate handling.
- Sleep metrics.
- Activity metrics.
- Recovery / strain / stress scoring, if already implemented.
- Any existing HealthKit permission request flow.

The `6fda2d3` commit specifically changed heart rate to use the latest sample within a 60-minute lookback instead of a 24-hour average. Preserve that behavior.

## Remove Casalist Dependencies

Profar should not depend on Casalist concepts such as:

```text
Household
FamilyMember
TaskItem
FamilyGoal
FamilyEvent
ChoreTemplate
Casalist navigation
Casalist dashboard
Casalist settings/modules
Casalist CloudKit container
Casalist Core Data stack
Casalist sharing model
Casalist rewards/points system
```

If Profar currently relies on `Household` or `FamilyMember`, replace those dependencies with Profar-specific concepts.

## Recommended Architecture

Start with a **personal-only** Profar app.

Do not build family sharing yet.

Recommended standalone concepts:

```text
ProfarApp.swift
ProfarDashboardView.swift
ProfarSettingsView.swift
ProfarHealthService.swift
ProfarEntry.swift
ProfarCoreDataStack.swift
ProfarProfile.swift, only if needed
```

If a user/profile object is needed, create a simple Profar-specific model instead of using `FamilyMember`.

Possible model names:

```text
ProfarProfile
ProfarUser
HealthProfile
```

## Persistence Rules

Profar should have its own persistence stack.

Recommended:

```swift
NSPersistentCloudKitContainer(name: "Profar")
```

If CloudKit sync is enabled, use:

```text
iCloud.com.gbrown10.profar
```

Do not use the Casalist Core Data stack.
Do not use the Casalist entity list.
Do not include Casalist-only entities in Profar.

## Profar Data Model

The `profar` branch currently adds a `ProfarEntry` entity with HealthKit-derived fields.

When moving Profar into its own app, create a clean Profar-specific schema for these health snapshots.

`ProfarEntry` may include fields such as:

```text
uid
date
steps
activeKcal
exerciseMinutes
sleepMinutes
deepSleepMinutes
remSleepMinutes
coreSleepMinutes
sleepEfficiencyPercent
restingHR
heartRate
respiratoryRate
bloodOxygen
mindfulMinutes
walkingMeters
flightsClimbed
hrvMS
vo2Max
weightKg
bmi
bodyFatPercent
bodyTemperatureC
bpSystolic
bpDiastolic
bloodGlucose
waterML
caffeineMG
recoveryScore
strainScore
stressScore
updatedAt
createdAt
deletedAt
```

For standalone Profar, remove or reconsider fields that only exist because Casalist was family-based, such as:

```text
memberName
memberUid
household relationship
```

If keeping these fields temporarily helps migration, document why.

## HealthKit Requirements

Set up HealthKit correctly for the standalone Profar app.

Required work:

- Add HealthKit capability/entitlement.
- Add required Info.plist privacy descriptions.
- Request only the HealthKit read permissions Profar actually uses.
- Keep write permissions out unless needed.
- Make sure the app handles denied permissions gracefully.
- Make sure the UI does not crash when HealthKit data is missing.

Recommended privacy description examples:

```text
NSHealthShareUsageDescription
Profar uses your Health data to show your personal activity, sleep, heart, and recovery insights.

NSHealthUpdateUsageDescription
Profar may save health-related preferences or derived activity data if you enable that feature.
```

Only include `NSHealthUpdateUsageDescription` if the app actually writes to HealthKit.

## Xcode / Entitlements Work

Make sure the standalone app has its own:

- Xcode project or target.
- Bundle ID.
- Signing configuration.
- Debug entitlement file.
- Release entitlement file.
- HealthKit entitlement.
- Optional CloudKit entitlement using the Profar container.

Do not copy Casalist signing/container settings blindly.

## Suggested Implementation Steps

1. Inspect the `profar` branch.
2. List every Profar-related file.
3. List every Casalist dependency inside those files.
4. Create the standalone Profar app structure.
5. Copy Profar-specific code into the new app.
6. Rename or refactor Casalist-specific references.
7. Replace Casalist Core Data stack with Profar persistence.
8. Replace household/member dependencies with personal-only data flow.
9. Configure HealthKit permissions and entitlements.
10. Configure the new bundle ID.
11. Configure CloudKit only if needed, using the Profar container.
12. Build in Xcode.
13. Fix compile errors.
14. Run the app and verify HealthKit permission flow.
15. Verify dashboard loads without HealthKit data.
16. Verify dashboard loads with HealthKit data.
17. Summarize changes clearly.

## Do Not Do Yet

Do not add these in the first standalone migration unless specifically requested:

- Family sharing.
- Casalist integration.
- Rewards or points.
- Household invitations.
- CloudKit sharing via CKShare.
- A full social leaderboard.
- Any destructive migration of Casalist data.

## Expected Final Summary

After completing the work, provide a summary with:

- New files created.
- Files copied from `profar`.
- Files removed or ignored from Casalist.
- Casalist dependencies removed.
- HealthKit permissions used.
- Persistence model created.
- Bundle ID / entitlement changes.
- Manual Xcode/App Store Connect steps still required.
- Any risks or unknowns.

## Safety Instruction For Coding Agents

If you are unsure whether a change affects Casalist sync, Core Data, CloudKit, or schema compatibility, stop and explain before editing.

Do not guess on schema.

Do not modify Casalist `main` to make Profar work.

Create Profar as a clean standalone app path instead.
