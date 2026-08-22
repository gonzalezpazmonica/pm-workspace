#!/usr/bin/env bash
set -uo pipefail
# block-commit-to-main.sh — SE-337: bloquea `git commit` en ramas humanas.
#
# autonomous-safety: NUNCA commit en ramas de humanos (main, develop,
# feature/* humano). Este guard lo mecaniza: si branch ∈ {main, master},
# bloquea el commit con JSON decision:block. Bypass consciente SOLO para
# la operadora: SAVIA_ALLOW_MAIN_COMMIT=1 (con registro en JSONL, RN-04).
#
# PreToolUse Bash(git commit*). PURE_BASH, sin red (CRIT-001).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${SAVIA_TURN_SDLC_LOG_DIR:-$ROOT/output/turn-sdlc}"

# Ignorar si no estamos en un repo git
BRANCH=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "")
fi
# vacío (detached/recién init) → no proteger (sin rama de humano en juego)
[[ -z "$BRANCH" ]] && exit 0

# Solo proteger ramas de humano: main y master
if [[ "$BRANCH" != "main" && "$BRANCH" != "master" ]]; then
  exit 0
fi

# Bypass consciente de la operadora (se registra, no es silencioso)
if [[ "${SAVIA_ALLOW_MAIN_COMMIT:-0}" == "1" ]]; then
  mkdir -p "$LOG_DIR"
  printf '{"ts":"%s","branch":"%s","action":"commit","verdict":"bypass","env":"SAVIA_ALLOW_MAIN_COMMIT=1"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$BRANCH" >> "$LOG_DIR/commit-guard.jsonl" 2>/dev/null || true
  exit 0
fi

# Bloqueo
mkdir -p "$LOG_DIR"
printf '{"ts":"%s","branch":"%s","action":"commit","verdict":"block"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$BRANCH" >> "$LOG_DIR/commit-guard.jsonl" 2>/dev/null || true

REASON="Commit en rama humana ($BRANCH) bloqueado por autonomous-safety (regla: NUNCA commit en main/master). Crea una rama agent/* propia y commitea ahí: git checkout -b agent/<tarea>. Si Eres la operadora y el commit en main es intencional, repitelo con SAVIA_ALLOW_MAIN_COMMIT=1 (queda registrado)."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg r "$REASON" '{decision: "block", reason: $r}'
else
  printf '{"decision":"block","reason":"%s"}\n' "$REASON"
fi
exit 0