#!/usr/bin/env bash
set -uo pipefail
# live-progress-hook.sh — Logs every tool use to ~/.savia/live.log
# Event: PreToolUse | Async: true | Tier: observability (never blocks)

LOG="$HOME/.savia/live.log"
mkdir -p "$HOME/.savia"

# Read tool info from stdin (JSON)
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty' 2>/dev/null)

[[ -z "$TOOL_NAME" ]] && exit 0

TS=$(date "+%H:%M:%S")

# Rotate log if >500 lines
if [[ -f "$LOG" ]] && [[ $(wc -l < "$LOG") -gt 500 ]]; then
  tail -250 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

# Format message by tool type
case "$TOOL_NAME" in
  Bash)
    DESC=$(echo "$TOOL_INPUT" | jq -r '.description // .command' 2>/dev/null | head -c 80)
    echo "[$TS] ⚙  Ejecutando: $DESC" >> "$LOG"
    ;;
  Edit)
    FILE=$(echo "$TOOL_INPUT" | jq -r '.file_path' 2>/dev/null | sed 's|.*/||')
    echo "[$TS] ✏  Editando:   $FILE" >> "$LOG"
    ;;
  Write)
    FILE=$(echo "$TOOL_INPUT" | jq -r '.file_path' 2>/dev/null | sed 's|.*/||')
    echo "[$TS] 📝 Escribiendo: $FILE" >> "$LOG"
    ;;
  Read)
    FILE=$(echo "$TOOL_INPUT" | jq -r '.file_path' 2>/dev/null | sed 's|.*/||')
    echo "[$TS] 👁  Leyendo:    $FILE" >> "$LOG"
    ;;
  Agent)
    DESC=$(echo "$TOOL_INPUT" | jq -r '.description // .prompt' 2>/dev/null | head -c 60)
    echo "[$TS] 🤖 Agente:     $DESC" >> "$LOG"
    ;;
  Glob)
    PAT=$(echo "$TOOL_INPUT" | jq -r '.pattern' 2>/dev/null)
    echo "[$TS] 🔍 Buscando:   $PAT" >> "$LOG"
    ;;
  Grep)
    PAT=$(echo "$TOOL_INPUT" | jq -r '.pattern' 2>/dev/null | head -c 40)
    echo "[$TS] 🔎 Grep:       $PAT" >> "$LOG"
    ;;
  Skill)
    SKILL=$(echo "$TOOL_INPUT" | jq -r '.skill // empty' 2>/dev/null)
    echo "[$TS] ⚡ Skill:      $SKILL" >> "$LOG"
    ;;
  Task*)
    DESC=$(echo "$TOOL_INPUT" | jq -r '.description // .status // empty' 2>/dev/null | head -c 60)
    echo "[$TS] 📋 Task:       $TOOL_NAME $DESC" >> "$LOG"
    ;;
  *)
    echo "[$TS] 🔧 $TOOL_NAME" >> "$LOG"
    ;;
esac

exit 0
