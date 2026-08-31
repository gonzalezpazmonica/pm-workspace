#!/usr/bin/env bash
# permission-mode-gate.sh — SE-354: Read-Only Permission Mode (policy as code).
# set -uo pipefail
#
# Deniega estructuralmente las tools de mutación cuando la sesión está en modo
# read-only. La denegación es en código, no una promesa al modelo: las tools
# de mutación "no existen" en una sesión read-only.
#
# Modo por sesión: SAVIA_PERMISSION_MODE=read-only|full (default full)
#
# En read-only se bloquean:
#   - Write, Edit, MultiEdit (tools de mutación directas)
#   - Bash con comandos de mutación (git push/commit/merge, rm, mv, cp,
#     install, apply_patch) — ver WHITELIST_READ_SAFE para excepciones
#
# Fail-soft: exit 0 si el modo no es read-only; exit 2 si se bloquea una tool
# de mutación (bloqueo real). Jamás bloquea la sesión entera.
#
# Ref: SE-354 — Read-Only Permission Mode
set -uo pipefail

SAVIA_PERMISSION_MODE="${SAVIA_PERMISSION_MODE:-full}"
[[ "$SAVIA_PERMISSION_MODE" != "read-only" ]] && exit 0

# Tools de mutación — denegadas por diseño en read-only
MUTATION_TOOLS="Write|Edit|MultiEdit|apply_patch|create_file|modify_file"

# Comandos de mutación (Bash) — denegados salvo en WHITELIST_READ_SAFE
MUTATION_CMDS='git[[:space:]]+(push|commit|merge|rebase|reset --hard|checkout \.|clean|stash)|^rm[[:space:]]|^mv[[:space:]]|^cp[[:space:]]|install|npm[[:space:]]+i|pip[[:space:]]+install|apt-get[[:space:]]+install|apply_patch|> *[^&|]'

# Whitelist read-safe dentro de Bash (comandos de consulta permitidos)
WHITELIST_READ_SAFE='git[[:space:]]+(status|log|diff|show|fetch|rev-parse|branch|remote|ls-files|check-ignore)|^(ls|cat|grep|rg|find|wc|head|tail|sed -n|awk|jq|python3? -c|bash -n|wc -l)[[:space:]]'

# ── Leer entrada PreToolUse (JSON) ────────────────────────────────────────────
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(timeout 2 cat 2>/dev/null) || true
fi
[[ -z "$INPUT" ]] && exit 0

if ! echo "$INPUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  exit 0
fi

TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_name', ''))
" 2>/dev/null) || TOOL_NAME=""
TOOL_INPUT=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {}) or {}
print(str(ti.get('command', ti.get('path', ti.get('file_path', ''))))[:600])
" 2>/dev/null) || TOOL_INPUT=""

# ── Verificación 1: tool de mutación directa ──────────────────────────────────
if echo "$TOOL_NAME" | grep -qE "^($MUTATION_TOOLS)$"; then
  echo "BLOQUEADO [SE-354]: '$TOOL_NAME' es una tool de mutación y la sesión está en read-only." >&2
  exit 2
fi

# ── Verificación 2: Bash con comando de mutación ──────────────────────────────
if [[ "$TOOL_NAME" == "Bash" ]]; then
  # Comando read-safe → permitido
  if echo "$TOOL_INPUT" | grep -qE "$WHITELIST_READ_SAFE"; then
    exit 0
  fi
  # Comando de mutación → bloqueado
  if echo "$TOOL_INPUT" | grep -qE "$MUTATION_CMDS"; then
    echo "BLOQUEADO [SE-354]: comando de mutación en sesión read-only: $TOOL_INPUT" >&2
    exit 2
  fi
fi

exit 0
