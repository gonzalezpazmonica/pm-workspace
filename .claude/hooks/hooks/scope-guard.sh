#!/bin/bash
set -uo pipefail
# scope-guard.sh — Detecta ficheros modificados fuera del scope de la spec SDD activa
# Usado por: settings.json (Stop hook)
# Lógica: Si hay una spec activa con sección "Ficheros a Crear/Modificar",
#         compara los ficheros modificados (git diff) contra los declarados.
#         Si hay ficheros fuera del scope → warning al PM (exit 0, NO bloquea).
# Exit codes: 0 = pass (con warning si aplica), 2 = bloqueo (no usado aquí)
# Profile tier: standard
# PERF: optimized 2026-05-07 — single git diff, maxdepth=4, early exit, declared specs cache

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh" && profile_gate "standard"
fi

INPUT=$(cat)

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

# Single git diff covers both staged + unstaged tracked changes
MODIFIED=$(git -C "$PROJECT_ROOT" diff HEAD --name-only 2>/dev/null | sort -u | grep -v '^$' || true)

if [ -z "$MODIFIED" ]; then
  exit 0
fi

# Restrict search to known SDD locations + maxdepth 4 (specs live at projects/{slug}/specs/ or docs/specs/)
SEARCH_PATHS=()
for p in "$PROJECT_ROOT/projects" "$PROJECT_ROOT/docs/specs" "$PROJECT_ROOT/docs/propuestas"; do
  [[ -d "$p" ]] && SEARCH_PATHS+=("$p")
done

# Early exit: no spec dirs → nothing to verify
if [[ ${#SEARCH_PATHS[@]} -eq 0 ]]; then
  exit 0
fi

SPEC_FILE=""
if [[ -n "${SAVIA_TMP:-}" && -f "$SAVIA_TMP/.scope-guard-marker" ]]; then
  SPEC_FILE=$(find "${SEARCH_PATHS[@]}" -maxdepth 4 \
    \( -name node_modules -o -name .git -o -name build -o -name dist -o -name target \) -prune -o \
    -name "*.spec.md" -newer "$SAVIA_TMP/.scope-guard-marker" -print 2>/dev/null | head -1)
fi

if [ -z "$SPEC_FILE" ]; then
  SPEC_FILE=$(find "${SEARCH_PATHS[@]}" -maxdepth 4 \
    \( -name node_modules -o -name .git -o -name build -o -name dist -o -name target \) -prune -o \
    -name "*.spec.md" -mmin -60 -print 2>/dev/null | head -1)
fi

if [ -z "$SPEC_FILE" ] || [ ! -f "$SPEC_FILE" ]; then
  exit 0
fi

# Extract declared files in spec — bullet lines only to avoid prose false-matches
DECLARED=$(sed -n '/[Ff]icheros\|[Ff]iles to [Cc]reate/,/^## /p' "$SPEC_FILE" \
  | grep -E '^[[:space:]]*[-*]' \
  | grep -oE '[a-zA-Z0-9_./\-]+\.[a-z]{1,5}' \
  | sort -u)

if [ -z "$DECLARED" ]; then
  exit 0
fi

# Compare modified vs declared
OUT_OF_SCOPE=""
for FILE in $MODIFIED; do
  BASENAME=$(basename "$FILE")
  MATCH=0
  for DECL in $DECLARED; do
    DECL_BASE=$(basename "$DECL")
    if [ "$FILE" = "$DECL" ] || [ "$BASENAME" = "$DECL_BASE" ]; then
      MATCH=1
      break
    fi
    if echo "$FILE" | grep -qF "$DECL"; then
      MATCH=1
      break
    fi
  done
  if [ "$MATCH" -eq 0 ]; then
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
  exit 0
fi

exit 0
