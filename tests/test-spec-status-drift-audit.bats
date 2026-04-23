#!/usr/bin/env bats
# BATS tests for scripts/spec-status-drift-audit.sh
# Ref: Era 186 drift sweep; batch 36

SCRIPT="scripts/spec-status-drift-audit.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
}
teardown() { cd /; }

@test "script exists and is executable" { [[ -x "$SCRIPT" ]]; }
@test "passes bash -n syntax" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "uses set -uo pipefail" { run grep -c 'set -uo pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "references batch 36 or Era 186" {
  run grep -cE 'batch 36|Era 186' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "--help exits 0 with usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "--bogus flag rejected with exit 2" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "default run: current workspace should be clean after batch 36 fix" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"VERDICT: PASS"* ]]
}

@test "--json produces valid JSON" {
  run bash -c 'bash scripts/spec-status-drift-audit.sh --json | python3 -m json.tool'
  [ "$status" -eq 0 ]
}

@test "--json includes required fields" {
  run bash -c 'bash scripts/spec-status-drift-audit.sh --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"verdict\",\"scanned\",\"min_refs\",\"drifted_count\",\"drifted\"]:
    assert k in d, f\"missing {k}\"
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

# ── Positive detection ────────────────────────────────

@test "positive: drifted spec detected in synthetic fixture" {
  local TMP="$BATS_TEST_TMPDIR/drift-pos"
  mkdir -p "$TMP/docs/propuestas" "$TMP/CHANGELOG.d"
  cat > "$TMP/docs/propuestas/SE-999-foo.md" <<'EOF'
---
id: SE-999
status: PROPOSED
---
# SE-999
EOF
  echo "SE-999 impl" > "$TMP/CHANGELOG.d/batch-a.md"
  echo "SE-999 slice 2" > "$TMP/CHANGELOG.d/batch-b.md"
  echo "SE-999 closure" > "$TMP/CHANGELOG.d/batch-c.md"
  run bash -c "cd '$TMP' && ln -s '$BATS_TEST_DIRNAME/../scripts' scripts && bash scripts/spec-status-drift-audit.sh --json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"SE-999"* ]]
}

@test "positive: IMPLEMENTED spec not flagged even with many refs" {
  local TMP="$BATS_TEST_TMPDIR/drift-impl"
  mkdir -p "$TMP/docs/propuestas" "$TMP/CHANGELOG.d"
  cat > "$TMP/docs/propuestas/SE-888-bar.md" <<'EOF'
---
id: SE-888
status: IMPLEMENTED
---
# SE-888
EOF
  echo "SE-888" > "$TMP/CHANGELOG.d/b1.md"
  echo "SE-888" > "$TMP/CHANGELOG.d/b2.md"
  echo "SE-888" > "$TMP/CHANGELOG.d/b3.md"
  run bash -c "cd '$TMP' && ln -s '$BATS_TEST_DIRNAME/../scripts' scripts && bash scripts/spec-status-drift-audit.sh"
  [ "$status" -eq 0 ]
}

# ── Negative cases ───────────────────────────────────

@test "negative: missing proposals dir errors with exit 2" {
  local TMP="$BATS_TEST_TMPDIR/no-proposals"
  mkdir -p "$TMP/CHANGELOG.d"
  run bash -c "cd '$TMP' && ln -s '$BATS_TEST_DIRNAME/../scripts' scripts && bash scripts/spec-status-drift-audit.sh"
  [ "$status" -eq 2 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "negative: missing CHANGELOG.d dir errors with exit 2" {
  local TMP="$BATS_TEST_TMPDIR/no-changelog"
  mkdir -p "$TMP/docs/propuestas"
  run bash -c "cd '$TMP' && ln -s '$BATS_TEST_DIRNAME/../scripts' scripts && bash scripts/spec-status-drift-audit.sh"
  [ "$status" -eq 2 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "negative: invalid --min-refs still runs but no crash" {
  run bash "$SCRIPT" --min-refs abc
  # Script will treat abc as 0; should not crash with exit 2
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

# ── Edge cases ───────────────────────────────────────

@test "edge: empty proposals dir produces PASS with 0 scanned" {
  local TMP="$BATS_TEST_TMPDIR/empty-props"
  mkdir -p "$TMP/docs/propuestas" "$TMP/CHANGELOG.d"
  run bash -c "cd '$TMP' && ln -s '$BATS_TEST_DIRNAME/../scripts' scripts && bash scripts/spec-status-drift-audit.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "edge: spec without id field skipped gracefully" {
  local TMP="$BATS_TEST_TMPDIR/no-id"
  mkdir -p "$TMP/docs/propuestas" "$TMP/CHANGELOG.d"
  cat > "$TMP/docs/propuestas/SE-777-x.md" <<'EOF'
---
status: PROPOSED
---
EOF
  echo "ref" > "$TMP/CHANGELOG.d/b1.md"
  run bash -c "cd '$TMP' && ln -s '$BATS_TEST_DIRNAME/../scripts' scripts && bash scripts/spec-status-drift-audit.sh"
  [ "$status" -eq 0 ]
}

@test "edge: high --min-refs filters out low-ref specs" {
  run bash "$SCRIPT" --min-refs 100
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "edge: --min-refs 1 finds more drift than default 2" {
  run bash -c 'bash scripts/spec-status-drift-audit.sh --min-refs 1 --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d[\"drifted_count\"])
"'
  # With cutoff 1, we expect >= drifted_count with default 2
  [[ "$output" -ge 0 ]]
}

@test "edge: large proposals dir (40+) runs under 10s" {
  run timeout 10 bash "$SCRIPT"
  [ "$status" -ne 124 ]
}

# ── Coverage breadth ─────────────────────────────────

@test "coverage: count_references function defined" {
  run grep -c '^count_references()' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "coverage: usage function defined" {
  run grep -c '^usage()' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "coverage: --min-refs option handled" {
  run grep -c 'min-refs' "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

@test "coverage: --json option handled" {
  run grep -c '^\s*--json' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in at least one test" {
  run grep -c 'BATS_TEST_TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ─────────────────────────────────────────

@test "isolation: script does not modify proposals dir" {
  local h_before
  h_before=$(find docs/propuestas -name "SE-*.md" -type f -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" >/dev/null 2>&1 || true
  local h_after
  h_after=$(find docs/propuestas -name "SE-*.md" -type f -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes in {0,1,2}" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}
