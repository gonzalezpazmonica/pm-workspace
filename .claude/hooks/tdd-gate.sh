#!/bin/bash
# tdd-gate.sh — Verifica que existen tests antes de permitir edición de código de producción
# Usado por: developer agents (PreToolUse hook)
# Lógica: Si el agente intenta editar un fichero de producción (.cs, .py, .ts, .go, .rs, .rb, .php, .java)
#         y NO existe un fichero de test correspondiente, BLOQUEA con exit 2.
# Excepción: ficheros de config, migrations, DTOs, y el propio test se permiten siempre.

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=""

# Solo aplica a Edit y Write
if [ "$TOOL" = "Edit" ]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
elif [ "$TOOL" = "Write" ]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
else
  exit 0
fi

[ -z "$FILE_PATH" ] && exit 0

# Obtener extensión
EXT="${FILE_PATH##*.}"

# Solo verificar extensiones de código de producción
case "$EXT" in
  cs|py|ts|tsx|js|jsx|go|rs|rb|php|java|kt|swift|dart) ;;
  *) exit 0 ;;
esac

# Excluir ficheros que no necesitan TDD gate
BASENAME=$(basename "$FILE_PATH")
case "$BASENAME" in
  *Test*|*test*|*Spec*|*spec*|*_test.*|*.test.*|*.spec.*) exit 0 ;;
  *Migration*|*migration*|*.dto.*|*DTO*|*.config.*|*Config.*) exit 0 ;;
  *Program.cs|*Startup.cs|*appsettings*|*.csproj|*.sln) exit 0 ;;
  *.d.ts|*.config.ts|*.config.js|tsconfig*|package.json) exit 0 ;;
  Dockerfile|docker-compose*|*.tf|*.tfvars|*.yml|*.yaml) exit 0 ;;
  *.md|*.txt|*.json|*.xml|*.html|*.css|*.scss) exit 0 ;;
esac

# Excluir paths que no son código de producción
case "$FILE_PATH" in
  */test/*|*/tests/*|*/Test/*|*/Tests/*|*/__tests__/*) exit 0 ;;
  */spec/*|*/specs/*|*/Spec/*|*/Specs/*) exit 0 ;;
  */fixtures/*|*/mocks/*|*/stubs/*|*/fakes/*) exit 0 ;;
  */migrations/*|*/Migrations/*|*/seeds/*) exit 0 ;;
  */config/*|*/Config/*|*/scripts/*) exit 0 ;;
esac

# Buscar test correspondiente
DIR=$(dirname "$FILE_PATH")
NAME_NO_EXT="${BASENAME%.*}"
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

# Buscar test files que coincidan
TESTS_FOUND=$(find "$PROJECT_ROOT" -type f \( \
  -name "${NAME_NO_EXT}Test.*" -o \
  -name "${NAME_NO_EXT}Tests.*" -o \
  -name "${NAME_NO_EXT}.test.*" -o \
  -name "${NAME_NO_EXT}.spec.*" -o \
  -name "${NAME_NO_EXT}_test.*" -o \
  -name "test_${NAME_NO_EXT}.*" \
  \) 2>/dev/null | head -1)

if [ -z "$TESTS_FOUND" ]; then
  echo "TDD GATE: No se encontraron tests para '$BASENAME'. Escribe los tests ANTES de implementar el código de producción. Busca o crea: ${NAME_NO_EXT}Test.${EXT} o ${NAME_NO_EXT}.test.${EXT}" >&2
  exit 2
fi

exit 0
