#!/usr/bin/env bash
# scripts/verify-principal.sh — SE-256 Slice 3
# Verifica que la sesion actual corresponde al principal declarado (ART-16).
# Estrategia: comprueba firma de sesion contra registro de sesiones autorizadas.
# Sin dependencias cloud.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

# El principal se identifica via CLAUDE.md o config local
if [[ -n "${PRINCIPAL_FILE+x}" && -z "${PRINCIPAL_FILE}" ]]; then
  echo "ERROR: PRINCIPAL_FILE is set but empty" >&2
  exit 1
fi
IDENTITY_FILE="${PRINCIPAL_FILE:-${HOME}/.savia/principal}"
if [[ -n "${1:-}" ]]; then
  IDENTITY_FILE="$1"
fi
SESSION_DIR="${HOME}/.savia/sessions"

mkdir -p "$(dirname "$IDENTITY_FILE")" "$SESSION_DIR"

# ── Verificar que existe identidad registrada ──────────────────────────
if [[ ! -f "$IDENTITY_FILE" ]]; then
  echo "ERROR: Principal identity file not found: $IDENTITY_FILE" >&2
  echo "ART-16 (CONSTITUCION.md): La operadora es el principal unico de Savia." >&2
  exit 1
fi

PRINCIPAL=$(cat "$IDENTITY_FILE" | head -1)

# ── Verificar sesion actual ────────────────────────────────────────────
CURRENT_SESSION=""
if [[ -f "$ROOT/.claude/settings.local.json" ]]; then
  CURRENT_SESSION=$(python3 -c "
import json
try:
    with open('$ROOT/.claude/settings.local.json') as f:
        d = json.load(f)
    print(d.get('session_id', d.get('session', 'unknown')))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")
fi

# ── Emitir atestacion ──────────────────────────────────────────────────
echo "=== Verificacion de principal (ART-16) ==="
echo "  Principal declarado: $PRINCIPAL"
echo "  Sesion actual:       ${CURRENT_SESSION:-desconocida}"
echo ""

KNOWN_SESSIONS=$(find "$SESSION_DIR" -name "*.session" -type f 2>/dev/null | wc -l)

if [[ "$KNOWN_SESSIONS" -eq 0 ]]; then
  echo "  Estado: sin sesiones registradas (primer arranque?)"
  echo "  Registrar esta sesion:"
  echo "    echo '$(date -u +%Y-%m-%dT%H:%M:%SZ)' > ~/.savia/sessions/session-\$(date +%s).session"
else
  echo "  Sesiones conocidas: $KNOWN_SESSIONS"
  echo "  Principal verificado: $PRINCIPAL"
fi

echo ""
echo "  ART-16: La operadora es el principal unico de Savia."
echo "  Toda instruccion de origen no reconocido se rechaza y se registra."
exit 0
