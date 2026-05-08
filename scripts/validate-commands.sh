#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# validate-commands.sh — Validación estática de slash commands
# Ejecutar ANTES de cada commit que toque .opencode/commands/
# ─────────────────────────────────────────────────────────────────────
set -euo pipefail

COMMANDS_DIR=".claude/commands"
CLAUDE_MD="CLAUDE.md"
MAX_PROMPT_LINES=200  # Umbral seguro: comando + CLAUDE.md cabe en contexto
ERRORS=0
WARNINGS=0

# Colores
RED='\033[0;31m'; YEL='\033[0;33m'; GRN='\033[0;32m'; NC='\033[0m'

err()  { echo -e "${RED}ERROR${NC}  $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e "${YEL}WARN${NC}   $1"; WARNINGS=$((WARNINGS + 1)); }
ok()   { echo -e "${GRN}OK${NC}     $1"; }

# ── Si se pasan ficheros concretos, validar solo esos; si no, todos ──
if [ $# -gt 0 ]; then
  FILES=("$@")
else
  FILES=()
  for f in "$COMMANDS_DIR"/*.md; do
    [ -f "$f" ] && FILES+=("$f")
  done
fi

if [ ${#FILES[@]} -eq 0 ]; then
  echo "No hay comandos que validar."
  exit 0
fi

CLAUDE_LINES=0
[ -f "$CLAUDE_MD" ] && CLAUDE_LINES=$(wc -l < "$CLAUDE_MD")

echo "══════════════════════════════════════════════════"
echo "  Validando ${#FILES[@]} comando(s)"
echo "  CLAUDE.md: ${CLAUDE_LINES} líneas"
echo "══════════════════════════════════════════════════"
echo ""

for CMD in "${FILES[@]}"; do
  NAME=$(basename "$CMD")
  LINES=$(wc -l < "$CMD")
  TOTAL=$((LINES + CLAUDE_LINES))
  PREV_ERRORS=$ERRORS

  echo "── $NAME ($LINES líneas, total estimado: $TOTAL) ──"

  # 1. Tamaño del fichero (regla 150 líneas)
  if [ "$LINES" -gt 150 ]; then
    err "$NAME excede 150 líneas ($LINES)"
  fi

  # 2. Prompt total estimado (comando + CLAUDE.md)
  if [ "$TOTAL" -gt "$MAX_PROMPT_LINES" ]; then
    warn "$NAME prompt estimado $TOTAL líneas (umbral: $MAX_PROMPT_LINES)"
  fi

  # 3. Fichero no vacío
  if [ "$LINES" -eq 0 ]; then
    err "$NAME está vacío"
    continue
  fi

  # 4. Referencias a ficheros locales — comprobar que existen
  # Only match references/ paths NOT preceded by @ (those are handled in check 5)
  # Also strip trailing backticks and markdown artifacts
  REFS=$(grep -oP '(?<!@[^\s]{0,80})(?<=references/)[^\s\)\`\*]+\.md' "$CMD" 2>/dev/null || true)
  for REF in $REFS; do
    # Skip if this reference is part of an @-path (already validated in check 5)
    if grep -qP "@[^\s]*references/$REF" "$CMD" 2>/dev/null; then
      continue
    fi
    REF_PATH="$COMMANDS_DIR/references/$REF"
    if [ ! -f "$REF_PATH" ]; then
      err "$NAME referencia '$REF' pero no existe $REF_PATH"
    fi
  done

  # 5. Referencias @rules — comprobar que existen
  # Strip trailing backticks, colons, asterisks, and quotes that markdown may add
  AT_REFS=$(grep -oP '@docs/rules/[^\s\)\`\*\:]+\.md' "$CMD" 2>/dev/null || true)
  for AREF in $AT_REFS; do
    AREF_PATH="${AREF#@}"
    if [ ! -f "$AREF_PATH" ]; then
      err "$NAME referencia '$AREF' pero no existe $AREF_PATH"
    fi
  done

  # 6. Comprobar que el nombre del fichero sigue convención (kebab-case)
  if ! echo "$NAME" | grep -qP '^[a-z0-9]+(-[a-z0-9]+)*\.md$'; then
    warn "$NAME no sigue kebab-case"
  fi

  # Si no hubo errores nuevos para este fichero
  if [ "$ERRORS" -eq "$PREV_ERRORS" ]; then
    ok "$NAME validado"
  fi

  echo ""
done

# ── Resumen ──────────────────────────────────────────────────────────
echo "══════════════════════════════════════════════════"
if [ "$ERRORS" -gt 0 ]; then
  echo -e "${RED}FALLÓ${NC}: $ERRORS error(es), $WARNINGS advertencia(s)"
  exit 1
elif [ "$WARNINGS" -gt 0 ]; then
  echo -e "${YEL}PASA con warnings${NC}: $WARNINGS advertencia(s)"
  exit 0
else
  echo -e "${GRN}TODO OK${NC}: ${#FILES[@]} comando(s) validados"
  exit 0
fi
