#!/usr/bin/env bats
# Ref: SE-348 — activaciones: router SE-346 (savia-env.sh), hook FxC, vector recall

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "SE-348: savia_model_by_uncertainty responde (advisory, sin fallar sin sklearn)" {
  run bash -c 'source "$1/scripts/savia-env.sh" && savia_model_by_uncertainty code' _ "$ROOT_DIR"
  [ "$status" -eq 0 ]
  # sin sklearn -> vacío (fail-open); con sklearn -> CLAUDE_MODEL_*
  if echo "$output" | grep -qE "CLAUDE_MODEL_(FAST|MID|AGENT)"; then
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
