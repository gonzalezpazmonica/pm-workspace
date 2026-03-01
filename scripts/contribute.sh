#!/bin/bash
# contribute.sh — Capa de interacción con GitHub para comunidad
# Uso: bash scripts/contribute.sh {pr|issue|list|search} [args...]
#
# Compartido entre /contribute, /feedback y /review-community.
# Valida privacidad antes de cualquier envío a GitHub.

set -euo pipefail

# ── Constantes ──────────────────────────────────────────────────────
REPO_OWNER="gonzalezpazmonica"
REPO_NAME="pm-workspace"
REPO_FULL="$REPO_OWNER/$REPO_NAME"
WORKSPACE_DIR="${PM_WORKSPACE_ROOT:-$HOME/claude}"

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

# ── Validación de privacidad ────────────────────────────────────────
# Bloquea contenido que NUNCA debe salir del entorno local.
validate_privacy() {
  local content="$1"
  local violations=()

  # PATs y tokens conocidos
  if echo "$content" | grep -qEi 'AKIA[0-9A-Z]{16}'; then
    violations+=("AWS Access Key detectada")
  fi
  if echo "$content" | grep -qEi 'ghp_[a-zA-Z0-9]{36}'; then
    violations+=("GitHub PAT detectado")
  fi
  if echo "$content" | grep -qEi 'sk-[a-zA-Z0-9]{20,}'; then
    violations+=("OpenAI/API key detectada")
  fi
  if echo "$content" | grep -qEi 'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}'; then
    violations+=("JWT token detectado")
  fi
  if echo "$content" | grep -qEi '[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}.*azure'; then
    violations+=("Azure credential detectada")
  fi

  # Emails corporativos (excluir @gmail, @outlook, @github)
  if echo "$content" | grep -qEi '[a-z0-9._%+-]+@(?!gmail|outlook|github|hotmail|yahoo)[a-z0-9.-]+\.[a-z]{2,}'; then
    violations+=("Email corporativo detectado")
  fi

  # IPs privadas
  if echo "$content" | grep -qE '(10\.[0-9]+\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+)'; then
    violations+=("IP privada detectada")
  fi

  # Rutas absolutas de usuario
  if echo "$content" | grep -qE '/home/[a-z]+/((?!claude/)[a-z])' 2>/dev/null; then
    violations+=("Ruta personal detectada")
  fi

  # Nombres de proyecto de CLAUDE.local.md
  if [ -f "$WORKSPACE_DIR/CLAUDE.local.md" ]; then
    local project_names
    project_names=$(grep -oP 'projects/\K[^/]+' "$WORKSPACE_DIR/CLAUDE.local.md" 2>/dev/null || true)
    for pname in $project_names; do
      if echo "$content" | grep -qi "$pname"; then
        violations+=("Nombre de proyecto privado '$pname' detectado")
      fi
    done
  fi

  # Connection strings
  if echo "$content" | grep -qEi '(Server=|Data Source=|jdbc:|mongodb\+srv://|redis://)'; then
    violations+=("Connection string detectada")
  fi

  if [ ${#violations[@]} -gt 0 ]; then
    log_error "Validación de privacidad FALLIDA:"
    for v in "${violations[@]}"; do
      echo -e "  ${RED}•${NC} $v"
    done
    return 1
  fi
  return 0
}

# ── Verificar gh CLI ────────────────────────────────────────────────
check_gh() {
  if ! command -v gh &>/dev/null; then
    log_error "gh CLI no instalado. Instala: https://cli.github.com"
    exit 1
  fi
  if ! gh auth status &>/dev/null; then
    log_error "gh CLI no autenticado. Ejecuta: gh auth login"
    exit 1
  fi
}

# ── Obtener info del usuario ────────────────────────────────────────
get_gh_user() {
  gh api user --jq '.login' 2>/dev/null || echo "unknown"
}

# ── Crear PR ────────────────────────────────────────────────────────
do_pr() {
  local title="${1:?Uso: contribute.sh pr 'título' 'cuerpo' [labels]}"
  local body="${2:-}"
  local labels="${3:-community,from-savia}"

  check_gh

  if [ -n "$body" ] && ! validate_privacy "$body"; then
    log_error "PR bloqueado por contenido privado. Sanitiza antes de enviar."
    exit 1
  fi
  if ! validate_privacy "$title"; then
    log_error "Título del PR contiene datos privados."
    exit 1
  fi

  local version
  version=$(git -C "$WORKSPACE_DIR" describe --tags --abbrev=0 2>/dev/null || echo "unknown")
  local branch_name="community/$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 50)"

  log_info "Creando rama: $branch_name"
  log_info "Título: $title"
  log_info "Versión local: $version"

  echo ""
  echo -e "${CYAN}── PR preparado ──${NC}"
  echo "  Rama:    $branch_name"
  echo "  Título:  $title"
  echo "  Labels:  $labels"
  echo "  Versión: $version"
  echo ""
  echo "Ejecuta desde Claude para completar el PR (rama, commit, push, gh pr create)."
}

# ── Crear Issue ─────────────────────────────────────────────────────
do_issue() {
  local title="${1:?Uso: contribute.sh issue 'título' 'cuerpo' [labels]}"
  local body="${2:-}"
  local labels="${3:-community}"

  check_gh

  if [ -n "$body" ] && ! validate_privacy "$body"; then
    log_error "Issue bloqueado por contenido privado."
    exit 1
  fi
  if ! validate_privacy "$title"; then
    log_error "Título del issue contiene datos privados."
    exit 1
  fi

  local version
  version=$(git -C "$WORKSPACE_DIR" describe --tags --abbrev=0 2>/dev/null || echo "unknown")

  local full_body="$body"
  if [ -n "$full_body" ]; then
    full_body="$full_body

---
_pm-workspace $version · Enviado con Savia_"
  else
    full_body="_pm-workspace $version · Enviado con Savia_"
  fi

  log_info "Creando issue en $REPO_FULL..."
  gh issue create \
    --repo "$REPO_FULL" \
    --title "$title" \
    --body "$full_body" \
    --label "$labels" 2>&1

  log_ok "Issue creado: $title"
}

# ── Listar PRs/Issues ──────────────────────────────────────────────
do_list() {
  local type="${1:-all}"  # all, pr, issue
  check_gh

  if [ "$type" = "pr" ] || [ "$type" = "all" ]; then
    echo -e "${CYAN}── Pull Requests abiertos ──${NC}"
    gh pr list --repo "$REPO_FULL" --state open --limit 20 2>&1 || echo "  (ninguno)"
    echo ""
  fi

  if [ "$type" = "issue" ] || [ "$type" = "all" ]; then
    echo -e "${CYAN}── Issues abiertos ──${NC}"
    gh issue list --repo "$REPO_FULL" --state open --limit 20 2>&1 || echo "  (ninguno)"
  fi
}

# ── Buscar Issues/PRs ──────────────────────────────────────────────
do_search() {
  local query="${1:?Uso: contribute.sh search 'término'}"
  check_gh

  echo -e "${CYAN}── Buscando: $query ──${NC}"
  gh search issues "$query" --repo "$REPO_FULL" --limit 10 2>&1 || echo "  Sin resultados"
}

# ── Main ────────────────────────────────────────────────────────────
main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    pr)     do_pr "$@" ;;
    issue)  do_issue "$@" ;;
    list)   do_list "$@" ;;
    search) do_search "$@" ;;
    validate)
      local content="${1:-}"
      if [ -z "$content" ]; then
        log_error "Uso: contribute.sh validate 'contenido'"
        exit 1
      fi
      if validate_privacy "$content"; then
        log_ok "Contenido limpio — sin datos privados detectados"
      fi
      ;;
    help|*)
      echo "contribute.sh — Interacción con GitHub para comunidad"
      echo ""
      echo "Uso: bash scripts/contribute.sh {comando} [args]"
      echo ""
      echo "Comandos:"
      echo "  pr 'título' ['cuerpo'] [labels]  — Preparar PR comunitario"
      echo "  issue 'título' ['cuerpo'] [labels] — Crear issue"
      echo "  list [all|pr|issue]               — Listar PRs/issues abiertos"
      echo "  search 'query'                    — Buscar issues/PRs"
      echo "  validate 'contenido'              — Validar privacidad"
      echo "  help                              — Esta ayuda"
      ;;
  esac
}

main "$@"
