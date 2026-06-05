#!/usr/bin/env bats
# Test suite — SPEC-157: Context Pre-Flight Check.
#
# Validates:
#   - Existence and shape of estimator script and hook
#   - Prompt token estimation (chars / 4)
#   - @-import file reference detection and token counting
#   - Cache behavior (hit / miss / isolation)
#   - Agent without token_budget is handled gracefully
#   - Verdict thresholds: ok (<80%), warn (80-100%), exceeded (>100%)
#   - Suggestions populated on warn / exceeded
#   - Hook integration: non-Task tools are ignored
#   - Hook enforcement: block mode exits 2 only when policy=block + exceeded
#   - JSON output is valid and complete
#   - SAVIA_PREFLIGHT=off bypasses hook
#
# Reference: SPEC-157 — Context Pre-Flight Check.
# Depends on: SPEC-156 (token_budget frontmatter on agents).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  ESTIMATOR="$REPO_ROOT/scripts/context-preflight-check.sh"
  HOOK="$REPO_ROOT/.opencode/hooks/context-preflight-check.sh"

  # Isolated temp dirs for each test
  TMP="$(mktemp -d)"
  CACHE_DIR="$(mktemp -d)"
  export PREFLIGHT_CACHE_DIR="$CACHE_DIR"
  export PROJECT_DIR="$TMP"

  # ── Mock agent: normal warn policy, budget 400, ctx_target 0 ─────────────
  mkdir -p "$TMP/.opencode/agents"
  cat > "$TMP/.opencode/agents/warn-agent.md" <<'YAML'
---
name: warn-agent
token_budget:
  per_invocation: 400
  context_window_target: 0
  escalation_policy: warn
---
YAML

  # ── Mock agent: block policy, tiny budget 200, ctx_target 0 ──────────────
  cat > "$TMP/.opencode/agents/block-agent.md" <<'YAML'
---
name: block-agent
token_budget:
  per_invocation: 200
  context_window_target: 0
  escalation_policy: block
---
YAML

  # ── Mock agent: no token_budget ────────────────────────────────────────────
  cat > "$TMP/.opencode/agents/no-budget-agent.md" <<'YAML'
---
name: no-budget-agent
description: agent without budget declaration
---
YAML

  # ── Mock agent: with context_window_target ────────────────────────────────
  cat > "$TMP/.opencode/agents/ctx-agent.md" <<'YAML'
---
name: ctx-agent
token_budget:
  per_invocation: 1000
  context_window_target: 500
  escalation_policy: warn
---
YAML

  # ── Mock skill ────────────────────────────────────────────────────────────
  mkdir -p "$TMP/.opencode/skills/context-rot-strategy"
  printf '%200s' "" | tr ' ' 'x' > "$TMP/.opencode/skills/context-rot-strategy/SKILL.md"

  # ── Mock file for @-import tests ──────────────────────────────────────────
  mkdir -p "$TMP/docs"
  printf '%400s' "" | tr ' ' 'a' > "$TMP/docs/sample.md"

  # Helper: generate a prompt of exactly N chars
  _N_CHARS() { python3 -c "print('a' * $1, end='')" 2>/dev/null || printf '%0.s-' $(seq 1 "$1"); }
}

teardown() {
  rm -rf "$TMP" "$CACHE_DIR" 2>/dev/null || true
}

# ── A. Existence and shape ───────────────────────────────────────────────────

@test "A1 estimator script exists and is executable" {
  [ -f "$ESTIMATOR" ]
  [ -x "$ESTIMATOR" ]
}

@test "A2 hook exists and is executable" {
  [ -f "$HOOK" ]
  [ -x "$HOOK" ]
}

@test "A3 estimator outputs valid JSON for known agent" {
  result=$(echo "hello world" | bash "$ESTIMATOR" "warn-agent")
  echo "$result" | python3 -m json.tool > /dev/null
}

@test "A4 estimator JSON contains required fields" {
  result=$(echo "hello world" | bash "$ESTIMATOR" "warn-agent")
  echo "$result" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for f in ['agent','budget','projected','verdict','policy','breakdown','suggestions']:
    assert f in d, f'missing field: {f}'
"
}

@test "A5 hook is registered in PreToolUse settings for Task matcher" {
  grep -q "context-preflight-check.sh" "$REPO_ROOT/.claude/settings.json"
}

# ── B. Prompt token estimation ────────────────────────────────────────────────

@test "B1 prompt tokens = chars divided by 4" {
  # 400 chars → 100 tokens
  prompt=$(python3 -c "print('a' * 400, end='')")
  result=$(echo "$prompt" | bash "$ESTIMATOR" "warn-agent")
  prompt_toks=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['breakdown']['prompt'])")
  [ "$prompt_toks" -eq 100 ]
}

@test "B2 verdict ok when projected below 80% of budget" {
  # warn-agent budget=400, ctx_target=0 → 80%=320 tokens → need < 320 tokens = 1280 chars
  prompt=$(python3 -c "print('a' * 100, end='')")  # 100 chars → 25 tokens
  result=$(echo "$prompt" | bash "$ESTIMATOR" "warn-agent")
  verdict=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['verdict'])")
  [ "$verdict" = "ok" ]
}

@test "B3 verdict warn when projected between 80-100% of budget" {
  # warn-agent budget=400, 80%=320 → need 320-400 prompt_tokens = 1280-1600 chars
  prompt=$(python3 -c "print('a' * 1400, end='')")  # 1400 chars → 350 tokens
  result=$(echo "$prompt" | bash "$ESTIMATOR" "warn-agent")
  verdict=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['verdict'])")
  [ "$verdict" = "warn" ]
}

@test "B4 verdict exceeded when projected above 100% of budget" {
  # warn-agent budget=400 → need > 400 tokens = > 1600 chars
  prompt=$(python3 -c "print('a' * 2000, end='')")  # 2000 chars → 500 tokens
  result=$(echo "$prompt" | bash "$ESTIMATOR" "warn-agent")
  verdict=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['verdict'])")
  [ "$verdict" = "exceeded" ]
}

# ── C. @-import file reference tokens ────────────────────────────────────────

@test "C1 @-import path resolves and contributes tokens" {
  # docs/sample.md is 400 bytes → 100 tokens
  result=$(echo "See @docs/sample.md for details" | bash "$ESTIMATOR" "warn-agent")
  file_toks=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['breakdown']['files'])")
  [ "$file_toks" -eq 100 ]
}

@test "C2 @-import to nonexistent file is silently ignored" {
  result=$(echo "See @docs/nonexistent-file.md for details" | bash "$ESTIMATOR" "warn-agent")
  file_toks=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['breakdown']['files'])")
  [ "$file_toks" -eq 0 ]
}

@test "C3 @-import path appears in file_refs map" {
  result=$(echo "Read @docs/sample.md" | bash "$ESTIMATOR" "warn-agent")
  echo "$result" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert len(d['file_refs']) > 0, 'file_refs should be non-empty'
"
}

# ── D. Cache behavior ─────────────────────────────────────────────────────────

@test "D1 cache file is created after first call" {
  echo "test prompt" | bash "$ESTIMATOR" "warn-agent" > /dev/null
  cache_count=$(find "$CACHE_DIR" -name "*.json" | wc -l | tr -d ' ')
  [ "$cache_count" -ge 1 ]
}

@test "D2 second call with same input returns cached result" {
  # First call populates cache
  result1=$(echo "exact same prompt" | bash "$ESTIMATOR" "warn-agent")
  # Second call should return same cache_key
  result2=$(echo "exact same prompt" | bash "$ESTIMATOR" "warn-agent")
  key1=$(echo "$result1" | python3 -c "import sys,json; print(json.load(sys.stdin)['cache_key'])")
  key2=$(echo "$result2" | python3 -c "import sys,json; print(json.load(sys.stdin)['cache_key'])")
  [ "$key1" = "$key2" ]
}

@test "D3 different prompt inputs produce different cache keys" {
  result1=$(echo "prompt one" | bash "$ESTIMATOR" "warn-agent")
  result2=$(echo "prompt two" | bash "$ESTIMATOR" "warn-agent")
  key1=$(echo "$result1" | python3 -c "import sys,json; print(json.load(sys.stdin)['cache_key'])")
  key2=$(echo "$result2" | python3 -c "import sys,json; print(json.load(sys.stdin)['cache_key'])")
  [ "$key1" != "$key2" ]
}

# ── E. Graceful degradation ───────────────────────────────────────────────────

@test "E1 agent without token_budget exits 0 with error JSON" {
  result=$(echo "test" | bash "$ESTIMATOR" "no-budget-agent")
  exit_code=$?
  [ "$exit_code" -eq 0 ]
  echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'error' in d"
}

@test "E2 unknown agent exits 0 with error JSON" {
  result=$(echo "test" | bash "$ESTIMATOR" "nonexistent-agent-xyz")
  exit_code=$?
  [ "$exit_code" -eq 0 ]
  echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'error' in d"
}

# ── F. context_window_target overhead ────────────────────────────────────────

@test "F1 context_window_target is added to projection" {
  # ctx-agent: budget=1000, ctx_target=500
  result=$(echo "hi" | bash "$ESTIMATOR" "ctx-agent")
  ctx_toks=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['breakdown']['context_target'])")
  [ "$ctx_toks" -eq 500 ]
}

@test "F2 projected includes context_window_target" {
  result=$(echo "hi" | bash "$ESTIMATOR" "ctx-agent")
  projected=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['projected'])")
  # prompt 2 chars → 0 tokens + ctx_target 500 = 500
  [ "$projected" -ge 500 ]
}

# ── G. Suggestions ────────────────────────────────────────────────────────────

@test "G1 suggestions is empty array when verdict ok" {
  prompt=$(python3 -c "print('a' * 100, end='')")  # 100 chars → 25 tokens (well under 320)
  result=$(echo "$prompt" | bash "$ESTIMATOR" "warn-agent")
  suggestions=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['suggestions'])")
  [ "$suggestions" = "[]" ]
}

@test "G2 suggestions includes context-rot-strategy on warn" {
  prompt=$(python3 -c "print('a' * 1400, end='')")  # 350 tokens → warn
  result=$(echo "$prompt" | bash "$ESTIMATOR" "warn-agent")
  echo "$result" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'context-rot-strategy' in d['suggestions'], 'missing context-rot-strategy'
"
}

@test "G3 suggestions includes context-task-classifier on exceeded" {
  prompt=$(python3 -c "print('a' * 2000, end='')")  # 500 tokens → exceeded
  result=$(echo "$prompt" | bash "$ESTIMATOR" "warn-agent")
  echo "$result" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'context-task-classifier' in d['suggestions'], 'missing context-task-classifier'
"
}

# ── H. Hook integration ───────────────────────────────────────────────────────

@test "H1 hook exits 0 for non-Task tool" {
  input='{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  result=$(echo "$input" | SAVIA_PREFLIGHT=on CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" 2>/dev/null)
  echo "$input" | SAVIA_PREFLIGHT=on CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" 2>/dev/null
  [ $? -eq 0 ]
}

@test "H2 hook exits 0 when SAVIA_PREFLIGHT=off" {
  prompt=$(python3 -c "print('a' * 2000, end='')")
  input=$(python3 -c "
import json, sys
print(json.dumps({'tool_name':'Task','tool_input':{'subagent_type':'block-agent','prompt': 'a'*2000}}))
")
  echo "$input" | SAVIA_PREFLIGHT=off SAVIA_BUDGET_ENFORCEMENT=block CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" 2>/dev/null
  [ $? -eq 0 ]
}

@test "H3 hook exits 0 on warn verdict when ENFORCE=warn" {
  prompt=$(python3 -c "print('a' * 1400, end='')")  # 350 tokens → warn for warn-agent
  input=$(python3 -c "
import json
print(json.dumps({'tool_name':'Task','tool_input':{'subagent_type':'warn-agent','prompt': 'a'*1400}}))
")
  echo "$input" | SAVIA_PREFLIGHT=on SAVIA_BUDGET_ENFORCEMENT=warn CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" 2>/dev/null
  [ $? -eq 0 ]
}

@test "H4 hook exits 2 on exceeded + block policy + ENFORCE=block" {
  # block-agent: budget=200 → exceeded with 900 chars (225 tokens)
  input=$(python3 -c "
import json
print(json.dumps({'tool_name':'Task','tool_input':{'subagent_type':'block-agent','prompt': 'a'*900}}))
")
  result=0
  echo "$input" | SAVIA_PREFLIGHT=on SAVIA_BUDGET_ENFORCEMENT=block CLAUDE_PROJECT_DIR="$TMP" bash "$HOOK" 2>/dev/null || result=$?
  [ "$result" -eq 2 ]
}

# ── I. Output correctness ─────────────────────────────────────────────────────

@test "I1 budget field matches per_invocation in agent frontmatter" {
  result=$(echo "hello" | bash "$ESTIMATOR" "warn-agent")
  budget=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['budget'])")
  [ "$budget" -eq 400 ]
}

@test "I2 policy field matches escalation_policy in agent frontmatter" {
  result=$(echo "hello" | bash "$ESTIMATOR" "block-agent")
  policy=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['policy'])")
  [ "$policy" = "block" ]
}

@test "I3 ts field is present and non-empty" {
  result=$(echo "hello" | bash "$ESTIMATOR" "warn-agent")
  ts=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['ts'])")
  [ -n "$ts" ]
}
