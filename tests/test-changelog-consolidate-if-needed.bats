#!/usr/bin/env bats
# BATS tests for scripts/changelog-consolidate-if-needed.sh (SE-053 Slice 1).
# Ref: SE-053
SCRIPT="scripts/changelog-consolidate-if-needed.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}
teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "references SE-053" { run grep -c 'SE-053' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"threshold"* ]]
}

@test "rejects unknown arg" { run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]; }
@test "rejects non-integer --threshold" { run bash "$SCRIPT" --threshold abc; [ "$status" -eq 2 ]; }
@test "rejects --threshold 0" { run bash "$SCRIPT" --threshold 0; [ "$status" -eq 2 ]; }

@test "dry-run against real repo" {
  run bash "$SCRIPT" --dry-run
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Fragments:"* ]]
  [[ "$output" == *"Action:"* ]]
}

@test "dry-run reports Threshold" {
  run bash "$SCRIPT" --dry-run
  [[ "$output" == *"Threshold:"* ]]
}

@test "--json dry-run produces valid JSON" {
  run bash -c 'bash scripts/changelog-consolidate-if-needed.sh --dry-run --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"action\",\"fragments\",\"threshold\",\"dry_run\"]:
    assert k in d
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "high threshold → below_threshold action" {
  run bash "$SCRIPT" --threshold 10000 --dry-run --json
  [[ "$output" == *'"action":"below_threshold"'* ]]
}

@test "threshold 1 with ≥1 fragment → would_consolidate or consolidated" {
  run bash "$SCRIPT" --threshold 1 --dry-run --json
  [[ "$output" == *'"action":"would_consolidate"'* ]]
}

# ── Edge cases ─────────────────────────────────────────

@test "edge: empty CHANGELOG.d handled" {
  local root="$BATS_TEST_TMPDIR/empty-cld"
  mkdir -p "$root/CHANGELOG.d" "$root/scripts"
  # Copy dep script + target
  cp "$SCRIPT" "$root/scripts/"
  cp scripts/changelog-consolidate.sh "$root/scripts/" 2>/dev/null || true
  chmod +x "$root/scripts/changelog-consolidate.sh" 2>/dev/null || true
  cd "$root"
  run bash scripts/changelog-consolidate-if-needed.sh --dry-run
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
  [[ "$output" == *"Fragments:    0"* || "$output" == *"below"* ]]
}

@test "edge: nonexistent CHANGELOG.d exits 2" {
  local root="$BATS_TEST_TMPDIR/no-cld"
  mkdir -p "$root/scripts"
  cp "$SCRIPT" "$root/scripts/"
  cp scripts/changelog-consolidate.sh "$root/scripts/" 2>/dev/null || true
  chmod +x "$root/scripts/changelog-consolidate.sh" 2>/dev/null || true
  cd "$root"
  run bash scripts/changelog-consolidate-if-needed.sh --dry-run
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 2 ]
}

@test "edge: README.md not counted as fragment" {
  local root="$BATS_TEST_TMPDIR/only-readme"
  mkdir -p "$root/CHANGELOG.d" "$root/scripts"
  echo "# README" > "$root/CHANGELOG.d/README.md"
  cp "$SCRIPT" "$root/scripts/"
  cp scripts/changelog-consolidate.sh "$root/scripts/" 2>/dev/null || true
  chmod +x "$root/scripts/changelog-consolidate.sh" 2>/dev/null || true
  cd "$root"
  run bash scripts/changelog-consolidate-if-needed.sh --dry-run --threshold 1 --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *'"fragments":0'* ]]
}

@test "edge: large fragment count (boundary) triggers consolidate path in dry-run" {
  local root="$BATS_TEST_TMPDIR/many-frags"
  mkdir -p "$root/CHANGELOG.d" "$root/scripts"
  for i in $(seq 1 50); do echo "frag $i" > "$root/CHANGELOG.d/frag-$i.md"; done
  cp "$SCRIPT" "$root/scripts/"
  cp scripts/changelog-consolidate.sh "$root/scripts/" 2>/dev/null || true
  chmod +x "$root/scripts/changelog-consolidate.sh" 2>/dev/null || true
  cd "$root"
  run bash scripts/changelog-consolidate-if-needed.sh --dry-run --threshold 10 --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *'"fragments":50'* ]]
  [[ "$output" == *'"action":"would_consolidate"'* ]]
}

# ── Negative ───────────────────────────────────────────

@test "negative: missing changelog-consolidate.sh exits 2" {
  local root="$BATS_TEST_TMPDIR/no-consolidate"
  mkdir -p "$root/CHANGELOG.d" "$root/scripts"
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/changelog-consolidate-if-needed.sh --dry-run
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 2 ]
}

@test "negative: bad threshold value rejected" {
  run bash "$SCRIPT" --threshold -5
  [ "$status" -eq 2 ]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: FRAGMENTS_DIR var" { run grep -c 'FRAGMENTS_DIR' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: CONSOLIDATE var" { run grep -c 'CONSOLIDATE' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: ACTION var" { run grep -c 'ACTION=' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

# ── Isolation ────────────────────────────────────────────

@test "isolation: dry-run does not modify CHANGELOG.d" {
  local h_before
  h_before=$(find CHANGELOG.d -name "*.md" 2>/dev/null | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" --dry-run >/dev/null 2>&1 || true
  local h_after
  h_after=$(find CHANGELOG.d -name "*.md" 2>/dev/null | sort | md5sum | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: dry-run does not modify CHANGELOG.md" {
  local h_before
  h_before=$(md5sum CHANGELOG.md | awk '{print $1}')
  bash "$SCRIPT" --dry-run >/dev/null 2>&1 || true
  local h_after
  h_after=$(md5sum CHANGELOG.md | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT" --dry-run; [ "$status" -eq 0 ]
  run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]
}
