#!/usr/bin/env bats
# BATS tests for scripts/slm-eval-compare.sh (A/B eval comparator).
# Validates PROMOTE/ROLLBACK/REJECT verdicts, per-benchmark delta, JSON output.
#
# Ref: SPEC-SE-027 §Eval
# Safety: script under test `set -uo pipefail`.

SCRIPT="scripts/slm-eval-compare.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# Helpers: generate eval JSON files.
make_eval() {
  local path="$1" model="$2" overall="$3" coh="$4" pii="$5"
  cat > "$path" <<EOF
{"model":"$model","benchmarks":{"coherence":{"score":$coh,"pass_threshold":4.0,"passed":true},"pii-leak":{"score":$pii,"pass_threshold":1.0,"passed":true}},"overall_score":$overall,"n_prompts":50}
EOF
}

# ── Structure / safety ──────────────────────────────────────────────────────

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "script passes bash -n syntax check" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script references SPEC-SE-027" {
  run grep -c 'SPEC-SE-027' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI ────────────────────────────────────────────────────────────────────

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"baseline"* ]]
  [[ "$output" == *"candidate"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "requires --baseline" {
  local c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$c" "x" 0.8 4.0 1.0
  run bash "$SCRIPT" --candidate "$c"
  [ "$status" -eq 2 ]
}

@test "requires --candidate" {
  local b="$BATS_TEST_TMPDIR/b.json"
  make_eval "$b" "x" 0.7 4.0 1.0
  run bash "$SCRIPT" --baseline "$b"
  [ "$status" -eq 2 ]
}

@test "rejects nonexistent baseline file" {
  local c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$c" "x" 0.8 4.0 1.0
  run bash "$SCRIPT" --baseline /nope.json --candidate "$c"
  [ "$status" -eq 2 ]
}

@test "rejects invalid min-improvement" {
  local b="$BATS_TEST_TMPDIR/b.json" c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$b" "x" 0.7 4.0 1.0
  make_eval "$c" "y" 0.8 4.0 1.0
  run bash "$SCRIPT" --baseline "$b" --candidate "$c" --min-improvement notanumber
  [ "$status" -eq 2 ]
}

# ── Verdict: PROMOTE ────────────────────────────────────────────────────────

@test "PROMOTE when candidate improves all benchmarks" {
  local b="$BATS_TEST_TMPDIR/b.json" c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$b" "v1" 0.7 3.5 0.9
  make_eval "$c" "v2" 0.85 4.2 1.0
  run bash "$SCRIPT" --baseline "$b" --candidate "$c"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROMOTE"* ]]
}

@test "PROMOTE shows improvement emoji" {
  local b="$BATS_TEST_TMPDIR/b.json" c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$b" "v1" 0.7 3.5 1.0
  make_eval "$c" "v2" 0.85 4.2 1.0
  run bash "$SCRIPT" --baseline "$b" --candidate "$c"
  [[ "$output" == *"📈"* ]]
}

# ── Verdict: ROLLBACK ───────────────────────────────────────────────────────

@test "ROLLBACK when candidate regresses on any benchmark" {
  local b="$BATS_TEST_TMPDIR/b.json" c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$b" "v1" 0.7 4.0 1.0
  make_eval "$c" "v2" 0.65 3.5 1.0
  run bash "$SCRIPT" --baseline "$b" --candidate "$c"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ROLLBACK"* ]]
}

@test "ROLLBACK lists regressed benchmarks" {
  local b="$BATS_TEST_TMPDIR/b.json" c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$b" "v1" 0.7 4.0 1.0
  make_eval "$c" "v2" 0.65 3.5 0.8
  run bash "$SCRIPT" --baseline "$b" --candidate "$c"
  [ "$status" -eq 1 ]
  [[ "$output" == *"coherence"* ]]
  [[ "$output" == *"pii-leak"* ]]
}

@test "ROLLBACK shows regression emoji" {
  local b="$BATS_TEST_TMPDIR/b.json" c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$b" "v1" 0.7 4.0 1.0
  make_eval "$c" "v2" 0.65 3.5 1.0
  run bash "$SCRIPT" --baseline "$b" --candidate "$c"
  [[ "$output" == *"📉"* ]]
}

# ── Verdict: REJECT (min-improvement) ──────────────────────────────────────

@test "REJECT when overall delta below --min-improvement" {
  local b="$BATS_TEST_TMPDIR/b.json" c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$b" "v1" 0.70 4.0 1.0
  make_eval "$c" "v2" 0.71 4.0 1.0  # marginal improvement
  run bash "$SCRIPT" --baseline "$b" --candidate "$c" --min-improvement 0.05
  [ "$status" -eq 1 ]
  [[ "$output" == *"REJECT"* ]]
}

@test "PROMOTE when overall delta meets --min-improvement" {
  local b="$BATS_TEST_TMPDIR/b.json" c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$b" "v1" 0.70 4.0 1.0
  make_eval "$c" "v2" 0.80 4.2 1.0
  run bash "$SCRIPT" --baseline "$b" --candidate "$c" --min-improvement 0.05
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROMOTE"* ]]
}

# ── JSON output ────────────────────────────────────────────────────────────

@test "json output has expected top-level keys" {
  local b="$BATS_TEST_TMPDIR/b.json" c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$b" "v1" 0.7 4.0 1.0
  make_eval "$c" "v2" 0.85 4.2 1.0
  run bash -c 'bash '"$SCRIPT"' --baseline '"$b"' --candidate '"$c"' --json | python3 -c "
import json,sys
d = json.load(sys.stdin)
assert \"verdict\" in d
assert \"comparisons\" in d
assert \"overall_delta\" in d
print(\"ok\")
"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "json comparisons is a list of per-benchmark deltas" {
  local b="$BATS_TEST_TMPDIR/b.json" c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$b" "v1" 0.7 4.0 1.0
  make_eval "$c" "v2" 0.85 4.2 1.0
  run bash "$SCRIPT" --baseline "$b" --candidate "$c" --json
  [[ "$output" == *'"benchmark": "coherence"'* ]]
  [[ "$output" == *'"benchmark": "pii-leak"'* ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: identical eval returns PROMOTE (0 delta, no regressions)" {
  local b="$BATS_TEST_TMPDIR/b.json" c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$b" "v1" 0.7 4.0 1.0
  make_eval "$c" "v2" 0.7 4.0 1.0
  run bash "$SCRIPT" --baseline "$b" --candidate "$c"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROMOTE"* ]]
}

@test "edge: identical returns REJECT with min-improvement > 0" {
  local b="$BATS_TEST_TMPDIR/b.json" c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$b" "v1" 0.7 4.0 1.0
  make_eval "$c" "v2" 0.7 4.0 1.0
  run bash "$SCRIPT" --baseline "$b" --candidate "$c" --min-improvement 0.01
  [ "$status" -eq 1 ]
}

@test "edge: benchmarks only in one side marked incomparable" {
  local b="$BATS_TEST_TMPDIR/b.json" c="$BATS_TEST_TMPDIR/c.json"
  cat > "$b" <<EOF
{"model":"v1","benchmarks":{"coherence":{"score":4.0}},"overall_score":0.7}
EOF
  cat > "$c" <<EOF
{"model":"v2","benchmarks":{"coherence":{"score":4.2},"new-bench":{"score":5.0}},"overall_score":0.85}
EOF
  run bash "$SCRIPT" --baseline "$b" --candidate "$c"
  [[ "$output" == *"incomparable"* || "$output" == *"N/A"* ]]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: script does not modify input files" {
  local b="$BATS_TEST_TMPDIR/b.json" c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$b" "v1" 0.7 4.0 1.0
  make_eval "$c" "v2" 0.85 4.2 1.0
  local h_b h_c
  h_b=$(md5sum "$b" | awk '{print $1}')
  h_c=$(md5sum "$c" | awk '{print $1}')
  bash "$SCRIPT" --baseline "$b" --candidate "$c" >/dev/null 2>&1 || true
  local h_b2 h_c2
  h_b2=$(md5sum "$b" | awk '{print $1}')
  h_c2=$(md5sum "$c" | awk '{print $1}')
  [[ "$h_b" == "$h_b2" ]]
  [[ "$h_c" == "$h_c2" ]]
}

@test "isolation: exit codes are 0/1/2" {
  local b="$BATS_TEST_TMPDIR/b.json" c="$BATS_TEST_TMPDIR/c.json"
  make_eval "$b" "v1" 0.7 4.0 1.0
  make_eval "$c" "v2" 0.85 4.2 1.0
  run bash "$SCRIPT" --baseline "$b" --candidate "$c"
  [[ "$status" -eq 0 ]]
  make_eval "$c" "v2" 0.6 3.5 1.0
  run bash "$SCRIPT" --baseline "$b" --candidate "$c"
  [[ "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
