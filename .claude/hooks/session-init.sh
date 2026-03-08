#!/bin/bash
set -uo pipefail
# session-init.sh — Auto-carga de contexto al inicio de sesión
# Usado por: settings.json (SessionStart hook)
# v0.42.0 — Arranque garantizado: sin red, sin jq, fallo = salida limpia
#
# PRINCIPIO: Savia SIEMPRE arranca. Este script NUNCA puede bloquear el inicio.
# - Sin llamadas de red (ni gh api, ni curl, ni npx)
# - Sin dependencias externas (ni jq) — solo bash puro
# - Timeout global de 5s como safety net
# - Cualquier error → salida limpia con contexto mínimo

set -o pipefail

# ── Safety net: timeout global ────────────────────────────────────────────────
SCRIPT_START=$SECONDS
MAX_SECONDS=5

check_timeout() {
  if (( SECONDS - SCRIPT_START > MAX_SECONDS )); then
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"PM-Workspace Init (timeout):\\n- Savia lista (init parcial)"}}\n'
    exit 0
  fi
}

# ── Fallback: si algo falla, salida limpia ────────────────────────────────────
trap 'printf "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"PM-Workspace Init (ERR line %s):\\n- Savia lista\"}}\n" "$LINENO"; exit 1' ERR

# ── Arrays de contexto ────────────────────────────────────────────────────────
ITEMS=()

# ── Detectar modo agente ──────────────────────────────────────────────────────
AGENT_MODE="false"
if [ "${PM_CLIENT_TYPE:-}" = "agent" ] || [ "${AGENT_MODE:-}" = "true" ]; then
  AGENT_MODE="true"
fi

# ── PAT status (solo check fichero local, sin red) ───────────────────────────
check_timeout
PAT_FILE="$HOME/.azure/devops-pat"
if [ -f "$PAT_FILE" ] && [ -s "$PAT_FILE" ]; then
  ITEMS+=("PAT ok")
else
  ITEMS+=("PAT no configurado — \$HOME/.azure/devops-pat")
fi

# ── Perfil activo ────────────────────────────────────────────────────────────
check_timeout
ACTIVE_USER_FILE="$HOME/claude/.claude/profiles/active-user.md"
if [ -f "$ACTIVE_USER_FILE" ]; then
  ACTIVE_SLUG=$(grep -oP 'active_slug:\s*"\K[^"]+' "$ACTIVE_USER_FILE" 2>/dev/null || echo "")
  if [ -n "$ACTIVE_SLUG" ] && [ -d "$HOME/claude/.claude/profiles/users/$ACTIVE_SLUG" ]; then
    PROFILE_NAME=$(grep -oP 'name:\s*"\K[^"]+' "$HOME/claude/.claude/profiles/users/$ACTIVE_SLUG/identity.md" 2>/dev/null || echo "$ACTIVE_SLUG")
    PROFILE_ROLE=$(grep -oP 'role:\s*"\K[^"]+' "$HOME/claude/.claude/profiles/users/$ACTIVE_SLUG/identity.md" 2>/dev/null || echo "")
    if [ "$PROFILE_ROLE" = "Agent" ]; then
      AGENT_MODE="true"
      ITEMS+=("Perfil: $PROFILE_NAME (Agent)")
    else
      ITEMS+=("Perfil: $PROFILE_NAME")
    fi
  else
    ITEMS+=("Sin perfil — /profile-setup")
  fi
else
  ITEMS+=("Sin perfil — /profile-setup")
fi

# ── Rama git (local, sin red) ────────────────────────────────────────────────
check_timeout
# FIX: Use fallback with empty var check to handle git failures safely
BRANCH=$(git -C "$HOME/claude" branch --show-current 2>/dev/null || true)
BRANCH="${BRANCH:-N/A}"
ITEMS+=("Rama: $BRANCH")

# ── Company Savia inbox (filesystem-only, no network) ────────────────────────
check_timeout
COMPANY_CONFIG="$HOME/.pm-workspace/company-repo"
if [ -f "$COMPANY_CONFIG" ]; then
  CS_PATH=$(grep -oP 'LOCAL_PATH=\K.*' "$COMPANY_CONFIG" 2>/dev/null || echo "")
  CS_HANDLE=$(grep -oP 'USER_HANDLE=\K.*' "$COMPANY_CONFIG" 2>/dev/null || echo "")
  if [ -n "$CS_PATH" ] && [ -n "$CS_HANDLE" ] && [ -d "$CS_PATH" ]; then
    CS_PERSONAL=0; CS_ANNOUNCE=0
    [ -d "$CS_PATH/team/$CS_HANDLE/savia-inbox/unread" ] && \
      CS_PERSONAL=$(find "$CS_PATH/team/$CS_HANDLE/savia-inbox/unread" -name '*.md' 2>/dev/null | wc -l)
    CS_READ_LOG="$HOME/.pm-workspace/company-inbox-read.log"
    if [ -d "$CS_PATH/company-inbox" ]; then
      CS_TOTAL=$(find "$CS_PATH/company-inbox" -name '*.md' 2>/dev/null | wc -l)
      CS_READ=0; [ -f "$CS_READ_LOG" ] && CS_READ=$(wc -l < "$CS_READ_LOG")
      CS_ANNOUNCE=$((CS_TOTAL - CS_READ)); [ "$CS_ANNOUNCE" -lt 0 ] && CS_ANNOUNCE=0
    fi
    [ "$CS_PERSONAL" -gt 0 ] || [ "$CS_ANNOUNCE" -gt 0 ] && \
      ITEMS+=("📬 ${CS_PERSONAL} mensaje(s) · ${CS_ANNOUNCE} anuncio(s)")
  fi
fi

# ── Context tracking (best-effort, no bloquea) ──────────────────────────────
if [ -f "$HOME/claude/scripts/context-tracker.sh" ]; then
  bash "$HOME/claude/scripts/context-tracker.sh" log "session-init" "identity.md" "50" 2>/dev/null &
fi

# ── Variables de entorno ─────────────────────────────────────────────────────
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PM_WORKSPACE_ROOT=$HOME/claude" >> "$CLAUDE_ENV_FILE"
  echo "export PM_SESSION_DATE=$(date +%Y-%m-%d)" >> "$CLAUDE_ENV_FILE"
fi

# ── Generar output (bash puro, sin jq) ───────────────────────────────────────
CTX="PM-Workspace Init:"
for item in "${ITEMS[@]}"; do
  CTX="$CTX\\n- $item"
done

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$CTX"
