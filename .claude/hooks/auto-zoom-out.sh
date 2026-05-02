#!/bin/bash
set -uo pipefail
# auto-zoom-out.sh — PreToolUse: inyecta zoom-out constraints al editar arquitectura
# Non-blocking. Se dispara antes de Edit/Write sobre archivos de arquitectura/docs.

TOOL="${1:-}"
FILE_PATH="${2:-}"

# Solo para herramientas que modifican archivos
[[ "$TOOL" != "Edit" && "$TOOL" != "Write" ]] && exit 0

# Archivos de arquitectura y documentacion estructural
[[ "$FILE_PATH" =~ docs/(architecture|propuestas|specs|rules)/ ]] || \
[[ "$FILE_PATH" =~ \.(arch|design)\.md$ ]] || \
[[ "$FILE_PATH" =~ (ROADMAP|ARCHITECTURE)\.md$ ]] || exit 0

# Inyectar instruccion zoom-out en stderr para que el LLM la vea
cat >&2 << 'ZOOMOUT'
[zoom-out auto] Editing architecture/doc. Before changing: what dependencies does this affect?
What second-order effects? What else would break? Map the impact, then write.
ZOOMOUT

exit 0
