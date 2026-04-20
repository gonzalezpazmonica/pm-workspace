#!/usr/bin/env bats
# BATS tests for scripts/gitagent-export.sh (SPEC-099 gitagent export adapter).
#
# Ref: SPEC-099, ROADMAP §Tier 4.8
# Safety: script under test `set -uo pipefail`, read-only on `.claude/agents/`.

SCRIPT="scripts/gitagent-export.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() { cd /; }

@test "script exists and executable" { [[ -x "$SCRIPT" ]]; }

@test "uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }

@test "references SPEC-099" {
  run grep -c 'SPEC-099' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"agent"* ]]
  [[ "$output" == *"output-dir"* ]]
}

@test "rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "requires --agent" {
  run bash "$SCRIPT" --output-dir "$BATS_TEST_TMPDIR/o"
  [ "$status" -eq 2 ]
}

@test "requires --output-dir" {
  run bash "$SCRIPT" --agent architect
  [ "$status" -eq 2 ]
}

@test "rejects nonexistent agent" {
  run bash "$SCRIPT" --agent nonexistent-agent-xyz --output-dir "$BATS_TEST_TMPDIR/o"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "rejects unsupported format" {
  run bash "$SCRIPT" --agent architect --output-dir "$BATS_TEST_TMPDIR/o" --format openai-0.5
  [ "$status" -eq 2 ]
}

# ── Export generation ─────────────────────────────────────────────────────

@test "generates 5 expected files" {
  local out="$BATS_TEST_TMPDIR/export"
  run bash "$SCRIPT" --agent architect --output-dir "$out"
  [ "$status" -eq 0 ]
  [[ -f "$out/architect/agent.yaml" ]]
  [[ -f "$out/architect/SOUL.md" ]]
  [[ -f "$out/architect/RULES.md" ]]
  [[ -f "$out/architect/DUTIES.md" ]]
  [[ -f "$out/architect/README.md" ]]
}

@test "agent.yaml contains name and description" {
  local out="$BATS_TEST_TMPDIR/export"
  bash "$SCRIPT" --agent architect --output-dir "$out" >/dev/null 2>&1
  run grep -c 'name: "architect"' "$out/architect/agent.yaml"
  [[ "$output" -ge 1 ]]
  run grep -c 'description' "$out/architect/agent.yaml"
  [[ "$output" -ge 1 ]]
}

@test "agent.yaml references pm-workspace origin" {
  local out="$BATS_TEST_TMPDIR/export"
  bash "$SCRIPT" --agent architect --output-dir "$out" >/dev/null 2>&1
  run grep -c 'pm-workspace' "$out/architect/agent.yaml"
  [[ "$output" -ge 1 ]]
}

@test "agent.yaml tools list is properly formatted" {
  local out="$BATS_TEST_TMPDIR/export"
  bash "$SCRIPT" --agent architect --output-dir "$out" >/dev/null 2>&1
  # Should NOT have '- -' (double dash = broken YAML list).
  run grep -c '^\s*- -' "$out/architect/agent.yaml"
  [[ "$output" -eq 0 ]]
}

@test "agent.yaml parses as valid YAML-like structure (no syntax errors)" {
  local out="$BATS_TEST_TMPDIR/export"
  bash "$SCRIPT" --agent architect --output-dir "$out" >/dev/null 2>&1
  # Must have expected section headers.
  run grep -cE '^(name|description|source|tools|limits|activation):' "$out/architect/agent.yaml"
  [[ "$output" -ge 5 ]]
}

# ── Permission level → DUTIES ─────────────────────────────────────────────

@test "DUTIES.md references permission_level" {
  local out="$BATS_TEST_TMPDIR/export"
  bash "$SCRIPT" --agent architect --output-dir "$out" >/dev/null 2>&1
  run grep -cE 'Permission level.*L[0-4]' "$out/architect/DUTIES.md"
  [[ "$output" -ge 1 ]]
}

@test "DUTIES.md has Must NEVER and Must ALWAYS sections" {
  local out="$BATS_TEST_TMPDIR/export"
  bash "$SCRIPT" --agent architect --output-dir "$out" >/dev/null 2>&1
  run grep -c 'Must NEVER' "$out/architect/DUTIES.md"
  [[ "$output" -ge 1 ]]
  run grep -c 'Must ALWAYS' "$out/architect/DUTIES.md"
  [[ "$output" -ge 1 ]]
}

# ── Framework hints ───────────────────────────────────────────────────────

@test "README mentions multiple frameworks" {
  local out="$BATS_TEST_TMPDIR/export"
  bash "$SCRIPT" --agent architect --output-dir "$out" >/dev/null 2>&1
  run grep -cE 'Claude Code|OpenAI|Cursor|Lyzr' "$out/architect/README.md"
  [[ "$output" -ge 2 ]]
}

@test "agent.yaml activation hints include multiple frameworks" {
  local out="$BATS_TEST_TMPDIR/export"
  bash "$SCRIPT" --agent architect --output-dir "$out" >/dev/null 2>&1
  run grep -cE 'claude-code|openai|cursor' "$out/architect/agent.yaml"
  [[ "$output" -ge 2 ]]
}

# ── Multi-agent export ────────────────────────────────────────────────────

@test "can export multiple agents independently" {
  local out="$BATS_TEST_TMPDIR/export"
  bash "$SCRIPT" --agent architect --output-dir "$out" >/dev/null 2>&1
  bash "$SCRIPT" --agent code-reviewer --output-dir "$out" >/dev/null 2>&1
  [[ -d "$out/architect" ]]
  [[ -d "$out/code-reviewer" ]]
}

# ── Isolation ────────────────────────────────────────────────────────────

@test "isolation: does not modify source agent file" {
  local src=".claude/agents/architect.md"
  local h_before
  h_before=$(md5sum "$src" | awk '{print $1}')
  bash "$SCRIPT" --agent architect --output-dir "$BATS_TEST_TMPDIR/out" >/dev/null 2>&1
  local h_after
  h_after=$(md5sum "$src" | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: only writes inside output-dir/<agent>" {
  local out="$BATS_TEST_TMPDIR/export"
  echo "untouched" > "$BATS_TEST_TMPDIR/sibling.txt"
  bash "$SCRIPT" --agent architect --output-dir "$out" >/dev/null 2>&1
  run cat "$BATS_TEST_TMPDIR/sibling.txt"
  [[ "$output" == "untouched" ]]
}

@test "isolation: exit codes are 0/1/2" {
  local out="$BATS_TEST_TMPDIR/export"
  run bash "$SCRIPT" --agent architect --output-dir "$out"
  [[ "$status" -eq 0 ]]
  run bash "$SCRIPT" --agent no-such-agent-abc --output-dir "$out"
  [[ "$status" -eq 1 ]]
  run bash "$SCRIPT" --bogus
  [[ "$status" -eq 2 ]]
}
