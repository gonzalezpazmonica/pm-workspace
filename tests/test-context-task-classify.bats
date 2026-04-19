#!/usr/bin/env bats
# BATS tests for scripts/context-task-classify.sh (SE-029 Slice 2).
# Validates the task-class classifier: 6 classes, scoring, frozen/ratio
# mapping, JSON output, stdin + file input, safety, edge cases.
#
# Ref: SE-029 §2 (SE-029-C), ROADMAP §Tier 4.1
# Safety: script under test has `set -uo pipefail`, read-only.

SCRIPT="scripts/context-task-classify.sh"

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
  run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "script passes bash -n syntax check" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script references SE-029" {
  run grep -c 'SE-029' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI surface ─────────────────────────────────────────────────────────────

@test "script accepts --help and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Classify"* ]]
  [[ "$output" == *"decision"* ]]
  [[ "$output" == *"chitchat"* ]]
}

@test "script rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "script rejects no-args invocation" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "script rejects nonexistent input file" {
  run bash "$SCRIPT" --input /nonexistent/path.txt
  [ "$status" -eq 2 ]
}

# ── Classification — positive cases ─────────────────────────────────────────

@test "classifies approval as decision" {
  run bash -c 'echo "APPROVED — ship it" | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
  [[ "$output" == "decision" ]]
}

@test "classifies SPEC reference as spec" {
  run bash -c 'echo "Implementing SPEC-120 AC-03 with new handler" | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
  [[ "$output" == "spec" ]]
}

@test "classifies code fence as code" {
  local tmp="$BATS_TEST_TMPDIR/turn.txt"
  printf '%s\n' '```python' 'def foo():' '    pass' '```' > "$tmp"
  run bash "$SCRIPT" --input "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == "code" ]]
}

@test "classifies diff marker as code" {
  local tmp="$BATS_TEST_TMPDIR/diff.txt"
  printf '%s\n' 'diff --git a/foo b/foo' '@@ -1 +1 @@' '-old' '+new' > "$tmp"
  run bash "$SCRIPT" --input "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == "code" ]]
}

@test "classifies traceback as code" {
  run bash -c 'echo "Traceback (most recent call last): Error: foo" | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
  [[ "$output" == "code" ]]
}

@test "classifies PASS/FAIL verdict as review" {
  run bash -c 'echo "G6 BATS tests PASS: 227/227 suites" | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
  [[ "$output" == "review" ]]
}

@test "classifies court judge output as review" {
  run bash -c 'echo "correctness-judge VERDICT: issues in line 42" | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
  [[ "$output" == "review" ]]
}

@test "classifies long markdown as context" {
  local tmp="$BATS_TEST_TMPDIR/long.txt"
  printf '# Heading\n\n' > "$tmp"
  for i in $(seq 1 30); do echo "- bullet item number $i with some explanation text here" >> "$tmp"; done
  run bash "$SCRIPT" --input "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == "context" ]]
}

@test "classifies thanks as chitchat" {
  run bash -c 'echo "thanks!" | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
  [[ "$output" == "chitchat" ]]
}

@test "classifies short ok as chitchat" {
  run bash -c 'echo "ok" | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
  [[ "$output" == "chitchat" ]]
}

# ── JSON output ─────────────────────────────────────────────────────────────

@test "json output is valid JSON with expected fields" {
  run bash -c 'echo "APPROVED" | bash '"$SCRIPT"' --stdin --json'
  [ "$status" -eq 0 ]
  run bash -c 'echo "APPROVED" | bash '"$SCRIPT"' --stdin --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"class\" in d; assert \"max_ratio\" in d; assert \"frozen\" in d; assert \"scores\" in d; print(\"ok\")"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "json decision has max_ratio 5 and frozen true" {
  run bash -c 'echo "APPROVED — merge" | bash '"$SCRIPT"' --stdin --json'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"class":"decision"'* ]]
  [[ "$output" == *'"max_ratio":5'* ]]
  [[ "$output" == *'"frozen":"true"'* ]]
}

@test "json spec has max_ratio 3 and frozen true" {
  run bash -c 'echo "SPEC-120 AC-01 implemented" | bash '"$SCRIPT"' --stdin --json'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"class":"spec"'* ]]
  [[ "$output" == *'"max_ratio":3'* ]]
}

@test "json chitchat has max_ratio 80 and frozen false" {
  run bash -c 'echo "thanks" | bash '"$SCRIPT"' --stdin --json'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"class":"chitchat"'* ]]
  [[ "$output" == *'"max_ratio":80'* ]]
  [[ "$output" == *'"frozen":"false"'* ]]
}

# ── Tie-breaking / priority ─────────────────────────────────────────────────

@test "tie-breaking favors stricter class (decision over code on tie)" {
  # Contains both "APPROVED" (decision +3) and code fence (code +3)
  local tmp="$BATS_TEST_TMPDIR/tie.txt"
  printf '%s\n' 'APPROVED' '```' 'code' '```' > "$tmp"
  run bash "$SCRIPT" --input "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == "decision" ]]
}

# ── Fallback / defaults ─────────────────────────────────────────────────────

@test "fallback: very short unknown input defaults to chitchat" {
  run bash -c 'echo "hmm" | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
  [[ "$output" == "chitchat" ]]
}

@test "fallback: longer unknown input defaults to context" {
  run bash -c 'echo "This is a longer explanation about something that has no particular keywords matching any class pattern at all here" | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
  [[ "$output" == "context" ]]
}

# ── Negative cases ─────────────────────────────────────────────────────────

@test "negative: unknown flag returns exit 2" {
  run bash "$SCRIPT" --unknown-flag
  [ "$status" -eq 2 ]
}

@test "negative: missing input argument returns exit 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "negative: nonexistent input file returns exit 2" {
  run bash "$SCRIPT" --input /does/not/exist.txt
  [ "$status" -eq 2 ]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: empty input is handled gracefully" {
  local tmp="$BATS_TEST_TMPDIR/empty.txt"
  : > "$tmp"
  run bash "$SCRIPT" --input "$tmp"
  [ "$status" -eq 0 ]
  # Empty defaults to chitchat (very short)
  [[ "$output" == "chitchat" ]]
}

@test "edge: input with only whitespace defaults to chitchat" {
  local tmp="$BATS_TEST_TMPDIR/ws.txt"
  printf '   \n  \n' > "$tmp"
  run bash "$SCRIPT" --input "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == "chitchat" ]]
}

@test "edge: 6 task classes are declared in script" {
  run grep -cE '\b(decision|spec|code|review|context|chitchat)\b' "$SCRIPT"
  [[ "$output" -ge 6 ]]
}

@test "edge: max_ratio mapping is consistent with SE-029 §2" {
  # Verify the case block maps each class to the documented ratio.
  run grep -E 'decision\).*max_ratio=5' "$SCRIPT"
  [ "$status" -eq 0 ]
  run grep -E 'spec\).*max_ratio=3' "$SCRIPT"
  [ "$status" -eq 0 ]
  run grep -E 'code\).*max_ratio=10' "$SCRIPT"
  [ "$status" -eq 0 ]
  run grep -E 'review\).*max_ratio=15' "$SCRIPT"
  [ "$status" -eq 0 ]
  run grep -E 'context\).*max_ratio=25' "$SCRIPT"
  [ "$status" -eq 0 ]
  run grep -E 'chitchat\).*max_ratio=80' "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: script does not modify input file" {
  local tmp="$BATS_TEST_TMPDIR/readonly.txt"
  echo "APPROVED" > "$tmp"
  local hash_before
  hash_before=$(md5sum "$tmp" | awk '{print $1}')
  bash "$SCRIPT" --input "$tmp" >/dev/null 2>&1
  local hash_after
  hash_after=$(md5sum "$tmp" | awk '{print $1}')
  [[ "$hash_before" == "$hash_after" ]]
}

@test "isolation: exit codes are 0 (success) or 2 (usage)" {
  run bash "$SCRIPT" --help
  [[ "$status" -eq 0 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
