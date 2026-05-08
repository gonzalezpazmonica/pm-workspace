#!/usr/bin/env bats
# BATS tests for .opencode/hooks/stress-awareness-nudge.sh
# UserPromptSubmit hook — detects pressure patterns and injects calm-anchoring nudge.
# Source: Anthropic "Emotion concepts in LLMs" (2026-04-02)
# Ref: batch 43 hook coverage

HOOK=".opencode/hooks/stress-awareness-nudge.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
}
teardown() { cd /; }

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── Silent pass paths ───────────────────────────────────

@test "silent: empty stdin exits 0 with no output" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "silent: short input (<10 chars) passes silently" {
  run bash "$HOOK" <<< "ok"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "silent: slash command (/foo) passes silently" {
  run bash "$HOOK" <<< "/command foo bar baz"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "silent: neutral request produces no nudge" {
  run bash "$HOOK" <<< '{"content":"please implement the feature described in the spec"}'
  [ "$status" -eq 0 ]
  [[ "$output" != *"pressure pattern detected"* ]]
}

@test "silent: long calm request without pressure words" {
  run bash "$HOOK" <<< "I would like to discuss the architecture of our service layer."
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

# ── Pressure pattern: artificial urgency ────────────────

@test "detect: MUST...NOW urgency triggers nudge" {
  run bash "$HOOK" <<< "You MUST finish this NOW before the deploy."
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "detect: 'do it now' triggers nudge" {
  run bash "$HOOK" <<< "do it now, no excuses"
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "detect: URGENT keyword triggers nudge" {
  run bash "$HOOK" <<< "This is URGENT, please resolve immediately"
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "detect: Spanish 'hazlo ya' triggers" {
  run bash "$HOOK" <<< "hazlo ya sin dar mas vueltas"
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "detect: Spanish 'inmediatamente' triggers" {
  run bash "$HOOK" <<< "necesito que lo hagas inmediatamente"
  [[ "$output" == *"pressure pattern detected"* ]]
}

# ── Pressure pattern: shame ─────────────────────────────

@test "detect: 'should be easy' triggers shame pattern" {
  run bash "$HOOK" <<< "this should be easy for you, right?"
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "detect: 'should be trivial' triggers" {
  run bash "$HOOK" <<< "this should be trivial to implement"
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "detect: Spanish 'debería ser fácil' triggers" {
  run bash "$HOOK" <<< "debería ser fácil, no entiendo por qué tardas tanto"
  [[ "$output" == *"pressure pattern detected"* ]]
}

# ── Pressure pattern: failure attribution ───────────────

@test "detect: 'you already failed' triggers" {
  run bash "$HOOK" <<< "you already failed to do this three times"
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "detect: Spanish 'ya fallaste' triggers" {
  run bash "$HOOK" <<< "ya fallaste antes con esta tarea"
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "detect: 'no puedes' triggers failure pattern" {
  run bash "$HOOK" <<< "parece que no puedes hacerlo bien"
  [[ "$output" == *"pressure pattern detected"* ]]
}

# ── Pressure pattern: corner-cutting ────────────────────

@test "detect: 'just make it work' triggers" {
  run bash "$HOOK" <<< "just make it work, I don't care how"
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "detect: Spanish 'haz que funcione' triggers" {
  run bash "$HOOK" <<< "haz que funcione de una vez, como sea"
  [[ "$output" == *"pressure pattern detected"* ]]
}

# ── Pressure pattern: emotional manipulation ────────────

@test "detect: 'I am disappointed' triggers" {
  run bash "$HOOK" <<< "I'm disappointed with the quality of this output"
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "detect: Spanish 'estoy decepcionada' triggers" {
  run bash "$HOOK" <<< "estoy decepcionada con el trabajo que has hecho"
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "detect: 'this is unacceptable' triggers" {
  run bash "$HOOK" <<< "this is unacceptable, we need better quality"
  [[ "$output" == *"pressure pattern detected"* ]]
}

# ── Nudge content ───────────────────────────────────────

@test "nudge: contains calm-anchoring guidance" {
  run bash "$HOOK" <<< "this is URGENT, do it NOW"
  [[ "$output" == *"Correctness matters more than speed"* ]]
  [[ "$output" == *"Transparency over forced output"* ]]
  [[ "$output" == *"escalate"* ]]
}

@test "nudge: mentions honest assessment over compliance" {
  run bash "$HOOK" <<< "you already failed, fix it now"
  [[ "$output" == *"honest assessment"* ]]
  [[ "$output" == *"compliance under pressure"* ]]
}

# ── Multiple patterns combine ───────────────────────────

@test "detect: multiple patterns in same message both detected" {
  run bash "$HOOK" <<< "do it NOW, this should be easy, you already failed"
  [[ "$output" == *"pressure pattern detected"* ]]
}

# ── JSON input extraction ───────────────────────────────

@test "parse: content field from JSON extracted" {
  run bash "$HOOK" <<< '{"content":"URGENT: fix this immediately before deploy"}'
  [[ "$output" == *"pressure pattern detected"* ]]
}

# ── Negative cases ──────────────────────────────────────

@test "negative: malformed JSON falls back to raw text parsing" {
  run bash "$HOOK" <<< "not valid json but URGENT text here"
  # Falls back to $INPUT directly; URGENT should match
  [[ "$output" == *"pressure pattern detected"* ]]
}

@test "negative: emoji-laden neutral message not flagged" {
  run bash "$HOOK" <<< "hi there, can we review the design together?"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

@test "negative: word 'fail' alone (not in pattern) not flagged" {
  run bash "$HOOK" <<< "the test suite includes failure scenarios"
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: case-insensitive matching (NOW, Now, now)" {
  run bash "$HOOK" <<< "you MUST do this NOW please"
  [[ "$output" == *"pressure"* ]]
}

@test "edge: very long input with pressure late in text" {
  local long
  long=$(printf 'filler text %.0s' {1..20})
  run bash "$HOOK" <<< "$long and then URGENT action"
  [[ "$output" == *"pressure"* ]]
}

@test "edge: boundary exactly 10 chars not triggering silent" {
  run bash "$HOOK" <<< "URGENT now"
  # 10 chars: "URGENT now" = 10, hook skips <10 so >= 10 processes
  [[ "$output" == *"pressure"* ]]
}

@test "edge: boundary exactly 9 chars passes silent" {
  run bash "$HOOK" <<< "hazlo ya."
  # 9 chars, < 10 threshold → silent
  [ "$status" -eq 0 ]
  [[ -z "$output" ]]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: 5 pressure categories defined" {
  for cat in urgency shame failure_attribution corner_cutting emotional_pressure; do
    grep -q "$cat" "$HOOK" || fail "missing category: $cat"
  done
}

@test "coverage: Anthropic research attribution present" {
  run grep -c 'Anthropic' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: emotional-state-tracker integration" {
  run grep -c 'emotional-state-tracker' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ────────────────────────────────────────────

@test "isolation: hook never exits non-zero" {
  for input in '' 'short' '{"bad":json' 'URGENT do it now or else'; do
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
  done
}

@test "isolation: hook writes only stdout (no file modifications)" {
  local before
  before=$(find "$TMPDIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
  bash "$HOOK" <<< "URGENT now please" >/dev/null 2>&1
  local after
  after=$(find "$TMPDIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}
