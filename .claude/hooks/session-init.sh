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

# Establecer variables de entorno si CLAUDE_ENV_FILE existe
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo "export PM_WORKSPACE_ROOT=$HOME/claude" >> "$CLAUDE_ENV_FILE"
  echo "export PM_SESSION_DATE=$(date +%Y-%m-%d)" >> "$CLAUDE_ENV_FILE"
fi

# Devolver contexto como additionalContext para Claude
jq -n --arg pat "$PAT_STATUS" \
      --arg tools "$TOOLS_STATUS" \
      --arg branch "$BRANCH" \
      --arg commits "$LAST_COMMITS" \
      --arg emergency "$EMERGENCY_PLAN_STATUS" \
'{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: ("PM-Workspace Session Init:\n- " + $pat + "\n- Herramientas:" + $tools + "\n- " + $emergency + "\n- Rama: " + $branch + "\n- Últimos commits:\n" + $commits)
  }
}'
