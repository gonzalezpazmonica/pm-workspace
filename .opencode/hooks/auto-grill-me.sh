#!/bin/bash
set -uo pipefail
# auto-grill-me.sh — PreToolUse: inyecta grill-me constraints al editar codigo
# Non-blocking. Se dispara antes de Edit/Write sobre archivos de codigo.

TOOL="${1:-}"
FILE_PATH="${2:-}"

# Solo para herramientas que modifican archivos
[[ "$TOOL" != "Edit" && "$TOOL" != "Write" ]] && exit 0

# Solo archivos de codigo
[[ "$FILE_PATH" =~ \.(py|sh|ts|js|cs|go|rs|java|rb|php|swift|kt|scala|ex|exs)$ ]] || exit 0

# Inyectar instruccion grill-me en stderr para que el LLM la vea
cat >&2 << 'GRILLME'
[grill-me auto] Editing code. Before writing, hunt: edge cases with empty/null/very-large inputs,
unstated assumptions, missing error handling, untested paths, silent failure modes.
GRILLME

exit 0
