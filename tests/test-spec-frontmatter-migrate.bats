#!/usr/bin/env bats
# BATS tests for scripts/spec-frontmatter-migrate.sh (SE-036 Slice 1).
#
# Purpose: validate automated migration of body-prose status markers
# (`> Status: **DRAFT**`) to YAML frontmatter, with mechanical mapping
# that substitutes no human judgment.
#
# Ref: SE-036, ROADMAP.md §Tier 1.4
# Safety: script under test has `set -uo pipefail`.

SCRIPT="scripts/spec-frontmatter-migrate.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# ── Structure / safety ──────────────────────────────────────────────────────

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script uses set -uo pipefail" {
  run grep -cE '^set -[euo]+ pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "script passes bash -n syntax check" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── CLI surface ─────────────────────────────────────────────────────────────

@test "script accepts --help and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]]
  [[ "$output" == *"apply"* ]]
}

@test "script rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "default mode is dry-run (no writes)" {
  # Create sandbox spec
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-901-x.md" <<EOF
# SPEC-901

> Status: **DRAFT** · Fecha: 2026-01-01

body
EOF
  local before_hash after_hash
  before_hash=$(md5sum "$sandbox/SPEC-901-x.md" | awk '{print $1}')
  REPO_ROOT="$BATS_TEST_TMPDIR" run bash "$SCRIPT" --limit 5
  after_hash=$(md5sum "$sandbox/SPEC-901-x.md" | awk '{print $1}')
  [[ "$before_hash" == "$after_hash" ]]
}

@test "rejects --limit < 1" {
  run bash "$SCRIPT" --limit 0
  [ "$status" -eq 2 ]
}

@test "rejects --limit > 50" {
  run bash "$SCRIPT" --limit 100
  [ "$status" -eq 2 ]
}

@test "rejects non-numeric --limit" {
  run bash "$SCRIPT" --limit abc
  [ "$status" -eq 2 ]
}

# ── Status mapping (canonical) ─────────────────────────────────────────────

@test "DRAFT maps to Proposed" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-902-draft.md" <<EOF
# SPEC-902: draft case

> Status: **DRAFT** · Fecha: 2026-01-01

body
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 1 >/dev/null 2>&1
  run grep -E '^status: Proposed' "$sandbox/SPEC-902-draft.md"
  [ "$status" -eq 0 ]
}

@test "COMPLETE maps to Implemented" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-903-complete.md" <<EOF
# SPEC-903: done

> Status: **COMPLETE** · Fecha: 2026-01-01

body
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 1 >/dev/null 2>&1
  run grep -E '^status: Implemented' "$sandbox/SPEC-903-complete.md"
  [ "$status" -eq 0 ]
}

@test "PHASE 1 DONE maps to Implemented" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-904-phase.md" <<EOF
# SPEC-904: phased

> Status: **PHASE 1 DONE** · Fecha: 2026-01-01

body
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 1 >/dev/null 2>&1
  run grep -E '^status: Implemented' "$sandbox/SPEC-904-phase.md"
  [ "$status" -eq 0 ]
}

@test "ACTIVE maps to IN_PROGRESS" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-905-active.md" <<EOF
# SPEC-905: active

> Status: **ACTIVE** · Fecha: 2026-01-01

body
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 1 >/dev/null 2>&1
  run grep -E '^status: IN_PROGRESS' "$sandbox/SPEC-905-active.md"
  [ "$status" -eq 0 ]
}

@test "READY maps to ACCEPTED" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-906-ready.md" <<EOF
# SPEC-906: ready

> Status: **READY**

body
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 1 >/dev/null 2>&1
  run grep -E '^status: ACCEPTED' "$sandbox/SPEC-906-ready.md"
  [ "$status" -eq 0 ]
}

@test "REJECTED maps to Rejected" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-907-rejected.md" <<EOF
# SPEC-907: rejected case

> Status: **REJECTED** · Fecha: 2026-01-01

body
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 1 >/dev/null 2>&1
  run grep -E '^status: Rejected' "$sandbox/SPEC-907-rejected.md"
  [ "$status" -eq 0 ]
}

@test "unknown status maps to UNLABELED (requires human review)" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-908-unknown.md" <<EOF
# SPEC-908: weird

> Status: **WEIRDSTATE**

body
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 1 >/dev/null 2>&1
  run grep -E '^status: UNLABELED' "$sandbox/SPEC-908-unknown.md"
  [ "$status" -eq 0 ]
}

# ── Frontmatter structure ──────────────────────────────────────────────────

@test "injected frontmatter has required fields" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-909-fields.md" <<EOF
# SPEC-909: fields

> Status: **DRAFT** · Fecha: 2026-03-21

body
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 1 >/dev/null 2>&1
  run grep -cE '^(id|title|status|migrated_at|migrated_from):' "$sandbox/SPEC-909-fields.md"
  [[ "$output" -ge 5 ]]
}

@test "injected frontmatter preserves body content intact" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-910-preserve.md" <<EOF
# SPEC-910: preserve

> Status: **DRAFT**

UNIQUE_MARKER_XYZ_PRESERVED
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 1 >/dev/null 2>&1
  run grep -c 'UNIQUE_MARKER_XYZ_PRESERVED' "$sandbox/SPEC-910-preserve.md"
  [ "$output" -eq 1 ]
}

@test "injected frontmatter captures origin_date from body" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-911-date.md" <<EOF
# SPEC-911: date

> Status: **DRAFT** · Fecha: 2026-04-07

body
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 1 >/dev/null 2>&1
  run grep -E 'origin_date: "2026-04-07"' "$sandbox/SPEC-911-date.md"
  [ "$status" -eq 0 ]
}

# ── Idempotency ────────────────────────────────────────────────────────────

@test "spec with existing frontmatter is skipped (idempotent)" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-912-existing.md" <<EOF
---
id: SPEC-912
status: Proposed
---

body
EOF
  local before_hash after_hash
  before_hash=$(md5sum "$sandbox/SPEC-912-existing.md" | awk '{print $1}')
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 5 >/dev/null 2>&1
  after_hash=$(md5sum "$sandbox/SPEC-912-existing.md" | awk '{print $1}')
  [[ "$before_hash" == "$after_hash" ]]
}

@test "running migration twice is a no-op on second run" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-913-idem.md" <<EOF
# SPEC-913

> Status: **DRAFT**

body
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 5 >/dev/null 2>&1
  local hash_after_first
  hash_after_first=$(md5sum "$sandbox/SPEC-913-idem.md" | awk '{print $1}')
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 5 >/dev/null 2>&1
  local hash_after_second
  hash_after_second=$(md5sum "$sandbox/SPEC-913-idem.md" | awk '{print $1}')
  [[ "$hash_after_first" == "$hash_after_second" ]]
}

# ── Single-spec mode ────────────────────────────────────────────────────────

@test "--spec PATH migrates exactly that spec" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-914-single.md" <<EOF
# SPEC-914: single

> Status: **DRAFT**

body
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" run bash "$SCRIPT" --apply --spec "$sandbox/SPEC-914-single.md"
  [ "$status" -eq 0 ]
  run grep -E '^status:' "$sandbox/SPEC-914-single.md"
  [ "$status" -eq 0 ]
}

@test "--spec fails if path does not exist" {
  run bash "$SCRIPT" --spec /does/not/exist.md
  [ "$status" -eq 2 ]
}

# ── Negative / edge cases ──────────────────────────────────────────────────

@test "negative: spec without body status is skipped" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-915-nostatus.md" <<EOF
# SPEC-915

just body with no status marker
EOF
  local before_hash after_hash
  before_hash=$(md5sum "$sandbox/SPEC-915-nostatus.md" | awk '{print $1}')
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 5 >/dev/null 2>&1
  after_hash=$(md5sum "$sandbox/SPEC-915-nostatus.md" | awk '{print $1}')
  [[ "$before_hash" == "$after_hash" ]]
}

@test "negative: spec with non-spec-id filename is skipped" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/README.md" <<EOF
# Readme

> Status: **DRAFT**

body
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 5 >/dev/null 2>&1
  # Readme does not match SPEC-*/SE-* glob — should be untouched
  local first
  first=$(head -1 "$sandbox/README.md")
  [[ "$first" != "---" ]]
}

@test "negative: empty spec file does not crash" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  : > "$sandbox/SPEC-916-empty.md"
  run env REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 5
  [ "$status" -eq 0 ]
}

@test "negative: lowercase status value is still recognized" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-917-lower.md" <<EOF
# SPEC-917

> status: draft

body
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply --limit 1 >/dev/null 2>&1
  run grep -E '^status: Proposed' "$sandbox/SPEC-917-lower.md"
  [ "$status" -eq 0 ]
}

@test "edge: limit boundary at 50 is accepted" {
  run bash "$SCRIPT" --limit 50
  # May exit 0 (nothing matches in limited sandbox) or process specs;
  # what matters is NOT rejection.
  [ "$status" -ne 2 ]
}

@test "edge: limit boundary at 1 is accepted" {
  run bash "$SCRIPT" --limit 1
  [ "$status" -ne 2 ]
}

@test "edge: script reports summary line with processed/applied/skipped" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  run env REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --dry-run --limit 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"spec-frontmatter-migrate:"* ]]
}

@test "edge: mapping table in script references all 6 canonical statuses" {
  run grep -cE 'Proposed|IN_PROGRESS|ACCEPTED|Implemented|Rejected|UNLABELED' "$SCRIPT"
  [[ "$output" -ge 6 ]]
}

# ── Real repo sanity (non-destructive) ─────────────────────────────────────

@test "real repo: dry-run mode does NOT modify any tracked spec" {
  local before_hash after_hash
  before_hash=$(find docs/propuestas -name '*.md' -exec md5sum {} \; 2>/dev/null | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" --dry-run --limit 1 >/dev/null 2>&1
  after_hash=$(find docs/propuestas -name '*.md' -exec md5sum {} \; 2>/dev/null | sort | md5sum | awk '{print $1}')
  [[ "$before_hash" == "$after_hash" ]]
}
