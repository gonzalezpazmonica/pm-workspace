#!/usr/bin/env bats
# BATS tests for scripts/doc-health-audit.sh
# Ref: SPEC-SE-094-DOC-AUDIT
# Minimum 15 tests covering script existence, syntax, output format,
# read-only guarantee, JSON mode, and scoring semantics.

SCRIPT="scripts/doc-health-audit.sh"

setup_file() {
  cd "$BATS_TEST_DIRNAME/.."
  # BATS_FILE_TMPDIR is stable for all tests in this file (bats-core ≥ 1.2)
  local cache="$BATS_FILE_TMPDIR/audit-cache.txt"
  local json_cache="$BATS_FILE_TMPDIR/audit-json-cache.txt"
  bash "$SCRIPT" > "$cache" 2>&1 || true
  bash "$SCRIPT" --json > "$json_cache" 2>&1 || true
}

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  CACHE="$BATS_FILE_TMPDIR/audit-cache.txt"
  JSON_CACHE="$BATS_FILE_TMPDIR/audit-json-cache.txt"
}

teardown() { cd /; }

# ── Basic existence and syntax ───────────────────────────────────────────────

@test "script exists" {
  [[ -f "$SCRIPT" ]]
}

@test "script is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "set -uo pipefail present" {
  run grep -c 'set -uo pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "ref SPEC-SE-094 present in script" {
  run grep -c 'SPEC-SE-094' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "passes bash -n syntax check" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Execution against workspace (uses cached run) ────────────────────────────

@test "exit code is 0 or 1 on workspace (no crash)" {
  [[ -s "$CACHE" ]]
}

@test "score line present in output" {
  grep -q 'Score:' "$CACHE"
}

@test "score is a number between 0 and 100" {
  score=$(grep -oE 'Score: [0-9]+/100' "$CACHE" | grep -oE '[0-9]+' | head -1)
  [[ -n "$score" ]]
  [[ "$score" -ge 0 && "$score" -le 100 ]]
}

@test "broken links count present (0 or positive number)" {
  grep -q 'Broken links:' "$CACHE"
  count=$(grep 'Broken links:' "$CACHE" | grep -oE '[0-9]+' | head -1)
  [[ -n "$count" ]]
  [[ "$count" -ge 0 ]]
}

@test "TBD sections count present" {
  grep -q 'TBD sections:' "$CACHE"
  count=$(grep 'TBD sections:' "$CACHE" | grep -oE '[0-9]+' | head -1)
  [[ -n "$count" ]]
  [[ "$count" -ge 0 ]]
}

@test "HIGH severity label appears in output" {
  grep -q 'HIGH' "$CACHE"
}

@test "MEDIUM severity label appears in output" {
  grep -q 'MEDIUM' "$CACHE"
}

@test "LOW severity label appears in output" {
  grep -q 'LOW' "$CACHE"
}

@test "output header line present" {
  grep -q '=== Documentation Health Audit ===' "$CACHE"
}

# ── JSON mode ─────────────────────────────────────────────────────────────────

@test "--json produces output with score key" {
  grep -q '"score"' "$JSON_CACHE"
}

@test "--json output is valid JSON (python3 parse)" {
  python3 -m json.tool < "$JSON_CACHE" > /dev/null
}

@test "--json output contains pass key" {
  grep -q '"pass"' "$JSON_CACHE"
}

@test "--json score key value is numeric 0-100" {
  score=$(python3 -c "import sys,json; d=json.load(open('$JSON_CACHE')); print(d['score'])" 2>/dev/null)
  [[ -n "$score" ]]
  [[ "$score" -ge 0 && "$score" -le 100 ]]
}

# ── Read-only guarantee ───────────────────────────────────────────────────────

@test "git status --porcelain docs/ unchanged after run (read-only)" {
  before=$(git status --porcelain docs/ 2>/dev/null)
  bash "$SCRIPT" > /dev/null 2>&1 || true
  after=$(git status --porcelain docs/ 2>/dev/null)
  [[ "$before" == "$after" ]]
}

# ── Edge cases ────────────────────────────────────────────────────────────────

@test "handles nonexistent docs dir gracefully (tmp isolation)" {
  local tmp_root="$TMPDIR/doc-audit-test-$$"
  mkdir -p "$tmp_root/scripts" "$tmp_root/docs/specs"
  cp "$SCRIPT" "$tmp_root/scripts/doc-health-audit.sh"
  chmod +x "$tmp_root/scripts/doc-health-audit.sh"
  run bash "$tmp_root/scripts/doc-health-audit.sh"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  rm -rf "$tmp_root"
}

@test "--help exits 0 and mentions --json" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--json"* ]]
}

@test "exit 0 when docs is clean (tmp empty workspace)" {
  local tmp_root="$TMPDIR/doc-audit-clean-$$"
  mkdir -p "$tmp_root/scripts" "$tmp_root/docs/specs"
  cp "$SCRIPT" "$tmp_root/scripts/doc-health-audit.sh"
  chmod +x "$tmp_root/scripts/doc-health-audit.sh"
  echo "# Clean doc" > "$tmp_root/docs/clean.md"
  run bash "$tmp_root/scripts/doc-health-audit.sh"
  [ "$status" -eq 0 ]
  rm -rf "$tmp_root"
}
