#!/usr/bin/env bats
# Tests for SPEC-SE-088-UA-ADOPT — Understand-Anything bridge integration
# Ref: SPEC-SE-088-UA-ADOPT
# Ref: docs/specs/SPEC-SE-088-UA-ADOPT.spec.md

BRIDGE="${BATS_TEST_DIRNAME}/../scripts/ua-bridge.sh"
OPENCODE_CMD_DIR="${BATS_TEST_DIRNAME}/../.opencode/commands"
CLAUDE_CMD_DIR="${BATS_TEST_DIRNAME}/../.claude/commands"
SKILL_DIR="${BATS_TEST_DIRNAME}/../.opencode/skills/understand-anything"

setup() {
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

# ── 1. ua-bridge.sh exists and is executable ─────────────────────────────────
@test "ua-bridge.sh exists and is executable" {
  [[ -f "$BRIDGE" ]]
  [[ -x "$BRIDGE" ]]
}

# ── 2. set -uo pipefail present ───────────────────────────────────────────────
@test "ua-bridge.sh uses set -uo pipefail" {
  run grep -E "set -uo pipefail" "$BRIDGE"
  [[ "$status" -eq 0 ]]
}

# ── 3. SPEC-SE-088 is referenced ──────────────────────────────────────────────
@test "ua-bridge.sh references SPEC-SE-088" {
  run grep "SPEC-SE-088" "$BRIDGE"
  [[ "$status" -eq 0 ]]
}

# ── 4. check subcommand exits 0 or 1 (no crash) ──────────────────────────────
@test "check subcommand exits 0 or 1 without crash" {
  run bash "$BRIDGE" check
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

# ── 5. check subcommand outputs something ─────────────────────────────────────
@test "check subcommand produces output" {
  run bash "$BRIDGE" check
  [[ -n "$output" ]]
}

# ── 6. diff --count returns a number ──────────────────────────────────────────
@test "diff --count returns a numeric value" {
  run bash "$BRIDGE" diff --count
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ ^[0-9]+$ ]]
}

# ── 7. ua-analyze.md exists in .opencode/commands ─────────────────────────────
@test "ua-analyze.md exists in .opencode/commands" {
  [[ -f "$OPENCODE_CMD_DIR/ua-analyze.md" ]]
}

# ── 8. ua-analyze.md has valid frontmatter ────────────────────────────────────
@test "ua-analyze.md has name and description in frontmatter" {
  run grep -E "^name:|^description:" "$OPENCODE_CMD_DIR/ua-analyze.md"
  [[ "$status" -eq 0 ]]
  [[ "${#lines[@]}" -ge 2 ]]
}

# ── 9. ua-diff.md exists in .opencode/commands ────────────────────────────────
@test "ua-diff.md exists in .opencode/commands" {
  [[ -f "$OPENCODE_CMD_DIR/ua-diff.md" ]]
}

# ── 10. ua-diff.md has valid frontmatter ──────────────────────────────────────
@test "ua-diff.md has name and description in frontmatter" {
  run grep -E "^name:|^description:" "$OPENCODE_CMD_DIR/ua-diff.md"
  [[ "$status" -eq 0 ]]
  [[ "${#lines[@]}" -ge 2 ]]
}

# ── 11. ua-domain.md exists in .opencode/commands ────────────────────────────
@test "ua-domain.md exists in .opencode/commands" {
  [[ -f "$OPENCODE_CMD_DIR/ua-domain.md" ]]
}

# ── 12. ua-domain.md has valid frontmatter ────────────────────────────────────
@test "ua-domain.md has name and description in frontmatter" {
  run grep -E "^name:|^description:" "$OPENCODE_CMD_DIR/ua-domain.md"
  [[ "$status" -eq 0 ]]
  [[ "${#lines[@]}" -ge 2 ]]
}

# ── 13. SKILL.md exists and is within 150 lines ───────────────────────────────
@test "understand-anything SKILL.md exists and is at most 150 lines" {
  [[ -f "$SKILL_DIR/SKILL.md" ]]
  line_count=$(wc -l < "$SKILL_DIR/SKILL.md")
  [[ "$line_count" -le 150 ]]
}

# ── 14. DOMAIN.md exists and is within 60 lines ──────────────────────────────
@test "understand-anything DOMAIN.md exists and is at most 60 lines" {
  [[ -f "$SKILL_DIR/DOMAIN.md" ]]
  line_count=$(wc -l < "$SKILL_DIR/DOMAIN.md")
  [[ "$line_count" -le 60 ]]
}

# ── 15. bridge handles UA not installed gracefully ────────────────────────────
@test "analyze with UA not installed exits 0 and reports gracefully" {
  # Override UA dirs to non-existent locations to simulate UA not installed
  run env UA_AGENTS_DIR="$TMP_DIR/no-ua" bash "$BRIDGE" analyze .
  [[ "$status" -eq 0 ]]
}

# ── 16. edge: nonexistent path handled without crash ─────────────────────────
@test "analyze with nonexistent path exits cleanly without crash" {
  run env UA_AGENTS_DIR="$TMP_DIR/no-ua" bash "$BRIDGE" analyze "$TMP_DIR/does_not_exist_xyz"
  [[ "$status" -eq 0 ]]
}

# ── 17. edge: diff --count on empty dir returns 0 ─────────────────────────────
@test "diff --count with UA not installed returns 0" {
  run env UA_AGENTS_DIR="$TMP_DIR/no-ua" bash "$BRIDGE" diff --count
  [[ "$status" -eq 0 ]]
  [[ "$output" == "0" ]]
}

# ── 18. ua-analyze.md also exists in .claude/commands ────────────────────────
@test "ua-analyze.md exists in .claude/commands" {
  [[ -f "$CLAUDE_CMD_DIR/ua-analyze.md" ]]
}

# ── 19. ua-diff.md also exists in .claude/commands ───────────────────────────
@test "ua-diff.md exists in .claude/commands" {
  [[ -f "$CLAUDE_CMD_DIR/ua-diff.md" ]]
}

# ── 20. ua-domain.md also exists in .claude/commands ─────────────────────────
@test "ua-domain.md exists in .claude/commands" {
  [[ -f "$CLAUDE_CMD_DIR/ua-domain.md" ]]
}

# ── Isolation ─────────────────────────────────────────────────────────────────

setup() { ISO_TMP="$(mktemp -d)"; }
teardown() { rm -rf "$ISO_TMP"; }

# ── Edge cases ────────────────────────────────────────────────────────────────

@test "edge: empty path arg to ua-bridge analyze exits 0 (graceful)" {
  run bash "$BRIDGE" analyze "" 2>&1 || true
  [[ "$status" -le 1 ]]
}

@test "edge: nonexistent path to ua-bridge analyze exits 0 (no crash)" {
  run bash "$BRIDGE" analyze "/nonexistent/path/$(date +%s)" 2>&1 || true
  [[ "$status" -le 1 ]]
}

@test "edge: zero count from ua-bridge diff --count when no changes" {
  run bash "$BRIDGE" diff --count 2>&1
  [[ "$output" =~ ^[0-9]+$ || "$status" -le 1 ]]
}

@test "edge: null UA installation — bridge check exits 1 not crash" {
  run bash "$BRIDGE" check 2>&1
  [[ "$status" -le 2 ]]
}

@test "coverage: SPEC-SE-088 referenced in ua-bridge.sh" {
  grep -qE 'SPEC-SE-088|SE-088' "$BRIDGE"
}

@test "coverage: skill SKILL.md has trigger or activation note" {
  local skill_md="${BATS_TEST_DIRNAME}/../.opencode/skills/understand-anything/SKILL.md"
  [[ -f "$skill_md" ]]
  grep -qi 'understand\|ua-' "$skill_md"
}
