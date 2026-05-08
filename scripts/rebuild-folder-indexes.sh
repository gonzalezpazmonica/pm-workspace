#!/usr/bin/env bash
# rebuild-folder-indexes.sh
#
# Regenera INDEX.md por subcarpeta del proyecto con tabla de ficheros recientes.
# Invocado por /project-update Fase 3.5 (agente idx-folders).
#
# Uso:
#   bash scripts/rebuild-folder-indexes.sh <slug>
#
# Salida:
#   stdout: JSON con resumen de INDEX.md regenerados
#   files:  actualiza projects/{slug}_main/{slug,slug-monica,slug-pm,slug-vass}/**/INDEX.md
#
# Reglas:
#   - Solo regenera INDEX.md de subcarpetas con >5 ficheros
#   - Crea uno si no existe
#   - Cabecera con "**Última actualización**: YYYY-MM-DD"
#   - Lista top 20 ficheros por mtime + extensión
#   - NO toca subcarpetas .git, .agent-maps, .human-maps, output, node_modules

set -uo pipefail

SLUG="${1:?Uso: $0 <slug>}"

WS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ_ROOT="$WS_ROOT/projects/${SLUG}_main"

if [[ ! -d "$PROJ_ROOT" ]]; then
  echo "ERROR: $PROJ_ROOT no existe" >&2
  exit 1
fi

TODAY="$(date +%Y-%m-%d)"
NOW_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Áreas a indexar (excluye repos/ — ese es código fuente, no docs)
AREAS=("$SLUG" "${SLUG}-monica" "${SLUG}-pm" "${SLUG}-vass")

# Regenerar un INDEX.md
rebuild_index() {
  local dir="$1"
  local rel
  rel="${dir#$PROJ_ROOT/}"

  # Saltar excluidos
  case "$dir" in
    */.git|*/.git/*|*/.agent-maps|*/.agent-maps/*|*/.human-maps|*/.human-maps/*|*/output|*/output/*|*/node_modules|*/node_modules/*|*/repos|*/repos/*) return 0 ;;
  esac

  # Contar ficheros (no recursivo, nivel 1)
  local nfiles
  nfiles=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l)
  if [[ "$nfiles" -lt 5 ]]; then
    return 0
  fi

  local idx="$dir/INDEX.md"
  local title
  title=$(basename "$dir")

  # Top 20 ficheros por mtime
  {
    echo "# $title — INDEX"
    echo ""
    echo "**Última actualización**: $TODAY"
    echo ""
    echo "Auto-generado por \`scripts/rebuild-folder-indexes.sh\` (parte de /project-update Fase 3.5)."
    echo ""
    echo "## Ficheros (top 20 por fecha de modificación)"
    echo ""
    echo "| Fichero | Tipo | Modificado |"
    echo "|---|---|---|"
    find "$dir" -maxdepth 1 -type f -name "*.*" -not -name "INDEX.md" -printf "%T@ %p\n" 2>/dev/null \
      | sort -rn | head -20 \
      | while read -r ts path; do
          local fname ext mtime base
          fname=$(basename "$path")
          ext="${fname##*.}"
          base="${fname%.*}"
          mtime=$(date -d "@${ts%.*}" "+%Y-%m-%d" 2>/dev/null || echo "unknown")
          # Wikilink for .md (Obsidian graph), backticks for binaries.
          if [[ "$ext" == "md" ]]; then
            echo "| [[$base]] | md | $mtime |"
          else
            echo "| \`$fname\` | $ext | $mtime |"
          fi
        done
    echo ""

    # Subcarpetas (1 nivel)
    local nsub
    nsub=$(find "$dir" -maxdepth 1 -mindepth 1 -type d -not -name ".*" 2>/dev/null | wc -l)
    if [[ "$nsub" -gt 0 ]]; then
      echo "## Subcarpetas"
      echo ""
      find "$dir" -maxdepth 1 -mindepth 1 -type d -not -name ".*" -printf "%f\n" 2>/dev/null | sort \
        | while read -r sub; do echo "- [[$sub/INDEX|$sub/]]"; done
      echo ""
    fi
  } > "$idx"

  echo "{\"path\":\"$rel/INDEX.md\",\"files\":$nfiles,\"updated\":\"$TODAY\"}"
}

echo "{\"slug\":\"$SLUG\",\"ts\":\"$NOW_TS\",\"indexes\":["
FIRST=1
for area in "${AREAS[@]}"; do
  area_dir="$PROJ_ROOT/$area"
  [[ -d "$area_dir" ]] || continue

  # Recorrer subcarpetas (3 niveles máx)
  while IFS= read -r d; do
    out=$(rebuild_index "$d")
    if [[ -n "$out" ]]; then
      if [[ "$FIRST" -eq 0 ]]; then echo ","; fi
      echo "$out"
      FIRST=0
    fi
  done < <(find "$area_dir" -maxdepth 3 -type d 2>/dev/null)
done
echo "]}"

echo "OK rebuild-folder-indexes slug=$SLUG" >&2
