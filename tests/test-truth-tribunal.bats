#!/usr/bin/env bats
# tests/test-truth-tribunal.bats
# BATS tests for scripts/truth-tribunal.sh — Truth Tribunal orchestration helper.
# Verifies: type/tier detection, weights, aggregation, verdict computation,
# cache TTL behavior, and edge cases (missing dirs, malformed YAML, empty input).
#
# Ref: SPEC-106 (Truth Tribunal — Report Reliability)
# Ref: docs/rules/domain/truth-tribunal-weights.md
# Ref: SPEC-055 (test quality gate, score >=80)

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/truth-tribunal.sh"
  TMPDIR_TEST=$(mktemp -d)
  export TRUTH_TRIBUNAL_CACHE="$TMPDIR_TEST/cache"
  mkdir -p "$TRUTH_TRIBUNAL_CACHE"
  REPORT="$TMPDIR_TEST/sample-report.md"
  JUDGES_DIR="$TMPDIR_TEST/judges"
  mkdir -p "$JUDGES_DIR"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# Helper: write a per-judge YAML output with score, verdict, confidence
write_judge() {
  local name="$1" score="$2" verdict="$3" conf="${4:-0.8}"
  cat > "$JUDGES_DIR/$name.yaml" <<EOF
judge: "$name-judge"
score: $score
verdict: "$verdict"
confidence: $conf
EOF
}

# Helper: write all 7 judges with the same score and verdict
write_all_judges() {
  local score="$1" verdict="${2:-pass}"
  for j in factuality source-traceability hallucination coherence calibration completeness compliance; do
    write_judge "$j" "$score" "$verdict"
  done
}

# ── Script structure ──────────────────────────────────────────────────────

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script uses set -uo pipefail" {
  head -25 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "help subcommand prints usage" {
  run bash "$SCRIPT" help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"truth-tribunal.sh"* ]]
  [[ "$output" == *"detect-type"* ]]
  [[ "$output" == *"aggregate"* ]]
}

@test "unknown subcommand exits 2 with error message" {
  run bash "$SCRIPT" frobnicate
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"Unknown"* ]]
}

# ── detect-type ───────────────────────────────────────────────────────────

@test "detect-type: ceo-report file => executive" {
  local f="$TMPDIR_TEST/ceo-report-q4.md"
  echo "# CEO Report" > "$f"
  run bash "$SCRIPT" detect-type "$f"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "executive" ]]
}

@test "detect-type: compliance-* file => compliance" {
  local f="$TMPDIR_TEST/compliance-aepd.md"
  echo "# Audit" > "$f"
  run bash "$SCRIPT" detect-type "$f"
  [[ "$output" == "compliance" ]]
}

@test "detect-type: meeting-digest file => digest" {
  local f="$TMPDIR_TEST/meeting-digest-2026.md"
  echo "# Meeting" > "$f"
  run bash "$SCRIPT" detect-type "$f"
  [[ "$output" == "digest" ]]
}

@test "detect-type: subjective sprint-retro => subjective" {
  local f="$TMPDIR_TEST/sprint-retro-q1.md"
  echo "# Retro" > "$f"
  run bash "$SCRIPT" detect-type "$f"
  [[ "$output" == "subjective" ]]
}

@test "detect-type: unknown filename => default" {
  local f="$TMPDIR_TEST/random-notes.md"
  echo "x" > "$f"
  run bash "$SCRIPT" detect-type "$f"
  [[ "$output" == "default" ]]
}

@test "detect-type: nonexistent file => default (graceful)" {
  run bash "$SCRIPT" detect-type "/nonexistent/path.md"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "default" ]]
}

@test "detect-type: frontmatter override beats filename heuristic" {
  local f="$TMPDIR_TEST/ceo-report.md"
  cat > "$f" <<EOF
---
report_type: compliance
---
# Body
EOF
  run bash "$SCRIPT" detect-type "$f"
  [[ "$output" == "compliance" ]]
}

# ── detect-tier ───────────────────────────────────────────────────────────

@test "detect-tier: path under projects/ => N4" {
  run bash "$SCRIPT" detect-tier "/foo/projects/alpha/report.md"
  [[ "$output" == "N4" ]]
}

@test "detect-tier: private-agent-memory path => N2" {
  run bash "$SCRIPT" detect-tier "/foo/private-agent-memory/x.md"
  [[ "$output" == "N2" ]]
}

@test "detect-tier: .local. file => N2" {
  run bash "$SCRIPT" detect-tier "/foo/CLAUDE.local.md"
  [[ "$output" == "N2" ]]
}

@test "detect-tier: generic path => N1 (strictest default)" {
  run bash "$SCRIPT" detect-tier "/foo/docs/readme.md"
  [[ "$output" == "N1" ]]
}

# ── weights ───────────────────────────────────────────────────────────────

@test "weights: default profile prints 7 numeric weights summing ~1.0" {
  run bash "$SCRIPT" weights default
  [[ "$status" -eq 0 ]]
  local count
  count=$(echo "$output" | tr ' ' '\n' | wc -l)
  [[ "$count" -eq 7 ]]
  # Sum should be 1.0 (allow floating tolerance via python)
  local sum
  sum=$(python3 -c "print(sum(float(x) for x in '$output'.split()))")
  python3 -c "import sys; sys.exit(0 if abs($sum - 1.0) < 0.001 else 1)"
}

@test "weights: compliance profile gives compliance dimension highest weight" {
  run bash "$SCRIPT" weights compliance
  [[ "$status" -eq 0 ]]
  # 7th weight is compliance; should be 0.30 per truth-tribunal-weights.md
  local last
  last=$(echo "$output" | awk '{print $7}')
  [[ "$last" == "0.30" ]]
}

@test "weights: unknown profile falls back to default" {
  run bash "$SCRIPT" weights unknown_profile
  [[ "$status" -eq 0 ]]
  local default_out
  default_out=$(bash "$SCRIPT" weights default)
  [[ "$output" == "$default_out" ]]
}

# ── aggregate ─────────────────────────────────────────────────────────────

@test "aggregate: missing judges dir exits 1 with error" {
  echo "x" > "$REPORT"
  run bash "$SCRIPT" aggregate "$REPORT" "/nonexistent/dir"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"ERROR"* ]]
}

@test "aggregate: 7 high-scoring judges => PUBLISHABLE verdict" {
  echo "# Test" > "$REPORT"
  write_all_judges 95 "pass"
  run bash "$SCRIPT" aggregate "$REPORT" "$JUDGES_DIR"
  [[ "$status" -eq 0 ]]
  local crc="${REPORT}.truth.crc"
  [[ -f "$crc" ]]
  grep -q "verdict: PUBLISHABLE" "$crc"
}

@test "aggregate: 7 low-scoring judges => ITERATE verdict" {
  echo "# Test" > "$REPORT"
  write_all_judges 40 "fail"
  run bash "$SCRIPT" aggregate "$REPORT" "$JUDGES_DIR"
  [[ "$status" -eq 1 ]]
  grep -q "verdict: ITERATE" "${REPORT}.truth.crc"
}

@test "aggregate: mid-range scores => CONDITIONAL verdict" {
  echo "# Test" > "$REPORT"
  write_all_judges 78 "conditional"
  run bash "$SCRIPT" aggregate "$REPORT" "$JUDGES_DIR"
  [[ "$status" -eq 1 ]]
  grep -q "verdict: CONDITIONAL" "${REPORT}.truth.crc"
}

@test "aggregate: 4 abstentions => NOT_EVALUABLE" {
  echo "# Test" > "$REPORT"
  # Only write 3 judges, leaving 4 missing
  write_judge "factuality" 90 "pass"
  write_judge "compliance" 90 "pass"
  write_judge "coherence" 90 "pass"
  run bash "$SCRIPT" aggregate "$REPORT" "$JUDGES_DIR"
  grep -q "verdict: NOT_EVALUABLE" "${REPORT}.truth.crc"
  grep -q "abstentions: 4" "${REPORT}.truth.crc"
}

@test "aggregate: compliance profile with low compliance score => ITERATE override" {
  local f="$TMPDIR_TEST/compliance-audit.md"
  echo "# Compliance" > "$f"
  # All judges pass with 95 except compliance which scores 80
  for j in factuality source-traceability hallucination coherence calibration completeness; do
    write_judge "$j" 95 "pass"
  done
  write_judge "compliance" 80 "conditional"
  run bash "$SCRIPT" aggregate "$f" "$JUDGES_DIR"
  # Compliance gate: <95 => ITERATE regardless of weighted score
  grep -q "verdict: ITERATE" "${f}.truth.crc"
}

# ── verdict subcommand ────────────────────────────────────────────────────

@test "verdict: missing crc returns no-verdict and exits 1" {
  echo "x" > "$REPORT"
  run bash "$SCRIPT" verdict "$REPORT"
  [[ "$status" -eq 1 ]]
  [[ "$output" == "no-verdict" ]]
}

@test "verdict: existing crc returns the parsed verdict" {
  echo "x" > "$REPORT"
  write_all_judges 95 "pass"
  bash "$SCRIPT" aggregate "$REPORT" "$JUDGES_DIR" >/dev/null || true
  run bash "$SCRIPT" verdict "$REPORT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "PUBLISHABLE" ]]
}

# ── cache ─────────────────────────────────────────────────────────────────

@test "cache-check: returns 1 (miss) when no cached crc exists" {
  echo "x" > "$REPORT"
  run bash "$SCRIPT" cache-check "$REPORT"
  [[ "$status" -eq 1 ]]
}

@test "cache-store + cache-check: roundtrip returns cached content" {
  echo "x" > "$REPORT"
  write_all_judges 95 "pass"
  bash "$SCRIPT" aggregate "$REPORT" "$JUDGES_DIR" >/dev/null || true
  bash "$SCRIPT" cache-store "$REPORT" "${REPORT}.truth.crc"
  run bash "$SCRIPT" cache-check "$REPORT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"verdict: PUBLISHABLE"* ]]
}

@test "cache-check: TTL expiration returns miss" {
  echo "x" > "$REPORT"
  write_all_judges 95 "pass"
  bash "$SCRIPT" aggregate "$REPORT" "$JUDGES_DIR" >/dev/null || true
  bash "$SCRIPT" cache-store "$REPORT" "${REPORT}.truth.crc"
  # Backdate cached file to 25h ago, then check with default 24h TTL
  local hash cached
  hash=$(sha256sum "$REPORT" | awk '{print $1}')
  cached="$TRUTH_TRIBUNAL_CACHE/${hash}.truth.crc"
  touch -d "25 hours ago" "$cached"
  run bash "$SCRIPT" cache-check "$REPORT"
  [[ "$status" -eq 1 ]]
}

# ── Edge cases ────────────────────────────────────────────────────────────

@test "aggregate: emits well-formed YAML frontmatter in crc" {
  echo "x" > "$REPORT"
  write_all_judges 95 "pass"
  bash "$SCRIPT" aggregate "$REPORT" "$JUDGES_DIR" >/dev/null || true
  local crc="${REPORT}.truth.crc"
  # Two `---` markers (open + close)
  local count
  count=$(grep -c "^---$" "$crc")
  [[ "$count" -eq 2 ]]
  grep -q "^tribunal_id: TT-" "$crc"
  grep -q "^report_type:" "$crc"
  grep -q "^destination_tier:" "$crc"
  grep -q "^weighted_score:" "$crc"
}

@test "aggregate: per-judge details preserved in crc output" {
  echo "x" > "$REPORT"
  write_all_judges 88 "conditional"
  bash "$SCRIPT" aggregate "$REPORT" "$JUDGES_DIR" >/dev/null || true
  local crc="${REPORT}.truth.crc"
  grep -q "factuality:" "$crc"
  grep -q "source_traceability:" "$crc"
  grep -q "hallucination:" "$crc"
  grep -q "compliance:" "$crc"
  grep -q "score: 88" "$crc"
}
