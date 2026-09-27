#!/usr/bin/env bats
# Ref: SE-348 — activaciones: router SE-346 (savia-env.sh), hook FxC, vector recall

setup() {
  set -o pipefail
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  FX="$(mktemp -d)"
}

teardown() {
  cd /
}

@test "SE-348: savia_model_by_uncertainty responde (advisory, sin fallar sin sklearn)" {
  run bash -c 'source "$1/scripts/savia-env.sh" && savia_model_by_uncertainty code' _ "$ROOT_DIR"
  [ "$status" -eq 0 ]
  # sin sklearn -> vacío (fail-open); con sklearn -> tier canónico heavy|mid|fast
  if echo "$output" | grep -qE "^(fast|mid|heavy)"$'\t'; then
    echo "$output" | grep -q "std="
  else
    [ -z "$output" ]
  fi
}

@test "SE-348: hook fronesis-gate-reminder registrado y warn-only (no bloquea)" {
  [ -x "$ROOT_DIR/.opencode/hooks/fronesis-gate-reminder.sh" ]
  python3 -c "
import json
s=json.load(open('$ROOT_DIR/.claude/settings.json'))
found=False
for g in s.get('hooks',{}).get('PostToolUse',[]):
    for h in g.get('hooks',[]):
        if 'fronesis-gate-reminder' in h.get('command',''):
            found=True
            assert h.get('async')==True, h
assert found, 'hook no registrado'
"
  # warn-only: no debe contener exit 2
  ! grep -qE "exit 2" "$ROOT_DIR/.opencode/hooks/fronesis-gate-reminder.sh"
}

@test "SE-348: vector recall activo (servidor de embeddings responde o script existe)" {
  if curl -sf --max-time 2 http://127.0.0.1:7331/health >/dev/null 2>&1; then
    curl -sf --max-time 2 http://127.0.0.1:7331/health | grep -q '"status": "ok"'
  else
    [ -f "$ROOT_DIR/scripts/embedding-server.py" ]
  fi
}

@test "safety: savia-env.sh is sourced under set -uo pipefail and defines the router helper once" {
  grep -q 'set -uo pipefail' "$ROOT_DIR/scripts/savia-env.sh"
  [ "$(grep -c '^savia_model_by_uncertainty()' "$ROOT_DIR/scripts/savia-env.sh")" -eq 1 ]
  [ "$(grep -c '^#!/usr/bin/env bash' "$ROOT_DIR/scripts/savia-env.sh")" -eq 1 ]
}

@test "missing: workspace without the router fails open with empty output" {
  run bash -c 'source "$1/scripts/savia-env.sh" && SAVIA_WORKSPACE_DIR="$2" savia_model_by_uncertainty code' _ "$ROOT_DIR" "$FX"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "nonexistent: unknown task type yields empty output, never a tier" {
  run bash -c 'source "$1/scripts/savia-env.sh" && savia_model_by_uncertainty bogus-type' _ "$ROOT_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "empty: fronesis reminder hook exits 0 on empty stdin (warn-only)" {
  run bash -c 'echo "" | bash "$1/.opencode/hooks/fronesis-gate-reminder.sh"' _ "$ROOT_DIR"
  [ "$status" -eq 0 ]
}

@test "reject: router output tiers are canonical (no legacy CLAUDE_MODEL_* names)" {
  ! grep -qE 'CLAUDE_MODEL_(FAST|MID|AGENT)' "$ROOT_DIR/scripts/surrogate/llm-router.py"
  grep -q 'return "heavy"' "$ROOT_DIR/scripts/surrogate/llm-router.py"
}
