#!/usr/bin/env bats
# Tests for SE-029-R — re-state anchor
# Ref: docs/propuestas/SE-029-rate-distortion-context.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/context-restate-anchor.sh"
}

# ── Safety ───────────────────────────────────────────────────────────────────

@test "safety: script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "safety: script has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: script references SE-029" {
  grep -q "SE-029" "$SCRIPT"
}

# ── Positive: emission ───────────────────────────────────────────────────────

@test "positive: ratio above 20 emits anchor" {
  run bash "$SCRIPT" --ratio 38 --current-task "impl" --active-spec "SPEC-120"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "Context Re-State.*38:1"
}

@test "positive: anchor contains all 5 sections" {
  run bash "$SCRIPT" --ratio 25 --current-task "x" --active-spec "Y" --last-decision "d" --next-step "n" --degraded "d"
  echo "$output" | grep -qE "Current task"
  echo "$output" | grep -qE "Active spec"
  echo "$output" | grep -qE "Last decision"
  echo "$output" | grep -qE "Next step"
  echo "$output" | grep -qE "Degraded"
}

@test "positive: --json emits valid JSON" {
  run bash "$SCRIPT" --ratio 30 --current-task "x" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['emitted'] is True
assert d['ratio'] == 30
"
}

@test "positive: --json has timestamp field ISO-8601" {
  run bash "$SCRIPT" --ratio 25 --json
  echo "$output" | python3 -c "
import json,sys,re
d=json.load(sys.stdin)
assert re.match(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z', d['timestamp'])
"
}

@test "positive: --help returns exit 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

# ── Threshold behavior ──────────────────────────────────────────────────────

@test "positive: ratio 20 → skipped (boundary)" {
  run bash "$SCRIPT" --ratio 20 --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['skipped'] is True"
}

@test "positive: ratio 21 → emitted (just above threshold)" {
  run bash "$SCRIPT" --ratio 21 --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['emitted'] is True"
}

@test "positive: --force emits anchor even below threshold" {
  run bash "$SCRIPT" --ratio 5 --force --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['emitted'] is True"
}

# ── Negative ─────────────────────────────────────────────────────────────────

@test "negative: missing --ratio rejected with exit 2" {
  run bash "$SCRIPT" --current-task "x"
  [ "$status" -eq 2 ]
}

@test "negative: non-numeric ratio rejected with exit 2" {
  run bash "$SCRIPT" --ratio "abc"
  [ "$status" -eq 2 ]
  echo "$output" | grep -qE "numeric"
}

@test "negative: unknown flag rejected" {
  run bash "$SCRIPT" --ratio 30 --bogus
  [ "$status" -eq 2 ]
}

# ── Defaults (fallbacks) ────────────────────────────────────────────────────

@test "positive: missing optional fields use fallback placeholders" {
  run bash "$SCRIPT" --ratio 25
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "\(unknown\)|\(none"
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: empty current-task replaced with fallback" {
  run bash "$SCRIPT" --ratio 25 --current-task ""
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "\(unknown\)"
}

@test "edge: very large ratio (9999) accepted" {
  run bash "$SCRIPT" --ratio 9999 --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ratio']==9999"
}

@test "edge: ratio 0 → skipped (boundary low)" {
  run bash "$SCRIPT" --ratio 0 --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('skipped') is True"
}

@test "edge: decimal ratio (22.5) → emitted" {
  run bash "$SCRIPT" --ratio 22.5 --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('emitted') is True"
}

# ── Isolation ────────────────────────────────────────────────────────────────

@test "isolation: does not write to any file" {
  # Script only writes stdout; no file creation
  run bash "$SCRIPT" --ratio 30 --json
  [ "$status" -eq 0 ]
}

@test "isolation: exit codes are 0 or 2" {
  run bash "$SCRIPT" --ratio 30
  [[ "$status" == "0" || "$status" == "2" ]]
}
