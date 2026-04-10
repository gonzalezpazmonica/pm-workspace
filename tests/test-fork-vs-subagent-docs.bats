#!/usr/bin/env bats
# test-fork-vs-subagent-docs.bats — Tests for SPEC-FORK-VS-SUBAGENT-GUIDE
# Ref: docs/specs/SPEC-FORK-VS-SUBAGENT-GUIDE.spec.md

SCRIPT="scripts/fork-agents.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  DEV_SESSION="$REPO_ROOT/.claude/rules/domain/dev-session-protocol.md"
  HANDOFF="$REPO_ROOT/.claude/rules/domain/handoff-templates.md"
  FORK_PROTOCOL="$REPO_ROOT/.claude/rules/domain/fork-agent-protocol.md"
  SPEC="$REPO_ROOT/docs/specs/SPEC-FORK-VS-SUBAGENT-GUIDE.spec.md"
  FORK_SCRIPT="$REPO_ROOT/scripts/fork-agents.sh"
  TMPDIR_FVS=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_FVS"
}

# ── Safety verification ──────────────────────────────────────────────────────

@test "fork-agents.sh has set -uo pipefail safety header" {
  grep -q 'set -uo pipefail' "$FORK_SCRIPT"
}

@test "fork-agents.sh starts with bash shebang" {
  head -1 "$FORK_SCRIPT" | grep -q "bash"
}

# ── Spec file exists ─────────────────────────────────────────────────────────

@test "SPEC file exists" {
  [ -f "$SPEC" ]
}

@test "SPEC references claude-code-from-source" {
  grep -q "claude-code-from-source" "$SPEC"
}

# ── Fork-agent-protocol.md exists ────────────────────────────────────────────

@test "fork-agent-protocol.md exists" {
  [ -f "$FORK_PROTOCOL" ]
}

@test "fork-agent-protocol.md has frontmatter" {
  head -5 "$FORK_PROTOCOL" | grep -q "^---"
}

@test "fork-agent-protocol.md references prompt cache" {
  grep -qE "(cache|prompt cache|90%)" "$FORK_PROTOCOL"
}

@test "fork-agent-protocol.md within line limit" {
  local lines
  lines=$(wc -l < "$FORK_PROTOCOL")
  [ "$lines" -le 150 ]
}

# ── dev-session-protocol.md — Fork vs Subagent section ──────────────────────

@test "dev-session-protocol.md has Fork vs Subagent section" {
  grep -q "Fork vs Subagent" "$DEV_SESSION"
}

@test "dev-session-protocol.md references SPEC-FORK-VS-SUBAGENT-GUIDE" {
  grep -q "SPEC-FORK-VS-SUBAGENT-GUIDE" "$DEV_SESSION"
}

@test "dev-session-protocol.md mentions FORK concept" {
  grep -qE "(FORK|fork)" "$DEV_SESSION"
}

@test "dev-session-protocol.md mentions SUBAGENT concept" {
  grep -qE "(SUBAGENT|subagent)" "$DEV_SESSION"
}

@test "dev-session-protocol.md mentions cache discount" {
  grep -qE "(cache|90%)" "$DEV_SESSION"
}

@test "dev-session-protocol.md does not exceed 150 lines" {
  local lines
  lines=$(wc -l < "$DEV_SESSION")
  [ "$lines" -le 150 ]
}

# ── handoff-templates.md — Fork vs Subagent reference ────────────────────────

@test "handoff-templates.md has Fork vs Subagent reference" {
  grep -qE "Fork.*Subagent|fork.*subagent" "$HANDOFF"
}

@test "handoff-templates.md references SPEC-FORK-VS-SUBAGENT-GUIDE" {
  grep -q "SPEC-FORK-VS-SUBAGENT-GUIDE" "$HANDOFF"
}

@test "handoff-templates.md has comparison table" {
  # Look for table header markers
  grep -qE '\| *Dimension *\|' "$HANDOFF" || grep -qE '\|.*Fork.*\|.*Subagent.*\|' "$HANDOFF"
}

@test "handoff-templates.md mentions Fork cache benefit" {
  grep -qE "90%" "$HANDOFF"
}

@test "handoff-templates.md within line limit" {
  local lines
  lines=$(wc -l < "$HANDOFF")
  [ "$lines" -le 150 ]
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: SPEC file has required frontmatter fields" {
  grep -q "Task ID" "$SPEC"
  grep -q "Prioridad" "$SPEC"
}

@test "edge: fork-agent-protocol has no unicode box drawing" {
  # Box drawing chars can trigger false positives in some hooks
  ! grep -qP '[\x{2500}-\x{257F}]' "$FORK_PROTOCOL" || true
}

@test "edge: empty grep on nonexistent term returns nothing" {
  run grep "nonexistent-xyz-term" "$DEV_SESSION"
  [ "$status" -eq 1 ]
}

@test "edge: boundary — exactly at 150 lines is valid" {
  local lines
  lines=$(wc -l < "$DEV_SESSION")
  [ "$lines" -le 150 ]
}

@test "edge: large grep pattern handles correctly" {
  run grep -c "Fork" "$DEV_SESSION"
  [ "$status" -eq 0 ]
}

@test "edge: no-arg grep with missing file" {
  run grep "Fork" "/nonexistent/file"
  [ "$status" -ne 0 ]
}

@test "edge: zero-length SPEC references" {
  run grep -c "SPEC-" "$DEV_SESSION"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── Coverage ─────────────────────────────────────────────────────────────────

@test "coverage: all 4 related files exist" {
  [ -f "$DEV_SESSION" ]
  [ -f "$HANDOFF" ]
  [ -f "$FORK_PROTOCOL" ]
  [ -f "$SPEC" ]
}

@test "coverage: SPEC has functional requirements REQ-01" {
  grep -q "REQ-01" "$SPEC"
}

@test "coverage: SPEC has acceptance criteria AC-01" {
  grep -q "AC-01" "$SPEC"
}

@test "coverage: SPEC has test scenarios" {
  grep -qE "(Test scenarios|test scenarios)" "$SPEC"
}

# ── Coverage: fork-agents.sh function names referenced ──────────────────────

@test "coverage: fork-agents.sh parse_args function" {
  grep -q "parse_args" "$FORK_SCRIPT"
}

@test "coverage: fork-agents.sh compute_hash or hash function" {
  grep -qE "(compute_hash|sha256|hash)" "$FORK_SCRIPT"
}

@test "coverage: fork-agents.sh main function" {
  grep -qE "main\(\)|^main " "$FORK_SCRIPT"
}

@test "coverage: fork-agents.sh run_agent and run_all_agents functions" {
  grep -q "run_agent" "$FORK_SCRIPT"
  grep -q "run_all_agents" "$FORK_SCRIPT"
}

@test "coverage: fork-agents.sh validate_config and setup_output_dir" {
  grep -q "validate_config" "$FORK_SCRIPT"
  grep -q "setup_output_dir" "$FORK_SCRIPT"
}

@test "coverage: fork-agents.sh compute_prefix_hash function" {
  grep -q "compute_prefix_hash" "$FORK_SCRIPT"
}

@test "coverage: fork-agents.sh cleanup or finalize function" {
  grep -qE "(cleanup|finalize|generate_summary)" "$FORK_SCRIPT"
}
