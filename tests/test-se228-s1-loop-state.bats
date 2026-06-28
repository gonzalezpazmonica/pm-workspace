#!/usr/bin/env bats
# Tests for SE-228 Slice 1 — STATE.md canónico cross-skill
# SCRIPT=scripts/loop-state-init.sh scripts/loop-state-prune.sh
# SPEC: SE-228 Slice 1 (docs/propuestas/SE-228-loop-engineering-patterns.md)
# AC: AC-01 AC-02 AC-03 AC-04 AC-05

INIT_SCRIPT="scripts/loop-state-init.sh"
PRUNE_SCRIPT="scripts/loop-state-prune.sh"
SCHEMA_DOC="docs/rules/domain/loop-state-schema.md"

setup() {
  export TEST_SKILL="test-skill-se228-$$"
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export STATE_DIR="output/loop-state/${TEST_SKILL}"
  export STATE_FILE="${STATE_DIR}/STATE.md"
  # ensure clean state
  rm -rf "$STATE_DIR"
}

teardown() {
  rm -rf "$STATE_DIR"
}

# ── AC-01 · Schema document ───────────────────────────────────────────────────

@test "loop-state-schema.md exists in docs/rules/domain/" {
  [[ -f "$SCHEMA_DOC" ]]
}

@test "loop-state-schema.md contains all required section headers" {
  grep -q "## High Priority" "$SCHEMA_DOC"
  grep -q "## Watch List" "$SCHEMA_DOC"
  grep -q "## Recently Resolved" "$SCHEMA_DOC"
  grep -q "## Noise / Ignored" "$SCHEMA_DOC"
}

# ── Script existence and safety ───────────────────────────────────────────────

@test "loop-state-init.sh exists and is executable" {
  [[ -x "$INIT_SCRIPT" ]]
}

@test "loop-state-prune.sh exists and is executable" {
  [[ -x "$PRUNE_SCRIPT" ]]
}

@test "loop-state-init.sh uses set -uo pipefail" {
  head -10 "$INIT_SCRIPT" | grep -q "set -uo pipefail"
}

@test "loop-state-prune.sh uses set -uo pipefail" {
  head -10 "$PRUNE_SCRIPT" | grep -q "set -uo pipefail"
}

# ── AC-02 · loop-state-init.sh usage and args ─────────────────────────────────

@test "loop-state-init.sh exits 1 without --skill" {
  run bash "$INIT_SCRIPT"
  [[ "$status" -eq 1 ]]
}

@test "loop-state-init.sh --help exits 0" {
  run bash "$INIT_SCRIPT" --help
  [[ "$status" -eq 0 ]]
}

@test "loop-state-init.sh creates STATE.md with all required sections" {
  run bash "$INIT_SCRIPT" --skill "$TEST_SKILL"
  [[ "$status" -eq 0 ]]
  [[ -f "$STATE_FILE" ]]
  grep -q "# Loop State — ${TEST_SKILL}" "$STATE_FILE"
  grep -q "^Last run:" "$STATE_FILE"
  grep -q "## High Priority" "$STATE_FILE"
  grep -q "## Watch List" "$STATE_FILE"
  grep -q "## Recently Resolved" "$STATE_FILE"
  grep -q "## Noise / Ignored" "$STATE_FILE"
}

@test "loop-state-init.sh is idempotent — second call exits 0 without overwriting" {
  bash "$INIT_SCRIPT" --skill "$TEST_SKILL"
  # capture first content
  first_content="$(cat "$STATE_FILE")"
  sleep 1
  run bash "$INIT_SCRIPT" --skill "$TEST_SKILL"
  [[ "$status" -eq 0 ]]
  second_content="$(cat "$STATE_FILE")"
  # content unchanged
  [[ "$first_content" == "$second_content" ]]
}

@test "loop-state-init.sh --force overwrites existing STATE.md" {
  bash "$INIT_SCRIPT" --skill "$TEST_SKILL"
  # modify file
  echo "# extra line" >> "$STATE_FILE"
  run bash "$INIT_SCRIPT" --skill "$TEST_SKILL" --force
  [[ "$status" -eq 0 ]]
  # extra line should be gone
  run grep "# extra line" "$STATE_FILE"
  [[ "$status" -ne 0 ]]
}

@test "loop-state-init.sh --dry-run does not create STATE.md" {
  run bash "$INIT_SCRIPT" --skill "$TEST_SKILL" --dry-run
  [[ "$status" -eq 0 ]]
  [[ ! -f "$STATE_FILE" ]]
}

@test "loop-state-init.sh --dry-run output mentions skill name" {
  run bash "$INIT_SCRIPT" --skill "$TEST_SKILL" --dry-run
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "$TEST_SKILL"
}

# ── AC-03 · loop-state-prune.sh usage and args ────────────────────────────────

@test "loop-state-prune.sh exits 1 without --skill" {
  run bash "$PRUNE_SCRIPT"
  [[ "$status" -eq 1 ]]
}

@test "loop-state-prune.sh exits 1 when STATE.md does not exist" {
  run bash "$PRUNE_SCRIPT" --skill "nonexistent-skill-$$"
  [[ "$status" -eq 1 ]]
}

@test "loop-state-prune.sh --dry-run does not modify STATE.md" {
  bash "$INIT_SCRIPT" --skill "$TEST_SKILL"
  original="$(cat "$STATE_FILE")"
  run bash "$PRUNE_SCRIPT" --skill "$TEST_SKILL" --dry-run
  [[ "$status" -eq 0 ]]
  after="$(cat "$STATE_FILE")"
  [[ "$original" == "$after" ]]
}

@test "loop-state-prune.sh with empty STATE.md does not fail" {
  bash "$INIT_SCRIPT" --skill "$TEST_SKILL"
  run bash "$PRUNE_SCRIPT" --skill "$TEST_SKILL"
  [[ "$status" -eq 0 ]]
}

@test "loop-state-prune.sh --max-resolved accepts a number" {
  bash "$INIT_SCRIPT" --skill "$TEST_SKILL"
  run bash "$PRUNE_SCRIPT" --skill "$TEST_SKILL" --max-resolved 5
  [[ "$status" -eq 0 ]]
}

# ── AC-04 · overnight-sprint skill references schema ─────────────────────────

@test "overnight-sprint SKILL.md references loop-state-schema" {
  skill_file=".opencode/skills/overnight-sprint/SKILL.md"
  grep -q "loop-state-schema" "$skill_file"
}

@test "overnight-sprint SKILL.md references loop-state-init.sh" {
  skill_file=".opencode/skills/overnight-sprint/SKILL.md"
  grep -q "loop-state-init.sh" "$skill_file"
}

# ── Edge cases ─────────────────────────────────────────────────────────────────

@test "loop-state-init.sh with unknown argument exits 1" {
  run bash "$INIT_SCRIPT" --skill "$TEST_SKILL" --unknown-flag
  [[ "$status" -eq 1 ]]
}

@test "loop-state-prune.sh with unknown argument exits 1" {
  run bash "$PRUNE_SCRIPT" --skill "$TEST_SKILL" --unknown-flag
  [[ "$status" -eq 1 ]]
}

@test "loop-state-init.sh --dry-run with --force still does not write" {
  run bash "$INIT_SCRIPT" --skill "$TEST_SKILL" --dry-run --force
  [[ "$status" -eq 0 ]]
  [[ ! -f "$STATE_FILE" ]]
}

@test "loop-state-prune.sh --help exits 0" {
  run bash "$PRUNE_SCRIPT" --help
  [[ "$status" -eq 0 ]]
}

@test "loop-state-init.sh output on success contains OK" {
  run bash "$INIT_SCRIPT" --skill "$TEST_SKILL"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ OK ]]
}

@test "loop-state-prune.sh --max-resolved 0 exits 0" {
  bash "$INIT_SCRIPT" --skill "$TEST_SKILL"
  run bash "$PRUNE_SCRIPT" --skill "$TEST_SKILL" --max-resolved 0
  [[ "$status" -eq 0 ]]
}

@test "loop-state-init.sh creates nested output/loop-state/<skill>/ directory" {
  run bash "$INIT_SCRIPT" --skill "$TEST_SKILL"
  [[ "$status" -eq 0 ]]
  [[ -d "$STATE_DIR" ]]
}

@test "loop-state-schema.md references loop-state-init.sh script" {
  grep -q "loop-state-init.sh" "$SCHEMA_DOC"
}

@test "loop-state-schema.md references loop-state-prune.sh script" {
  grep -q "loop-state-prune.sh" "$SCHEMA_DOC"
}
