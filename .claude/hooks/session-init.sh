#!/bin/bash
# session-init.sh — Auto-carga de contexto al inicio de sesión
# Usado por: settings.json (SessionStart hook)
# v0.41.0 — Sistema de prioridades con budget máximo de 300 tokens

# ── Budget y prioridades ────────────────────────────────────────────────────
# Prioridad CRÍTICA (siempre): PAT, perfil activo, rama git
# Prioridad ALTA (si aplica): Actualización disponible, error herramientas
# Prioridad MEDIA (condicional): Backup reminder, emergency plan
# Prioridad BAJA (probabilística): Community tip
# Budget máximo: ~300 tokens de additionalContext
# ────────────────────────────────────────────────────────────────────────────

MAX_ITEMS=8  # Máx. items en output para no saturar

# ── Arrays de prioridad ─────────────────────────────────────────────────────
CRITICAL_ITEMS=()
HIGH_ITEMS=()
MEDIUM_ITEMS=()
LOW_ITEMS=()

# ── Detectar modo agente ────────────────────────────────────────────────────
AGENT_MODE="false"
if [ "${PM_CLIENT_TYPE:-}" = "agent" ] || [ "${AGENT_MODE:-}" = "true" ]; then
  AGENT_MODE="true"
fi

# ── CRÍTICA: PAT ────────────────────────────────────────────────────────────
PAT_FILE="$HOME/.azure/devops-pat"
if [ -f "$PAT_FILE" ] && [ -s "$PAT_FILE" ]; then
  CRITICAL_ITEMS+=("PAT ✅")
else
  CRITICAL_ITEMS+=("PAT ❌ — Configura \$HOME/.azure/devops-pat")
fi

# ── CRÍTICA: Perfil activo ──────────────────────────────────────────────────
ACTIVE_USER_FILE="$HOME/claude/.claude/profiles/active-user.md"
if [ -f "$ACTIVE_USER_FILE" ]; then
  ACTIVE_SLUG=$(grep -oP 'active_slug:\s*"\K[^"]+' "$ACTIVE_USER_FILE" 2>/dev/null || echo "")
  if [ -n "$ACTIVE_SLUG" ] && [ -d "$HOME/claude/.claude/profiles/users/$ACTIVE_SLUG" ]; then
    PROFILE_NAME=$(grep -oP 'name:\s*"\K[^"]+' "$HOME/claude/.claude/profiles/users/$ACTIVE_SLUG/identity.md" 2>/dev/null || echo "$ACTIVE_SLUG")
    PROFILE_ROLE=$(grep -oP 'role:\s*"\K[^"]+' "$HOME/claude/.claude/profiles/users/$ACTIVE_SLUG/identity.md" 2>/dev/null || echo "")
    if [ "$PROFILE_ROLE" = "Agent" ]; then
      AGENT_MODE="true"
      CRITICAL_ITEMS+=("Perfil: $PROFILE_NAME (Agent) — MODO AGENTE")
    else
      CRITICAL_ITEMS+=("Perfil: $PROFILE_NAME ✅")
    fi
  else
    if [ "$AGENT_MODE" = "true" ]; then
      CRITICAL_ITEMS+=("⚠️ AGENTE SIN PERFIL — error YAML NO_PROFILE")
    else
      CRITICAL_ITEMS+=("⚠️ SIN PERFIL — Lee .claude/profiles/savia.md → /profile-setup")
    fi
  fi
else
  if [ "$AGENT_MODE" = "true" ]; then
    CRITICAL_ITEMS+=("⚠️ AGENTE SIN PERFIL — error YAML NO_PROFILE")
  else
    CRITICAL_ITEMS+=("⚠️ SIN PERFIL — Lee .claude/profiles/savia.md → /profile-setup")
  fi
fi

# ── CRÍTICA: Rama git ───────────────────────────────────────────────────────
BRANCH=$(git -C "$HOME/claude" branch --show-current 2>/dev/null || echo "N/A")
CRITICAL_ITEMS+=("Rama: $BRANCH")

# ── ALTA: Herramientas con errores ──────────────────────────────────────────
TOOLS_MISSING=""
for TOOL in az gh jq; do
  if ! command -v "$TOOL" &> /dev/null; then
    TOOLS_MISSING="$TOOLS_MISSING $TOOL"
  fi
done
if [ -n "$TOOLS_MISSING" ]; then
  HIGH_ITEMS+=("Herramientas faltantes:$TOOLS_MISSING")
fi

# ── ALTA: Actualización disponible ──────────────────────────────────────────
UPDATE_CONFIG="$HOME/.pm-workspace/update-config"
if [ -f "$UPDATE_CONFIG" ]; then
  AUTO_CHECK=$(grep -oP 'auto_check=\K\w+' "$UPDATE_CONFIG" 2>/dev/null || echo "true")
  LAST_CHECK=$(grep -oP 'last_check=\K\d+' "$UPDATE_CONFIG" 2>/dev/null || echo "0")
else
  AUTO_CHECK="true"
  LAST_CHECK="0"
fi

if [ "$AUTO_CHECK" = "true" ]; then
  NOW=$(date +%s)
  DIFF=$((NOW - LAST_CHECK))
  if [ "$DIFF" -gt 604800 ]; then
    LATEST=$(timeout 5 gh api repos/gonzalezpazmonica/pm-workspace/releases/latest --jq '.tag_name' 2>/dev/null || echo "")
    CURRENT=$(git -C "$HOME/claude" describe --tags --abbrev=0 2>/dev/null || echo "")
    if [ -n "$LATEST" ] && [ -n "$CURRENT" ] && [ "$LATEST" != "$CURRENT" ]; then
      HIGH_ITEMS+=("🆕 Update: $CURRENT → $LATEST — /update")
    fi
    mkdir -p "$HOME/.pm-workspace"
    if [ -f "$UPDATE_CONFIG" ]; then
      sed -i "s/last_check=.*/last_check=$NOW/" "$UPDATE_CONFIG"
    else
      printf "auto_check=true\nlast_check=%s\ncheck_interval=604800\n" "$NOW" > "$UPDATE_CONFIG"
    fi
  fi
fi

# ── MEDIA: Backup ───────────────────────────────────────────────────────────
BACKUP_CONFIG="$HOME/.pm-workspace/backup-config"
if [ "$AGENT_MODE" = "false" ]; then
  if [ ! -f "$BACKUP_CONFIG" ]; then
    MEDIUM_ITEMS+=("💾 Sin backup — /backup now")
  else
    BACKUP_AUTO=$(grep -oP 'auto_backup=\K\w+' "$BACKUP_CONFIG" 2>/dev/null || echo "false")
    BACKUP_LAST=$(grep -oP 'last_backup=\K\d+' "$BACKUP_CONFIG" 2>/dev/null || echo "0")
    if [ "$BACKUP_AUTO" = "true" ] && [ "$BACKUP_LAST" != "0" ]; then
      BACKUP_NOW=$(date +%s)
      BACKUP_DIFF=$((BACKUP_NOW - BACKUP_LAST))
      if [ "$BACKUP_DIFF" -gt 86400 ]; then
        MEDIUM_ITEMS+=("💾 Backup >24h — /backup now")
      fi
    fi
  fi
fi

# ── MEDIA: Emergency plan ───────────────────────────────────────────────────
PLAN_MARKER="$HOME/.pm-workspace-emergency/.plan-executed"
if [ ! -f "$PLAN_MARKER" ]; then
  MEDIUM_ITEMS+=("⚠️ Emergency plan pendiente — /emergency-plan")
fi

# ── BAJA: Community tip (1/20) ──────────────────────────────────────────────
if [ "$AGENT_MODE" = "false" ]; then
  RANDOM_NUM=$((RANDOM % 20))
  if [ "$RANDOM_NUM" -eq 0 ]; then
    LOW_ITEMS+=("💡 /contribute idea o /feedback bug")
  fi
fi

# ── Context tracking (registrar sesión) ─────────────────────────────────────
if [ -f "$HOME/claude/scripts/context-tracker.sh" ]; then
  bash "$HOME/claude/scripts/context-tracker.sh" log "session-init" "identity.md" "50" 2>/dev/null || true
fi

# ── Construir output con budget ─────────────────────────────────────────────
ITEMS=()
COUNT=0

# Críticos siempre entran
for item in "${CRITICAL_ITEMS[@]}"; do
  ITEMS+=("$item")
  ((COUNT++))
done

# Altos si hay espacio
for item in "${HIGH_ITEMS[@]}"; do
  if [ "$COUNT" -lt "$MAX_ITEMS" ]; then
    ITEMS+=("$item")
    ((COUNT++))
  fi
done

# Medios si hay espacio
for item in "${MEDIUM_ITEMS[@]}"; do
  if [ "$COUNT" -lt "$MAX_ITEMS" ]; then
    ITEMS+=("$item")
    ((COUNT++))
  fi
done

# Bajos solo si queda espacio suficiente
for item in "${LOW_ITEMS[@]}"; do
  if [ "$COUNT" -lt "$((MAX_ITEMS - 1))" ]; then
    ITEMS+=("$item")
    ((COUNT++))
  fi
done

# ── Establecer variables de entorno ─────────────────────────────────────────
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PM_WORKSPACE_ROOT=$HOME/claude" >> "$CLAUDE_ENV_FILE"
  echo "export PM_SESSION_DATE=$(date +%Y-%m-%d)" >> "$CLAUDE_ENV_FILE"
fi

# ── Generar output JSON ────────────────────────────────────────────────────
ADDITIONAL_CONTEXT="PM-Workspace Init:"
for item in "${ITEMS[@]}"; do
  ADDITIONAL_CONTEXT="$ADDITIONAL_CONTEXT\n- $item"
done

jq -n --arg ctx "$ADDITIONAL_CONTEXT" \
'{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
