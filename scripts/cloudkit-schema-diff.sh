#!/usr/bin/env bash
# Compares the Development and Production CloudKit schemas for Casalist.
# Prints the diff (if any) so you can tell whether a deploy is needed
# before shipping a build.
#
# Flags:
#   --ci    Exit 1 if Production != Development (use in build phases / CI
#           so Release archives ABORT when a schema deploy is missing).
#           Without --ci the script always exits 0 (informational mode).
#
# Requires a CloudKit Management Token saved via:
#     xcrun cktool save-token --type management

set -euo pipefail

CI_MODE=0
for arg in "$@"; do
    case "$arg" in
        --ci) CI_MODE=1 ;;
    esac
done

TEAM_ID="57Z9HL3SZJ"
CONTAINER="iCloud.com.gbrown10.casalist"

tmp_dev=$(mktemp)
tmp_prod=$(mktemp)
trap 'rm -f "$tmp_dev" "$tmp_prod"' EXIT

echo "› Fetching Development schema..."
xcrun cktool export-schema \
    --team-id "$TEAM_ID" \
    --container-id "$CONTAINER" \
    --environment DEVELOPMENT \
    --output-file "$tmp_dev"

echo "› Fetching Production schema..."
xcrun cktool export-schema \
    --team-id "$TEAM_ID" \
    --container-id "$CONTAINER" \
    --environment PRODUCTION \
    --output-file "$tmp_prod"

echo
if diff -u "$tmp_prod" "$tmp_dev" > /tmp/casalist-schema.diff; then
    echo "✅ Production and Development schemas are identical. No deploy needed."
    exit 0
fi

echo "============================================================"
echo "⛔  CLOUDKIT SCHEMA MISMATCH — Production is BEHIND Development."
echo "============================================================"
echo
echo "Deploy via the CloudKit Console BEFORE archiving:"
echo "    https://icloud.developer.apple.com/dashboard/database/$CONTAINER"
echo "    → switch env to Development"
echo "    → sidebar 'Deploy Schema Changes…'"
echo "    → 'Deploy'"
echo
echo "If you ship now, devices on this build will write records with"
echo "fields Production doesn't know, CloudKit will silently reject"
echo "them, NSPersistentCloudKitContainer will mark those mutations"
echo "as terminal failures locally, and even AFTER you deploy the"
echo "schema later, testers will need to delete-and-reinstall the app"
echo "to recover. This has bitten three times. Deploy first."
echo
echo "Diff (lines starting with '+' need to land in Production):"
echo "------------------------------------------------------------"
cat /tmp/casalist-schema.diff
echo "------------------------------------------------------------"

if [ "$CI_MODE" -eq 1 ]; then
    echo
    echo "❌ Build aborted by cloudkit-schema-diff.sh --ci"
    exit 1
fi
