#!/usr/bin/env bats
# Tests for advisor-config.sh — Anthropic Advisor Strategy config generator
# Ref: SPEC-ADVISOR-STRATEGY

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/advisor-config.sh"
  TMPDIR_AC="$(mktemp -d)"

  # Create mock agents directory with test fixtures
  MOCK_AGENTS="$TMPDIR_AC/agents"
  mkdir -p "$MOCK_AGENTS"

  # Agent with advisor configured (sonnet executor + opus advisor)
  cat > "$MOCK_AGENTS/sonnet-with-advisor.md" <<'AGENT'
---
name: sonnet-with-advisor
model: claude-sonnet-4-6
advisor: opus
advisor_max_uses: 5
tools:
  - Read
  - Write
---
A test agent with advisor configured.
AGENT

  # Agent without advisor field
  cat > "$MOCK_AGENTS/no-advisor.md" <<'AGENT'
---
name: no-advisor
model: claude-sonnet-4-6
tools:
  - Read
---
A test agent without advisor.
AGENT

  # Agent already on opus (ADV-04)
  cat > "$MOCK_AGENTS/opus-agent.md" <<'AGENT'
---
name: opus-agent
model: claude-opus-4-6
advisor: opus
tools:
  - Read
---
An opus agent that should not get an advisor.
AGENT

  # Agent with short model name
  cat > "$MOCK_AGENTS/haiku-agent.md" <<'AGENT'
---
name: haiku-agent
model: haiku
advisor: sonnet
advisor_max_uses: 2
tools:
  - Read
---
A haiku agent advised by sonnet.
AGENT

  # Clear env vars to avoid test pollution
  unset ADVISOR_ENABLED 2>/dev/null || true
  unset ADVISOR_MODEL 2>/dev/null || true
  unset ADVISOR_MAX_USES 2>/dev/null || true
  unset ADVISOR_EXECUTOR_DEFAULT 2>/dev/null || true
}

teardown() {
  rm -rf "$TMPDIR_AC"
  unset ADVISOR_ENABLED 2>/dev/null || true
  unset ADVISOR_MODEL 2>/dev/null || true
  unset ADVISOR_MAX_USES 2>/dev/null || true
  unset ADVISOR_EXECUTOR_DEFAULT 2>/dev/null || true
}

# ── Script integrity ─────────────────────────────────────────────────────────

@test "script has safety flags set" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "script starts with proper shebang" {
  head -1 "$SCRIPT" | grep -q '#!/usr/bin/env bash'
}

# ── Default JSON output (no args) ───────────────────────────────────────────

@test "default output is valid JSON with correct fields" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"type"'* ]]
  [[ "$output" == *'"advisor_20260301"'* ]]
  [[ "$output" == *'"name"'* ]]
  [[ "$output" == *'"advisor"'* ]]
  [[ "$output" == *'"model"'* ]]
  [[ "$output" == *'"max_uses"'* ]]
}

@test "default advisor model is claude-opus-4-6" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *'claude-opus-4-6'* ]]
}

@test "default max_uses is 3" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"max_uses":3'* ]] || [[ "$output" == *'"max_uses": 3'* ]]
}

# ── Custom executor/advisor/max-uses ─────────────────────────────────────────

@test "custom advisor model via --advisor" {
  run bash "$SCRIPT" --advisor claude-sonnet-4-6
  [ "$status" -eq 0 ]
  [[ "$output" == *'claude-sonnet-4-6'* ]]
}

@test "custom max-uses via --max-uses" {
  run bash "$SCRIPT" --max-uses 7
  [ "$status" -eq 0 ]
  [[ "$output" == *'7'* ]]
}

@test "short model name resolved via --advisor" {
  run bash "$SCRIPT" --advisor sonnet
  [ "$status" -eq 0 ]
  [[ "$output" == *'claude-sonnet-4-6'* ]]
}

# ── YAML output format ───────────────────────────────────────────────────────

@test "YAML output contains expected fields" {
  run bash "$SCRIPT" --output yaml
  [ "$status" -eq 0 ]
  [[ "$output" == *'type: advisor_20260301'* ]]
  [[ "$output" == *'name: advisor'* ]]
  [[ "$output" == *'model: claude-opus-4-6'* ]]
  [[ "$output" == *'max_uses: 3'* ]]
}

@test "YAML output with custom values" {
  run bash "$SCRIPT" --output yaml --advisor sonnet --max-uses 10
  [ "$status" -eq 0 ]
  [[ "$output" == *'model: claude-sonnet-4-6'* ]]
  [[ "$output" == *'max_uses: 10'* ]]
}

# ── Advisor disabled ─────────────────────────────────────────────────────────

@test "exits 1 when ADVISOR_ENABLED=false" {
  export ADVISOR_ENABLED=false
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *'ADVISOR_DISABLED'* ]]
}

@test "exits 1 when --enabled false" {
  run bash "$SCRIPT" --enabled false
  [ "$status" -eq 1 ]
  [[ "$output" == *'ADVISOR_DISABLED'* ]]
}

# ── Agent lookup mode — advisor in frontmatter ───────────────────────────────

@test "agent with advisor generates config" {
  run bash "$SCRIPT" --agent sonnet-with-advisor --agents-dir "$MOCK_AGENTS"
  [ "$status" -eq 0 ]
  [[ "$output" == *'claude-opus-4-6'* ]]
}

@test "agent frontmatter advisor_max_uses overrides default" {
  run bash "$SCRIPT" --agent sonnet-with-advisor --agents-dir "$MOCK_AGENTS"
  [ "$status" -eq 0 ]
  [[ "$output" == *'5'* ]]
}

@test "agent with haiku model and sonnet advisor" {
  run bash "$SCRIPT" --agent haiku-agent --agents-dir "$MOCK_AGENTS"
  [ "$status" -eq 0 ]
  [[ "$output" == *'claude-sonnet-4-6'* ]]
  [[ "$output" == *'2'* ]]
}

# ── Agent lookup mode — no advisor ───────────────────────────────────────────

@test "agent without advisor exits 1" {
  run bash "$SCRIPT" --agent no-advisor --agents-dir "$MOCK_AGENTS"
  [ "$status" -eq 1 ]
  [[ "$output" == *'NO_ADVISOR'* ]]
}

# ── ADV-04: Agent already on opus ────────────────────────────────────────────

@test "opus agent exits 1 with ADV-04 message" {
  run bash "$SCRIPT" --agent opus-agent --agents-dir "$MOCK_AGENTS"
  [ "$status" -eq 1 ]
  [[ "$output" == *'ADV-04'* ]]
}

@test "CLI executor opus exits 1 with ADV-04" {
  run bash "$SCRIPT" --executor opus
  [ "$status" -eq 1 ]
  [[ "$output" == *'ADV-04'* ]]
}

@test "CLI executor claude-opus-4-6 exits 1 with ADV-04" {
  run bash "$SCRIPT" --executor claude-opus-4-6
  [ "$status" -eq 1 ]
  [[ "$output" == *'ADV-04'* ]]
}

# ── Invalid max-uses ─────────────────────────────────────────────────────────

@test "max-uses 0 exits 2" {
  run bash "$SCRIPT" --max-uses 0
  [ "$status" -eq 2 ]
  [[ "$output" == *'ERROR'* ]]
}

@test "negative max-uses exits 2" {
  run bash "$SCRIPT" --max-uses -5
  [ "$status" -eq 2 ]
  [[ "$output" == *'ERROR'* ]]
}

@test "non-numeric max-uses exits 2" {
  run bash "$SCRIPT" --max-uses abc
  [ "$status" -eq 2 ]
  [[ "$output" == *'ERROR'* ]]
}

# ── Missing agent file ───────────────────────────────────────────────────────

@test "missing agent file exits 2" {
  run bash "$SCRIPT" --agent nonexistent --agents-dir "$MOCK_AGENTS"
  [ "$status" -eq 2 ]
  [[ "$output" == *'ERROR'* ]]
  [[ "$output" == *'not found'* ]]
}

# ── Invalid output format ────────────────────────────────────────────────────

@test "invalid output format exits 2" {
  run bash "$SCRIPT" --output xml
  [ "$status" -eq 2 ]
  [[ "$output" == *'ERROR'* ]]
}

# ── Unknown option ───────────────────────────────────────────────────────────

@test "unknown option exits 2" {
  run bash "$SCRIPT" --foobar
  [ "$status" -eq 2 ]
  [[ "$output" == *'ERROR'* ]]
}

# ── Environment variable overrides ───────────────────────────────────────────

@test "ADVISOR_MODEL env var overrides default" {
  export ADVISOR_MODEL=claude-sonnet-4-6
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *'claude-sonnet-4-6'* ]]
}

@test "ADVISOR_MAX_USES env var overrides default" {
  export ADVISOR_MAX_USES=9
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *'9'* ]]
}

@test "CLI args override env vars" {
  export ADVISOR_MODEL=claude-sonnet-4-6
  export ADVISOR_MAX_USES=9
  run bash "$SCRIPT" --advisor opus --max-uses 2
  [ "$status" -eq 0 ]
  [[ "$output" == *'claude-opus-4-6'* ]]
  [[ "$output" == *'2'* ]]
}

@test "ADVISOR_EXECUTOR_DEFAULT env var is respected" {
  export ADVISOR_EXECUTOR_DEFAULT=claude-haiku-4-5-20251001
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  # Should succeed since haiku is not opus
}

# ── JSON validity (if jq available) ──────────────────────────────────────────

@test "JSON output is valid (jq parse)" {
  if ! command -v jq &>/dev/null; then
    skip "jq not available"
  fi
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | jq . > /dev/null 2>&1
}

@test "JSON has exactly 4 fields" {
  if ! command -v jq &>/dev/null; then
    skip "jq not available"
  fi
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | jq 'keys | length')
  [ "$count" -eq 4 ]
}

@test "agent lookup JSON is valid (jq parse)" {
  if ! command -v jq &>/dev/null; then
    skip "jq not available"
  fi
  run bash "$SCRIPT" --agent sonnet-with-advisor --agents-dir "$MOCK_AGENTS"
  [ "$status" -eq 0 ]
  echo "$output" | jq . > /dev/null 2>&1
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: empty agent file handled gracefully" {
  printf '' > "$MOCK_AGENTS/empty-agent.md"
  run bash "$SCRIPT" --agent empty-agent --agents-dir "$MOCK_AGENTS"
  [ "$status" -eq 1 ]
}

@test "edge: no-arg invocation uses defaults (boundary)" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ -n "$output" ]]
}

@test "edge: boundary max-uses = 1 (minimum valid)" {
  run bash "$SCRIPT" --max-uses 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"1"* ]]
}

@test "edge: nonexistent agents-dir returns error" {
  run bash "$SCRIPT" --agent any-agent --agents-dir "/nonexistent/path/xyz"
  [ "$status" -eq 2 ]
}

@test "edge: very large max-uses value (overflow boundary)" {
  run bash "$SCRIPT" --max-uses 999999
  [ "$status" -eq 0 ]
}
