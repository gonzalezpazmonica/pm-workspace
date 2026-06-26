#!/usr/bin/env bats
# tests/bats/test-se-079-scope-gate.bats
# SE-079 — G13 Scope-trace gate
# >= 5 tests

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/scope-trace-gate.sh"

# ── Test 1: Script exists and is executable ────────────────────────────────────
@test "SE-079 AC-01: scope-trace-gate.sh exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

# ── Test 2: Files within declared spec scope → passed=true ────────────────────
@test "SE-079 AC-03: files in scope → passed=true, files_outside_scope empty" {
  run bash "$SCRIPT" --spec SE-079 --files \
    "scripts/scope-trace-gate.sh" \
    "tests/bats/test-se-079-scope-gate.bats" \
    "CHANGELOG.d/se-079-scope-gate.md"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null
  local passed
  passed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['passed'])")
  [ "$passed" = "True" ]
  local outside
  outside=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['files_outside_scope']))")
  [ "$outside" = "0" ]
}

# ── Test 3: Files outside scope → passed=false, files_outside_scope non-empty ─
@test "SE-079 AC-03: files outside scope → passed=false, files_outside_scope non-empty" {
  run bash "$SCRIPT" --spec SE-079 --files "src/totally/unrelated/widget.py"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null
  local passed
  passed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['passed'])")
  [ "$passed" = "False" ]
  local outside
  outside=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['files_outside_scope']))")
  [ "$outside" -gt 0 ]
}

# ── Test 4: Output is always valid JSON ───────────────────────────────────────
@test "SE-079 AC-07: output is valid JSON in all scenarios" {
  # No spec
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null

  # With spec, in-scope files
  run bash "$SCRIPT" --spec SE-079 --files "scripts/scope-trace-gate.sh"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null

  # With spec, out-of-scope files
  run bash "$SCRIPT" --spec SE-079 --files "some/unrelated/path.go"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null

  # Non-existent spec
  run bash "$SCRIPT" --spec SE-NONEXIST --files "any/file.sh"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null
}

# ── Test 5: No spec → exit 0, verdict SKIP ────────────────────────────────────
@test "SE-079 AC-04: no spec → exit 0, graceful SKIP" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  local verdict
  verdict=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['verdict'])")
  [ "$verdict" = "SKIP" ]
  local spec_id
  spec_id=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['spec_id'])")
  [ "$spec_id" = "None" ]
}

# ── Test 6: CHANGELOG.d/* and .scm/* are always whitelisted ──────────────────
@test "SE-079 AC-06: CHANGELOG.d and .scm paths always whitelisted" {
  run bash "$SCRIPT" --spec SE-079 --files \
    "CHANGELOG.d/se-079-fragment.md" \
    ".scm/some-signature-file" \
    ".confidentiality-signature" \
    ".pr-summary.md"
  [ "$status" -eq 0 ]
  local passed
  passed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['passed'])")
  [ "$passed" = "True" ]
  local verdict
  verdict=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['verdict'])")
  [ "$verdict" = "PASS" ]
}

# ── Test 7: gate field is always G13-SCOPE-TRACE ─────────────────────────────
@test "SE-079: gate field is always 'G13-SCOPE-TRACE'" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  local gate
  gate=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['gate'])")
  [ "$gate" = "G13-SCOPE-TRACE" ]
}
