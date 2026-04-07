#!/usr/bin/env bash
set -uo pipefail

# legalize-es.sh — Gestión del corpus legislativo español (legalize-es)
# Funciones: install, update, status, search

LEGALIZE_ES_DEFAULT_PATH="${LEGALIZE_ES_PATH:-$HOME/.savia/legalize-es}"
LEGALIZE_ES_REPO="https://github.com/legalize-dev/legalize-es.git"

usage() {
  cat <<'EOF'
Uso: legalize-es.sh <comando> [opciones]

Comandos:
  install              Clonar legalize-es en $LEGALIZE_ES_PATH
  update               Actualizar legislación (git pull)
  status               Mostrar estado del corpus
  search <término>     Buscar en legislación vigente
  search-article <BOE-ID> <artículo>  Buscar artículo específico
  history <BOE-ID>     Historial de reformas de una norma
  check-status <BOE-ID> Verificar si una norma está vigente o derogada

Variables de entorno:
  LEGALIZE_ES_PATH     Ruta del corpus (default: ~/.savia/legalize-es)
EOF
  exit 1
}

cmd_install() {
  if [[ -d "$LEGALIZE_ES_DEFAULT_PATH/.git" ]]; then
    echo "✅ legalize-es ya instalado en $LEGALIZE_ES_DEFAULT_PATH"
    echo "   Usa 'legalize-es.sh update' para actualizar."
    return 0
  fi

  echo "📥 Clonando legalize-es (solo último commit)..."
  mkdir -p "$(dirname "$LEGALIZE_ES_DEFAULT_PATH")"
  git clone --depth=1 "$LEGALIZE_ES_REPO" "$LEGALIZE_ES_DEFAULT_PATH" 2>&1

  if [[ $? -eq 0 ]]; then
    local count
    count=$(find "$LEGALIZE_ES_DEFAULT_PATH/es" -name "*.md" 2>/dev/null | wc -l)
    echo "✅ Instalado: $count normas estatales disponibles"
  else
    echo "❌ Error al clonar. Verifica conexión a internet."
    return 1
  fi
}

cmd_update() {
  if [[ ! -d "$LEGALIZE_ES_DEFAULT_PATH/.git" ]]; then
    echo "❌ legalize-es no instalado. Ejecuta: legalize-es.sh install"
    return 1
  fi

  echo "🔄 Actualizando legislación..."
  git -C "$LEGALIZE_ES_DEFAULT_PATH" pull --ff-only 2>&1
  local last_commit
  last_commit=$(git -C "$LEGALIZE_ES_DEFAULT_PATH" log -1 --format="%ci — %s" 2>/dev/null)
  echo "✅ Actualizado. Último commit: $last_commit"
}

cmd_status() {
  if [[ ! -d "$LEGALIZE_ES_DEFAULT_PATH/.git" ]]; then
    echo "❌ legalize-es NO instalado"
    echo "   Ruta esperada: $LEGALIZE_ES_DEFAULT_PATH"
    echo "   Instalar con: bash scripts/legalize-es.sh install"
    return 1
  fi

  local state_count ccaa_count last_commit disk_usage
  state_count=$(find "$LEGALIZE_ES_DEFAULT_PATH/es" -name "*.md" 2>/dev/null | wc -l)
  ccaa_count=$(find "$LEGALIZE_ES_DEFAULT_PATH" -maxdepth 1 -type d -name "es-*" 2>/dev/null | wc -l)
  last_commit=$(git -C "$LEGALIZE_ES_DEFAULT_PATH" log -1 --format="%ci" 2>/dev/null)
  disk_usage=$(du -sh "$LEGALIZE_ES_DEFAULT_PATH" 2>/dev/null | cut -f1)

  echo "📚 legalize-es — Estado"
  echo "   Ruta: $LEGALIZE_ES_DEFAULT_PATH"
  echo "   Normas estatales: $state_count"
  echo "   Comunidades autónomas: $ccaa_count"
  echo "   Último commit BOE: $last_commit"
  echo "   Espacio en disco: $disk_usage"
}

cmd_search() {
  local term="$1"
  if [[ -z "$term" ]]; then
    echo "❌ Falta término de búsqueda. Uso: legalize-es.sh search \"término\""
    return 1
  fi

  if [[ ! -d "$LEGALIZE_ES_DEFAULT_PATH" ]]; then
    echo "❌ legalize-es no instalado. Ejecuta: legalize-es.sh install"
    return 1
  fi

  local scope="${2:-es}"
  echo "🔍 Buscando \"$term\" en $scope/..."

  # Buscar en frontmatter (título) y contenido, solo normas vigentes
  grep -rl --include="*.md" -i "$term" "$LEGALIZE_ES_DEFAULT_PATH/$scope/" 2>/dev/null \
    | while read -r file; do
      # Verificar que la norma está vigente (status: "in_force")
      if grep -q 'status:.*"in_force"' "$file" 2>/dev/null; then
        local title boe_id
        title=$(grep "^title:" "$file" 2>/dev/null | head -1 | sed 's/^title: *//' | sed 's/^"//' | sed 's/"$//')
        boe_id=$(grep "^identifier:" "$file" 2>/dev/null | head -1 | sed 's/^identifier: *//')
        echo "  📄 $boe_id — $title"
      fi
    done | head -20

  echo ""
  echo "💡 Para ver artículos: legalize-es.sh search-article <BOE-ID> <artículo>"
}

cmd_search_article() {
  local boe_id="$1" article="$2"
  if [[ -z "$boe_id" || -z "$article" ]]; then
    echo "❌ Uso: legalize-es.sh search-article BOE-A-2018-16673 \"Artículo 13\""
    return 1
  fi

  local file
  file=$(find "$LEGALIZE_ES_DEFAULT_PATH" -name "${boe_id}.md" 2>/dev/null | head -1)
  if [[ -z "$file" ]]; then
    echo "❌ Norma $boe_id no encontrada"
    return 1
  fi

  echo "📄 $(grep "^title:" "$file" | head -1 | sed 's/^title: *//')"
  echo "---"
  # Extraer artículo con contexto (hasta el siguiente artículo o sección)
  grep -A 30 -i "$article" "$file" 2>/dev/null | head -40
}

cmd_history() {
  local boe_id="$1"
  if [[ -z "$boe_id" ]]; then
    echo "❌ Uso: legalize-es.sh history BOE-A-2018-16673"
    return 1
  fi

  local file
  file=$(find "$LEGALIZE_ES_DEFAULT_PATH" -name "${boe_id}.md" 2>/dev/null | head -1)
  if [[ -z "$file" ]]; then
    echo "❌ Norma $boe_id no encontrada"
    return 1
  fi

  echo "📜 Historial de reformas: $boe_id"
  echo "   $(grep "^title:" "$file" | head -1 | sed 's/^title: *//' | sed 's/^"//' | sed 's/"$//')"
  echo "---"
  # Verificar si es shallow clone (--depth=1)
  if [[ -f "$LEGALIZE_ES_DEFAULT_PATH/.git/shallow" ]]; then
    echo "⚠️  Clone superficial — solo último commit disponible."
    echo "   Para historial completo: git -C $LEGALIZE_ES_DEFAULT_PATH fetch --unshallow"
    echo ""
  fi
  # git log con fecha BOE real (fecha del commit = fecha de publicación BOE)
  git -C "$LEGALIZE_ES_DEFAULT_PATH" log --format="%ci | %s" -- "${file#$LEGALIZE_ES_DEFAULT_PATH/}" 2>/dev/null | head -20
}

cmd_check_status() {
  local boe_id="$1"
  if [[ -z "$boe_id" ]]; then
    echo "❌ Uso: legalize-es.sh check-status BOE-A-2018-16673"
    return 1
  fi

  local file
  file=$(find "$LEGALIZE_ES_DEFAULT_PATH" -name "${boe_id}.md" 2>/dev/null | head -1)
  if [[ -z "$file" ]]; then
    echo "❌ Norma $boe_id no encontrada"
    return 1
  fi

  local title status rank last_updated
  title=$(grep "^title:" "$file" | head -1 | sed 's/^title: *//' | sed 's/^"//' | sed 's/"$//')
  status=$(grep "^status:" "$file" | head -1 | sed 's/^status: *//' | sed 's/^"//' | sed 's/"$//')
  rank=$(grep "^rank:" "$file" | head -1 | sed 's/^rank: *//' | sed 's/^"//' | sed 's/"$//')
  last_updated=$(grep "^last_updated:" "$file" | head -1 | sed 's/^last_updated: *//' | sed 's/^"//' | sed 's/"$//')

  local status_icon
  case "$status" in
    in_force)   status_icon="✅ VIGENTE" ;;
    repealed)   status_icon="❌ DEROGADA" ;;
    *)          status_icon="⚠️ $status" ;;
  esac

  echo "⚖️  $boe_id"
  echo "   Título: $title"
  echo "   Estado: $status_icon"
  echo "   Rango: $rank"
  echo "   Última actualización: $last_updated"
}

# --- Main ---
case "${1:-}" in
  install)        cmd_install ;;
  update)         cmd_update ;;
  status)         cmd_status ;;
  search)         cmd_search "${2:-}" "${3:-es}" ;;
  search-article) cmd_search_article "${2:-}" "${3:-}" ;;
  history)        cmd_history "${2:-}" ;;
  check-status)   cmd_check_status "${2:-}" ;;
  *)              usage ;;
esac
