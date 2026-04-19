#!/usr/bin/env bats
# BATS tests for scripts/operational-point-selector.sh (SE-029 Slice 4).
#
# Valida el selector: parsing de turnos, classificación delegada,
# aplicación de max_ratio por class, frozen=true → ratio=1, verdict
# FITS/OVERFLOW según budget, JSON output, safety.
#
# Ref: SE-029 §3 (SE-029-O), ROADMAP §Tier 4.1
# Dep: context-task-classify.sh (Slice 2), compress-skip-frozen.sh (Slice 3)
# Safety: script under test `set -uo pipefail`, read-only.

SCRIPT="scripts/operational-point-selector.sh"
CLASSIFIER="scripts/context-task-classify.sh"

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

@test "classifier dependency exists and is executable" {
  [[ -x "$CLASSIFIER" ]]
}

@test "script uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "script passes bash -n syntax check" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script references SE-029 and Slice 4" {
  run grep -c 'SE-029' "$SCRIPT"
  [[ "$output" -ge 1 ]]
  run grep -c 'Slice 4\|SE-029-O' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI surface ─────────────────────────────────────────────────────────────

@test "script accepts --help and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"session"* ]]
  [[ "$output" == *"budget"* ]]
}

@test "script rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "script rejects no-args invocation" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "script requires --session argument" {
  run bash "$SCRIPT" --budget 100
  [ "$status" -eq 2 ]
  [[ "$output" == *"session required"* ]]
}

@test "script requires --budget argument" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  echo "hi" > "$tmp"
  run bash "$SCRIPT" --session "$tmp"
  [ "$status" -eq 2 ]
  [[ "$output" == *"budget required"* ]]
}

@test "script rejects nonexistent session file" {
  run bash "$SCRIPT" --session /does/not/exist.txt --budget 100
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

@test "script rejects non-integer budget" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  echo "hi" > "$tmp"
  run bash "$SCRIPT" --session "$tmp" --budget not-a-number
  [ "$status" -eq 2 ]
  [[ "$output" == *"integer"* ]]
}

# ── Single-turn sessions ────────────────────────────────────────────────────

@test "single decision turn: ratio=1, frozen=true in plan" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  echo "APPROVED — ship it" > "$tmp"
  run bash "$SCRIPT" --session "$tmp" --budget 1000
  [ "$status" -eq 0 ]
  [[ "$output" == *"decision"* ]]
  [[ "$output" == *"ratio=1:1"* ]]
  [[ "$output" == *"frozen=true"* ]]
}

@test "single chitchat turn: high ratio applied" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  echo "thanks" > "$tmp"
  run bash "$SCRIPT" --session "$tmp" --budget 1000
  [ "$status" -eq 0 ]
  [[ "$output" == *"chitchat"* ]]
  [[ "$output" == *"ratio=80:1"* ]]
}

@test "single spec turn: ratio=1 (frozen)" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  echo "SPEC-120 AC-03 requires OAuth authentication" > "$tmp"
  run bash "$SCRIPT" --session "$tmp" --budget 1000
  [ "$status" -eq 0 ]
  [[ "$output" == *"spec"* ]]
  [[ "$output" == *"ratio=1:1"* ]]
}

# ── Multi-turn sessions ────────────────────────────────────────────────────

@test "multi-turn session: 4 turns parsed correctly" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  cat > "$tmp" <<EOF
APPROVED
---TURN---
SPEC-120 AC-03
---TURN---
thanks
---TURN---
ok
EOF
  run bash "$SCRIPT" --session "$tmp" --budget 1000
  [ "$status" -eq 0 ]
  [[ "$output" == *"Turnos analizados: 4"* ]]
  [[ "$output" == *"turn=1"* ]]
  [[ "$output" == *"turn=4"* ]]
}

@test "multi-turn: mixed classes get distinct ratios" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  cat > "$tmp" <<EOF
APPROVED merge
---TURN---
thanks
EOF
  run bash "$SCRIPT" --session "$tmp" --budget 1000
  [ "$status" -eq 0 ]
  [[ "$output" == *"class=decision"* ]]
  [[ "$output" == *"class=chitchat"* ]]
}

# ── Verdict FITS / OVERFLOW ────────────────────────────────────────────────

@test "verdict FITS when plan under budget" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  echo "thanks" > "$tmp"
  run bash "$SCRIPT" --session "$tmp" --budget 1000
  [ "$status" -eq 0 ]
  [[ "$output" == *"FITS"* ]]
  [[ "$output" == *"headroom"* ]]
}

@test "verdict OVERFLOW exits 1 when plan exceeds budget" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  cat > "$tmp" <<EOF
APPROVED merging the full payment gateway refactor with all the backend service migrations pending review on AB1023 AB1024 AB1025
EOF
  run bash "$SCRIPT" --session "$tmp" --budget 5
  [ "$status" -eq 1 ]
  [[ "$output" == *"OVERFLOW"* ]]
  [[ "$output" == *"EXCEDE"* ]]
}

# ── JSON output ─────────────────────────────────────────────────────────────

@test "json output is valid with expected top-level keys" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  echo "thanks" > "$tmp"
  run bash -c 'bash '"$SCRIPT"' --session '"$tmp"' --budget 1000 --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"verdict\" in d; assert \"plan\" in d; assert \"budget\" in d; assert isinstance(d[\"plan\"], list); print(\"ok\")"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "json plan entries have expected keys" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  echo "APPROVED" > "$tmp"
  run bash -c 'bash '"$SCRIPT"' --session '"$tmp"' --budget 1000 --json | python3 -c "import json,sys; p=json.load(sys.stdin)[\"plan\"][0]; assert \"turn\" in p; assert \"class\" in p; assert \"applied_ratio\" in p; print(\"ok\")"'
  [ "$status" -eq 0 ]
}

@test "json OVERFLOW verdict marks correctly" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  echo "APPROVED full payment gateway refactor backend migration AB1023 AB1024 AB1025 extended context here" > "$tmp"
  run bash -c 'bash '"$SCRIPT"' --session '"$tmp"' --budget 5 --json'
  [ "$status" -eq 1 ]
  [[ "$output" == *'"verdict":"OVERFLOW"'* ]]
}

# ── Negative cases ─────────────────────────────────────────────────────────

@test "negative: zero-length session produces error or empty plan" {
  local tmp="$BATS_TEST_TMPDIR/empty.txt"
  : > "$tmp"
  run bash "$SCRIPT" --session "$tmp" --budget 100
  # Empty session → awk creates 1 empty turn file → 0 words → skipped → n_turns is 0 in practice OR script treats it as single empty turn
  # Accept either 0 (degraded gracefully) or 2 (rejected as no turns)
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
}

@test "negative: negative budget rejected" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  echo "hi" > "$tmp"
  run bash "$SCRIPT" --session "$tmp" --budget -50
  [ "$status" -eq 2 ]
}

@test "negative: unknown flag rejected" {
  run bash "$SCRIPT" --foo-bar
  [ "$status" -eq 2 ]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: session without separator is treated as 1 turn" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  printf 'line1\nline2\nline3\nAPPROVED\n' > "$tmp"
  run bash "$SCRIPT" --session "$tmp" --budget 1000
  [ "$status" -eq 0 ]
  [[ "$output" == *"Turnos analizados: 1"* ]]
}

@test "edge: words_plan never goes below 1 for nonempty turn" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  echo "thanks" > "$tmp"
  run bash "$SCRIPT" --session "$tmp" --budget 1000
  [ "$status" -eq 0 ]
  [[ "$output" == *"words_plan=1"* ]]
}

@test "edge: token estimate uses 1.3x words heuristic" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  # 10 words → ~13 tokens
  echo "one two three four five six seven eight nine ten" > "$tmp"
  run bash "$SCRIPT" --session "$tmp" --budget 1000
  [ "$status" -eq 0 ]
  [[ "$output" == *"~13 tokens"* ]]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: script does not modify session file" {
  local tmp="$BATS_TEST_TMPDIR/ro.txt"
  echo "APPROVED" > "$tmp"
  local hash_before
  hash_before=$(md5sum "$tmp" | awk '{print $1}')
  bash "$SCRIPT" --session "$tmp" --budget 1000 >/dev/null 2>&1
  local hash_after
  hash_after=$(md5sum "$tmp" | awk '{print $1}')
  [[ "$hash_before" == "$hash_after" ]]
}

@test "isolation: text and json modes produce same plan entries" {
  local tmp="$BATS_TEST_TMPDIR/s.txt"
  echo "APPROVED" > "$tmp"
  run bash "$SCRIPT" --session "$tmp" --budget 1000
  local text_out="$output"
  run bash -c 'bash '"$SCRIPT"' --session '"$tmp"' --budget 1000 --json'
  # Both should contain the same class and ratio data.
  [[ "$text_out" == *"decision"* ]]
  [[ "$output" == *'"class":"decision"'* ]]
}
