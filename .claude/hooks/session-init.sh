#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
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

# ── External memory bootstrap (SPEC-110) ─────────────────────────────────────
check_timeout
MEMORY_MODE=""
for mb_path in "$HOME/claude/scripts/savia-memory-bootstrap.sh" "./scripts/savia-memory-bootstrap.sh"; do
  if [ -f "$mb_path" ]; then
    MEMORY_OUT=$(bash "$mb_path" 2>/dev/null | tail -1)
    MEMORY_MODE=$(echo "$MEMORY_OUT" | grep -oE '"mode":"[^"]+"' | cut -d'"' -f4)
    break
  fi
done
case "$MEMORY_MODE" in
  canonical)     ITEMS+=("Memoria: ../.savia-memory (canónico)") ;;
  repo-local)    ITEMS+=("Memoria: repo/.savia-memory (fallback)") ;;
  home-fallback) ITEMS+=("Memoria: \$HOME/.savia-memory (fallback)") ;;
esac

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

    # ── ND Profile detection (SPEC-061) ──────────────────────────────────────
    ND_FILE="$USERS_DIR/$ACTIVE_SLUG/neurodivergent.md"
    if [ -f "$ND_FILE" ] 2>/dev/null; then
      # Check if any dimension is active (not all commented out)
      if grep -qE '^\s*(adhd|autism|dyslexia|giftedness|dyscalculia):' "$ND_FILE" 2>/dev/null && \
         grep -qE 'present:\s*true' "$ND_FILE" 2>/dev/null; then
        if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
          echo "export SAVIA_ND_ACTIVE=true" >> "$CLAUDE_ENV_FILE"
        fi
        # Run auto-config in background (ND→accessibility mapping)
        for nd_script in "$HOME/claude/scripts/nd-autoconfig.sh" "./scripts/nd-autoconfig.sh"; do
          if [ -f "$nd_script" ]; then
            bash "$nd_script" "$ND_FILE" "$USERS_DIR/$ACTIVE_SLUG/accessibility.md" >/dev/null 2>&1 &
            break
          fi
        done
      fi
    fi
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

# ── Nido detection (Savia Nidos — parallel terminal isolation) ──
check_timeout
SAVIA_NIDO=""
NIDOS_BASE=""
case "${OSTYPE:-}" in
  msys*|cygwin*) NIDOS_BASE="${USERPROFILE:-$HOME}/.savia/nidos" ;;
  *)             NIDOS_BASE="$HOME/.savia/nidos" ;;
esac
# Normalize to POSIX path for Git Bash comparison ($PWD is /c/Users/...)
NIDOS_CMP="$NIDOS_BASE"
if command -v cygpath >/dev/null 2>&1; then
  NIDOS_CMP=$(cygpath -u "$NIDOS_BASE" 2>/dev/null) || NIDOS_CMP="$NIDOS_BASE"
elif [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* ]]; then
  NIDOS_CMP="${NIDOS_BASE//\\//}"
  if [[ "$NIDOS_CMP" =~ ^([A-Za-z]):/ ]]; then
    _drv=$(echo "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')
    NIDOS_CMP="/${_drv}${NIDOS_CMP:2}"
  fi
fi
if [[ "$PWD" == "$NIDOS_CMP"/* ]]; then
  SAVIA_NIDO="${PWD#"$NIDOS_CMP"/}"
  SAVIA_NIDO="${SAVIA_NIDO%%/*}"
  NIDO_BRANCH=$(git branch --show-current 2>/dev/null | tr -d '\r')
  ITEMS+=("Nido: $SAVIA_NIDO | Rama nido: ${NIDO_BRANCH:-N/A}")
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export SAVIA_NIDO=$SAVIA_NIDO" >> "$CLAUDE_ENV_FILE"
  fi
fi

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

# ── Shield auto-start + health check (SPEC-071) ─────────────────────────────
check_timeout
SHIELD_PORT="${SAVIA_SHIELD_PORT:-8444}"
SHIELD_PROXY_PORT="${SAVIA_SHIELD_PROXY_PORT:-8443}"
if command -v curl >/dev/null 2>&1; then
  if curl -sf --max-time 2 "http://127.0.0.1:$SHIELD_PORT/health" >/dev/null 2>&1; then
    ITEMS+=("Shield: daemon activo")
  fi
  if curl -sf --max-time 2 "http://127.0.0.1:$SHIELD_PROXY_PORT/health" >/dev/null 2>&1; then
    ITEMS+=("Shield proxy: activo (localhost:$SHIELD_PROXY_PORT)")
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

# Regenerar .scm (Savia Capability Map) si hay recursos nuevos/modificados.
# Determinístico: solo corre si algún fichero de commands/skills/agents/scripts
# es más reciente que el INDEX.scm. ENTERAMENTE en background — el find sobre
# 991 ficheros añade ~100ms al hook síncrono, así que el check + regen corren
# juntos en subshell para mantener el hook por debajo del umbral de latencia.
(
  SCM_INDEX=".scm/INDEX.scm"
  if [[ ! -f "$SCM_INDEX" ]] || \
     find .claude/commands .claude/skills .claude/agents scripts \
          \( -name "*.md" -o -name "*.sh" \) -newer "$SCM_INDEX" -print -quit 2>/dev/null | grep -q .; then
    python3 scripts/generate-capability-map.py >/dev/null 2>&1
  fi
) &
disown 2>/dev/null || true

# Limpieza de auto-memory en background (SPEC-142)
for mh_path in "$HOME/claude/scripts/memory-hygiene.sh" "./scripts/memory-hygiene.sh"; do
  if [ -f "$mh_path" ]; then
    bash "$mh_path" >/dev/null 2>&1 &
    break
  fi
done

# Context rotation check (SE-033) — async, non-blocking
for cr_path in "$HOME/claude/scripts/context-rotation.sh" "./scripts/context-rotation.sh"; do
  if [ -f "$cr_path" ]; then
    bash "$cr_path" daily >/dev/null 2>&1 &
    DOW=$(date +%u)
    [[ "$DOW" == "1" ]] && bash "$cr_path" weekly >/dev/null 2>&1 &
    DOM=$(date +%d)
    [[ "$DOM" == "01" ]] && bash "$cr_path" monthly >/dev/null 2>&1 &
    break
  fi
done

# Ensure git merge drivers from .gitattributes are wired in local git config.
# Idempotent and silent. Without this, merge=ours in .gitattributes is a no-op.
# Gracefully handles unset CLAUDE_PROJECT_DIR (e.g. when hook is tested in isolation).
_setup_md_dir="${CLAUDE_PROJECT_DIR:-${PWD:-.}}"
if [[ -x "$_setup_md_dir/scripts/setup-merge-drivers.sh" ]]; then
  bash "$_setup_md_dir/scripts/setup-merge-drivers.sh" >/dev/null 2>&1 || true
fi

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$CTX"
