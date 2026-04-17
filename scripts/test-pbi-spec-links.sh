#!/usr/bin/env bash
# test-pbi-spec-links.sh — Tests for PBI ↔ Spec bidirectional linkage
# Validates that the data model changes and validation script work correctly.
set -euo pipefail

PROJECT_DIR="projects/savia-web"
PBI_DIR="$PROJECT_DIR/backlog/pbi"
SPECS_DIR="$PROJECT_DIR/specs"
VALIDATOR="scripts/validate-pbi-spec-links.sh"

passed=0
failed=0
total=0

assert() {
  local description="$1"
  local result="$2"
  total=$((total + 1))
  if [ "$result" -eq 0 ]; then
    echo "  PASS: $description"
    passed=$((passed + 1))
  else
    echo "  FAIL: $description"
    failed=$((failed + 1))
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PBI ↔ Spec Link Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# --- Test Group 1: PBI files have specs: field ---
echo "Group 1: PBI frontmatter has specs: field"

for pbi_id in PBI-005 PBI-006 PBI-007; do
  pbi_file=$(find "$PBI_DIR" -name "${pbi_id}-*.md" -type f 2>/dev/null | head -1)
  if [ -z "$pbi_file" ]; then
    assert "$pbi_id file exists" 1
    continue
  fi
  # Check specs: field exists in YAML frontmatter (between --- delimiters)
  has_specs=$(sed -n '/^---$/,/^---$/p' "$pbi_file" | grep -c '^specs:' || true)
  assert "$pbi_id has specs: field in frontmatter" "$([ "$has_specs" -ge 1 ] && echo 0 || echo 1)"
done

echo ""

# --- Test Group 2: Spec files have parent_pbi: field ---
echo "Group 2: Spec metadatos has parent_pbi: field"

for spec_name in phase2-backlog-ui phase2-pipelines phase2-i18n; do
  spec_file="$SPECS_DIR/${spec_name}.spec.md"
  if [ ! -f "$spec_file" ]; then
    assert "$spec_name spec file exists" 1
    continue
  fi
  # Check parent_pbi: exists in Metadatos section
  has_parent=$(sed -n '/^## Metadatos/,/^## [^M]/p' "$spec_file" \
    | grep -c '^- parent_pbi:' || true)
  assert "$spec_name has parent_pbi: in metadatos" "$([ "$has_parent" -ge 1 ] && echo 0 || echo 1)"
done

echo ""

# --- Test Group 3: Phase1 specs do NOT have parent_pbi ---
echo "Group 3: Phase1 specs are untouched (no parent_pbi)"

for spec_name in phase1-pbi-history phase1-tasks-entities; do
  spec_file="$SPECS_DIR/${spec_name}.spec.md"
  if [ ! -f "$spec_file" ]; then
    # Phase1 spec not found — skip (not an error for this test)
    continue
  fi
  has_parent=$(sed -n '/^## Metadatos/,/^## [^M]/p' "$spec_file" \
    | grep -c '^- parent_pbi:' || true)
  assert "$spec_name does NOT have parent_pbi" "$([ "$has_parent" -eq 0 ] && echo 0 || echo 1)"
done

echo ""

# --- Test Group 4: Validation script ---
echo "Group 4: Validation script"

assert "Validation script exists" "$([ -f "$VALIDATOR" ] && echo 0 || echo 1)"
# Check executable: filesystem -x OR git index has executable bit
is_exec=1
if [ -x "$VALIDATOR" ]; then
  is_exec=0
elif git ls-files -s "$VALIDATOR" 2>/dev/null | grep -q '^100755'; then
  is_exec=0
fi
assert "Validation script is executable (filesystem or git)" "$is_exec"

# Run validator and check exit code
validator_output=$(bash "$VALIDATOR" 2>&1)
validator_exit=$?
assert "Validation script runs without errors (exit 0)" "$validator_exit"

# Check validator scans PBI files
pbi_count=$(echo "$validator_output" | grep -o 'PBIs scanned: [0-9]*' \
  | grep -o '[0-9]*' || echo "0")
assert "Validator scans PBI files (count > 0)" "$([ "$pbi_count" -gt 0 ] && echo 0 || echo 1)"

# Check validator scans spec files
spec_count=$(echo "$validator_output" | grep -o 'Specs scanned: [0-9]*' \
  | grep -o '[0-9]*' || echo "0")
assert "Validator scans spec files (count > 0)" "$([ "$spec_count" -gt 0 ] && echo 0 || echo 1)"

echo ""

# --- Summary ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$failed" -eq 0 ]; then
  echo "  Result: ALL PASSED ($passed/$total)"
else
  echo "  Result: $failed FAILED ($passed/$total passed)"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit "$failed"
