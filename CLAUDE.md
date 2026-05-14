# Casalist

## Logging — read first

Every meaningful action you take gets logged in TWO places. Do not skip this.

1. **Global ticker** (one-liner, append as you work):
   `~/.claude/projects/-Users-geezy/memory/replicants_log.md`
   Format: `[crN · YYYY-MM-DD HH:MM · casaList] summary` (≤90 chars).
   Newest at the **bottom**.

2. **Project journal — Progress Log section below** (paragraph, end of session):
   Newest paragraph on **top**. One per session. Terse — what shipped + the key gotcha future-you needs.

**What to log:** TestFlight builds, commits to main, cross-project edits, feature ships/rollbacks, hard-won gotchas. **What to skip:** read-only inspections, single-typo edits, build-only-no-push, anything visible in `git log` anyway.

**Token-bloat prevention:** the Progress Log keeps the latest **5** entries inline. When you add a 6th, move the oldest into `docs/progress-log-archive.md` (newest on top there too). This caps CLAUDE.md size forever. New Claudes read the inline 5 cheaply and grep the archive only when they need deeper history.

Full protocol: `~/.claude/projects/-Users-geezy/memory/claude_replicants.md`.

## Progress Log

> Newest entries on top. Keep this section terse — one paragraph per session
> covering what shipped and what to know going in next time. When this section
> hits 6 entries, rotate the oldest to `docs/progress-log-archive.md`.

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

## Overview
Casalist is a private family household management app for iOS.

The app is built in SwiftUI and uses:
- Core Data via NSPersistentCloudKitContainer (private + shared stores)
- CloudKit (private + shared database scopes, CKShare-based sharing)
- SF Symbols
- Apple-native UI patterns

Earlier iterations used SwiftData @Model; that approach was abandoned because
SwiftData's `.private` scope is per-Apple-ID and could not deliver the
headline family-sharing feature. See the "Progress Log" entry for 2026-05-14
and the "CRITICAL: multi-user family sharing" section.

## Goals
- Keep the app simple and fast
- Prioritize native iOS design
- Avoid unnecessary complexity
- Build features incrementally

## Coding Style
- Use modular SwiftUI views
- Prefer reusable components
- Keep files reasonably small
- Use clear naming
- Avoid unnecessary comments

## Current Features
- Dashboard
- Task creation
- Grocery list
- Personal task filtering

## Important Files
- `CasalistApp.swift` → app entry point
- `ContentView.swift` → dashboard
- `TaskItem.swift` → data model
- `AddTaskView.swift` → task creation

## Workflow
- Read existing code before modifying architecture
- Preserve CloudKit compatibility
- Prefer editing existing components over creating duplicates

## CRITICAL: multi-user family sharing

**Casalist is a family app where multiple iCloud users need to see the same data.** That requirement is load-bearing — the entire concept of "household" is meaningless if family members each see their own private silo. Any feature that touches FamilyMember, TaskItem, FamilyGoal, ChoreTemplate, or FamilyEvent has to assume those records will be visible to people on different Apple IDs.

### What's wrong today (as of 2026-05-14)

The current data layer uses `ModelConfiguration(cloudKitDatabase: .private("iCloud.com.gbrown10.casalist"))`. **SwiftData's `.private` scope is a per-Apple-ID silo.** It syncs across one user's iPhone + iPad + Mac, but it does NOT share data across users. The "Invite family" flow creates a CKShare on a placeholder `Household` CKRecord in a custom zone — but no SwiftData records ever land in that zone. So when a recipient accepts a share, they get an empty Household record and their own private silo continues unchanged.

This means:
- The owner's family/tasks/goals are invisible to anyone they invite.
- The recipient's family/tasks/goals are invisible to the owner.
- All the "admin can give points" / "role-based permissions" UX is currently single-device theater.

### Why this got built the wrong way the first time

This is the prior Claude (me) writing this section. The mistake was:

1. **Stacking features without validating the foundation.** When Geezy asked for invites, the right move was to stop and ask "does the data layer even support multi-user visibility?" Instead I built a slick `UICloudSharingController` flow on top of SwiftData's per-user-private store and called it done because the UI worked. The UI worked; the data didn't move.
2. **Choosing SwiftData out of consistency instead of capability.** SwiftData was already used for the rest of the app, so I reached for it for the shared data too. SwiftData's CloudKit-sharing surface is still partial and partly undocumented as of iOS 17–18, while `NSPersistentCloudKitContainer` (Core Data) has a battle-tested `share(_:to:)` API that Apple's own apps (Reminders, Notes) use. The right call was to either (a) migrate the shareable models off SwiftData onto Core Data, or (b) use a code-based public-zone scheme. I did neither.
3. **Treating "it compiles and the sheet opens" as proof of correctness.** I didn't test a real cross-iCloud-account accept flow until very late, and when Geezy reported failures I kept patching the symptom (build numbers, `CKSharingSupported`, schema deploys) instead of stepping back to see that the underlying store wasn't shareable in the first place.

If you (future Claude) are about to add ANY feature that touches family data, **read this section first** and don't paper over it with more UI. The data layer needs to be fixed before more invitation/role/sharing features mean anything.

### The two paths forward (Geezy chose one of these on 2026-05-14)

**Option A — Apple-managed shared mailbox.**
Migrate shareable models to `NSPersistentCloudKitContainer` (Core Data) and use `share(_:to:)` to put records into a shared zone. Recipients accept via the standard CKShare flow; their app reads the shared zone. End-to-end private through iCloud, Apple manages permissions. Cost: every `@Query` in the app becomes `@FetchRequest`, every `@Model` becomes an `NSManagedObject`, the schema migration is non-trivial. 4–6 hours of careful work, multiple TestFlight cycles to validate.

**Option B — Household-code via CloudKit Public DB.**
Each household gets a code (UUID or short string). Records live in the CloudKit public database with a `householdID` field. Family members enter the code to "join" — their app subscribes to records matching that ID. No CKShare flow, no Apple-managed permissions. Cost: data is technically readable to anyone who knows the code, so don't put anything sensitive in there. For a chores/groceries/schedule app this is acceptable. 2–3 hours, simpler to debug.

**Both options require ripping out the current InviteFamilyView CKShare flow.** Don't try to layer either approach on top of the existing single-user SwiftData store — that's how we got here.

### Rules for any future "family sharing" work

- Never assume SwiftData's `.private` scope shares data across users. It doesn't.
- Before adding any feature that says "everyone sees", verify with a two-Apple-ID test (Geezy's iPhone Air + iPhone 15) that the data is actually visible on both sides. UI-only validation is not enough.
- If using Option A: the underlying `NSPersistentCloudKitContainer` is what does the work — the SwiftData wrapper just hides it.
- If using Option B: every shareable record must have a `householdID` field, and every Query must filter on it. Records without that field are orphans.
- The `CKSharingSupported = YES` Info.plist key only matters for Option A. Setting it without backing data sharing logic does nothing — it just removes one of the "you need a newer version" errors.
- Xcode's `INFOPLIST_KEY_*` build-setting prefix does NOT honor `CKSharingSupported`. Use an explicit `Info.plist` file at the project root with `INFOPLIST_FILE = Info.plist` and `GENERATE_INFOPLIST_FILE = NO`. (Burned on this; the key was silently dropped in builds 3.2 and 3.3.)

### Rules for every future Claude opening this repo

**Rule 1 — Two-account test is the only proof.**
No family-sharing feature is "done" until Geezy has installed it on two devices logged into two different iCloud accounts and confirmed a record created on device A appears on device B within 30 seconds. "It compiles," "the sheet opens," "the invite sends," and "the build uploads" are not proof. Two-account observation is proof. Don't claim a sharing feature is done without it.

**Rule 2 — Validate the foundation before stacking features.**
Before adding any new family-facing feature (invites, roles, permissions, leaderboards, shared lists, anything that says "everyone sees"), stop and verify the data layer actually shares data. If the data layer is broken, building UI on top of it is theater and makes the eventual fix harder. The first question on any family-feature request is "does the store under this support multi-user visibility?" not "what does the screen look like?"

**Rule 4 — Don't trust prior sessions. Run the 5-minute trust check.**
Future Claudes: assume the data layer is broken for multi-user sharing until you've personally verified it. The 5-minute trust check:

1. **Read the data-layer file.** Find where `ModelContainer` / `ModelConfiguration` / `NSPersistentCloudKitContainer` is set up. Look at the scope:
   - `cloudKitDatabase: .private(...)` → single-user silo. Sharing is broken. Stop.
   - `NSPersistentCloudKitContainer` + `share(_:to:)` calls somewhere → likely Option A. Continue to step 2.
   - `CKContainer.default().publicCloudDatabase` + `householdID` filter on every fetch → likely Option B. Continue to step 2.
2. **Grep for the field that proves the chosen path.**
   - Option A: `share(_:to:)` should appear at least once in the codebase.
   - Option B: every `@Query` / fetch must include a `householdID == X` predicate. Even one unfiltered query leaks data across households — treat that as broken.
3. **Check `replicants_log.md` for a recent "two-account verified" entry.** If the most recent data-layer entry doesn't include explicit two-account verification, the layer is unverified — treat it as broken.
4. **If still unsure, ask Geezy to run the test.** Tell him: "Install on two devices on two iCloud accounts. Create a task on device A. Does it appear on device B within 30 seconds?" Yes = trust. No = broken, stop and report.

The cost of a 5-minute check is far smaller than the cost of stacking 4+ hours of UI on a broken foundation and shipping theater. The prior session (cr2, 2026-05-13) did exactly that. Don't repeat it.

## Dependencies

- **CasaGlassKit** — reusable Swift package for the Casa Glass design system.
  - Repo: https://github.com/geezy14/CasaGlassKit (private)
  - Add via Xcode → File → Add Packages → paste the URL above. Auth uses the GitHub account set up in Xcode → Settings → Accounts (PAT).
  - Import with `import CasaGlassKit`.
  - Provides: `.casaCard()` modifier (the casaglass3 neutral-card chrome), `AppBackgroundView` (gradient or user-picked photo background), `BackgroundImageStore` (photo persistence), 8 built-in gradient presets, `.cardBackground()` view extension.
  - **casaglass3 is the frozen standard.** Do not modify the kit's implementations in place. If different behavior is needed, cut a new version (casaglass4) in a separate commit with its own evolution-doc entry.
  - The kit assumes the host app sets these `@AppStorage` keys: `glassEnabled` (Bool), `customBgEnabled` (Bool), `customBgRevision` (Int), optionally `appBackground` (String).

### Things NOT in CasaGlassKit (build per-app if needed)
- `AppTheme` enum / accent color picker
- `Haptics` helper
- App-specific Casa surfaces (entry sheet, Money Year, etc. — those live in casaBills2)

## Build Target

- Scheme: `casalist`
- Project: `casalist.xcodeproj`
- Bundle ID: `com.gbrown10.casalist`
- Physical devices (both paired wirelessly):
  - **iPhone Air** (primary dev / inviter test device): UDID `9A471194-E5FA-5B11-82F9-178E5612C19C`, device name `geezy`
  - **iPhone 15** (second account / share recipient test device): UDID `62C1F8BD-F78E-523B-929A-CC780C68595B`, device name `iPhone`
- Geezy gets builds on the iPhone 15 via direct Xcode/devicectl push (NOT TestFlight) for the two-account sharing test loop. TestFlight uploads only when explicitly requested.
- Working directory: `/Users/geezy/Documents/casaList`

## Deploy Workflows

### "push it" — wireless deploy to Geezy's iPhone

When Geezy says "push it" (or similar), push to the iPhone Air (primary dev device) from `/Users/geezy/Documents/casaList`:

```bash
xcodebuild -project casalist.xcodeproj -scheme casalist -configuration Debug \
  -destination 'id=9A471194-E5FA-5B11-82F9-178E5612C19C' \
  -derivedDataPath build -allowProvisioningUpdates

xcrun devicectl device install app --device 9A471194-E5FA-5B11-82F9-178E5612C19C \
  build/Build/Products/Debug-iphoneos/casalist.app

xcrun devicectl device process launch --device 9A471194-E5FA-5B11-82F9-178E5612C19C \
  com.gbrown10.casalist
```

### "push both" / "push to 15 too" — also deploy to iPhone 15

When Geezy needs both devices on the same build (always for the two-account sharing test), also push to the iPhone 15 (separate `-derivedDataPath build-iphone15` so the build artifacts don't collide with the iPhone Air ones):

```bash
xcodebuild -project casalist.xcodeproj -scheme casalist -configuration Debug \
  -destination 'id=62C1F8BD-F78E-523B-929A-CC780C68595B' \
  -derivedDataPath build-iphone15 -allowProvisioningUpdates

xcrun devicectl device install app --device 62C1F8BD-F78E-523B-929A-CC780C68595B \
  build-iphone15/Build/Products/Debug-iphoneos/casalist.app

xcrun devicectl device process launch --device 62C1F8BD-F78E-523B-929A-CC780C68595B \
  com.gbrown10.casalist
```

If install/launch fails with "unavailable" or a network timeout, the phone went to sleep or wifi dropped. Retry after a few seconds.

### "testflight it" — archive + upload to TestFlight

When Geezy says "testflight it" (or similar):

1. Commit current changes to `main` (do NOT push to remote unless Geezy explicitly says to push).
2. Bump `CURRENT_PROJECT_VERSION` (build number) in `casalist.xcodeproj/project.pbxproj` — must be higher than the last TestFlight build, never reuse.
3. Write release notes to `testflight-notes-<build>.txt` at the project root (covers What's New + What's Fixed + What to Test).
4. Archive Release config:
   ```bash
   xcodebuild -project casalist.xcodeproj -scheme casalist -configuration Release \
     -destination 'generic/platform=iOS' \
     -archivePath build/casalist.xcarchive archive -allowProvisioningUpdates
   ```
5. Export the IPA using the App Store Connect API key (this is the critical trick — without these flags, export fails because no iOS Distribution cert is in the local keychain):
   ```bash
   xcodebuild -exportArchive \
     -archivePath build/casalist.xcarchive \
     -exportPath build/export \
     -exportOptionsPlist ExportOptions.plist \
     -allowProvisioningUpdates \
     -authenticationKeyID RSZWNZ7YL3 \
     -authenticationKeyIssuerID 69a6de73-6a85-47e3-e053-5b8c7c11a4d1 \
     -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_RSZWNZ7YL3.p8
   ```
   The `-authenticationKey*` flags pull the iOS Distribution cert via the API on the fly. Don't skip them.
6. Upload to App Store Connect:
   ```bash
   xcrun altool --upload-app -f build/export/casalist.ipa -t ios \
     --apiKey RSZWNZ7YL3 --apiIssuer 69a6de73-6a85-47e3-e053-5b8c7c11a4d1
   ```
7. (Optional) Set the "What to Test" notes on the build via the API. Write a small Python script using PyJWT to call the App Store Connect API and PATCH the build's `betaBuildLocalizations` with the contents of `testflight-notes-<build>.txt`. See casaBills2 history for a working `set_testflight_notes.py` template — the auth flow is identical, just swap the bundle ID filter to `com.gbrown10.casalist`.

### ExportOptions.plist

Should live at the project root. Required contents:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>destination</key>
    <string>export</string>
    <key>uploadSymbols</key>
    <true/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>57Z9HL3SZJ</string>
</dict>
</plist>
```

Team ID `57Z9HL3SZJ` is the team that owns the store provisioning profile for `com.gbrown10.*` apps. If a different team owns this app, replace it.

### CloudKit schema deploys (when you change a @Model)

When you add a new `@Model`, add a stored property to one, or rename/remove
fields, the Production CloudKit schema must be updated or sync will silently
fail across devices.

**Full playbook**: `docs/cloudkit-schema-workflow.md`

**Quick check** — does Production match Dev?
```bash
scripts/cloudkit-schema-diff.sh
```

**Quick deploy** (only when the script reports differences):
1. Remove the `com.apple.developer.icloud-container-environment` key from
   `casalist/casalist.entitlements` so Debug builds hit Dev CloudKit.
2. Build/install and exercise each new model on the phone so SwiftData
   writes a record (Dev auto-registers schema from writes).
3. Verify with `scripts/cloudkit-schema-diff.sh` — Dev should now have the
   new types.
4. Open https://icloud.developer.apple.com/dashboard → switch env to
   **Development** → sidebar "Deploy Schema Changes…" → **Deploy**.
5. Restore the entitlement (`Production`) and rebuild.

`cktool import-schema --environment PRODUCTION` does NOT work — only the
Console's "Deploy Schema Changes…" promotes Dev → Prod. The management
token is saved in the keychain via `xcrun cktool save-token --type management`.

### App Store Connect API credentials (shared across all of Geezy's apps)

- **Issuer ID**: `69a6de73-6a85-47e3-e053-5b8c7c11a4d1`
- **Key ID**: `RSZWNZ7YL3`
- **.p8 path**: `~/.appstoreconnect/private_keys/AuthKey_RSZWNZ7YL3.p8`
- **Apple ID**: gbrown10@me.com
- Treat these as credential-adjacent — don't echo into chat unnecessarily.

### Pre-flight checklist for the first TestFlight build of casaList

The first time you "testflight it" for casaList, verify these exist (the next Claude likely won't have built TestFlight for this app yet):

- [ ] App record created in App Store Connect for bundle ID `com.gbrown10.casalist`
- [ ] App Store provisioning profile for `com.gbrown10.casalist` exists under team `57Z9HL3SZJ` (Xcode → automatic signing will create it on first archive if signed in)
- [ ] `ExportOptions.plist` present at project root (see template above)
- [ ] `CURRENT_PROJECT_VERSION` bumped from the previous TestFlight upload

If the export step fails with "No profiles found" or "No signing certificate iOS Distribution found", the `-authenticationKey*` flags are missing or pointing at the wrong key file.