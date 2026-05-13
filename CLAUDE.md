# Casalist

## Overview
Casalist is a private family household management app for iOS.

The app is being built in SwiftUI and uses:
- SwiftData
- CloudKit
- SF Symbols
- Apple-native UI patterns

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
- Physical device: `geezy` (iPhone Air), UDID `9A471194-E5FA-5B11-82F9-178E5612C19C`, paired wirelessly
- Working directory: `/Users/geezy/Documents/casaList`

## Deploy Workflows

### "push it" — wireless deploy to Geezy's iPhone

When Geezy says "push it" (or similar), run these from `/Users/geezy/Documents/casaList`:

```bash
xcodebuild -project casalist.xcodeproj -scheme casalist -configuration Debug \
  -destination 'id=9A471194-E5FA-5B11-82F9-178E5612C19C' \
  -derivedDataPath build -allowProvisioningUpdates

xcrun devicectl device install app --device 9A471194-E5FA-5B11-82F9-178E5612C19C \
  build/Build/Products/Debug-iphoneos/casalist.app

xcrun devicectl device process launch --device 9A471194-E5FA-5B11-82F9-178E5612C19C \
  com.gbrown10.casalist
```

If the install/launch fails with "unavailable" or a network timeout, the phone went to sleep or wifi dropped. Retry after a few seconds.

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