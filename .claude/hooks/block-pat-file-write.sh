#!/bin/bash
set -uo pipefail
# block-pat-file-write.sh — SPEC-SE-036 Slice 3: bloquea escrituras a paths PAT.
#
# PreToolUse hook (matcher: Write, Edit) que impide que agentes autónomos
# escriban o editen ficheros cuyo path contiene "pat" (Personal Access Token),
# salvo que el path esté explícitamente gitignored (donde se permite almacenar
# el token como fallback durante la transición PAT→JWT).
#
# Lógica:
#   1. Extraer filePath del input JSON
#   2. Si el path NO contiene 'pat' (case-insensitive) → exit 0 (dejar pasar)
#   3. Si el path contiene 'pat':
#      a. Verificar si está gitignored: `git check-ignore -q <path>`
#      b. Si gitignored → exit 0 (permitido — fallback durante transición)
#      c. Si NO gitignored → BLOCKED + mensaje educativo (exit 2)
#
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md (AC-06)
# Aplica a: overnight-sprint, code-improvement-loop, cualquier agente autónomo

# Perfil: security (cargar si existe gate)
LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh" && profile_gate "security"
fi

INPUT=""
if INPUT=$(timeout 3 cat 2>/dev/null); then
  :
fi

if ! command -v jq &>/dev/null; then
  exit 0   # jq ausente: dejar pasar (no bloquear silenciosamente)
fi

# Extraer el path del fichero a escribir
FILE_PATH=""
if [[ -n "$INPUT" ]]; then
  FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null) || FILE_PATH=""
fi

if [[ -z "$FILE_PATH" ]]; then
  exit 0   # No hay path: no aplica
fi

# Verificar si el path contiene 'pat' (case-insensitive)
if ! echo "$FILE_PATH" | grep -qi 'pat'; then
  exit 0   # No es un path PAT
fi

# El path contiene 'pat': verificar si está gitignored
WORKSPACE_DIR="${CLAUDE_PROJECT_DIR:-${SAVIA_WORKSPACE_DIR:-$PWD}}"
if git -C "$WORKSPACE_DIR" check-ignore -q "$FILE_PATH" 2>/dev/null; then
  # Gitignored: permitido durante la transición PAT→JWT
  exit 0
fi

# Path PAT no gitignored: BLOQUEADO
cat >&2 << 'MSG'
BLOQUEADO [SPEC-SE-036]: Escritura a path PAT no permitida.

Los agentes autónomos no deben crear ni editar ficheros de Personal Access Token
fuera de paths gitignored. Esto aplica Rule #1 de CLAUDE.md a nivel de infraestructura.

Alternativas:
  - Usar JWT efímero: jwt-mint.sh --key-stdin --scope <scope>
  - Si necesitas PAT como fallback: asegura que el path está en .gitignore
    y confirma el path exacto de almacenamiento (~/.savia/secrets/ o $HOME/.azure/)

Ref: docs/propuestas/savia-enterprise/SPEC-SE-036-api-key-jwt-mint.md
     docs/rules/domain/savia-enterprise/agent-jwt-mint.md (sección Slice 3)
MSG

exit 2
