#!/usr/bin/env bash
# SPEC-154 Slice 2 — validate-spec-frontmatter.sh
# Verifica que toda spec activa tiene los 4 campos consistentes o needs-triage.
# Exit 0: todo OK. Exit 1: hay inconsistencias.
# AC-03: priority_score = (value * urgency) / effort_score ±5%.
set -euo pipefail

SPECS_DIR="${SPECS_DIR:-docs/propuestas}"
TOLERANCE=0.05

PASS=0
FAIL=0
TRIAGE=0
SKIP=0
FAIL_FILES=()

check_consistency() {
    local value="$1" urgency="$2" effort_score="$3" priority_score="$4"
    python3 -c "
import sys
v, u, e, ps = $value, $urgency, $effort_score, $priority_score
expected = (v * u) / max(1, e)
tolerance = expected * $TOLERANCE + 0.1
ok = abs(ps - expected) <= tolerance
sys.exit(0 if ok else 1)
"
}

get_field() {
    local file="$1" field="$2"
    python3 - "$file" "$field" << 'PYEOF'
import sys, re
path, field = sys.argv[1], sys.argv[2]
with open(path) as f:
    text = f.read()
if not text.startswith("---"):
    sys.exit(0)
end = text.find("\n---", 3)
if end == -1:
    sys.exit(0)
fm = text[3:end]
for line in fm.splitlines():
    m = re.match(r"^(\w[\w_-]*):\s*(.*)", line)
    if m and m.group(1) == field:
        print(m.group(2).strip())
        sys.exit(0)
PYEOF
}

ACTIVE_STATUSES="APPROVED PROPOSED IN_PROGRESS DRAFT ACCEPTED"

printf "%-60s %-20s %s\n" "FILE" "ACTION" "DETAILS"
printf "%s\n" "$(python3 -c "print('-'*100)")"

for spec in "$SPECS_DIR"/*.md; do
    [ -f "$spec" ] || continue
    name=$(basename "$spec")

    status=$(get_field "$spec" "status")
    status_upper=$(echo "$status" | tr '[:lower:]' '[:upper:]')

    # Skip inactive
    found=false
    for s in $ACTIVE_STATUSES; do
        [ "$status_upper" = "$s" ] && found=true && break
    done
    if [ "$found" = "false" ]; then
        SKIP=$((SKIP + 1))
        continue
    fi

    needs_triage=$(get_field "$spec" "needs-triage")
    if [ "$needs_triage" = "true" ]; then
        printf "%-60s %-20s %s\n" "$name" "OK/needs-triage" ""
        TRIAGE=$((TRIAGE + 1))
        continue
    fi

    value=$(get_field "$spec" "value")
    urgency=$(get_field "$spec" "urgency")
    effort_score=$(get_field "$spec" "effort_score")
    priority_score=$(get_field "$spec" "priority_score")

    # All 4 present → check consistency
    if [ -n "$value" ] && [ -n "$urgency" ] && [ -n "$effort_score" ] && [ -n "$priority_score" ]; then
        if check_consistency "$value" "$urgency" "$effort_score" "$priority_score"; then
            printf "%-60s %-20s %s\n" "$name" "OK" "V=$value/U=$urgency/E=$effort_score/score=$priority_score"
            PASS=$((PASS + 1))
        else
            expected=$(python3 -c "print(round(($value * $urgency) / max(1, $effort_score), 1))")
            printf "%-60s %-20s %s\n" "$name" "FAIL/inconsistent" "found=$priority_score expected≈$expected"
            FAIL=$((FAIL + 1))
            FAIL_FILES+=("$name")
        fi
        continue
    fi

    # Missing metadata without needs-triage → FAIL
    printf "%-60s %-20s %s\n" "$name" "FAIL/missing-metadata" "no V/U/E and no needs-triage"
    FAIL=$((FAIL + 1))
    FAIL_FILES+=("$name")
done

printf "%s\n" "$(python3 -c "print('-'*100)")"
echo "PASS=$PASS  FAIL=$FAIL  NEEDS-TRIAGE=$TRIAGE  SKIPPED=$SKIP"

if [ "${#FAIL_FILES[@]}" -gt 0 ]; then
    echo ""
    echo "FAILED files:"
    for f in "${FAIL_FILES[@]}"; do
        echo "  - $f"
    done
    exit 1
fi

exit 0
