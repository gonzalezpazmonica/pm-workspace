#!/bin/bash
set -uo pipefail
# session-init.sh — Arranque garantizado: sin red, sin jq, fallo = salida limpia

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

# ── Model capability detection (Era 100) ────────────────────────────────────
for rpath in "$HOME/claude/scripts/model-capability-resolver.sh" "./scripts/model-capability-resolver.sh"; do
  if [ -f "$rpath" ]; then
    while IFS= read -r _l; do
      case "$_l" in export\ SAVIA_*) declare "${_l#export }" 2>/dev/null ;; esac
    done < <(echo '' | bash "$rpath" 2>/dev/null || true)
    break
  fi
done

# ── Context snapshot recovery (Era 100.2) ───────────────────────────────────
SNAPSHOT_PROJ=""
for spath in "$HOME/claude/scripts/context-snapshot.sh" "./scripts/context-snapshot.sh"; do
  if [ -x "$spath" ]; then
    SNAPSHOT_PROJ=$(echo '' | bash "$spath" load 2>/dev/null | grep -o '"project":"[^"]*"' | cut -d'"' -f4) || true
    break
  fi
done

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
# FIX: Try multiple possible profile locations (CI may use different $HOME)
ACTIVE_USER_FILE=""
for profile_base in "$HOME/claude/.claude/profiles" "$HOME/.claude/profiles" "./.claude/profiles"; do
  candidate="$profile_base/active-user.md"
  if [ -f "$candidate" ] 2>/dev/null; then
    ACTIVE_USER_FILE="$candidate"
    break
  fi
done

if [ -f "$ACTIVE_USER_FILE" ]; then
  ACTIVE_SLUG=$(grep -oP 'active_slug:\s*"\K[^"]+' "$ACTIVE_USER_FILE" 2>/dev/null || echo "")
  PROFILE_DIR=$(dirname "$ACTIVE_USER_FILE")
  USERS_DIR="$PROFILE_DIR/users"

  if [ -n "$ACTIVE_SLUG" ] && [ -d "$USERS_DIR/$ACTIVE_SLUG" ]; then
    PROFILE_NAME=$(grep -oP 'name:\s*"\K[^"]+' "$USERS_DIR/$ACTIVE_SLUG/identity.md" 2>/dev/null || echo "$ACTIVE_SLUG")
    PROFILE_ROLE=$(grep -oP 'role:\s*"\K[^"]+' "$USERS_DIR/$ACTIVE_SLUG/identity.md" 2>/dev/null || echo "")
    PROFILE_LANG=$(grep -oP 'language:\s*"\K[^"]+' "$USERS_DIR/$ACTIVE_SLUG/preferences.md" 2>/dev/null || echo "")
    if [ "$PROFILE_ROLE" = "Agent" ]; then
      AGENT_MODE="true"
      ITEMS+=("Perfil: $PROFILE_NAME (Agent)")
    else
      ITEMS+=("Perfil: $PROFILE_NAME")
    fi
    [ -n "$PROFILE_LANG" ] && ITEMS+=("Idioma: $PROFILE_LANG")
  else
    ITEMS+=("Sin perfil — /profile-setup")
  fi
else
  ITEMS+=("Sin perfil — /profile-setup")
fi

# ── Rama git ──
check_timeout
BRANCH=""
for repo_path in "$HOME/claude" "$HOME/.claude" "." "$PWD"; do
  if [ -d "$repo_path/.git" ] 2>/dev/null; then
    BRANCH=$(git -C "$repo_path" branch --show-current 2>/dev/null || true)
    [ -n "$BRANCH" ] && break
  fi
done
BRANCH="${BRANCH:-N/A}"
ITEMS+=("Rama: $BRANCH")

# ── Recovered context from last session (Era 100.2) ──
if [ -n "$SNAPSHOT_PROJ" ] && [ "$SNAPSHOT_PROJ" != "none" ]; then
  ITEMS+=("Contexto recuperado: $SNAPSHOT_PROJ")
fi

# ── Company Savia inbox ──
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
TRACKER_SCRIPT=""
for script_path in "$HOME/claude/scripts/context-tracker.sh" "$HOME/scripts/context-tracker.sh" "./scripts/context-tracker.sh"; do
  if [ -f "$script_path" ] 2>/dev/null; then
    TRACKER_SCRIPT="$script_path"
    break
  fi
done
if [ -n "$TRACKER_SCRIPT" ]; then
  bash "$TRACKER_SCRIPT" log "session-init" "identity.md" "50" 2>/dev/null &
fi

# ── Readiness check (ligero: solo verifica stamp) ─────────────────────────────
check_timeout
READINESS_STAMP="$HOME/.pm-workspace/.readiness-stamp"
if [ ! -f "$READINESS_STAMP" ] 2>/dev/null; then
  ITEMS+=("Readiness: no verificado — bash scripts/readiness-check.sh")
else
  STAMP_DATE=$(cat "$READINESS_STAMP" 2>/dev/null || echo "0")
  CURRENT_HASH=$(git -C "${HOME}/claude" rev-parse --short HEAD 2>/dev/null || echo "x")
  if [ "$STAMP_DATE" != "$CURRENT_HASH" ]; then
    ITEMS+=("Readiness: actualizado — bash scripts/readiness-check.sh")
  fi
fi

# ── Ollama pre-warm (Era 149: Data Sovereignty) ───────────────────────────────
check_timeout
if command -v curl >/dev/null 2>&1; then
  if curl -s --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    # Ollama running — pre-warm model to avoid 9s cold-start on first classify
    curl -s --max-time 3 http://127.0.0.1:11434/api/generate \
      -d '{"model":"qwen2.5:7b","prompt":"hi","stream":false,"options":{"num_predict":1}}' \
      >/dev/null 2>&1 &
    ITEMS+=("Ollama: modelo pre-cargado en RAM")
  fi
fi

# ── Shield daemon pre-warm (SPEC-071: reduce NER cold start) ─────────────────
check_timeout
SHIELD_PORT="${SAVIA_SHIELD_PORT:-8444}"
if command -v curl >/dev/null 2>&1; then
  if curl -sf --max-time 2 "http://127.0.0.1:$SHIELD_PORT/health" >/dev/null 2>&1; then
    ITEMS+=("Shield: daemon activo")
  fi
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

# Regenerar manifesto si está desactualizado (skills más nuevos que el manifesto)
MANIFEST=".claude/skill-manifests.json"
if [[ ! -f "$MANIFEST" ]] || find .claude/skills -name "SKILL.md" -newer "$MANIFEST" | grep -q .; then
  bash scripts/build-skill-manifest.sh >/dev/null 2>&1 &
fi

# Limpieza de auto-memory en background (SPEC-142)
for mh_path in "$HOME/claude/scripts/memory-hygiene.sh" "./scripts/memory-hygiene.sh"; do
  if [ -f "$mh_path" ]; then
    bash "$mh_path" >/dev/null 2>&1 &
    break
  fi
done

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$CTX"
