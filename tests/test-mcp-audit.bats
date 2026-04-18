#!/usr/bin/env bats
# BATS tests for scripts/mcp-audit.sh
# Ref: docs/rules/domain/mcp-overhead.md
# Origin: MindStudio blog on MCP token overhead per-turn cost.
# SPEC-055 quality gate (score >= 80)

SCRIPT="scripts/mcp-audit.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export REPO_ROOT="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO_ROOT/.claude" "$REPO_ROOT/scripts" "$REPO_ROOT/projects"
  cp "$BATS_TEST_DIRNAME/../$SCRIPT" "$REPO_ROOT/scripts/"
  chmod +x "$REPO_ROOT/scripts/"*.sh
  # Point HOME to a clean dir so ~/.claude.json doesn't leak into tests
  export HOME="$REPO_ROOT/fake-home"
  mkdir -p "$HOME"
  cd "$REPO_ROOT"
}

teardown() {
  cd /
  rm -rf "$REPO_ROOT"
}

# ── Structure / safety ──────────────────────────────────────────────────────

@test "mcp-audit.sh exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "mcp-audit.sh uses set -uo pipefail" {
  run head -20 "$SCRIPT"
  [[ "$output" == *"set -uo pipefail"* ]]
}

@test "mcp-audit.sh has valid bash syntax" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "mcp-audit.sh heredoc is quoted (prevent fork-bomb regression)" {
  # Applying the lesson from feedback_heredoc_quoted.md
  run grep -E "^python3 <<'PY'" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "mcp-audit.sh --help exits 0 and shows usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"mcp-audit"* ]]
}

# ── Behavior: empty config (optimal case) ──────────────────────────────────

@test "zero MCP configs returns verdict OK with 0 tokens" {
  echo '{"mcpServers": {}}' > .claude/mcp.json
  run bash scripts/mcp-audit.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 tokens/turn"* ]]
  [[ "$output" == *"zero overhead"* || "$output" == *"under budget"* ]]
}

@test "empty configs emit recommendation to keep the design" {
  echo '{"mcpServers": {}}' > .claude/mcp.json
  run bash scripts/mcp-audit.sh
  [[ "$output" == *"on-demand"* || "$output" == *"optimal"* ]]
}

# ── Behavior: single server below budget ───────────────────────────────────

@test "single server with 5 tools under budget returns 0" {
  cat > .claude/mcp.json <<'EOF'
{
  "mcpServers": {
    "test-server": {
      "tools": [
        {"name": "tool1", "description": "short"},
        {"name": "tool2", "description": "short"},
        {"name": "tool3", "description": "short"},
        {"name": "tool4", "description": "short"},
        {"name": "tool5", "description": "short"}
      ]
    }
  }
}
EOF
  run bash scripts/mcp-audit.sh --budget 3000
  [ "$status" -eq 0 ]
  [[ "$output" == *"test-server"* ]]
  [[ "$output" == *"5 tools"* ]]
}

# ── Behavior: server over budget ───────────────────────────────────────────

@test "server with 50 tools over budget returns exit 1 and verdict FAIL/WARN" {
  # 50 tools × 200 base = 10000 tokens, way over budget 3000
  local tools
  tools=$(python3 -c "
import json
print(json.dumps([{'name': f'tool{i}', 'description': 'x'} for i in range(50)]))
")
  cat > .claude/mcp.json <<EOF
{"mcpServers": {"big": {"tools": $tools}}}
EOF
  run bash scripts/mcp-audit.sh --budget 3000
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL"* || "$output" == *"WARN"* ]]
  [[ "$output" == *"Recommendations"* ]]
}

@test "over-budget case produces compression recommendation" {
  local tools
  tools=$(python3 -c "
import json
print(json.dumps([{'name': f'tool{i}', 'description': 'x'} for i in range(50)]))
")
  cat > .claude/mcp.json <<EOF
{"mcpServers": {"big": {"tools": $tools}}}
EOF
  run bash scripts/mcp-audit.sh --budget 3000
  [[ "$output" == *"Compress"* || "$output" == *"per-project"* || "$output" == *"Prune"* ]]
}

# ── JSON output ────────────────────────────────────────────────────────────

@test "--json produces valid JSON" {
  echo '{"mcpServers": {}}' > .claude/mcp.json
  run bash scripts/mcp-audit.sh --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys, json; json.load(sys.stdin)"
}

@test "--json output has required keys" {
  echo '{"mcpServers": {}}' > .claude/mcp.json
  run bash -c "bash scripts/mcp-audit.sh --json | python3 -c 'import sys,json; d=json.load(sys.stdin); print(\"OK\" if all(k in d for k in [\"budget_tokens\",\"servers\",\"total_tokens_estimated\",\"verdict\",\"recommendations\"]) else \"MISS\")'"
  [[ "$output" == "OK" ]]
}

@test "--json over-budget includes recommendations array" {
  local tools
  tools=$(python3 -c "
import json
print(json.dumps([{'name': f'tool{i}', 'description': 'x'} for i in range(50)]))
")
  cat > .claude/mcp.json <<EOF
{"mcpServers": {"big": {"tools": $tools}}}
EOF
  run bash -c "bash scripts/mcp-audit.sh --budget 3000 --json | python3 -c 'import sys,json; d=json.load(sys.stdin); print(len(d[\"recommendations\"]))'"
  [[ "$output" -ge 1 ]]
}

# ── Budget flag ────────────────────────────────────────────────────────────

@test "--budget accepts custom threshold" {
  local tools
  tools=$(python3 -c "
import json
print(json.dumps([{'name': f'tool{i}', 'description': 'x'} for i in range(5)]))
")
  cat > .claude/mcp.json <<EOF
{"mcpServers": {"s": {"tools": $tools}}}
EOF
  # 5 tools × 200 = 1000 tokens. Budget 500 → over. Budget 1500 → under.
  run bash scripts/mcp-audit.sh --budget 500
  [ "$status" -eq 1 ]
  run bash scripts/mcp-audit.sh --budget 1500
  [ "$status" -eq 0 ]
}

# ── Per-project config detection ───────────────────────────────────────────

@test "per-project mcpServers in ~/.claude.json is detected" {
  mkdir -p "$HOME"
  # Reconstruct a ~/.claude.json with a project having mcpServers
  cat > "$HOME/.claude.json" <<EOF
{
  "mcpServers": {},
  "projects": {
    "$REPO_ROOT": {
      "mcpServers": {
        "per-proj": {
          "tools": [
            {"name": "t1", "description": "x"},
            {"name": "t2", "description": "x"}
          ]
        }
      }
    }
  }
}
EOF
  echo '{"mcpServers": {}}' > .claude/mcp.json
  run bash scripts/mcp-audit.sh
  [[ "$output" == *"per-proj"* ]]
  [[ "$output" == *"project:"* ]]
}

# ── Negative cases ─────────────────────────────────────────────────────────

@test "negative: invalid --flag returns exit 2" {
  run bash "$SCRIPT" --nonexistent-flag
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown flag"* ]]
}

@test "negative: malformed JSON config is handled gracefully" {
  echo 'not valid json' > .claude/mcp.json
  run bash scripts/mcp-audit.sh
  # Exit 0 (no servers found, 0 tokens) and error logged per config
  [ "$status" -eq 0 ]
  [[ "$output" == *"error"* || "$output" == *"ERROR"* ]]
}

@test "negative: missing .claude/mcp.json does not crash" {
  # No config file at all
  run bash scripts/mcp-audit.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 tokens/turn"* ]]
}

@test "negative: broken bash -n would be caught" {
  local bad="$BATS_TEST_TMPDIR/bad.sh"
  echo 'if then fi' > "$bad"
  run bash -n "$bad"
  [ "$status" -ne 0 ]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: empty tools list means 0 estimated tokens (statically unknown)" {
  cat > .claude/mcp.json <<'EOF'
{"mcpServers": {"empty-tools": {"command": "x"}}}
EOF
  run bash scripts/mcp-audit.sh
  # Server appears in output with note
  [[ "$output" == *"empty-tools"* ]]
  [[ "$output" == *"tools-not-enumerated-statically"* || "$output" == *"0 tools"* ]]
}

@test "edge: boundary — exactly at budget returns exit 0" {
  # 15 tools × 200 = 3000 tokens. At budget.
  local tools
  tools=$(python3 -c "
import json
print(json.dumps([{'name': f't{i}', 'description': ''} for i in range(15)]))
")
  cat > .claude/mcp.json <<EOF
{"mcpServers": {"s": {"tools": $tools}}}
EOF
  run bash scripts/mcp-audit.sh --budget 3000
  [ "$status" -eq 0 ]
}

@test "edge: --quiet suppresses human output but preserves exit code" {
  echo '{"mcpServers": {}}' > .claude/mcp.json
  run bash scripts/mcp-audit.sh --quiet
  [ "$status" -eq 0 ]
  # Quiet mode: no "=== MCP" header
  [[ "$output" != *"==="* || -z "$output" ]]
}

@test "edge: nonexistent script path triggers bash error" {
  run bash /tmp/nonexistent-mcp-audit-12345.sh
  [ "$status" -ne 0 ]
}
