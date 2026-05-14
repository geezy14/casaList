#!/usr/bin/env bash
# Compares the Development and Production CloudKit schemas for Casalist.
# Prints the diff (if any) so you can tell whether a deploy is needed
# before shipping a build.
#
# Requires a CloudKit Management Token saved via:
#     xcrun cktool save-token --type management

set -euo pipefail

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
else
    echo "⚠️  Dev and Prod schemas differ. Deploy via CloudKit Console:"
    echo "    https://icloud.developer.apple.com/dashboard/database/$CONTAINER"
    echo
    echo "Diff (lines starting with '+' will appear in Production after deploy):"
    echo "------------------------------------------------------------------"
    cat /tmp/casalist-schema.diff
fi
