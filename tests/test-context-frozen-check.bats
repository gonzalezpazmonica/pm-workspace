#!/usr/bin/env bats
# Tests for SE-029-F — frozen core checker
# Ref: docs/propuestas/SE-029-rate-distortion-context.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/context-frozen-check.sh"
  TMPDIR_FZ="$(mktemp -d)"
  export TMPDIR_FZ
}

teardown() {
  rm -rf "$TMPDIR_FZ" 2>/dev/null || true
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

# ── Positive: frozen detection ───────────────────────────────────────────────

@test "positive: decision-log.md path → FROZEN with exit 1" {
  run bash "$SCRIPT" --path "decision-log.md"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qE "FROZEN.*decision-log"
}

@test "positive: nested path to decision-log → FROZEN" {
  run bash "$SCRIPT" --path "projects/alpha/decision-log.md"
  [ "$status" -eq 1 ]
}

@test "positive: class=decision → FROZEN" {
  run bash "$SCRIPT" --class "decision"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qE "task-class-decision"
}

@test "positive: class=spec → FROZEN" {
  run bash "$SCRIPT" --class "spec"
  [ "$status" -eq 1 ]
}

@test "positive: class=handoff → FROZEN" {
  run bash "$SCRIPT" --class "handoff"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qE "agent-handoff"
}

@test "positive: class=stacktrace → FROZEN" {
  run bash "$SCRIPT" --class "stacktrace"
  [ "$status" -eq 1 ]
}

@test "positive: acceptance-criteria.md path → FROZEN" {
  run bash "$SCRIPT" --path "docs/sprint/acceptance-criteria.md"
  [ "$status" -eq 1 ]
}

# ── Positive: approved spec detection ────────────────────────────────────────

@test "positive: APPROVED spec → FROZEN" {
  mkdir -p "$TMPDIR_FZ/docs/propuestas"
  cat > "$TMPDIR_FZ/docs/propuestas/SPEC-999-test.md" <<'F'
---
id: SPEC-999
status: APPROVED
---
content
F
  run env REPO_ROOT="$TMPDIR_FZ" bash "$SCRIPT" --path "docs/propuestas/SPEC-999-test.md"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qE "approved-spec"
}

@test "positive: DONE spec → FROZEN" {
  mkdir -p "$TMPDIR_FZ/docs/propuestas"
  cat > "$TMPDIR_FZ/docs/propuestas/SPEC-998-done.md" <<'F'
---
status: DONE
---
content
F
  run env REPO_ROOT="$TMPDIR_FZ" bash "$SCRIPT" --path "docs/propuestas/SPEC-998-done.md"
  [ "$status" -eq 1 ]
}

# ── Negative: NOT frozen cases ───────────────────────────────────────────────

@test "negative: random.md path → NOT frozen (exit 0)" {
  run bash "$SCRIPT" --path "random-file.md"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "NOT FROZEN"
}

@test "negative: PROPOSED spec → NOT frozen" {
  mkdir -p "$TMPDIR_FZ/docs/propuestas"
  cat > "$TMPDIR_FZ/docs/propuestas/SPEC-997-proposed.md" <<'F'
---
status: PROPOSED
---
content
F
  run env REPO_ROOT="$TMPDIR_FZ" bash "$SCRIPT" --path "docs/propuestas/SPEC-997-proposed.md"
  [ "$status" -eq 0 ]
}

@test "negative: class=chitchat → NOT frozen" {
  run bash "$SCRIPT" --class "chitchat"
  [ "$status" -eq 0 ]
}

@test "negative: class=context → NOT frozen" {
  run bash "$SCRIPT" --class "context"
  [ "$status" -eq 0 ]
}

@test "negative: unknown flag rejected with exit 2" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: --help returns exit 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "edge: --json output has all 4 required fields" {
  run bash "$SCRIPT" --path "decision-log.md" --json
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for k in ['frozen','reason','path','class']:
    assert k in d
assert d['frozen'] is True
"
}

@test "edge: empty arguments default to NOT frozen" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "edge: nonexistent spec path → NOT frozen (file check skipped)" {
  run bash "$SCRIPT" --path "docs/propuestas/SPEC-99999-does-not-exist.md"
  [ "$status" -eq 0 ]
}

@test "edge: empty string --class accepted as null" {
  run bash "$SCRIPT" --path "random.md" --class ""
  [ "$status" -eq 0 ]
}

@test "edge: path AND class both evaluated (priority: path first)" {
  run bash "$SCRIPT" --path "decision-log.md" --class "chitchat" --json
  [ "$status" -eq 1 ]
  echo "$output" | grep -qE "decision-log"
}

# ── Isolation ────────────────────────────────────────────────────────────────

@test "isolation: does not modify any files" {
  mkdir -p "$TMPDIR_FZ/docs/propuestas"
  cat > "$TMPDIR_FZ/docs/propuestas/SPEC-996.md" <<'F'
status: APPROVED
F
  h=$(sha256sum "$TMPDIR_FZ/docs/propuestas/SPEC-996.md" | awk '{print $1}')
  cd "$TMPDIR_FZ" && bash "$SCRIPT" --path "docs/propuestas/SPEC-996.md" >/dev/null 2>&1
  h2=$(sha256sum "$TMPDIR_FZ/docs/propuestas/SPEC-996.md" | awk '{print $1}')
  [ "$h" = "$h2" ]
}

@test "isolation: exit codes are 0, 1, or 2" {
  run bash "$SCRIPT" --path "test.md"
  [[ "$status" == "0" || "$status" == "1" || "$status" == "2" ]]
}
