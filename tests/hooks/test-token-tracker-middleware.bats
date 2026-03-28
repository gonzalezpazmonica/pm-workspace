#!/usr/bin/env bats
# Tests for token-tracker-middleware.sh (SPEC-138)

setup() {
  # Ensure output dir exists for log writes
  mkdir -p "$(pwd)/output"
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

@test "sin variables: silencioso (fail-safe)" {
  unset CLAUDE_CONTEXT_TOKENS_USED CLAUDE_CONTEXT_TOKENS_MAX
  run bash .claude/hooks/token-tracker-middleware.sh
  [ "$status" -eq 0 ]
}
