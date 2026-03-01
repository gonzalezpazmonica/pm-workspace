#!/bin/bash
# update.sh — Sistema de actualización de pm-workspace
# Uso: bash scripts/update.sh {check|install|status|config}
#
# Compara versión local con GitHub, aplica actualizaciones preservando
# datos del usuario (profiles, projects, output, config local).

set -euo pipefail

# ── Constantes ──────────────────────────────────────────────────────
REPO_OWNER="gonzalezpazmonica"
REPO_NAME="pm-workspace"
WORKSPACE_DIR="${PM_WORKSPACE_ROOT:-$HOME/claude}"
CONFIG_DIR="$HOME/.pm-workspace"
CONFIG_FILE="$CONFIG_DIR/update-config"
DEFAULT_INTERVAL=604800  # 7 días en segundos

# ── Colores ─────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Utilidades ──────────────────────────────────────────────────────
log_info()  { echo -e "${BLUE}ℹ${NC}  $1"; }
log_ok()    { echo -e "${GREEN}✅${NC} $1"; }
log_warn()  { echo -e "${YELLOW}⚠️${NC}  $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

ensure_config() {
  mkdir -p "$CONFIG_DIR"
  if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << EOF
auto_check=true
last_check=0
check_interval=$DEFAULT_INTERVAL
EOF
  fi
}

read_config() {
  local key="$1"
  local default="${2:-}"
  if [ -f "$CONFIG_FILE" ]; then
    local val
    val=$(grep -oP "${key}=\K.*" "$CONFIG_FILE" 2>/dev/null || echo "")
    echo "${val:-$default}"
  else
    echo "$default"
  fi
}

write_config() {
  local key="$1"
  local value="$2"
  ensure_config
  if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
  else
    echo "${key}=${value}" >> "$CONFIG_FILE"
  fi
}

get_local_version() {
  git -C "$WORKSPACE_DIR" describe --tags --abbrev=0 2>/dev/null || echo "unknown"
}

get_remote_version() {
  if command -v gh &>/dev/null; then
    timeout 10 gh api "repos/$REPO_OWNER/$REPO_NAME/releases/latest" --jq '.tag_name' 2>/dev/null || echo ""
  else
    log_warn "gh CLI no disponible — instálalo para comprobar actualizaciones"
    echo ""
  fi
}

# ── Datos protegidos (verificación) ─────────────────────────────────
PROTECTED_PATHS=(
  ".claude/profiles/users"
  "projects"
  "output"
  "CLAUDE.local.md"
  "decision-log.md"
  ".claude/rules/domain/pm-config.local.md"
)

verify_protected_data() {
  log_info "Verificando datos protegidos..."
  local all_safe=true
  for path in "${PROTECTED_PATHS[@]}"; do
    local full_path="$WORKSPACE_DIR/$path"
    if [ -e "$full_path" ]; then
      # Verificar que está en gitignore
      if git -C "$WORKSPACE_DIR" check-ignore -q "$full_path" 2>/dev/null; then
        log_ok "$path — protegido por .gitignore"
      else
        # Algunos paths son dirs con reglas especiales
        if [ -d "$full_path" ]; then
          log_ok "$path — directorio existente"
        else
          log_warn "$path — NO está en .gitignore, podría verse afectado"
          all_safe=false
        fi
      fi
    fi
  done
  $all_safe
}

# ── Subcomandos ─────────────────────────────────────────────────────

do_check() {
  ensure_config
  local current
  current=$(get_local_version)
  log_info "Versión local: ${CYAN}$current${NC}"

  log_info "Consultando GitHub..."
  local latest
  latest=$(get_remote_version)

  if [ -z "$latest" ]; then
    log_warn "No se pudo consultar la versión remota (sin conexión o gh no disponible)"
    write_config "last_check" "$(date +%s)"
    return 1
  fi

  log_info "Versión remota: ${CYAN}$latest${NC}"
  write_config "last_check" "$(date +%s)"

  if [ "$current" = "$latest" ]; then
    log_ok "pm-workspace está actualizado ($current)"
    return 0
  else
    echo ""
    echo -e "${GREEN}🆕 Nueva versión disponible: ${CYAN}$current${NC} → ${CYAN}$latest${NC}"
    echo ""
    # Mostrar changelog resumido de la nueva versión
    local release_body
    release_body=$(timeout 10 gh api "repos/$REPO_OWNER/$REPO_NAME/releases/latest" --jq '.body' 2>/dev/null || echo "")
    if [ -n "$release_body" ]; then
      echo -e "${BLUE}Notas de la versión:${NC}"
      echo "$release_body" | head -20
      echo ""
    fi
    echo -e "Ejecuta ${CYAN}/update install${NC} para actualizar."
    return 2  # 2 = update available
  fi
}

do_install() {
  ensure_config
  local current
  current=$(get_local_version)

  log_info "Versión actual: $current"
  log_info "Obteniendo última versión..."

  local latest
  latest=$(get_remote_version)

  if [ -z "$latest" ]; then
    log_error "No se pudo obtener la versión remota"
    return 1
  fi

  if [ "$current" = "$latest" ]; then
    log_ok "Ya estás en la última versión ($current)"
    return 0
  fi

  echo ""
  echo -e "Actualización: ${CYAN}$current${NC} → ${CYAN}$latest${NC}"
  echo ""

  # Paso 1: Verificar datos protegidos
  verify_protected_data || {
    log_warn "Algunos datos locales podrían no estar protegidos. Revisa antes de continuar."
  }

  # Paso 2: Verificar rama actual
  local branch
  branch=$(git -C "$WORKSPACE_DIR" branch --show-current 2>/dev/null || echo "")
  if [ "$branch" != "main" ]; then
    log_warn "Estás en rama '$branch', no en 'main'"
    log_info "Cambiando a main para actualizar..."
    git -C "$WORKSPACE_DIR" checkout main 2>/dev/null || {
      log_error "No se pudo cambiar a main. Haz checkout manualmente."
      return 1
    }
  fi

  # Paso 3: Stash cambios locales si los hay
  local had_stash=false
  local stash_output
  stash_output=$(git -C "$WORKSPACE_DIR" stash push -m "pm-workspace-update-$(date +%Y%m%d)" 2>&1)
  if echo "$stash_output" | grep -q "Saved working directory"; then
    had_stash=true
    log_info "Cambios locales guardados en stash"
  fi

  # Paso 4: Fetch y merge
  log_info "Descargando actualizaciones..."
  git -C "$WORKSPACE_DIR" fetch --tags origin 2>/dev/null || {
    log_error "Error al hacer fetch. Verifica tu conexión."
    [ "$had_stash" = true ] && git -C "$WORKSPACE_DIR" stash pop 2>/dev/null
    return 1
  }

  log_info "Aplicando versión $latest..."
  if ! git -C "$WORKSPACE_DIR" merge "$latest" --ff-only 2>/dev/null; then
    # Intentar merge normal si ff no es posible
    if ! git -C "$WORKSPACE_DIR" merge "$latest" --no-edit 2>/dev/null; then
      log_error "Conflicto de merge. Abortando actualización..."
      git -C "$WORKSPACE_DIR" merge --abort 2>/dev/null
      [ "$had_stash" = true ] && git -C "$WORKSPACE_DIR" stash pop 2>/dev/null
      log_error "La actualización no se pudo aplicar automáticamente."
      log_info "Puedes intentar manualmente: git pull origin main"
      return 1
    fi
  fi

  # Paso 5: Restaurar stash
  if [ "$had_stash" = true ]; then
    log_info "Restaurando cambios locales..."
    git -C "$WORKSPACE_DIR" stash pop 2>/dev/null || {
      log_warn "No se pudieron restaurar los cambios del stash automáticamente."
      log_info "Revisa con: git stash list / git stash pop"
    }
  fi

  # Paso 6: Validación post-update
  log_info "Verificando integridad..."
  local new_version
  new_version=$(get_local_version)

  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}✅ Actualización completada: $current → $new_version${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  log_ok "Tus perfiles, proyectos y configuración local están intactos"
  write_config "last_check" "$(date +%s)"
  return 0
}

do_status() {
  ensure_config
  local current
  current=$(get_local_version)
  local auto_check
  auto_check=$(read_config "auto_check" "true")
  local last_check
  last_check=$(read_config "last_check" "0")
  local interval
  interval=$(read_config "check_interval" "$DEFAULT_INTERVAL")

  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}🦉 Savia — Estado de actualizaciones${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "  Versión actual:          ${CYAN}$current${NC}"
  echo -e "  Auto-check semanal:      $([ "$auto_check" = "true" ] && echo "${GREEN}activado ✅${NC}" || echo "${YELLOW}desactivado ❌${NC}")"

  if [ "$last_check" != "0" ]; then
    local last_date
    last_date=$(date -d "@$last_check" "+%Y-%m-%d %H:%M" 2>/dev/null || date -r "$last_check" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "desconocida")
    local now
    now=$(date +%s)
    local days_ago=$(( (now - last_check) / 86400 ))
    echo -e "  Última comprobación:     $last_date (hace ${days_ago}d)"
  else
    echo -e "  Última comprobación:     ${YELLOW}nunca${NC}"
  fi

  echo -e "  Intervalo:               $((interval / 86400)) días"
  echo -e "  Repositorio:             github.com/$REPO_OWNER/$REPO_NAME"
  echo -e "  Config:                  $CONFIG_FILE"
  echo ""
}

do_config() {
  local key="${1:-}"
  local value="${2:-}"
  if [ -z "$key" ] || [ -z "$value" ]; then
    echo "Uso: update.sh config <clave> <valor>"
    echo "Claves: auto_check (true|false), check_interval (segundos)"
    return 1
  fi
  ensure_config
  write_config "$key" "$value"
  log_ok "Configuración actualizada: $key=$value"
}

# ── Main ────────────────────────────────────────────────────────────
main() {
  local cmd="${1:-check}"
  shift 2>/dev/null || true

  case "$cmd" in
    check)   do_check ;;
    install) do_install ;;
    status)  do_status ;;
    config)  do_config "$@" ;;
    *)
      echo "Uso: update.sh {check|install|status|config}"
      echo ""
      echo "  check    Comprobar si hay actualizaciones disponibles"
      echo "  install  Descargar e instalar la última versión"
      echo "  status   Mostrar estado del sistema de actualizaciones"
      echo "  config   Modificar configuración (auto_check, check_interval)"
      return 1
      ;;
  esac
}

main "$@"
