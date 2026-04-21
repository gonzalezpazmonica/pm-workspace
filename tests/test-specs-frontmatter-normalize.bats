#!/usr/bin/env bats
# BATS tests for scripts/specs-frontmatter-normalize.sh (SE-054 Slice 2+3).
# Ref: SE-054, SE-036
SCRIPT="scripts/specs-frontmatter-normalize.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}
teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "references SE-054" { run grep -c 'SE-054' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"scan"* ]]
  [[ "$output" == *"apply"* ]]
}

@test "rejects unknown arg" { run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]; }
@test "rejects non-integer --limit" { run bash "$SCRIPT" --limit abc; [ "$status" -eq 2 ]; }

@test "default mode is scan" {
  run bash "$SCRIPT" --json
  [[ "$output" == *'"mode":"scan"'* ]]
}

@test "--scan against real repo" {
  run bash "$SCRIPT" --scan
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" == *"VERDICT"* ]]
}

@test "--scan reports Drift found" {
  run bash "$SCRIPT" --scan
  [[ "$output" == *"Drift found:"* ]]
}

@test "--json scan output valid" {
  run bash -c 'bash scripts/specs-frontmatter-normalize.sh --scan --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
for k in [\"mode\",\"processed\",\"drift\",\"fixed\",\"limit\",\"total_files\"]:
    assert k in d
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

@test "total_files > 0" {
  run bash -c 'bash scripts/specs-frontmatter-normalize.sh --scan --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d[\"total_files\"] > 0
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

# ── Edge cases ───────────────────────────────────────────

@test "edge: empty docs/propuestas returns processed=0" {
  local root="$BATS_TEST_TMPDIR/empty"
  mkdir -p "$root/docs/propuestas" "$root/scripts"
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/specs-frontmatter-normalize.sh --scan --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *'"processed":0'* ]]
}

@test "edge: nonexistent docs/propuestas exits 2" {
  local root="$BATS_TEST_TMPDIR/no-dir"
  mkdir -p "$root/scripts"
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/specs-frontmatter-normalize.sh --scan
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 2 ]
}

@test "edge: zero drift when frontmatter already canonical" {
  local root="$BATS_TEST_TMPDIR/canonical"
  mkdir -p "$root/docs/propuestas" "$root/scripts"
  cat > "$root/docs/propuestas/SPEC-001-test.md" <<EOF
---
id: SPEC-001
status: PROPOSED
---
# Test
EOF
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/specs-frontmatter-normalize.sh --scan --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *'"drift":0'* ]]
}

@test "edge: detects lowercase status" {
  local root="$BATS_TEST_TMPDIR/lowercase"
  mkdir -p "$root/docs/propuestas" "$root/scripts"
  cat > "$root/docs/propuestas/SPEC-001-test.md" <<EOF
---
id: SPEC-001
status: Proposed
---
EOF
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/specs-frontmatter-normalize.sh --scan --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *'"drift":1'* ]]
}

@test "edge: detects missing status field" {
  local root="$BATS_TEST_TMPDIR/no-status"
  mkdir -p "$root/docs/propuestas" "$root/scripts"
  cat > "$root/docs/propuestas/SPEC-001-test.md" <<EOF
---
id: SPEC-001
---
EOF
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/specs-frontmatter-normalize.sh --scan --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *'"drift":1'* ]]
}

@test "edge: --limit 1 processes single file" {
  run bash "$SCRIPT" --scan --limit 1 --json
  [[ "$output" == *'"processed":1'* ]]
}

@test "edge: --limit 0 processes all (default)" {
  run bash -c 'bash scripts/specs-frontmatter-normalize.sh --scan --json | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d[\"processed\"] == d[\"total_files\"]
print(\"ok\")
"'
  [[ "$output" == *"ok"* ]]
}

# ── Apply mode (synthetic) ──────────────────────────────

@test "apply: normalizes lowercase status" {
  local root="$BATS_TEST_TMPDIR/apply-case"
  mkdir -p "$root/docs/propuestas" "$root/scripts"
  cat > "$root/docs/propuestas/SPEC-001-test.md" <<EOF
---
id: SPEC-001
status: Proposed
---
EOF
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/specs-frontmatter-normalize.sh --apply
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
  grep -q 'status: PROPOSED' "$root/docs/propuestas/SPEC-001-test.md"
}

@test "apply: adds missing status field" {
  local root="$BATS_TEST_TMPDIR/apply-add"
  mkdir -p "$root/docs/propuestas" "$root/scripts"
  cat > "$root/docs/propuestas/SPEC-001-test.md" <<EOF
---
id: SPEC-001
---
# Body
EOF
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/specs-frontmatter-normalize.sh --apply
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
  grep -q 'status:' "$root/docs/propuestas/SPEC-001-test.md"
}

@test "apply: infers status from body '> Status: X'" {
  local root="$BATS_TEST_TMPDIR/apply-infer"
  mkdir -p "$root/docs/propuestas" "$root/scripts"
  cat > "$root/docs/propuestas/SPEC-001-test.md" <<EOF
# No frontmatter

> Status: Draft
EOF
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/specs-frontmatter-normalize.sh --apply
  cd "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
  grep -q 'status: DRAFT' "$root/docs/propuestas/SPEC-001-test.md"
}

@test "apply: default PROPOSED when no body status hint" {
  local root="$BATS_TEST_TMPDIR/apply-default"
  mkdir -p "$root/docs/propuestas" "$root/scripts"
  cat > "$root/docs/propuestas/SPEC-001-noop.md" <<EOF
# No frontmatter, no status hint
EOF
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/specs-frontmatter-normalize.sh --apply
  cd "$BATS_TEST_DIRNAME/.."
  grep -q 'status: PROPOSED' "$root/docs/propuestas/SPEC-001-noop.md"
}

# ── Negative ────────────────────────────────────────────

@test "negative: file with only non-md extensions ignored" {
  local root="$BATS_TEST_TMPDIR/non-md"
  mkdir -p "$root/docs/propuestas" "$root/scripts"
  echo "noise" > "$root/docs/propuestas/not-a-spec.txt"
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/specs-frontmatter-normalize.sh --scan --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *'"total_files":0'* ]]
}

@test "negative: bad --limit rejects" { run bash "$SCRIPT" --limit -5; [ "$status" -eq 2 ]; }

# ── Coverage ────────────────────────────────────────────

@test "coverage: normalize_status function" { run grep -c 'normalize_status' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: infer_status_from_body function" { run grep -c 'infer_status_from_body' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: process_file function" { run grep -c 'process_file' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "coverage: apply_file function" { run grep -c 'apply_file' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

# ── Isolation ────────────────────────────────────────────

@test "isolation: --scan does not modify docs/propuestas" {
  local h_before
  h_before=$(find docs/propuestas -name "*.md" -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" --scan >/dev/null 2>&1 || true
  local h_after
  h_after=$(find docs/propuestas -name "*.md" -exec md5sum {} + 2>/dev/null | sort | md5sum | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: exit codes 0/1/2" {
  run bash "$SCRIPT" --scan
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

# ── Legacy inline-status exception (SE-054 Slice 3) ──────

@test "legacy: SPEC file with inline **Status** and header on line 1 is skipped" {
  local root="$BATS_TEST_TMPDIR/legacy"
  mkdir -p "$root/docs/propuestas" "$root/scripts"
  cat > "$root/docs/propuestas/SPEC-999-legacy.md" <<'SPEC'
# SPEC-999: Legacy Format

**Status**: Approved | **Date**: 2026-04-01

## Problem
Legacy body-status format.
SPEC
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/specs-frontmatter-normalize.sh --scan --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *'"drift":0'* ]]
}

@test "legacy: non-legacy SPEC still migrates normally" {
  local root="$BATS_TEST_TMPDIR/nonlegacy"
  mkdir -p "$root/docs/propuestas" "$root/scripts"
  cat > "$root/docs/propuestas/SPEC-998-normal.md" <<'SPEC'
# SPEC-998: Normal Spec

Some body without inline Status marker.

## Problem
Body.
SPEC
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  run bash scripts/specs-frontmatter-normalize.sh --scan --json
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$output" == *'"drift":1'* ]]
}

@test "legacy: --apply does not write to legacy files" {
  local root="$BATS_TEST_TMPDIR/legacy-apply"
  mkdir -p "$root/docs/propuestas" "$root/scripts"
  cat > "$root/docs/propuestas/SPEC-997-legacy.md" <<'SPEC'
# SPEC-997: Another Legacy

**Status**: Draft | **Date**: 2026-01-01

## Problem
Body.
SPEC
  cp "$SCRIPT" "$root/scripts/"
  cd "$root"
  local h_before=$(md5sum docs/propuestas/SPEC-997-legacy.md | awk '{print $1}')
  run bash scripts/specs-frontmatter-normalize.sh --apply
  local h_after=$(md5sum docs/propuestas/SPEC-997-legacy.md | awk '{print $1}')
  cd "$BATS_TEST_DIRNAME/.."
  [[ "$h_before" == "$h_after" ]]
}
