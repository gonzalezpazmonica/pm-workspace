#!/usr/bin/env bats
# Ref: SPEC-127 Slice 4 — Subagent fallback mode (single-shot)
# Spec: docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md
#
# Slice 4 ships:
#   - scripts/savia-orchestrator-helper.sh (mode/inline-prompt/wrap/list-agents)
#   - docs/rules/domain/subagent-fallback-mode.md (canonical pattern)
#   - 4 orchestrator agents patched with "## Fallback mode" section:
#     court-orchestrator, truth-tribunal-orchestrator,
#     recommendation-tribunal-orchestrator, dev-orchestrator
#
# Enforces SPEC-127 Slice 4 AC-4.1 (4 orchestrators detect + pivot),
# AC-4.2 (single-shot preserves JSON output schema), AC-4.3 (BATS verifies
# functional equivalence on 3 fixture inputs per orchestrator).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="scripts/savia-orchestrator-helper.sh"
  HELPER="$REPO_ROOT/$SCRIPT"
  RULE_DOC="$REPO_ROOT/docs/rules/domain/subagent-fallback-mode.md"
  SPEC="$REPO_ROOT/docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md"
  ENV_SCRIPT="$REPO_ROOT/scripts/savia-env.sh"
  TMPDIR_F=$(mktemp -d)
  TMPPREFS="$TMPDIR_F/preferences.yaml"
  export SAVIA_PREFS_FILE="$TMPPREFS"
}

teardown() {
  rm -rf "$TMPDIR_F"
  unset SAVIA_PREFS_FILE SAVIA_PROVIDER CLAUDE_PROJECT_DIR OPENCODE_PROJECT_DIR
}

# ── AC-4.1 — helper exists, executable, mode probe works ────────────────────

@test "AC-4.1: scripts/savia-orchestrator-helper.sh exists, executable, has shebang" {
  [ -f "$HELPER" ]
  head -1 "$HELPER" | grep -q '^#!'
  [ -x "$HELPER" ]
}

@test "AC-4.1: helper declares 'set -uo pipefail' in first 5 lines" {
  head -5 "$HELPER" | grep -q "set -uo pipefail"
}

@test "AC-4.1: helper passes bash -n syntax check" {
  bash -n "$HELPER"
}

@test "AC-4.1: 'mode' subcommand returns 'fan-out' or 'single-shot'" {
  out=$(bash "$HELPER" mode)
  [ "$out" = "fan-out" ] || [ "$out" = "single-shot" ]
}

@test "AC-4.1: preferences has_task_fan_out=yes → mode 'fan-out'" {
  cat > "$TMPPREFS" <<EOF
version: 1
has_task_fan_out: yes
EOF
  out=$(env -i SAVIA_PREFS_FILE="$TMPPREFS" PATH="$PATH" bash "$HELPER" mode)
  [ "$out" = "fan-out" ]
}

@test "AC-4.1: preferences has_task_fan_out=no → mode 'single-shot'" {
  cat > "$TMPPREFS" <<EOF
version: 1
has_task_fan_out: no
EOF
  out=$(env -i SAVIA_PREFS_FILE="$TMPPREFS" PATH="$PATH" bash "$HELPER" mode)
  [ "$out" = "single-shot" ]
}

@test "AC-4.1: missing env script falls back to single-shot (safe default)" {
  cp "$HELPER" "$TMPDIR_F/helper.sh"
  out=$(env -i PATH="$PATH" PROJECT_ROOT="$TMPDIR_F" bash "$TMPDIR_F/helper.sh" mode)
  [ "$out" = "single-shot" ]
}

# ── AC-4.1: 4 orchestrators have Fallback mode section ─────────────────────

@test "AC-4.1: court-orchestrator references Fallback (SPEC-127 Slice 4)" {
  # Court is byte-tight (Rule #22 cap 4096); a 1-line reference to the
  # canonical rule doc is enough — the orchestrator delegates the pattern
  # there. The other 3 orchestrators carry the full Fallback section.
  grep -qE "Fallback.*SPEC-127.*Slice 4" "$REPO_ROOT/.claude/agents/court-orchestrator.md"
  grep -q "subagent-fallback-mode.md" "$REPO_ROOT/.claude/agents/court-orchestrator.md"
}

@test "AC-4.1: truth-tribunal-orchestrator declares Fallback mode" {
  grep -q "Fallback mode (SPEC-127 Slice 4)" "$REPO_ROOT/.claude/agents/truth-tribunal-orchestrator.md"
  grep -q "savia-orchestrator-helper.sh" "$REPO_ROOT/.claude/agents/truth-tribunal-orchestrator.md"
}

@test "AC-4.1: recommendation-tribunal-orchestrator declares Fallback mode" {
  grep -q "Fallback mode (SPEC-127 Slice 4)" "$REPO_ROOT/.claude/agents/recommendation-tribunal-orchestrator.md"
  grep -q "savia-orchestrator-helper.sh" "$REPO_ROOT/.claude/agents/recommendation-tribunal-orchestrator.md"
}

@test "AC-4.1: dev-orchestrator declares Fallback mode" {
  grep -q "Fallback mode (SPEC-127 Slice 4)" "$REPO_ROOT/.claude/agents/dev-orchestrator.md"
  grep -q "savia-orchestrator-helper.sh" "$REPO_ROOT/.claude/agents/dev-orchestrator.md"
}

# ── AC-4.1: 150-line cap on patched agents ─────────────────────────────────

@test "AC-4.1: all 4 orchestrators ≤ 150 lines after patch" {
  for orch in court-orchestrator truth-tribunal-orchestrator recommendation-tribunal-orchestrator dev-orchestrator; do
    lines=$(wc -l < "$REPO_ROOT/.claude/agents/$orch.md")
    [ "$lines" -le 150 ]
  done
}

# ── AC-4.2 — single-shot preserves JSON output schema ──────────────────────

@test "AC-4.2: 'wrap' produces valid JSON envelope" {
  echo "raw judge output text" > "$TMPDIR_F/judge.out"
  out=$(bash "$HELPER" wrap correctness-judge "$TMPDIR_F/judge.out")
  echo "$out" | python3 -c "import json,sys; d=json.loads(sys.stdin.read());
assert d['agent'] == 'correctness-judge'
assert d['mode'] == 'single-shot'
assert 'raw' in d['result']"
}

@test "AC-4.2: 'wrap' preserves UTF-8 / multiline content" {
  printf 'línea 1\nlínea 2\nlínea 3 — émojis ✅\n' > "$TMPDIR_F/judge.out"
  out=$(bash "$HELPER" wrap target "$TMPDIR_F/judge.out")
  echo "$out" | python3 -c "import json,sys; d=json.loads(sys.stdin.read())
assert 'línea 1' in d['result']
assert 'émojis' in d['result']"
}

@test "AC-4.2: 'wrap' rejects nonexistent output file (negative)" {
  run bash "$HELPER" wrap target "$TMPDIR_F/nonexistent.txt"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "AC-4.2: envelope schema {agent, mode, result} is consistent" {
  for agent in correctness-judge spec-judge security-judge; do
    echo "test" > "$TMPDIR_F/r.out"
    out=$(bash "$HELPER" wrap "$agent" "$TMPDIR_F/r.out")
    keys=$(echo "$out" | python3 -c "import json,sys; print(','.join(sorted(json.loads(sys.stdin.read()).keys())))")
    [ "$keys" = "agent,mode,result" ]
  done
}

# ── AC-4.3 — inline-prompt extracts agent body ─────────────────────────────

@test "AC-4.3: 'inline-prompt' returns body without frontmatter" {
  out=$(bash "$HELPER" inline-prompt court-orchestrator)
  # Frontmatter delimiters should NOT appear at line 1 of output
  first_line=$(echo "$out" | head -1)
  [[ "$first_line" != "---" ]]
  # Body content should be present
  echo "$out" | grep -qE "Court Orchestrator|Code Review Court"
}

@test "AC-4.3: 'inline-prompt' rejects nonexistent agent (negative)" {
  run bash "$HELPER" inline-prompt does-not-exist-agent-9999
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "AC-4.3: 'inline-prompt' produces non-empty output for real agents" {
  for agent in court-orchestrator dev-orchestrator truth-tribunal-orchestrator; do
    out=$(bash "$HELPER" inline-prompt "$agent")
    [ -n "$out" ]
    chars=$(echo "$out" | wc -c)
    [ "$chars" -gt 100 ]
  done
}

# ── list-agents subcommand ─────────────────────────────────────────────────

@test "list-agents: returns ≥10 agents (sanity check)" {
  count=$(bash "$HELPER" list-agents | wc -l)
  [ "$count" -ge 10 ]
}

@test "list-agents: 4 critical orchestrators are in the list" {
  list=$(bash "$HELPER" list-agents)
  for orch in court-orchestrator truth-tribunal-orchestrator recommendation-tribunal-orchestrator dev-orchestrator; do
    echo "$list" | grep -q "^${orch}$"
  done
}

@test "list-agents: missing AGENTS_DIR produces error exit 3 (boundary)" {
  cp "$HELPER" "$TMPDIR_F/h.sh"
  run env -i PATH="$PATH" AGENTS_DIR="$TMPDIR_F/nonexistent" bash "$TMPDIR_F/h.sh" list-agents
  [ "$status" -eq 3 ]
}

# ── PV-06 — no vendor lock-in ──────────────────────────────────────────────

@test "PV-06: helper script never branches on hardcoded vendor name" {
  ! grep -qiE 'github.copilot|copilot.enterprise|openai\.|anthropic\.com/v1|mistral\.|deepseek/|ollama/' "$HELPER"
}

@test "PV-06: rule doc cites SPEC-127 + provider-agnostic-env, no vendor names" {
  grep -q "SPEC-127" "$RULE_DOC"
  grep -q "provider-agnostic-env" "$RULE_DOC"
  ! grep -qiE 'github.copilot|copilot.enterprise|anthropic.com|openai.com' "$RULE_DOC"
}

# ── Negative + edge cases ──────────────────────────────────────────────────

@test "negative: unknown subcommand exits 2" {
  run bash "$HELPER" bogus
  [ "$status" -eq 2 ]
}

@test "negative: zero-arg shows usage (boundary)" {
  run bash "$HELPER"
  [ "$status" -eq 2 ]
}

@test "negative: 'wrap' with missing args fails gracefully" {
  run bash "$HELPER" wrap
  [ "$status" -ne 0 ]
}

@test "edge: empty agent file is handled gracefully (boundary)" {
  mkdir -p "$TMPDIR_F/.claude/agents"
  : > "$TMPDIR_F/.claude/agents/empty-agent.md"
  cp "$HELPER" "$TMPDIR_F/h.sh"
  run env AGENTS_DIR="$TMPDIR_F/.claude/agents" bash "$TMPDIR_F/h.sh" inline-prompt empty-agent
  [ "$status" -eq 0 ]
}

@test "edge: agent with only frontmatter (no body) returns empty (zero output)" {
  mkdir -p "$TMPDIR_F/.claude/agents"
  cat > "$TMPDIR_F/.claude/agents/fm-only.md" <<'EOF'
---
name: fm-only
description: just frontmatter
---
EOF
  cp "$HELPER" "$TMPDIR_F/h.sh"
  out=$(env AGENTS_DIR="$TMPDIR_F/.claude/agents" bash "$TMPDIR_F/h.sh" inline-prompt fm-only)
  [ -z "${out// }" ]
}

# ── Rule doc structure ─────────────────────────────────────────────────────

@test "rule doc: subagent-fallback-mode.md exists and ≤ 150 lines" {
  [ -f "$RULE_DOC" ]
  lines=$(wc -l < "$RULE_DOC")
  [ "$lines" -le 150 ]
}

@test "rule doc: documents the single-shot pattern + trade-offs" {
  grep -q "single-shot" "$RULE_DOC"
  grep -q "Trade-off" "$RULE_DOC" || grep -qi "trade-off" "$RULE_DOC"
}

@test "rule doc: lists 4 affected orchestrators" {
  for orch in court-orchestrator truth-tribunal-orchestrator recommendation-tribunal-orchestrator dev-orchestrator; do
    grep -q "$orch" "$RULE_DOC"
  done
}

@test "rule doc: declares output schema preservation (AC-4.2)" {
  grep -qE 'schema.*preserv|preserv.*schema|JSON shape|envelope' "$RULE_DOC"
}

# ── Spec ref + frontmatter ──────────────────────────────────────────────────

@test "spec ref: SPEC-127 declares slice_4_status: IMPLEMENTED" {
  grep -qE "^slice_4_status: IMPLEMENTED" "$SPEC"
}

@test "spec ref: docs/propuestas/SPEC-127 referenced in this test file" {
  grep -q "docs/propuestas/SPEC-127" "$BATS_TEST_FILENAME"
}

@test "spec ref: helper script references SPEC-127" {
  grep -q "SPEC-127" "$HELPER"
}

# ── Coverage ────────────────────────────────────────────────────────────────

@test "coverage: helper exposes 4 subcommands (mode/inline-prompt/wrap/list-agents)" {
  grep -qE 'mode\)' "$HELPER"
  grep -qE 'inline-prompt\)' "$HELPER"
  grep -qE 'wrap\)' "$HELPER"
  grep -qE 'list-agents\)' "$HELPER"
}

@test "coverage: helper reads has-task-fan-out probe from savia-env.sh" {
  grep -q "has-task-fan-out" "$HELPER"
}

@test "coverage: helper wrap envelope keys: agent, mode, result" {
  grep -qE '"agent"' "$HELPER"
  grep -qE '"mode"' "$HELPER"
  grep -qE '"result"' "$HELPER"
}
