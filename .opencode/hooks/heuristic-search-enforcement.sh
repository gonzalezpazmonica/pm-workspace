#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh" 2>/dev/null || true
# heuristic-search-enforcement.sh — PreToolUse hook (Bash)
#
# Bloquea `grep -r` / `grep -ri` recursivo sobre projects/{slug}/ si en el
# turno actual NO se ha consultado ningun indice T1 de la heuristica
# tier-based (members/, GLOSSARY, STAKEHOLDERS, INDEX, _HUB, .acm, .hcm,
# .afm, MEMORY).
#
# Bypass legitimo:
#   - grep dirigido a vault concreto con --include="*.md"
#   - SAVIA_HEURISTIC_ENFORCE=0 → desactivado
#   - SAVIA_HEURISTIC_ENFORCE=warn → solo stderr (default inicial)
#   - SAVIA_HEURISTIC_ENFORCE=block → enforcement
#   - flag explicito en el comando: # heuristic-bypass:<motivo>
#
# Exit 2 = bloqueo. Mensaje cita los paths T1 a probar primero.

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  source "$LIB_DIR/profile-gate.sh" && profile_gate "standard"
fi

ENFORCE_MODE="${SAVIA_HEURISTIC_ENFORCE:-warn}"
[[ "$ENFORCE_MODE" == "0" || "$ENFORCE_MODE" == "off" ]] && exit 0

if ! command -v jq &>/dev/null; then exit 0; fi

INPUT=""
if INPUT=$(timeout 3 cat 2>/dev/null); then :; fi
[[ -z "$INPUT" ]] && exit 0

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[[ "$TOOL_NAME" != "Bash" ]] && exit 0

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$CMD" ]] && exit 0

# Solo intercepta grep recursivo
if ! echo "$CMD" | grep -qE '(^|[^a-zA-Z_])grep[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*|--recursive|-R)'; then
  exit 0
fi

# Bypass explicito
if echo "$CMD" | grep -q "heuristic-bypass:"; then
  exit 0
fi

# Solo si apunta a projects/
if ! echo "$CMD" | grep -qE 'projects/[a-zA-Z0-9_-]+'; then
  exit 0
fi

PROJECT_NAME=$(echo "$CMD" | sed -nE 's|.*projects/([a-zA-Z0-9_-]+).*|\1|p' | head -1)
[[ -z "$PROJECT_NAME" ]] && exit 0

TURN_ID="${CLAUDE_TURN_ID:-${CLAUDE_SESSION_ID:-default}}"
MARKER_DIR="${TMPDIR:-/tmp}/savia-turn-${TURN_ID}"
MARKER="$MARKER_DIR/heuristic-t1-${PROJECT_NAME}"

# Si el marker existe → ya consulto T1, permitir
[[ -f "$MARKER" ]] && exit 0

# Excepcion: si el grep es dirigido (--include + --exclude-dir o vault concreto)
# → es T4 legitimo segun la heuristica
if echo "$CMD" | grep -qE -- '--include[= ]"?\*\.md' && \
   echo "$CMD" | grep -qE -- '--exclude-dir[= ]"?(repos|raw|transcripts)'; then
  # Aun asi, registrar en search-misses si no hubo T1
  exit 0
fi

# BLOQUEO o WARN
MSG="HEURISTIC-SEARCH GUARD: grep recursivo sobre projects/${PROJECT_NAME}/ sin consulta previa a indices T1.

Antes de grep, prueba (en este orden):
  1. T1 PERSONA:    projects/${PROJECT_NAME}/*/members/{handle}.md
  2. T1 CONCEPTO:   projects/${PROJECT_NAME}/*/GLOSSARY.md
  3. T1 REGLA:      projects/${PROJECT_NAME}/*/business-rules/STAKEHOLDERS.md
  4. T1 CODIGO:     projects/${PROJECT_NAME}/.agent-maps/INDEX.acm
  5. T1 NARRATIVA:  projects/${PROJECT_NAME}/.human-maps/{vault}.hcm
  6. T1 NAVEGACION: projects/${PROJECT_NAME}/_HUB.md o {vault}/INDEX.md

Si T1-T3 no responden, lanza grep dirigido con:
  --include=\"*.md\" --exclude-dir=repos --exclude-dir=raw --exclude-dir=transcripts

Bypass explicito: añade '# heuristic-bypass:<motivo>' al final del comando.
Registrar miss: scripts/search-miss-log.sh T4 <CAT> \"<query>\" \"<reason>\""

if [[ "$ENFORCE_MODE" == "warn" ]]; then
  echo "[WARN] $MSG" >&2
  exit 0
fi

# block
echo "$MSG" >&2
exit 2
