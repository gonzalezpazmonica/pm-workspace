#!/bin/bash
set -uo pipefail
# ast-quality-gate-hook.sh — PostToolUse async hook para AST Quality Gate
# Usado por: settings.json (PostToolUse, async: true)
# Trigger: tras Edit|Write en sesiones SDD
# Acción: ejecuta quality gate sobre el fichero modificado en background
# Output: output/quality-gates/latest.json

INPUT=$(cat 2>/dev/null || true)
FILE_PATH=""

if [[ -n "$INPUT" ]]; then
  if command -v jq &>/dev/null; then
    FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || FILE_PATH=""
  fi
fi

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Solo procesar ficheros de código fuente (excluir docs, config, outputs)
EXT="${FILE_PATH##*.}"
case "$EXT" in
  cs|vb|csproj|sln|\
  ts|tsx|js|jsx|mts|cts|\
  py|pyi|\
  go|\
  rs|\
  php|\
  swift|\
  kt|kts|\
  rb|\
  java|\
  tf|tfvars|\
  dart|\
  cob|cbl|cpy)
    # Fichero de código → continuar
    ;;
  *)
    # No es código fuente → salir silenciosamente
    exit 0
    ;;
esac

# Verificar que el fichero existe
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Localizar el script del gate
WORKSPACE_ROOT=""
if [[ -f "$FILE_PATH" ]]; then
  # Subir hasta encontrar la raíz del workspace (donde está scripts/)
  DIR="$(cd "$(dirname "$FILE_PATH")" && pwd)"
  while [[ "$DIR" != "/" ]]; do
    if [[ -f "$DIR/scripts/ast-quality-gate.sh" ]]; then
      WORKSPACE_ROOT="$DIR"
      break
    fi
    DIR="$(dirname "$DIR")"
  done
fi

# Fallback: usar directorio de trabajo actual
if [[ -z "$WORKSPACE_ROOT" ]] && [[ -f "scripts/ast-quality-gate.sh" ]]; then
  WORKSPACE_ROOT="$(pwd)"
fi

if [[ -z "$WORKSPACE_ROOT" ]]; then
  # Gate no disponible — salir silenciosamente (no bloquear flujo)
  exit 0
fi

GATE_SCRIPT="$WORKSPACE_ROOT/scripts/ast-quality-gate.sh"

if [[ ! -x "$GATE_SCRIPT" ]]; then
  chmod +x "$GATE_SCRIPT" 2>/dev/null || true
fi

# Crear directorio de output si no existe
mkdir -p "$WORKSPACE_ROOT/output/quality-gates" 2>/dev/null || true

# Ejecutar gate en modo advisory (no bloquear el flujo async)
# El resultado se escribe en latest.json para consulta posterior
LATEST="$WORKSPACE_ROOT/output/quality-gates/latest.json"

if bash "$GATE_SCRIPT" "$FILE_PATH" --advisory > /dev/null 2>&1; then
  # Copiar el más reciente al alias latest.json
  NEWEST=$(ls -t "$WORKSPACE_ROOT/output/quality-gates/"*.json 2>/dev/null | grep -v latest | head -1)
  if [[ -n "$NEWEST" ]]; then
    cp "$NEWEST" "$LATEST" 2>/dev/null || true
  fi
fi

exit 0
