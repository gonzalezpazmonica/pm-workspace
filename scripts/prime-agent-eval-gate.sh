#!/usr/bin/env bash
# prime-agent-eval-gate.sh — SE-347 gate de arranque CRIT-001-strict
#
# Comprueba que la evaluacion de Prime Agent puede arrancar sin exponer datos
# a proveedores cloud. Fallo en cualquiera de las comprobaciones => exit 1 y
# la evaluacion NO arranca (AC-S1.5).
#
# Comprobaciones:
#   1. Provider local alcanzable (curl localhost:11434/v1/models — Ollama).
#   2. telemetry.enabled=false en ~/.prime/agent/settings.json.
#   3. sessionDir apunta a infraestructura propia (no ~/.prime/agent por defecto).
#   4. bundledSkills.websearch=false (skill de red desactivada).
#   5. Env PRIME_AGENT_TELEMETRY=0 / DO_NOT_TRACK=1 (si se exportan).
#   6. node >=22.8 disponible (prime-agent es una CLI node).
#
# Uso: bash scripts/prime-agent-eval-gate.sh
set -uo pipefail

SETTINGS="${PRIME_AGENT_SETTINGS:-$HOME/.prime/agent/settings.json}"
MODELS="${PRIME_AGENT_MODELS:-$HOME/.prime/agent/models.json}"
OLLAMA_BASE="${PRIME_AGENT_OLLAMA_BASE:-http://localhost:11434/v1}"

fail() { echo "GATE FAIL: $1" >&2; exit 1; }
note() { echo "  ok: $1"; }

[[ -f "$SETTINGS" ]] || fail "settings.json no existe en $SETTINGS"
[[ -f "$MODELS" ]]  || fail "models.json no existe en $MODELS"

# 1. Provider local alcanzable
if ! curl -fsS --max-time 3 "$OLLAMA_BASE/models" >/dev/null 2>&1; then
  fail "provider local no alcanzable en $OLLAMA_BASE (arranca Ollama?)"
fi
note "provider local alcanzable ($OLLAMA_BASE)"

# 2. Telemetria OFF
TELEM=$(python3 -c "import json;print(json.load(open('$SETTINGS')).get('telemetry',{}).get('enabled',True))" 2>/dev/null)
[[ "$TELEM" == "False" ]] || fail "telemetry.enabled no es false en $SETTINGS (CRIT-001)"
note "telemetry.enabled=false"

# 3. sessionDir en infraestructura propia
SDIR=$(python3 -c "import json;print(json.load(open('$SETTINGS')).get('sessionDir',''))" 2>/dev/null)
case "$SDIR" in
  *"~/.prime/agent"*|*"/.prime/agent"*) fail "sessionDir apunta a path default cloud-oriented: $SDIR" ;;
  "") fail "sessionDir no configurado" ;;
esac
note "sessionDir=$SDIR (disco propio)"

# 4. websearch desactivado
WS=$(python3 -c "import json;print(json.load(open('$SETTINGS')).get('bundledSkills',{}).get('websearch',True))" 2>/dev/null)
[[ "$WS" == "False" ]] || fail "bundledSkills.websearch no es false (skill de red activa)"
note "bundledSkills.websearch=false"

# 5. Env anti-telemetria (si se exportan, deben ser OFF)
if [[ -n "${PRIME_AGENT_TELEMETRY:-}" ]]; then
  [[ "${PRIME_AGENT_TELEMETRY:-}" == "0" ]] || fail "PRIME_AGENT_TELEMETRY debe ser 0"
fi
if [[ -n "${DO_NOT_TRACK:-}" ]]; then
  [[ "${DO_NOT_TRACK:-}" == "1" ]] || fail "DO_NOT_TRACK debe ser 1"
fi
note "env telemetry OFF (o sin exportar)"

# 6. node >=22.8 disponible (prime-agent CLI node)
if ! command -v node >/dev/null 2>&1; then
  export PATH="$HOME/.savia/node/bin:$PATH"  # node propio de Savia
fi
if ! command -v node >/dev/null 2>&1; then
  fail "node no disponible (prime-agent requiere node >=22.8; usa $HOME/.savia/node/bin/node)"
fi
NODE_VER=$(node --version 2>/dev/null | sed 's/^v//')
[[ -n "$NODE_VER" ]] || fail "node no disponible (prime-agent requiere node >=22.8)"
if [[ "$(printf '%s\n22.8.0' "$NODE_VER" | sort -V | head -1)" != "22.8.0" ]]; then
  fail "node $NODE_VER < 22.8.0 (prime-agent lo requiere)"
fi
note "node $NODE_VER (>=22.8)"

echo "GATE PASS — evaluación Prime Agent puede arrancar en modo CRIT-001-strict"
