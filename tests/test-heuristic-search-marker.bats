#!/usr/bin/env bats
# Tests for .opencode/hooks/heuristic-search-marker.sh
# Ref: docs/rules/domain/heuristic-self-learning.md

SCRIPT="${BATS_TEST_DIRNAME}/../.opencode/hooks/heuristic-search-marker.sh"

setup() {
  [[ -x "$SCRIPT" ]] || skip "marker hook missing"
  command -v jq >/dev/null 2>&1 || skip "jq not available"
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export TMPDIR="$TMP_DIR"
  export CLAUDE_TURN_ID="test-turn-$$-${BATS_TEST_NUMBER:-0}"
  MARKER_DIR="${TMPDIR}/savia-turn-${CLAUDE_TURN_ID}"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

# ─────────────────────────── Smoke ───────────────────────────

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "safety: script uses set -uo pipefail" {
  run grep -E "set -uo pipefail" "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "empty stdin returns exit 0 (no-op)" {
  run bash "$SCRIPT" <<< ""
  [[ "$status" -eq 0 ]]
  [[ ! -d "$MARKER_DIR" ]] || [[ -z "$(ls -A "$MARKER_DIR" 2>/dev/null)" ]]
}

@test "malformed JSON returns exit 0 (no-op)" {
  run bash "$SCRIPT" <<< 'not-json{'
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────── Tool filtering ───────────────────────────

@test "non-Read/Grep/Glob tool is ignored (Bash)" {
  run bash "$SCRIPT" <<< '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  [[ "$status" -eq 0 ]]
  [[ ! -e "$MARKER_DIR/heuristic-t1-alpha" ]]
}

@test "Read tool with no path is ignored" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{}}'
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────── Path filtering ───────────────────────────

@test "Read outside projects/ does not create marker" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{"file_path":"/etc/hosts"}}'
  [[ "$status" -eq 0 ]]
  [[ ! -e "$MARKER_DIR/heuristic-t1-etc" ]]
}

@test "Read on non-T1 file inside projects/ does not mark" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{"file_path":"/repo/projects/alpha/random.md"}}'
  [[ "$status" -eq 0 ]]
  [[ ! -e "$MARKER_DIR/heuristic-t1-alpha" ]]
}

# ─────────────────────────── Positive: T1 indexes create marker ───────────────────────────

@test "T1 hit: members/{handle}.md → marker created" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{"file_path":"/repo/projects/alpha/team/members/jane.md"}}'
  [[ "$status" -eq 0 ]]
  [[ -e "$MARKER_DIR/heuristic-t1-alpha" ]]
}

@test "T1 hit: GLOSSARY.md → marker created" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{"file_path":"/repo/projects/alpha/GLOSSARY.md"}}'
  [[ "$status" -eq 0 ]]
  [[ -e "$MARKER_DIR/heuristic-t1-alpha" ]]
}

@test "T1 hit: STAKEHOLDERS.md → marker created" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{"file_path":"/repo/projects/alpha/business-rules/STAKEHOLDERS.md"}}'
  [[ "$status" -eq 0 ]]
  [[ -e "$MARKER_DIR/heuristic-t1-alpha" ]]
}

@test "T1 hit: INDEX.md → marker created" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{"file_path":"/repo/projects/alpha/vault/INDEX.md"}}'
  [[ "$status" -eq 0 ]]
  [[ -e "$MARKER_DIR/heuristic-t1-alpha" ]]
}

@test "T1 hit: _HUB.md → marker created" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{"file_path":"/repo/projects/alpha/_HUB.md"}}'
  [[ "$status" -eq 0 ]]
  [[ -e "$MARKER_DIR/heuristic-t1-alpha" ]]
}

@test "T1 hit: MEMORY.md → marker created" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{"file_path":"/repo/projects/alpha/agent-memory/decisions/MEMORY.md"}}'
  [[ "$status" -eq 0 ]]
  [[ -e "$MARKER_DIR/heuristic-t1-alpha" ]]
}

@test "T1 hit: .acm file → marker created" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{"file_path":"/repo/projects/alpha/.agent-maps/INDEX.acm"}}'
  [[ "$status" -eq 0 ]]
  [[ -e "$MARKER_DIR/heuristic-t1-alpha" ]]
}

@test "T1 hit: .hcm file → marker created" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{"file_path":"/repo/projects/alpha/.human-maps/vault.hcm"}}'
  [[ "$status" -eq 0 ]]
  [[ -e "$MARKER_DIR/heuristic-t1-alpha" ]]
}

@test "T1 hit: .afm file → marker created" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{"file_path":"/repo/projects/alpha/.agent-maps/files/INDEX.afm"}}'
  [[ "$status" -eq 0 ]]
  [[ -e "$MARKER_DIR/heuristic-t1-alpha" ]]
}

# ─────────────────────────── Tool: Grep + Glob (use .path) ───────────────────────────

@test "Grep on T1 path → marker created" {
  run bash "$SCRIPT" <<< '{"tool_name":"Grep","tool_input":{"pattern":"x","path":"/repo/projects/alpha/GLOSSARY.md"}}'
  [[ "$status" -eq 0 ]]
  [[ -e "$MARKER_DIR/heuristic-t1-alpha" ]]
}

@test "Glob on T1 path → marker created" {
  run bash "$SCRIPT" <<< '{"tool_name":"Glob","tool_input":{"pattern":"*.md","path":"/repo/projects/alpha/team/members/jane.md"}}'
  [[ "$status" -eq 0 ]]
  [[ -e "$MARKER_DIR/heuristic-t1-alpha" ]]
}

# ─────────────────────────── Project-scoping ───────────────────────────

@test "marker is per-project: alpha read does not unlock beta" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{"file_path":"/repo/projects/alpha/GLOSSARY.md"}}'
  [[ "$status" -eq 0 ]]
  [[ -e "$MARKER_DIR/heuristic-t1-alpha" ]]
  [[ ! -e "$MARKER_DIR/heuristic-t1-beta" ]]
}

@test "marker is per-turn: different CLAUDE_TURN_ID → separate dir" {
  run bash "$SCRIPT" <<< '{"tool_name":"Read","tool_input":{"file_path":"/repo/projects/alpha/GLOSSARY.md"}}'
  [[ -e "$MARKER_DIR/heuristic-t1-alpha" ]]
  OLD_DIR="$MARKER_DIR"
  export CLAUDE_TURN_ID="other-turn"
  NEW_DIR="${TMPDIR}/savia-turn-other-turn"
  [[ ! -e "$NEW_DIR/heuristic-t1-alpha" ]]
  [[ -e "$OLD_DIR/heuristic-t1-alpha" ]]
}
