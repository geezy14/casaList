#!/usr/bin/env bash
# Verifies the Production CloudKit schema has the three new fields added
# during the May 2026 session before shipping a TestFlight build. Designed
# to be run AFTER deploying schema changes through the CloudKit Console,
# so you get a green/red answer rather than a paragraph of diff to read.
#
# Required deploys for tomorrow's TestFlight build:
#   - CD_TaskItem.CD_completedAt  (Date, optional)
#   - CD_FamilyGoal.CD_note       (String, optional, default "")
#   - CD_Household.CD_routinesJSON (String, optional, default "")
#
# Token: xcrun cktool save-token --type management

set -euo pipefail

TEAM_ID="57Z9HL3SZJ"
CONTAINER="iCloud.com.gbrown10.casalist"
ENV="${1:-PRODUCTION}"  # pass DEVELOPMENT as arg to check Dev instead

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

echo "› Fetching $ENV schema for $CONTAINER..."
xcrun cktool export-schema \
    --team-id "$TEAM_ID" \
    --container-id "$CONTAINER" \
    --environment "$ENV" \
    --output-file "$tmp"

echo

# Each check: (record type, field name, friendly description)
checks=(
    "CD_TaskItem|CD_completedAt|completion timestamp (drives WHAT'S NEW + My Wins log)"
    "CD_TaskItem|CD_repeatEndMinutes|hourly reminder stop-time-of-day"
    "CD_FamilyGoal|CD_note|reward-request note (kid 'make your case' text)"
    "CD_Household|CD_routinesJSON|routine templates (DEBUG-only feature for now)"
)

missing=0
for entry in "${checks[@]}"; do
    IFS="|" read -r record field desc <<< "$entry"
    # Look for a field declaration within the record type. cktool emits
    # schemas with `RECORD TYPE <name>` headers and `<field> <type>` lines
    # underneath.
    if awk -v rec="RECORD TYPE $record" -v fld="$field" '
        $0 ~ rec {in_rec=1; next}
        in_rec && /^RECORD TYPE/ {in_rec=0}
        in_rec && $1==fld {found=1; exit}
        END {exit !found}
    ' "$tmp"; then
        printf "  ✅ %-30s %-26s %s\n" "$record" "$field" "$desc"
    else
        printf "  ❌ %-30s %-26s MISSING — %s\n" "$record" "$field" "$desc"
        missing=$((missing + 1))
    fi
done

echo
if [ "$missing" -eq 0 ]; then
    echo "✅ All three new fields are registered in $ENV. Safe to ship."
    exit 0
else
    echo "⚠️  $missing field(s) missing in $ENV."
    if [ "$ENV" = "PRODUCTION" ]; then
        echo "   → Deploy via: https://icloud.developer.apple.com/dashboard/database/$CONTAINER"
        echo "     Switch env to Development → 'Deploy Schema Changes…' → Deploy."
        echo "   → Then re-run: scripts/verify-testflight-schema.sh"
    fi
    exit 1
fi
