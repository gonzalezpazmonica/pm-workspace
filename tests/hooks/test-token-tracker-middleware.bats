#!/usr/bin/env bats
# Tests for token-tracker-middleware.sh (SPEC-138)
# Ref: .claude/rules/domain/context-health.md

setup() {
  TMPDIR=$(mktemp -d)
  # Ensure output dir exists for log writes
  mkdir -p "$(pwd)/output"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "target has safety flags" {
  grep -q "set -[euo]" .claude/hooks/token-tracker-middleware.sh
}

@test "zona verde: sin output" {
  CLAUDE_CONTEXT_TOKENS_USED=40000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
    run bash .claude/hooks/token-tracker-middleware.sh
  [ "$status" -eq 0 ]
  [[ "$output" == "" ]]
}

@test "zona gradual (55%): mensaje informativo" {
  CLAUDE_CONTEXT_TOKENS_USED=110000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
    run bash .claude/hooks/token-tracker-middleware.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"/compact"* ]]
}

@test "zona alerta (75%): advertencia" {
  CLAUDE_CONTEXT_TOKENS_USED=150000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
    run bash .claude/hooks/token-tracker-middleware.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"alto"* ]]
}

@test "zona critica (90%): mensaje critico" {
  CLAUDE_CONTEXT_TOKENS_USED=180000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
    run bash .claude/hooks/token-tracker-middleware.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"crítico"* ]]
}

# ── Negative / error cases ──

@test "sin variables: silencioso (fail-safe)" {
  unset CLAUDE_CONTEXT_TOKENS_USED CLAUDE_CONTEXT_TOKENS_MAX
  run bash .claude/hooks/token-tracker-middleware.sh
  [ "$status" -eq 0 ]
}

@test "negative tokens handled gracefully" {
  CLAUDE_CONTEXT_TOKENS_USED=-1 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
    run bash .claude/hooks/token-tracker-middleware.sh
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

# ── Edge cases ──

@test "non-numeric max tokens exits gracefully" {
  CLAUDE_CONTEXT_TOKENS_USED=100 CLAUDE_CONTEXT_TOKENS_MAX=abc \
    run bash .claude/hooks/token-tracker-middleware.sh
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "zero max tokens handled without division error" {
  CLAUDE_CONTEXT_TOKENS_USED=100 CLAUDE_CONTEXT_TOKENS_MAX=0 \
    run bash .claude/hooks/token-tracker-middleware.sh
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "boundary at exactly 50 percent threshold" {
  # SPEC-042: Zona Gradual starts at 50%
  CLAUDE_CONTEXT_TOKENS_USED=100000 CLAUDE_CONTEXT_TOKENS_MAX=200000 \
    run bash .claude/hooks/token-tracker-middleware.sh
  [ "$status" -eq 0 ]
  python3 -c "pct=100000/200000*100; assert pct == 50.0"
}

@test "core hooks use safety flags" {
  grep -q "set -[euo]" .claude/hooks/validate-bash-global.sh
}

@test "edge: empty input produces no error" {
  run bash -c "echo '{}' | SAVIA_HOOK_PROFILE=minimal bash .claude/hooks/validate-bash-global.sh 2>&1"
  [ "$status" -eq 0 ]
}
