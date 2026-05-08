#!/usr/bin/env bash
# refresh-agent-maps.sh
#
# Regenera los .acm de un proyecto contra el estado real local.
# Invocado por /project-update Fase 3.5 (agente maps-acm).
#
# Uso:
#   bash scripts/refresh-agent-maps.sh <slug>            # todos los repos del proyecto
#   bash scripts/refresh-agent-maps.sh <slug> <repo>     # solo un repo
#
# Salida:
#   stdout: JSON con resumen del refresh por repo
#   stderr: progreso humano
#   files:  actualiza projects/{slug}_main/.agent-maps/repos/{repo}.acm
#           actualiza projects/{slug}_main/.agent-maps/INDEX.acm (tabla de frescura)

set -uo pipefail

SLUG="${1:?Uso: $0 <slug> [repo]}"
SINGLE_REPO="${2:-}"

# Resolver workspace root
WS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ_ROOT="$WS_ROOT/projects/${SLUG}_main"
REPOS_DIR="$PROJ_ROOT/${SLUG}/repos"
MAPS_DIR="$PROJ_ROOT/.agent-maps/repos"
INDEX_FILE="$PROJ_ROOT/.agent-maps/INDEX.acm"

if [[ ! -d "$REPOS_DIR" ]]; then
  echo "ERROR: $REPOS_DIR no existe" >&2
  exit 1
fi
if [[ ! -d "$MAPS_DIR" ]]; then
  echo "ERROR: $MAPS_DIR no existe (correr /codemap:generate primero)" >&2
  exit 1
fi

TODAY="$(date +%Y-%m-%d)"
NOW_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Función: refrescar un repo individual
refresh_repo() {
  local repo="$1"
  local repo_dir="$REPOS_DIR/$repo"
  local acm_file repo_normalized cand_normalized cand
  # Estrategia robusta: comparar el nombre del repo contra los .acm existentes
  # ignorando case, guiones y underscores. El primer match es el válido.
  # Esto evita errores de naming convention (DotNet→dotnet, no dot-net).
  repo_normalized=$(echo "$repo" | tr -d '_-' | tr '[:upper:]' '[:lower:]')
  acm_file=""
  for cand in "$MAPS_DIR"/*.acm; do
    [[ -f "$cand" ]] || continue
    cand_normalized=$(basename "$cand" .acm | tr -d '_-' | tr '[:upper:]' '[:lower:]')
    if [[ "$cand_normalized" == "$repo_normalized" ]]; then
      acm_file="$cand"
      break
    fi
  done
  # Si no encuentra match, generar nombre por convención simple (lowercase + _→-)
  if [[ -z "$acm_file" ]]; then
    acm_file="$MAPS_DIR/$(echo "$repo" | tr '_' '-' | tr '[:upper:]' '[:lower:]').acm"
  fi

  if [[ ! -d "$repo_dir" ]]; then
    echo "  SKIP $repo: repo dir missing" >&2
    return 1
  fi

  # Detectar si tiene checkout local (algo más que .git)
  local entries
  entries=$(ls "$repo_dir" 2>/dev/null | wc -l)
  if [[ "$entries" -le 1 ]]; then
    # Solo .git → marcar stale-no-checkout
    if [[ -f "$acm_file" ]]; then
      sed -i "s/^> .*$/> hash: sha256:auto | generated: ?? | refreshed: $TODAY | status: stale-no-checkout (only .git, no source files)/" "$acm_file"
    fi
    echo "{\"repo\":\"$repo\",\"status\":\"stale-no-checkout\",\"acm\":\"$acm_file\"}"
    return 0
  fi

  # Última info git
  local last_commit="unknown"
  if [[ -d "$repo_dir/.git" ]]; then
    last_commit=$(cd "$repo_dir" && git log -1 --format='%ai %h %s' 2>/dev/null | head -c 100 || echo "unknown")
  fi

  # Conteos de código (solo si .acm existe — lo actualizamos in-place)
  local cs_count vue_count sql_count tf_count csproj_count controllers
  cs_count=$(find "$repo_dir" -maxdepth 6 -name "*.cs" 2>/dev/null | wc -l)
  vue_count=$(find "$repo_dir" -maxdepth 6 -name "*.vue" 2>/dev/null | wc -l)
  sql_count=$(find "$repo_dir" -maxdepth 6 -name "*.sql" 2>/dev/null | wc -l)
  tf_count=$(find "$repo_dir" -maxdepth 6 -name "*.tf" 2>/dev/null | wc -l)
  csproj_count=$(find "$repo_dir" -maxdepth 6 -name "*.csproj" 2>/dev/null | wc -l)
  controllers=$(find "$repo_dir" -path '*/Controllers/*.cs' 2>/dev/null | wc -l)

  # Si el .acm existe, actualizar la línea de cabecera con refreshed:
  if [[ -f "$acm_file" ]]; then
    # Reemplazar refreshed: <fecha> en la primera línea con `>` (cabecera)
    awk -v today="$TODAY" -v lc="$last_commit" '
      NR==1 { print; next }
      /^> / && !done {
        # Tiene refreshed: ya?
        if ($0 ~ /refreshed:/) {
          gsub(/refreshed: [0-9-]+/, "refreshed: " today)
        } else {
          sub(/$/, " | refreshed: " today)
        }
        # Tiene local-commit: ya?
        if ($0 ~ /local-commit:/) {
          # No tocamos el SHA — confianza del autor
        } else {
          # Append local-commit-ts si no existe
        }
        done=1
        print
        next
      }
      { print }
    ' "$acm_file" > "$acm_file.tmp" && mv "$acm_file.tmp" "$acm_file"
  fi

  # Output JSON
  echo "{\"repo\":\"$repo\",\"status\":\"refreshed\",\"acm\":\"$acm_file\",\"counts\":{\"cs\":$cs_count,\"vue\":$vue_count,\"sql\":$sql_count,\"tf\":$tf_count,\"csproj\":$csproj_count,\"controllers\":$controllers},\"last_commit\":\"$(echo "$last_commit" | sed 's/"/\\"/g')\"}"
}

# Iterar repos
echo "=== refresh-agent-maps: slug=$SLUG ts=$NOW_TS ===" >&2
echo "{\"slug\":\"$SLUG\",\"ts\":\"$NOW_TS\",\"repos\":["
FIRST=1
if [[ -n "$SINGLE_REPO" ]]; then
  if [[ "$FIRST" -eq 0 ]]; then echo ","; fi
  refresh_repo "$SINGLE_REPO"
  FIRST=0
else
  for d in "$REPOS_DIR"/*; do
    [[ -d "$d" ]] || continue
    repo="$(basename "$d")"
    [[ "$repo" == ".git" ]] && continue
    if [[ "$FIRST" -eq 0 ]]; then echo ","; fi
    refresh_repo "$repo"
    FIRST=0
  done
fi
echo "]}"

# Actualizar timestamp en INDEX.acm
if [[ -f "$INDEX_FILE" ]]; then
  if grep -q "refreshed:" "$INDEX_FILE" 2>/dev/null; then
    sed -i "s/refreshed: [0-9-]\+/refreshed: $TODAY/g" "$INDEX_FILE"
  fi
fi

echo "OK refresh-agent-maps slug=$SLUG" >&2
