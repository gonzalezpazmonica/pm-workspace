#!/usr/bin/env bats
# BATS tests for scripts/claude-md-drift-check.sh (SE-043 Slice 1).
# Ref: SE-043, SPEC-109 action 7
SCRIPT="scripts/claude-md-drift-check.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}
teardown() { cd /; }

@test "exists + executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "passes bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "references SPEC-109" { run grep -c 'SPEC-109' "$SCRIPT"; [[ "$output" -ge 1 ]]; }

@test "runs against real workspace" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
}

@test "reports counts (PASS path)" {
  run bash "$SCRIPT"
  # Either PASS or DRIFT output — both mention counts
  [[ "$output" == *"agents="* || "$output" == *"agents:"* ]]
}

@test "references CLAUDE.md" {
  run grep -c 'CLAUDE.md' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "detects drift when CLAUDE.md count wrong (synthetic)" {
  # Create synthetic CLAUDE.md under TMPDIR with wrong count
  local root="$BATS_TEST_TMPDIR/fake-ws"
  mkdir -p "$root/.claude/agents" "$root/.claude/commands" "$root/.claude/skills" "$root/.claude/hooks" "$root/.opencode/agents" "$root/.opencode/commands" "$root/.opencode/hooks"
  for i in 1 2 3; do touch "$root/.opencode/agents/agent$i.md"; done
  for i in 1 2; do touch "$root/.opencode/commands/cmd$i.md"; done
  for i in 1; do mkdir -p "$root/.opencode/skills/skill$i"; touch "$root/.opencode/skills/skill$i/SKILL.md"; done
  for i in 1 2; do touch "$root/.opencode/hooks/hook$i.sh"; done
  echo '{"hooks":{}}' > "$root/.claude/settings.json"
  echo 'agents(999)' > "$root/CLAUDE.md"
  # Copy script to fake root (script expects to be in $ROOT/scripts)
  mkdir -p "$root/scripts"
  cp "$SCRIPT" "$root/scripts/"
  run bash "$root/scripts/claude-md-drift-check.sh"
  [ "$status" -eq 2 ]
}

@test "passes when counts match (synthetic)" {
  local root="$BATS_TEST_TMPDIR/fake-ws2"
  mkdir -p "$root/.claude/agents" "$root/.claude/commands" "$root/.claude/skills" "$root/.claude/hooks" "$root/.opencode/agents" "$root/.opencode/commands" "$root/.opencode/hooks" "$root/scripts"
  touch "$root/.opencode/agents/a1.md" "$root/.opencode/agents/a2.md"
  touch "$root/.opencode/commands/c1.md"
  mkdir -p "$root/.opencode/skills/s1"; touch "$root/.opencode/skills/s1/SKILL.md"
  touch "$root/.opencode/hooks/h1.sh"
  echo '{"hooks":{}}' > "$root/.claude/settings.json"
  cat > "$root/CLAUDE.md" <<MD
.claude/{agents(2), commands(1), hooks(1/0reg), skills(1)}
| Catálogo 2 agentes | path |
MD
  cp "$SCRIPT" "$root/scripts/"
  run bash "$root/scripts/claude-md-drift-check.sh"
  [ "$status" -eq 0 ]
}

@test "missing CLAUDE.md exits 2" {
  local root="$BATS_TEST_TMPDIR/no-claude-md"
  mkdir -p "$root/scripts"
  cp "$SCRIPT" "$root/scripts/"
  run bash "$root/scripts/claude-md-drift-check.sh"
  [ "$status" -eq 2 ]
}

@test "isolation: does not modify CLAUDE.md" {
  local h_before
  h_before=$(md5sum CLAUDE.md | awk '{print $1}')
  bash "$SCRIPT" >/dev/null 2>&1 || true
  local h_after
  h_after=$(md5sum CLAUDE.md | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "isolation: does not modify .claude/" {
  local h_before
  h_before=$(find .claude/agents .claude/commands .claude/hooks -maxdepth 1 -name "*.md" -o -name "*.sh" 2>/dev/null | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" >/dev/null 2>&1 || true
  local h_after
  h_after=$(find .claude/agents .claude/commands .claude/hooks -maxdepth 1 -name "*.md" -o -name "*.sh" 2>/dev/null | sort | md5sum | awk '{print $1}')
  [[ "$h_before" == "$h_after" ]]
}

@test "exit codes 0 or 2 (never random)" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
}

@test "references readiness integration" {
  # SPEC-109 item 7: called from readiness-check
  run grep -c 'claude-md-drift' scripts/readiness-check.sh
  [[ "$output" -ge 1 ]]
}

# ── Edge cases ─────────────────────────────────────────────────────

@test "edge: empty CLAUDE.md exits 2 (drift detected)" {
  local root="$BATS_TEST_TMPDIR/empty-claude"
  mkdir -p "$root/.claude/agents" "$root/.opencode/agents" "$root/scripts"
  : > "$root/CLAUDE.md"  # empty file
  echo '{"hooks":{}}' > "$root/.claude/settings.json"
  cp "$SCRIPT" "$root/scripts/"
  run bash "$root/scripts/claude-md-drift-check.sh"
  [ "$status" -eq 2 ]
}

@test "edge: zero agents (empty .opencode/agents/) counted correctly" {
  local root="$BATS_TEST_TMPDIR/zero-agents"
  mkdir -p "$root/.claude/agents" "$root/.claude/commands" "$root/.claude/skills" "$root/.claude/hooks" "$root/.opencode/agents" "$root/.opencode/commands" "$root/.opencode/hooks" "$root/scripts"
  # No agents at all
  echo '{"hooks":{}}' > "$root/.claude/settings.json"
  cat > "$root/CLAUDE.md" <<MD
.claude/{agents(0), commands(0), hooks(0/0reg), skills(0)}
| Catálogo 0 agentes | path |
MD
  cp "$SCRIPT" "$root/scripts/"
  run bash "$root/scripts/claude-md-drift-check.sh"
  [ "$status" -eq 0 ]
}

@test "edge: nonexistent .claude/ dirs counted as zero" {
  local root="$BATS_TEST_TMPDIR/no-claude-dir"
  mkdir -p "$root/scripts"
  # No .claude/ at all
  echo '{"hooks":{}}' > /dev/null  # noop
  cat > "$root/CLAUDE.md" <<MD
.claude/{agents(0), commands(0), hooks(0/0reg), skills(0)}
| Catálogo 0 agentes | path |
MD
  cp "$SCRIPT" "$root/scripts/"
  run bash "$root/scripts/claude-md-drift-check.sh"
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
}

@test "edge: large count (100+ agents) handled" {
  local root="$BATS_TEST_TMPDIR/large-agents"
  mkdir -p "$root/.claude/agents" "$root/.claude/commands" "$root/.claude/skills" "$root/.claude/hooks" "$root/.opencode/agents" "$root/.opencode/commands" "$root/.opencode/hooks" "$root/scripts"
  for i in $(seq 1 100); do touch "$root/.opencode/agents/a$i.md"; done
  echo '{"hooks":{}}' > "$root/.claude/settings.json"
  cat > "$root/CLAUDE.md" <<MD
.claude/{agents(100), commands(0), hooks(0/0reg), skills(0)}
| Catálogo 100 agentes | path |
MD
  cp "$SCRIPT" "$root/scripts/"
  run bash "$root/scripts/claude-md-drift-check.sh"
  [ "$status" -eq 0 ]
}

@test "edge: boundary off-by-one (n vs n+1)" {
  local root="$BATS_TEST_TMPDIR/off-by-one"
  mkdir -p "$root/.claude/agents" "$root/.claude/commands" "$root/.claude/skills" "$root/.claude/hooks" "$root/.opencode/agents" "$root/.opencode/commands" "$root/.opencode/hooks" "$root/scripts"
  touch "$root/.opencode/agents/a1.md" "$root/.opencode/agents/a2.md" "$root/.opencode/agents/a3.md"
  echo '{"hooks":{}}' > "$root/.claude/settings.json"
  # CLAUDE.md says 2 but real is 3 → drift
  cat > "$root/CLAUDE.md" <<MD
.claude/{agents(2), commands(0), hooks(0/0reg), skills(0)}
| Catálogo 2 agentes | path |
MD
  cp "$SCRIPT" "$root/scripts/"
  run bash "$root/scripts/claude-md-drift-check.sh"
  [ "$status" -eq 2 ]
}

# ── Negative cases ─────────────────────────────────────────────────

@test "negative: invalid settings.json degrades gracefully" {
  local root="$BATS_TEST_TMPDIR/bad-settings"
  mkdir -p "$root/.claude/agents" "$root/.claude/commands" "$root/.claude/skills" "$root/.claude/hooks" "$root/.opencode/agents" "$root/.opencode/commands" "$root/.opencode/hooks" "$root/scripts"
  touch "$root/.opencode/agents/a1.md"
  echo 'invalid json }' > "$root/.claude/settings.json"
  cat > "$root/CLAUDE.md" <<MD
.claude/{agents(1), commands(0), hooks(0/0reg), skills(0)}
| Catálogo 1 agentes | path |
MD
  cp "$SCRIPT" "$root/scripts/"
  run bash "$root/scripts/claude-md-drift-check.sh"
  # Script should not crash — either exit 0 or 2, not random
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
}

@test "negative: error output reports drift fields when FAIL" {
  local root="$BATS_TEST_TMPDIR/drift-fail"
  mkdir -p "$root/.claude/agents" "$root/.opencode/agents" "$root/scripts"
  touch "$root/.opencode/agents/a1.md" "$root/.opencode/agents/a2.md"
  echo '{"hooks":{}}' > "$root/.claude/settings.json"
  echo 'agents(999)' > "$root/CLAUDE.md"
  cp "$SCRIPT" "$root/scripts/"
  run bash "$root/scripts/claude-md-drift-check.sh"
  [ "$status" -eq 2 ]
  [[ "$output" == *"DRIFT"* || "$output" == *"drift"* ]]
}

# ── Coverage breadth ───────────────────────────────────────────────

@test "coverage: REAL_AGENTS count variable present" {
  run grep -c 'REAL_AGENTS' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "coverage: REAL_COMMANDS count variable present" {
  run grep -c 'REAL_COMMANDS' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "coverage: REAL_SKILLS count variable present" {
  run grep -c 'REAL_SKILLS' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "coverage: REAL_HOOKS count variable present" {
  run grep -c 'REAL_HOOKS' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "coverage: DRIFT flag present" {
  run grep -c 'DRIFT' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
