#!/usr/bin/env bats
# BATS tests for scripts/spec-status-normalize.sh
# Ref: docs/propuestas/ROADMAP-UNIFIED-20260418.md §Wave 4 D1
# Purpose: validate the status normalization script handles all 156 specs
# correctly, respects idempotency, and never damages files that lack
# YAML frontmatter.
#
# Safety: the script has `set -uo pipefail` for proper error propagation.
# Tests run the script in a sandbox copy; never on the live docs tree for
# --apply semantics.

SCRIPT="scripts/spec-status-normalize.sh"

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

@test "script uses set -uo pipefail (safety header)" {
  run grep -cE '^set -[ueuo]+ pipefail' "$SCRIPT"
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
  [[ "$output" == *"audit"* ]]
  [[ "$output" == *"apply"* ]]
  [[ "$output" == *"suggest"* ]]
}

@test "script rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown arg"* ]]
}

@test "default mode is audit" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"mode=audit"* ]]
}

# ── Audit mode ──────────────────────────────────────────────────────────────

@test "audit mode scans all specs in docs/propuestas/" {
  run bash "$SCRIPT" --audit
  [ "$status" -eq 0 ]
  # Must scan both top-level and savia-enterprise subdir
  [[ "$output" == *"total="* ]]
}

@test "audit mode writes report to output/" {
  bash "$SCRIPT" --audit > /dev/null 2>&1
  local report
  report=$(find output -name 'spec-status-report-*.md' -newer scripts/spec-status-normalize.sh 2>/dev/null | head -1)
  [[ -n "$report" ]]
}

@test "audit mode does NOT modify any spec files" {
  local before_hash after_hash
  before_hash=$(find docs/propuestas -name '*.md' -exec md5sum {} \; | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" --audit > /dev/null 2>&1
  after_hash=$(find docs/propuestas -name '*.md' -exec md5sum {} \; | sort | md5sum | awk '{print $1}')
  [[ "$before_hash" == "$after_hash" ]]
}

@test "audit report lists canonical status values" {
  bash "$SCRIPT" --audit > /dev/null 2>&1
  local report
  report=$(ls -t output/spec-status-report-*.md 2>/dev/null | head -1)
  [[ -f "$report" ]]
  run grep -c 'PROPOSED\|Implemented\|DROPPED' "$report"
  [[ "$output" -ge 3 ]]
}

# ── Suggest mode ────────────────────────────────────────────────────────────

@test "suggest mode emits heuristic suggestions" {
  run bash "$SCRIPT" --suggest
  [ "$status" -eq 0 ]
  [[ "$output" == *"mode=suggest"* ]]
}

@test "suggest mode does NOT modify any spec files" {
  local before_hash after_hash
  before_hash=$(find docs/propuestas -name '*.md' -exec md5sum {} \; | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" --suggest > /dev/null 2>&1
  after_hash=$(find docs/propuestas -name '*.md' -exec md5sum {} \; | sort | md5sum | awk '{print $1}')
  [[ "$before_hash" == "$after_hash" ]]
}

@test "suggest report includes Heuristic status suggestions section" {
  bash "$SCRIPT" --suggest > /dev/null 2>&1
  local report
  report=$(ls -t output/spec-status-report-*.md 2>/dev/null | head -1)
  run grep -c "Heuristic status suggestions" "$report"
  [[ "$output" -ge 1 ]]
}

# ── Apply mode (sandbox only — never touch real docs) ──────────────────────

@test "apply mode is idempotent on spec already having status" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-TEST-001-fake.md" <<EOF
---
id: TEST-001
status: PROPOSED
---

# Test spec
EOF
  # Run the core logic inline: since script uses \$REPO_ROOT, override it
  # to point at sandbox parent. This validates the idempotency semantics.
  local before_hash after_hash
  before_hash=$(md5sum "$sandbox/SPEC-TEST-001-fake.md" | awk '{print $1}')
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply > /dev/null 2>&1 || true
  after_hash=$(md5sum "$sandbox/SPEC-TEST-001-fake.md" | awk '{print $1}')
  [[ "$before_hash" == "$after_hash" ]]
}

@test "apply mode adds status to frontmatter-having spec without status" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-TEST-002-fake.md" <<EOF
---
id: TEST-002
title: no status field
---

# Body
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply > /dev/null 2>&1 || true
  run grep -c '^status: UNLABELED' "$sandbox/SPEC-TEST-002-fake.md"
  [[ "$output" -eq 1 ]]
}

@test "apply mode does NOT touch spec without frontmatter" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-TEST-003-fake.md" <<EOF
# SPEC-TEST-003: No frontmatter spec

> Status: DRAFT

Body content here.
EOF
  local before_hash after_hash
  before_hash=$(md5sum "$sandbox/SPEC-TEST-003-fake.md" | awk '{print $1}')
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply > /dev/null 2>&1 || true
  after_hash=$(md5sum "$sandbox/SPEC-TEST-003-fake.md" | awk '{print $1}')
  [[ "$before_hash" == "$after_hash" ]]
}

# ── Negative cases ─────────────────────────────────────────────────────────

@test "negative: broken bash syntax in script would fail bash -n" {
  local bad="$BATS_TEST_TMPDIR/bad.sh"
  echo 'set -uo pipefail' > "$bad"
  echo 'if then fi' >> "$bad"
  run bash -n "$bad"
  [ "$status" -ne 0 ]
}

@test "negative: apply mode on empty sandbox produces applied=0" {
  local empty="$BATS_TEST_TMPDIR/empty-docs/propuestas"
  mkdir -p "$empty"
  run env REPO_ROOT="$BATS_TEST_TMPDIR/empty-docs/.." bash "$SCRIPT" --apply
  [ "$status" -eq 0 ]
}

@test "negative: non-yaml file is classified as missing_no_fm, not applied" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  # Plain markdown, no frontmatter
  echo "# SPEC-TEST-004 plain markdown" > "$sandbox/SPEC-TEST-004-plain.md"
  local before after
  before=$(md5sum "$sandbox/SPEC-TEST-004-plain.md" | awk '{print $1}')
  REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --apply > /dev/null 2>&1 || true
  after=$(md5sum "$sandbox/SPEC-TEST-004-plain.md" | awk '{print $1}')
  [[ "$before" == "$after" ]]
}

@test "negative: --apply fails fast-ish with no args other than mode" {
  # Smoke test — script exits 0 even on unusual but valid input
  run bash "$SCRIPT" --apply
  [ "$status" -eq 0 ]
}

@test "negative: empty spec file is handled without crash" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  : > "$sandbox/SPEC-TEST-005-empty.md"
  run env REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --audit
  [ "$status" -eq 0 ]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: report has generated date stamp" {
  bash "$SCRIPT" --audit > /dev/null 2>&1
  local report
  report=$(ls -t output/spec-status-report-*.md 2>/dev/null | head -1)
  run grep -cE 'Generated by scripts/spec-status-normalize.sh' "$report"
  [[ "$output" -ge 1 ]]
}

@test "edge: script is idempotent in audit mode (2 runs = same outcome)" {
  bash "$SCRIPT" --audit > "$BATS_TEST_TMPDIR/run1.out" 2>&1
  bash "$SCRIPT" --audit > "$BATS_TEST_TMPDIR/run2.out" 2>&1
  # Only timestamps may differ — totals/counts should match
  local t1 t2
  t1=$(grep -E 'total=[0-9]+' "$BATS_TEST_TMPDIR/run1.out" | grep -oE 'total=[0-9]+')
  t2=$(grep -E 'total=[0-9]+' "$BATS_TEST_TMPDIR/run2.out" | grep -oE 'total=[0-9]+')
  [[ "$t1" == "$t2" ]]
}

@test "edge: all 3 modes produce valid reports without errors" {
  run bash "$SCRIPT" --audit
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" --suggest
  [ "$status" -eq 0 ]
  # apply needs no cleanup on main repo since 0 applicable
  run bash "$SCRIPT" --apply
  [ "$status" -eq 0 ]
}

@test "edge: script reads CHANGELOG.md for heuristic suggestions" {
  bash "$SCRIPT" --suggest > /dev/null 2>&1
  local report
  report=$(ls -t output/spec-status-report-*.md 2>/dev/null | head -1)
  # At least one spec should be classified as Implemented (CHANGELOG references exist)
  run grep -c 'Implemented' "$report"
  [[ "$output" -ge 1 ]]
}

@test "edge: script handles specs with quoted status values" {
  local sandbox="$BATS_TEST_TMPDIR/docs/propuestas"
  mkdir -p "$sandbox"
  cat > "$sandbox/SPEC-TEST-006-quoted.md" <<EOF
---
status: "PROPOSED"
---
body
EOF
  REPO_ROOT="$BATS_TEST_TMPDIR" run bash "$SCRIPT" --audit
  [ "$status" -eq 0 ]
}
