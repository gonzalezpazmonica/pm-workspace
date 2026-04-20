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
  mkdir -p "$root/.claude/agents" "$root/.claude/commands" "$root/.claude/skills" "$root/.claude/hooks"
  for i in 1 2 3; do touch "$root/.claude/agents/agent$i.md"; done
  for i in 1 2; do touch "$root/.claude/commands/cmd$i.md"; done
  for i in 1; do mkdir -p "$root/.claude/skills/skill$i"; touch "$root/.claude/skills/skill$i/SKILL.md"; done
  for i in 1 2; do touch "$root/.claude/hooks/hook$i.sh"; done
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
  mkdir -p "$root/.claude/agents" "$root/.claude/commands" "$root/.claude/skills" "$root/.claude/hooks" "$root/scripts"
  touch "$root/.claude/agents/a1.md" "$root/.claude/agents/a2.md"
  touch "$root/.claude/commands/c1.md"
  mkdir -p "$root/.claude/skills/s1"; touch "$root/.claude/skills/s1/SKILL.md"
  touch "$root/.claude/hooks/h1.sh"
  echo '{"hooks":{}}' > "$root/.claude/settings.json"
  cat > "$root/CLAUDE.md" <<MD
.claude/{agents(2), commands(1), hooks(1/0reg), skills(1)}
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
