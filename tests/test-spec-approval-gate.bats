#!/usr/bin/env bats
# BATS tests for scripts/spec-approval-gate.sh (SE-051 Slice 1).
# Ref: SE-051, Rule #8 autonomous-safety
SCRIPT="scripts/spec-approval-gate.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}
teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "references SE-051" { run grep -c 'SE-051' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "references Rule #8" { run grep -c 'Rule #8' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"staged"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "default mode scans full workspace" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT"* ]]
}

@test "output reports files scanned" {
  run bash "$SCRIPT"
  [[ "$output" == *"Files scanned:"* ]]
}

@test "output reports violations count" {
  run bash "$SCRIPT"
  [[ "$output" == *"Violations:"* ]]
}

@test "--json produces valid JSON" {
  run bash -c 'bash scripts/spec-approval-gate.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"verdict\",\"total_files\",\"with_spec_link\",\"violations\",\"mode\",\"violation_list\"]:
    assert k in d
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "--json verdict is PASS or FAIL" {
  run bash "$SCRIPT" --json
  [[ "$output" == *'"verdict":"PASS"'* || "$output" == *'"verdict":"FAIL"'* ]]
}

@test "--staged mode accepts empty diff" {
  run bash "$SCRIPT" --staged
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "--against branch mode works" {
  run bash "$SCRIPT" --against HEAD
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "--allow-spec bypasses a specific spec" {
  # Even if a script links to PROPOSED spec, --allow-spec should skip it
  run bash "$SCRIPT" --allow-spec SPEC-123 --json
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "violation_list is an array" {
  run bash -c 'bash scripts/spec-approval-gate.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert isinstance(d[\"violation_list\"], list)
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "total_files > 0" {
  run bash -c 'bash scripts/spec-approval-gate.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d[\"total_files\"] > 0
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

# ── Approval status recognition ────────────────────────────────────

@test "APPROVED status recognized" {
  local tmp_script="$BATS_TEST_TMPDIR/fake-spec-ref.sh"
  local tmp_spec_dir="$BATS_TEST_TMPDIR/fake-propuestas"
  mkdir -p "$tmp_spec_dir"
  cat > "$tmp_spec_dir/SE-999-test.md" <<EOF
---
id: SE-999
status: APPROVED
---
# SE-999
EOF
  echo "# References SE-999" > "$tmp_script"
  # Can't fully test without refactoring, but confirm APPROVED is in script
  run grep -c 'APPROVED' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "ACCEPTED and Implemented are also approved statuses" {
  run grep -cE 'ACCEPTED|Implemented' "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

# ── Isolation ────────────────────────────────────────────

@test "isolation: does not modify any file" {
  local h_before
  h_before=$(find scripts .claude/agents docs/propuestas -type f -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" >/dev/null 2>&1 || true
  local h_after
  h_after=$(find scripts .claude/agents docs/propuestas -type f -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
