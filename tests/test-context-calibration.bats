#!/usr/bin/env bats
# test-context-calibration.bats — Tests for SPEC-AUTOCOMPACT-CALIBRATION
# Ref: docs/specs/SPEC-AUTOCOMPACT-CALIBRATION.spec.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/context-calibration-measure.sh"
  SETTINGS="$REPO_ROOT/.claude/settings.json"
  CONTEXT_HEALTH="$REPO_ROOT/.claude/rules/domain/context-health.md"

  TMPDIR_CC=$(mktemp -d)
  LOG_FILE="$TMPDIR_CC/context.log"
  OUTPUT_FILE="$TMPDIR_CC/report.md"
}

teardown() {
  rm -rf "$TMPDIR_CC"
}

# ── Script integrity ─────────────────────────────────────────────────────────

@test "script exists" {
  [ -f "$SCRIPT" ]
}

@test "script has bash shebang" {
  head -1 "$SCRIPT" | grep -q "bash"
}

@test "script has set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "script --help shows usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# ── Settings.json calibration ────────────────────────────────────────────────

@test "settings.json has AUTOCOMPACT_PCT_OVERRIDE set to 75" {
  run grep -c '"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "75"' "$SETTINGS"
  [ "$output" -eq 1 ]
}

@test "settings.json is valid JSON" {
  run python3 -c "import json; json.load(open('$SETTINGS'))"
  [ "$status" -eq 0 ]
}

# ── Context-health.md updated zones ──────────────────────────────────────────

@test "context-health.md has Gradual zone 50-70 percent" {
  grep -q "Gradual .* 50-70%" "$CONTEXT_HEALTH"
}

@test "context-health.md has Alerta zone 70-85 percent" {
  grep -q "Alerta .* 70-85%" "$CONTEXT_HEALTH"
}

@test "context-health.md references SPEC-AUTOCOMPACT-CALIBRATION" {
  grep -q "SPEC-AUTOCOMPACT-CALIBRATION" "$CONTEXT_HEALTH"
}

@test "context-health.md does not exceed 150 lines" {
  local lines
  lines=$(wc -l < "$CONTEXT_HEALTH")
  [ "$lines" -le 150 ]
}

# ── Measurement script — happy path ──────────────────────────────────────────

@test "happy path: script processes valid log" {
  printf '2026-04-10T10:00:00Z|cmd1|45|9000\n' > "$LOG_FILE"
  printf '2026-04-10T10:05:00Z|cmd2|68|13600\n' >> "$LOG_FILE"
  printf '2026-04-10T10:10:00Z|cmd3|82|16400\n' >> "$LOG_FILE"
  run bash "$SCRIPT" --log "$LOG_FILE" --output "$OUTPUT_FILE"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_FILE" ]
}

@test "report contains statistics section" {
  printf '2026-04-10T10:00:00Z|cmd1|45|9000\n' > "$LOG_FILE"
  bash "$SCRIPT" --log "$LOG_FILE" --output "$OUTPUT_FILE"
  grep -q "Statistics" "$OUTPUT_FILE"
}

@test "report contains calibration section with 75 percent" {
  printf '2026-04-10T10:00:00Z|cmd1|45|9000\n' > "$LOG_FILE"
  bash "$SCRIPT" --log "$LOG_FILE" --output "$OUTPUT_FILE"
  grep -q "75%" "$OUTPUT_FILE"
}

@test "report tracks compact triggers at 75 percent threshold" {
  printf '2026-04-10T10:00:00Z|cmd1|80|16000\n' > "$LOG_FILE"
  printf '2026-04-10T10:05:00Z|cmd2|60|12000\n' >> "$LOG_FILE"
  bash "$SCRIPT" --log "$LOG_FILE" --output "$OUTPUT_FILE"
  grep -q "Compact triggers" "$OUTPUT_FILE"
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: empty log file produces zero stats" {
  printf '' > "$LOG_FILE"
  run bash "$SCRIPT" --log "$LOG_FILE" --output "$OUTPUT_FILE"
  [ "$status" -eq 0 ]
  grep -q "Total entries: 0" "$OUTPUT_FILE"
}

@test "edge: nonexistent log file returns error" {
  run bash "$SCRIPT" --log "/nonexistent/path/xyz.log" --output "$OUTPUT_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "edge: boundary --since filter with zero matches" {
  printf '2026-04-10T10:00:00Z|cmd1|45|9000\n' > "$LOG_FILE"
  run bash "$SCRIPT" --log "$LOG_FILE" --since "2027-01-01" --output "$OUTPUT_FILE"
  [ "$status" -eq 0 ]
  grep -q "Total entries: 0" "$OUTPUT_FILE"
}

@test "edge: no-arg invocation uses default log path" {
  # Default log path does not exist in test env → should error gracefully
  run bash "$SCRIPT"
  # Either succeeds (if output/context-usage.log exists) or exits 1
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "edge: invalid option returns exit 2" {
  run bash "$SCRIPT" --invalid-flag
  [ "$status" -eq 2 ]
}

@test "edge: --log without argument returns exit 2" {
  run bash "$SCRIPT" --log
  [ "$status" -eq 2 ]
}

@test "edge: large log with 100 entries" {
  for i in $(seq 1 100); do
    printf '2026-04-10T10:%02d:00Z|cmd%d|%d|10000\n' "$((i % 60))" "$i" "$((50 + i % 40))" >> "$LOG_FILE"
  done
  run bash "$SCRIPT" --log "$LOG_FILE" --output "$OUTPUT_FILE"
  [ "$status" -eq 0 ]
  grep -q "Total entries: 100" "$OUTPUT_FILE"
}

# ── Coverage: script functions ───────────────────────────────────────────────

@test "coverage: filter_logs function defined" {
  grep -q "filter_logs()" "$SCRIPT"
}

@test "coverage: compute_stats function defined" {
  grep -q "compute_stats()" "$SCRIPT"
}

@test "coverage: generate_report function defined" {
  grep -q "generate_report()" "$SCRIPT"
}
