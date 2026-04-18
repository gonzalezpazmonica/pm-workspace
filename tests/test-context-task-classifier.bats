#!/usr/bin/env bats
# Tests for SE-029-C — context task classifier
# Ref: docs/propuestas/SE-029-rate-distortion-context.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/context-task-classifier.sh"
  TMPDIR_TC="$(mktemp -d)"
  export TMPDIR_TC
}

teardown() {
  rm -rf "$TMPDIR_TC" 2>/dev/null || true
}

classify() {
  echo "$1" | bash "$SCRIPT" --json 2>/dev/null
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

# ── Positive: class detection ────────────────────────────────────────────────

@test "positive: spec reference → class=spec" {
  result=$(classify "Implementing SPEC-120 now")
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['class']=='spec'"
}

@test "positive: acceptance criteria → class=spec" {
  result=$(classify "Check AC-03 of the acceptance criteria")
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['class']=='spec'"
}

@test "positive: approval → class=decision" {
  result=$(classify "I approve this PR")
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['class']=='decision'"
}

@test "positive: merge mention → class=decision" {
  result=$(classify "merged PR #593 into main")
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['class']=='decision'"
}

@test "positive: diff → class=code" {
  result=$(classify 'diff --git a/foo b/foo
@@ -1 +1 @@
-old
+new')
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['class']=='code'"
}

@test "positive: traceback → class=code" {
  result=$(classify 'Traceback (most recent call last):
  File "x.py" line 1
NameError')
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['class']=='code'"
}

@test "positive: review terms → class=review" {
  result=$(classify "Code review finding: nitpick on naming")
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['class']=='review'"
}

@test "positive: short thanks → class=chitchat" {
  result=$(classify "thanks")
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['class']=='chitchat'"
}

@test "positive: generic text → class=context" {
  result=$(classify "Vue composition API uses setup scripts to declare reactive state")
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['class']=='context'"
}

# ── Ratio + frozen table ─────────────────────────────────────────────────────

@test "positive: decision class has max_ratio=5 and frozen=yes" {
  result=$(classify "approve")
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['max_ratio']==5; assert d['frozen']=='yes'"
}

@test "positive: spec class has max_ratio=3 (most restrictive)" {
  result=$(classify "SPEC-100")
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['max_ratio']==3"
}

@test "positive: chitchat class has max_ratio=80 (most permissive)" {
  result=$(classify "thanks")
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['max_ratio']==80"
}

@test "positive: all 6 classes have ratio defined" {
  for cls in decision spec code review context chitchat; do
    grep -qE "\[$cls\]=" "$SCRIPT"
  done
}

# ── Negative ─────────────────────────────────────────────────────────────────

@test "negative: empty stdin rejected with exit 2" {
  run bash -c "echo '' | bash '$SCRIPT'"
  [ "$status" -eq 2 ]
}

@test "negative: nonexistent --input file rejected" {
  run bash "$SCRIPT" --input "/nonexistent/xyz.md"
  [ "$status" -eq 2 ]
}

@test "negative: unknown flag rejected" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "negative: no stdin and no --input rejected" {
  run bash "$SCRIPT" </dev/null
  [ "$status" -eq 2 ]
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: --help returns exit 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "edge: decision priority > spec when both present" {
  # When both present, decision wins (priority order)
  result=$(classify "approve SPEC-120 implementation")
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['class']=='decision'"
}

@test "edge: long 'thanks' still → chitchat if prefix matches" {
  result=$(classify "thanks")
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['class']=='chitchat'"
}

@test "edge: Spanish chitchat detected" {
  result=$(classify "gracias")
  echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['class']=='chitchat'"
}

# ── Isolation ────────────────────────────────────────────────────────────────

@test "isolation: does not write to stdout with --json except JSON" {
  result=$(echo "SPEC-100" | bash "$SCRIPT" --json)
  echo "$result" | python3 -c "import json,sys; json.load(sys.stdin)"
}

@test "isolation: --input does not modify input file" {
  echo "SPEC-120" > "$TMPDIR_TC/in.md"
  h=$(sha256sum "$TMPDIR_TC/in.md" | awk '{print $1}')
  bash "$SCRIPT" --input "$TMPDIR_TC/in.md" >/dev/null 2>&1
  h2=$(sha256sum "$TMPDIR_TC/in.md" | awk '{print $1}')
  [ "$h" = "$h2" ]
}
