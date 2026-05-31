#!/usr/bin/env bats
# tests/hooks/test-spec156-token-budget-projection.bats
# SPEC-156 Slice 2 — Token budget PreToolUse hook on Task tool
# Ref: docs/propuestas/SPEC-156-token-budget-frontmatter.md

setup() {
  HOOK="$BATS_TEST_DIRNAME/../../.claude/hooks/spec156-token-budget-projection.sh"
  TMPDIR=$(mktemp -d)
  export CLAUDE_PROJECT_DIR="$TMPDIR"
  mkdir -p "$TMPDIR/.opencode/agents" "$TMPDIR/output/agent-runs"

  # Synthetic agent with nested token_budget
  cat > "$TMPDIR/.opencode/agents/test-agent-block.md" <<'EOF'
---
name: test-agent-block
description: test
token_budget:
  per_invocation: 1000
  context_window_target: 500
  escalation_policy: block
---
body
EOF

  cat > "$TMPDIR/.opencode/agents/test-agent-warn.md" <<'EOF'
---
name: test-agent-warn
description: test
token_budget:
  per_invocation: 10000
  context_window_target: 2000
  escalation_policy: warn
---
body
EOF

  cat > "$TMPDIR/.opencode/agents/test-agent-escalate.md" <<'EOF'
---
name: test-agent-escalate
description: test
token_budget:
  per_invocation: 5000
  context_window_target: 1000
  escalation_policy: escalate
---
body
EOF

  cat > "$TMPDIR/.opencode/agents/test-agent-nobudget.md" <<'EOF'
---
name: test-agent-nobudget
description: no budget declared
---
body
EOF
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "script has safety flags" {
  grep -q "set -uo pipefail" "$HOOK"
}

@test "script es bash valido" {
  bash -n "$HOOK"
}

@test "no-op cuando tool_name != Task" {
  INPUT='{"tool_name":"Edit","tool_input":{}}'
  run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 0 ]
  [ ! -f "$TMPDIR/output/agent-runs/budget-projections.jsonl" ]
}

@test "no-op cuando enforcement=off" {
  INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"test-agent-block","prompt":"hi"}}'
  SAVIA_BUDGET_ENFORCEMENT=off run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 0 ]
  [ ! -f "$TMPDIR/output/agent-runs/budget-projections.jsonl" ]
}

@test "no-op cuando agent file no existe" {
  INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"nonexistent","prompt":"hi"}}'
  run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 0 ]
}

@test "no-op cuando agent no tiene token_budget" {
  INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"test-agent-nobudget","prompt":"hi"}}'
  run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 0 ]
  [ ! -s "$TMPDIR/output/agent-runs/budget-projections.jsonl" ]
}

@test "telemetria escrita en JSONL para Task con budget" {
  INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"test-agent-warn","prompt":"small prompt"}}'
  run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR/output/agent-runs/budget-projections.jsonl" ]
  grep -q '"agent":"test-agent-warn"' "$TMPDIR/output/agent-runs/budget-projections.jsonl"
  grep -q '"verdict":"ok"' "$TMPDIR/output/agent-runs/budget-projections.jsonl"
}

@test "verdict=warn cuando projected > 80% del cap" {
  # cap=1000, ctx_target=500. prompt of 1700 chars = 425 tokens. 425+500=925 > 800 (80%)
  BIG_PROMPT=$(python3 -c "print('x'*1700)")
  INPUT=$(printf '{"tool_name":"Task","tool_input":{"subagent_type":"test-agent-block","prompt":"%s"}}' "$BIG_PROMPT")
  run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 0 ]
  grep -q '"verdict":"warn"' "$TMPDIR/output/agent-runs/budget-projections.jsonl"
}

@test "verdict=exceeded cuando projected > cap (modo warn default)" {
  BIG_PROMPT=$(python3 -c "print('x'*3000)")
  INPUT=$(printf '{"tool_name":"Task","tool_input":{"subagent_type":"test-agent-block","prompt":"%s"}}' "$BIG_PROMPT")
  run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 0 ]  # warn mode does not block
  grep -q '"verdict":"exceeded"' "$TMPDIR/output/agent-runs/budget-projections.jsonl"
}

@test "BLOCK exit 2 cuando enforcement=block + verdict=exceeded + policy=block" {
  BIG_PROMPT=$(python3 -c "print('x'*3000)")
  INPUT=$(printf '{"tool_name":"Task","tool_input":{"subagent_type":"test-agent-block","prompt":"%s"}}' "$BIG_PROMPT")
  SAVIA_BUDGET_ENFORCEMENT=block run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOCKED"* ]]
}

@test "NO bloquea cuando enforcement=block pero policy=warn" {
  BIG_PROMPT=$(python3 -c "print('x'*60000)")
  INPUT=$(printf '{"tool_name":"Task","tool_input":{"subagent_type":"test-agent-warn","prompt":"%s"}}' "$BIG_PROMPT")
  SAVIA_BUDGET_ENFORCEMENT=block run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 0 ]
  grep -q '"verdict":"exceeded"' "$TMPDIR/output/agent-runs/budget-projections.jsonl"
}

@test "NO bloquea cuando enforcement=block pero policy=escalate" {
  BIG_PROMPT=$(python3 -c "print('x'*30000)")
  INPUT=$(printf '{"tool_name":"Task","tool_input":{"subagent_type":"test-agent-escalate","prompt":"%s"}}' "$BIG_PROMPT")
  SAVIA_BUDGET_ENFORCEMENT=block run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 0 ]
  grep -q '"policy":"escalate"' "$TMPDIR/output/agent-runs/budget-projections.jsonl"
}

@test "JSONL contiene campos requeridos" {
  INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"test-agent-warn","prompt":"hi"}}'
  run bash "$HOOK" <<< "$INPUT"
  LINE=$(tail -1 "$TMPDIR/output/agent-runs/budget-projections.jsonl")
  echo "$LINE" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); assert all(k in d for k in ['ts','session','agent','per_invocation','projected','prompt_tokens','context_target','policy','verdict','enforcement']), d"
}

@test "session id capturado desde CLAUDE_SESSION_ID" {
  INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"test-agent-warn","prompt":"hi"}}'
  CLAUDE_SESSION_ID="test-sess-42" run bash "$HOOK" <<< "$INPUT"
  grep -q '"session":"test-sess-42"' "$TMPDIR/output/agent-runs/budget-projections.jsonl"
}

@test "hook silencioso (stdout vacio) en modo ok" {
  INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"test-agent-warn","prompt":"hi"}}'
  run bash "$HOOK" <<< "$INPUT"
  [ -z "$output" ]
}

@test "tool_input.subagent_type vacio → no-op" {
  INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"","prompt":"hi"}}'
  run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 0 ]
}

@test "flow YAML syntax: parsea per_invocation correctamente" {
  cat > "$TMPDIR/.opencode/agents/test-flow.md" <<'EOF'
---
name: test-flow
description: flow syntax
token_budget: {per_invocation: 8000, context_window_target: 1500, escalation_policy: warn}
---
body
EOF
  INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"test-flow","prompt":"x"}}'
  run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 0 ]
  LINE=$(tail -1 "$TMPDIR/output/agent-runs/budget-projections.jsonl")
  echo "$LINE" | grep -q '"per_invocation":8000'
  echo "$LINE" | grep -q '"context_target":1500'
  echo "$LINE" | grep -q '"policy":"warn"'
}

@test "flow YAML syntax: block exit 2 cuando policy=block + verdict=exceeded" {
  cat > "$TMPDIR/.opencode/agents/test-flow-block.md" <<'EOF'
---
name: test-flow-block
description: flow + block
token_budget: {per_invocation: 100, context_window_target: 50, escalation_policy: block}
---
body
EOF
  BIG=$(python3 -c "print('x'*5000)")
  INPUT=$(python3 -c "import json,sys; print(json.dumps({'tool_name':'Task','tool_input':{'subagent_type':'test-flow-block','prompt':'$BIG'}}))")
  SAVIA_BUDGET_ENFORCEMENT=block run bash "$HOOK" <<< "$INPUT"
  [ "$status" -eq 2 ]
}
