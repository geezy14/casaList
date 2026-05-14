# CloudKit Schema Workflow

This is the playbook for when you (or Claude) add or change a `@Model` class
in Casalist. Skipping it = silent CloudKit sync failures across devices.

## When you need this

Anytime you:

- Add a new `@Model` class (e.g. `FamilyGoal`, `ChoreTemplate`)
- Add a new stored property to an existing `@Model` (e.g. `repeatKind` on `TaskItem`)
- Rename a property (effectively a remove + add, more dangerous)
- Change `@Attribute(.externalStorage)` etc.

You do NOT need this when:

- Adding `@Transient` properties
- Adding computed properties (`var foo: String { ... }`)
- Adding methods or extensions

## The clean workflow

1. **Edit the `@Model`** in Swift. Build locally to confirm it compiles.

2. **Temporarily switch the build to Development CloudKit**: remove the
   `com.apple.developer.icloud-container-environment` key from
   `casalist/casalist.entitlements`. Save.

3. **Build + install** to the phone:
   ```bash
   xcodebuild -project casalist.xcodeproj -scheme casalist -configuration Debug \
     -destination 'id=9A471194-E5FA-5B11-82F9-178E5612C19C' \
     -derivedDataPath build -allowProvisioningUpdates \
     -authenticationKeyID RSZWNZ7YL3 \
     -authenticationKeyIssuerID 69a6de73-6a85-47e3-e053-5b8c7c11a4d1 \
     -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_RSZWNZ7YL3.p8
   xcrun devicectl device install app --device 9A471194-E5FA-5B11-82F9-178E5612C19C \
     build/Build/Products/Debug-iphoneos/casalist.app
   xcrun devicectl device process launch --device 9A471194-E5FA-5B11-82F9-178E5612C19C \
     com.gbrown10.casalist
   ```

4. **On the phone, exercise each new/changed model** at least once so
   SwiftData writes a record of that type:
   - New `@Model X` → create one X record in the app
   - New property on existing model → create or edit a record that sets that property

   SwiftData auto-registers the schema in the **Development** CloudKit env
   when it writes the record.

5. **Verify Dev has the changes** via cktool:
   ```bash
   xcrun cktool export-schema --team-id 57Z9HL3SZJ \
     --container-id iCloud.com.gbrown10.casalist \
     --environment DEVELOPMENT
   ```
   You should see your new record types and fields.

   Or run the helper: `scripts/cloudkit-schema-diff.sh`

6. **Deploy Dev → Production** via the CloudKit Console:
   - Open https://icloud.developer.apple.com/dashboard/database/iCloud.com.gbrown10.casalist
   - Top env selector: switch to **Development**
   - Left sidebar bottom → **Deploy Schema Changes…**
   - Review the diff (record types added, fields added) → **Deploy**

   `cktool import-schema --environment PRODUCTION` does NOT work — Production
   schema can only be modified by promoting from Development via the Console.

7. **Restore Production entitlement** in `casalist.entitlements`:
   ```xml
   <key>com.apple.developer.icloud-container-environment</key>
   <string>Production</string>
   ```

8. **Rebuild + reinstall**. App now talks to Production CloudKit again, and
   the schema includes your changes.

## Helper: check whether dev and prod are in sync

Run `scripts/cloudkit-schema-diff.sh` (it uses cktool with the saved
management token).

## When schema deploys fail

- **"endpoint not applicable in the environment 'production'"** —
  you tried `cktool import-schema --environment PRODUCTION`. Use the
  Console's deploy button instead.

- **"invalid attempt to delete a record type which is active in a
  production container"** — your imported CKML is missing a record type
  that already exists in Production. cktool import is a *full replace*
  on the Dev side; it must be a strict superset of Production's record
  types.

- **Console deploy dialog shows "0 changes"** — your Dev schema matches
  Production already (no deploy needed). If you *know* Dev should have
  changes, double-check via `cktool export-schema --environment DEVELOPMENT`.

## Why bother?

Debug builds force Production CloudKit via the
`icloud-container-environment` entitlement so we don't have to remember
"oh this is the dev env, my data is fake here". The downside is Production
will silently drop writes for record types it doesn't know about. The
workflow above is the cost of having Debug == Production by default.

If we ever ship a real TestFlight build, **the schema must be deployed
before that build's testers can sync**, since TestFlight always uses
Production.
