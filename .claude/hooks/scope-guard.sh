#!/bin/bash
# scope-guard.sh — Detecta ficheros modificados fuera del scope de la spec SDD activa
# Usado por: settings.json (Stop hook)
# Lógica: Si hay una spec activa con sección "Ficheros a Crear/Modificar",
#         compara los ficheros modificados (git diff) contra los declarados.
#         Si hay ficheros fuera del scope → warning al PM (exit 0, NO bloquea).
# Exit codes: 0 = pass (con warning si aplica), 2 = bloqueo (no usado aquí)

INPUT=$(cat)

# Buscar spec activa: la más reciente en el proyecto actual
# El agente SDD trabaja dentro de projects/{proyecto}/
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

# Obtener ficheros modificados (tracked, no staged + staged)
MODIFIED=$(git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null)
MODIFIED=$(echo "$MODIFIED" | sort -u | grep -v '^$')

if [ -z "$MODIFIED" ]; then
  exit 0
fi

# Buscar spec activa: fichero .spec.md más reciente modificado en los últimos 60 min
SPEC_FILE=$(find "$PROJECT_ROOT" -name "*.spec.md" -newer /tmp/.scope-guard-marker 2>/dev/null | head -1)

# Si no hay marker, buscar la spec más recientemente modificada
if [ -z "$SPEC_FILE" ]; then
  SPEC_FILE=$(find "$PROJECT_ROOT" -name "*.spec.md" -mmin -60 2>/dev/null | sort -t/ -k1,1 | tail -1)
fi

# Si no hay spec activa, no podemos verificar scope
if [ -z "$SPEC_FILE" ] || [ ! -f "$SPEC_FILE" ]; then
  exit 0
fi

# Extraer ficheros declarados en la spec
# Busca la sección "Ficheros a Crear/Modificar" o "Files to Create/Modify"
# y extrae paths de líneas que parecen rutas de fichero
DECLARED=$(sed -n '/[Ff]icheros\|[Ff]iles to [Cc]reate/,/^## /p' "$SPEC_FILE" \
  | grep -oE '[a-zA-Z0-9_./\-]+\.[a-z]{1,5}' \
  | sort -u)

if [ -z "$DECLARED" ]; then
  # La spec no tiene sección de ficheros declarados → no podemos verificar
  exit 0
fi

# Comparar: buscar ficheros modificados que NO están en la lista declarada
OUT_OF_SCOPE=""
for FILE in $MODIFIED; do
  BASENAME=$(basename "$FILE")
  # Verificar si el fichero o su basename está en los declarados
  MATCH=0
  for DECL in $DECLARED; do
    DECL_BASE=$(basename "$DECL")
    if [ "$FILE" = "$DECL" ] || [ "$BASENAME" = "$DECL_BASE" ]; then
      MATCH=1
      break
    fi
    # Match parcial: si el path declarado termina igual que el modificado
    if echo "$FILE" | grep -qF "$DECL"; then
      MATCH=1
      break
    fi
  done
  if [ "$MATCH" -eq 0 ]; then
    # Excluir ficheros que siempre son legítimos fuera del scope
    case "$BASENAME" in
      *.spec.md|*.test.*|*Test*|*test*|*.md|*.json|*.yml|*.yaml) continue ;;
      .gitignore|Dockerfile|docker-compose*|*.csproj|*.sln|package.json) continue ;;
    esac
    case "$FILE" in
      */test/*|*/tests/*|*/Test/*|*/Tests/*|*/__tests__/*) continue ;;
      */agent-notes/*|*/adrs/*|*/specs/*|*/output/*) continue ;;
    esac
    OUT_OF_SCOPE="$OUT_OF_SCOPE\n  - $FILE"
  fi
done

if [ -n "$OUT_OF_SCOPE" ]; then
  echo "⚠️ SCOPE GUARD: Ficheros modificados FUERA del scope de la spec activa ($SPEC_FILE):" >&2
  echo -e "$OUT_OF_SCOPE" >&2
  echo "" >&2
  echo "Revisa si estos cambios son intencionales o si el agente expandió el alcance." >&2
  echo "Ficheros declarados en la spec: $(echo "$DECLARED" | tr '\n' ', ')" >&2
  # Warning, no bloqueo — el PM decide
  exit 0
fi

exit 0
