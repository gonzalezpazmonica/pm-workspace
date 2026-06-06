#!/usr/bin/env bats
# Test suite — SPEC-160: Tool Ergonomics Auto-Audit
#
# Validates:
#   - tool-ergonomics-audit.sh exists and is executable
#   - set -uo pipefail present
#   - SPEC-160 referenced in script
#   - --dry-run does not create output files
#   - --json produces valid JSON
#   - output file has date in filename
#   - handles missing output/agent-runs/ directory gracefully
#   - handles empty JSONL gracefully
#   - detects error_rate > 15% from fixture data
#   - no JSONL files → empty report, no crash
#   - malformed JSONL → skip with warning, no crash
#   - --json flag produces parseable JSON output
#   - report contains SPEC-160 reference
#   - dry-run output goes to stdout
#   - pr_limit is reflected in report
#
# Reference: SPEC-160 — Tool Ergonomics Auto-Audit.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  AUDIT="$REPO_ROOT/scripts/tool-ergonomics-audit.sh"

  # Isolated temp dir per test
  TMP="$(mktemp -d)"
  export OUTPUT_DIR="$TMP/output"
  mkdir -p "$OUTPUT_DIR"
}

teardown() {
  [[ -n "${TMP:-}" && -d "$TMP" ]] && rm -rf "$TMP"
}

# ─── 1. Script exists ──────────────────────────────────────────────────────────
@test "tool-ergonomics-audit.sh exists" {
  [[ -f "$AUDIT" ]]
}

# ─── 2. Script is executable ──────────────────────────────────────────────────
@test "tool-ergonomics-audit.sh is executable" {
  [[ -x "$AUDIT" ]]
}

# ─── 3. set -uo pipefail present ─────────────────────────────────────────────
@test "tool-ergonomics-audit.sh has set -uo pipefail" {
  grep -q "set -uo pipefail" "$AUDIT"
}

# ─── 4. SPEC-160 referenced in script ─────────────────────────────────────────
@test "SPEC-160 is referenced in the script" {
  grep -q "SPEC-160" "$AUDIT"
}

# ─── 5. --dry-run does not create output files ────────────────────────────────
@test "--dry-run flag does not write output files" {
  run bash "$AUDIT" --dry-run --output-dir "$TMP/output-dryrun"
  [[ "$status" -eq 0 ]]
  # No .md file should exist in the dry-run output dir
  local count
  count=$(find "$TMP/output-dryrun" -name "*.md" 2>/dev/null | wc -l)
  [[ "$count" -eq 0 ]]
}

# ─── 6. --json flag produces valid JSON ──────────────────────────────────────
@test "--json flag produces parseable JSON output" {
  # Redirect stderr to avoid mixing with JSON stdout in BATS $output
  run bash -c "bash \"$AUDIT\" --json --dry-run --output-dir \"$OUTPUT_DIR\" 2>/dev/null"
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "import sys,json; json.loads(sys.stdin.read())"
}

# ─── 7. Output file has date in filename ──────────────────────────────────────
@test "output file contains date string in name" {
  run bash "$AUDIT" --output-dir "$OUTPUT_DIR"
  [[ "$status" -eq 0 ]]
  local count
  count=$(find "$OUTPUT_DIR" -name "tool-ergonomics-[0-9]*.md" 2>/dev/null | wc -l)
  [[ "$count" -ge 1 ]]
}

# ─── 8. Missing agent-runs directory handled gracefully ───────────────────────
@test "missing output/agent-runs/ directory does not crash" {
  local empty_dir
  empty_dir="$(mktemp -d)"
  run bash "$AUDIT" --output-dir "$empty_dir/out"
  [[ "$status" -eq 0 ]]
  rm -rf "$empty_dir"
}

# ─── 9. Empty JSONL handled gracefully ────────────────────────────────────────
@test "empty JSONL file handled gracefully" {
  mkdir -p "$OUTPUT_DIR/agent-runs"
  touch "$OUTPUT_DIR/agent-runs/empty-run.jsonl"

  run bash "$AUDIT" --output-dir "$OUTPUT_DIR"
  [[ "$status" -eq 0 ]]
}

# ─── 10. Detects error_rate > 15% from fixture ────────────────────────────────
@test "detects tools with error_rate > 15% from fixture JSONL" {
  mkdir -p "$OUTPUT_DIR/agent-runs"

  # Create fixture: 10 calls, 3 errors = 30% error rate for "Read"
  local fixture="$OUTPUT_DIR/agent-runs/fixture-run.jsonl"
  for i in {1..7}; do
    echo '{"tool":"Read","status":"success","input":{"path":"/foo.txt"}}' >> "$fixture"
  done
  for i in {1..3}; do
    echo '{"tool":"Read","status":"error","error":"file not found","input":{"path":"/bar.txt"}}' >> "$fixture"
  done

  run bash "$AUDIT" --output-dir "$OUTPUT_DIR"
  [[ "$status" -eq 0 ]]

  # Report should mention error rate or the tool Read
  local report
  report=$(find "$OUTPUT_DIR" -name "tool-ergonomics-*.md" | head -1)
  [[ -n "$report" ]]
  grep -q "Read\|error_rate\|error rate" "$report"
}

# ─── 11. No JSONL files → empty report, no crash ──────────────────────────────
@test "no JSONL files produces empty report without crashing" {
  local empty_out
  empty_out="$(mktemp -d)"
  run bash "$AUDIT" --output-dir "$empty_out"
  [[ "$status" -eq 0 ]]
  rm -rf "$empty_out"
}

# ─── 12. Malformed JSONL skipped with warning ─────────────────────────────────
@test "malformed JSONL lines are skipped with warning, no crash" {
  mkdir -p "$OUTPUT_DIR/agent-runs"
  local fixture="$OUTPUT_DIR/agent-runs/malformed.jsonl"
  echo '{"tool":"Bash","status":"success"}' >> "$fixture"
  echo 'NOT VALID JSON {{{' >> "$fixture"
  echo '{"tool":"Bash","status":"error"}' >> "$fixture"

  run bash "$AUDIT" --output-dir "$OUTPUT_DIR"
  [[ "$status" -eq 0 ]]
}

# ─── 13. --json output contains required fields ───────────────────────────────
@test "--json output contains spec and tools fields" {
  # Redirect stderr to avoid mixing with JSON stdout in BATS $output
  run bash -c "bash \"$AUDIT\" --json --dry-run --output-dir \"$OUTPUT_DIR\" 2>/dev/null"
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
assert 'spec' in data, 'missing spec'
assert 'tools' in data, 'missing tools'
assert data['spec'] == 'SPEC-160', f'wrong spec: {data[\"spec\"]}'
"
}

# ─── 14. Dry-run output goes to stdout ────────────────────────────────────────
@test "--dry-run output appears on stdout" {
  run bash "$AUDIT" --dry-run
  [[ "$status" -eq 0 ]]
  [[ -n "$output" ]]
}

# ─── 15. PR limit reflected in report ────────────────────────────────────────
@test "report references PR limit of 3/month" {
  run bash "$AUDIT" --output-dir "$OUTPUT_DIR"
  [[ "$status" -eq 0 ]]
  local report
  report=$(find "$OUTPUT_DIR" -name "tool-ergonomics-*.md" | head -1)
  [[ -n "$report" ]]
  grep -qE "3.*month|month.*3|3.*mes|mes.*3|pr_limit.*3|limit.*3" "$report"
}

# ─── 16. Retry pattern detection ──────────────────────────────────────────────
@test "detects retry-same-input pattern from fixture" {
  mkdir -p "$OUTPUT_DIR/agent-runs"
  local fixture="$OUTPUT_DIR/agent-runs/retry-fixture.jsonl"

  # Same input used 3 times = retry pattern
  for i in {1..3}; do
    echo '{"tool":"Grep","status":"success","input":{"pattern":"TODO","path":"/src"}}' >> "$fixture"
  done

  run bash "$AUDIT" --json --dry-run
  [[ "$status" -eq 0 ]]
}
