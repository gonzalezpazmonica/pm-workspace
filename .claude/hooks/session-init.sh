#!/bin/bash
# session-init.sh — Auto-carga de contexto al inicio de sesión
# Usado por: settings.json (SessionStart hook)

# Verificar PAT configurado
PAT_FILE="$HOME/.azure/devops-pat"
if [ -f "$PAT_FILE" ] && [ -s "$PAT_FILE" ]; then
  PAT_STATUS="PAT configurado ✅"
else
  PAT_STATUS="PAT NO configurado ❌ — Configura \$HOME/.azure/devops-pat"
fi

# Verificar herramientas disponibles
TOOLS_STATUS=""
for TOOL in az gh jq node python3; do
  if command -v "$TOOL" &> /dev/null; then
    TOOLS_STATUS="$TOOLS_STATUS $TOOL ✅"
  else
    TOOLS_STATUS="$TOOLS_STATUS $TOOL ❌"
  fi
done

# Obtener rama actual y últimos commits
BRANCH=$(git -C "$HOME/claude" branch --show-current 2>/dev/null || echo "N/A")
LAST_COMMITS=$(git -C "$HOME/claude" log --oneline -3 2>/dev/null || echo "N/A")

# Verificar si emergency-plan se ha ejecutado alguna vez
EMERGENCY_PLAN_STATUS=""
PLAN_MARKER="$HOME/.pm-workspace-emergency/.plan-executed"
if [ -f "$PLAN_MARKER" ]; then
  EMERGENCY_PLAN_STATUS="Emergency plan: OK ✅"
else
  EMERGENCY_PLAN_STATUS="Emergency plan: NO ejecutado ⚠️ — Ejecuta /emergency-plan para preparar contingencia offline"
fi

# Detectar si el cliente es un agente (por variable de entorno)
AGENT_MODE="false"
if [ "${PM_CLIENT_TYPE:-}" = "agent" ] || [ "${AGENT_MODE:-}" = "true" ]; then
  AGENT_MODE="true"
fi

# Verificar si hay perfil de usuario activo
PROFILE_STATUS=""
ACTIVE_USER_FILE="$HOME/claude/.claude/profiles/active-user.md"
if [ -f "$ACTIVE_USER_FILE" ]; then
  ACTIVE_SLUG=$(grep -oP 'active_slug:\s*"\K[^"]+' "$ACTIVE_USER_FILE" 2>/dev/null || echo "")
  if [ -n "$ACTIVE_SLUG" ] && [ -d "$HOME/claude/.claude/profiles/users/$ACTIVE_SLUG" ]; then
    PROFILE_NAME=$(grep -oP 'name:\s*"\K[^"]+' "$HOME/claude/.claude/profiles/users/$ACTIVE_SLUG/identity.md" 2>/dev/null || echo "$ACTIVE_SLUG")
    PROFILE_ROLE=$(grep -oP 'role:\s*"\K[^"]+' "$HOME/claude/.claude/profiles/users/$ACTIVE_SLUG/identity.md" 2>/dev/null || echo "")
    if [ "$PROFILE_ROLE" = "Agent" ]; then
      AGENT_MODE="true"
      PROFILE_STATUS="Perfil activo: $PROFILE_NAME (Agent) ✅ — MODO AGENTE: output estructurado YAML/JSON, sin narrativa"
    else
      PROFILE_STATUS="Perfil activo: $PROFILE_NAME ✅"
    fi
  else
    if [ "$AGENT_MODE" = "true" ]; then
      PROFILE_STATUS="⚠️ AGENTE SIN PERFIL — Responder con error YAML NO_PROFILE. Ver modo agente en .claude/profiles/savia.md"
    else
      PROFILE_STATUS="⚠️ SIN PERFIL — Savia no te conoce aún. Lee .claude/profiles/savia.md y preséntate como Savia al usuario, luego ejecuta /profile-setup"
    fi
  fi
else
  if [ "$AGENT_MODE" = "true" ]; then
    PROFILE_STATUS="⚠️ AGENTE SIN PERFIL — Responder con error YAML NO_PROFILE. Ver modo agente en .claude/profiles/savia.md"
  else
    PROFILE_STATUS="⚠️ SIN PERFIL — Savia no te conoce aún. Lee .claude/profiles/savia.md y preséntate como Savia al usuario, luego ejecuta /profile-setup"
  fi
fi

# Check semanal de actualizaciones
UPDATE_STATUS=""
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
  if [ "$DIFF" -gt 604800 ]; then  # 7 días
    LATEST=$(timeout 5 gh api repos/gonzalezpazmonica/pm-workspace/releases/latest --jq '.tag_name' 2>/dev/null || echo "")
    CURRENT=$(git -C "$HOME/claude" describe --tags --abbrev=0 2>/dev/null || echo "")
    if [ -n "$LATEST" ] && [ -n "$CURRENT" ] && [ "$LATEST" != "$CURRENT" ]; then
      UPDATE_STATUS="🆕 Actualización disponible: $CURRENT → $LATEST — Ejecuta /update para actualizar"
    fi
    # Actualizar timestamp
    mkdir -p "$HOME/.pm-workspace"
    if [ -f "$UPDATE_CONFIG" ]; then
      sed -i "s/last_check=.*/last_check=$NOW/" "$UPDATE_CONFIG"
    else
      printf "auto_check=true\nlast_check=%s\ncheck_interval=604800\n" "$NOW" > "$UPDATE_CONFIG"
    fi
  fi
fi

# Establecer variables de entorno si CLAUDE_ENV_FILE existe
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo "export PM_WORKSPACE_ROOT=$HOME/claude" >> "$CLAUDE_ENV_FILE"
  echo "export PM_SESSION_DATE=$(date +%Y-%m-%d)" >> "$CLAUDE_ENV_FILE"
fi

# Devolver contexto como additionalContext para Claude
# Construir contexto adicional
ADDITIONAL_CONTEXT="PM-Workspace Session Init:\n- $PAT_STATUS\n- Herramientas:$TOOLS_STATUS\n- $EMERGENCY_PLAN_STATUS\n- $PROFILE_STATUS"
if [ -n "$UPDATE_STATUS" ]; then
  ADDITIONAL_CONTEXT="$ADDITIONAL_CONTEXT\n- $UPDATE_STATUS"
fi
ADDITIONAL_CONTEXT="$ADDITIONAL_CONTEXT\n- Rama: $BRANCH\n- Últimos commits:\n$LAST_COMMITS"

jq -n --arg ctx "$ADDITIONAL_CONTEXT" \
'{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
