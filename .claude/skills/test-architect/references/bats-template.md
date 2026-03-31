# Golden BATS Template — Score 90+ on Auditor

Replace `{BRACES}`. Each section maps to an auditor criterion (C1-C9).

```bash
#!/usr/bin/env bats
# Tests for {TARGET_DESCRIPTION}
# Ref: {SPEC_OR_RULE_PATH}
# Strategy: Positive={MAIN_FEATURES}. Negative={ERROR_SCENARIOS}. Edge={BOUNDARIES}.

SCRIPT="{PATH_TO_TARGET}"

setup() { TMPDIR_TEST=$(mktemp -d); }
teardown() { rm -rf "$TMPDIR_TEST"; }

@test "{target} exists and is executable" {
  [ -f "$SCRIPT" ] && [ -x "$SCRIPT" ]
}
@test "{target} has safety flags (set -uo pipefail)" {
  head -10 "$SCRIPT" | grep -q "set -uo pipefail"
}

# ── Positive cases (5+ for 15pts) ────────────────────────────────
@test "{feature A} produces expected output" {
  run bash "$SCRIPT" {valid_args}
  [ "$status" -eq 0 ]
  [[ "$output" == *"{expected}"* ]]
}
@test "{feature B} handles standard input" {
  run bash "$SCRIPT" {args}
  [ "$status" -eq 0 ]
  grep -q "{pattern}" <<< "$output"
}
@test "{feature C} writes output file" {
  run bash "$SCRIPT" {args} "$TMPDIR_TEST/out.txt"
  [ "$status" -eq 0 ] && [ -f "$TMPDIR_TEST/out.txt" ]
}
@test "{feature D} produces valid JSON" {
  run bash "$SCRIPT" --json {args}
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}
@test "{feature E} returns correct count" {
  run bash "$SCRIPT" --count {args}
  [ "$status" -eq 0 ] && [ "$output" -gt 0 ]
}

# ── Negative cases (4+). Keywords: error, fail, missing, invalid ─
@test "fails with missing arguments" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
}
@test "fails with invalid input file" {
  run bash "$SCRIPT" "/nonexistent/path.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"error"* ]] || [[ "$output" == *"not found"* ]]
}
@test "rejects bad format gracefully" {
  echo "not-valid" > "$TMPDIR_TEST/bad.txt"
  run bash "$SCRIPT" "$TMPDIR_TEST/bad.txt"
  [ "$status" -ne 0 ]
}
@test "error on missing required config" {
  run bash "$SCRIPT" --config "/nonexistent/config"
  [ "$status" -ne 0 ]
}

# ── Edge cases (3+). Keywords: empty, boundary, zero, nonexistent ─
@test "handles empty input gracefully" {
  touch "$TMPDIR_TEST/empty.txt"
  run bash "$SCRIPT" "$TMPDIR_TEST/empty.txt"
  [[ "$status" -eq 0 ]] || [[ "$output" == *"empty"* ]]
}
@test "handles nonexistent directory" {
  run bash "$SCRIPT" "$TMPDIR_TEST/nonexistent-dir/"
  [ "$status" -ne 0 ]
}
@test "boundary: single-line input" {
  echo "one-line" > "$TMPDIR_TEST/single.txt"
  run bash "$SCRIPT" "$TMPDIR_TEST/single.txt"
  [ "$status" -eq 0 ]
}
@test "SPEC document exists" {
  [ -f "docs/propuestas/{SPEC_FILE}" ]
}
```

## Scoring: C1(10) C2(10) C3(15) C4(15) C5(10) C6(10) C7(7-10) C8(10) C9(10) = 90-100pts
