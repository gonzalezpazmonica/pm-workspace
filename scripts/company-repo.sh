#!/bin/bash
# company-repo.sh — Git operations for company repo lifecycle
# Uso: bash scripts/company-repo.sh {create|connect|status|sync} [args]
#
# Manages the Company Savia shared repository: creation, connection,
# synchronization. Uses company-repo-templates.sh for structure.

set -euo pipefail

# ── Constantes ──────────────────────────────────────────────────────
CONFIG_DIR="$HOME/.pm-workspace"
CONFIG_FILE="$CONFIG_DIR/company-repo"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS_DIR/savia-compat.sh"

# ── Colores ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info()  { echo -e "${BLUE}ℹ${NC}  $1"; }
log_ok()    { echo -e "${GREEN}✅${NC} $1"; }
log_warn()  { echo -e "${YELLOW}⚠️${NC}  $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

# ── Config helpers (reuse pattern from backup.sh) ──────────────────
ensure_config() {
  mkdir -p "$CONFIG_DIR"
  [ -f "$CONFIG_FILE" ] || touch "$CONFIG_FILE"
}

read_config() {
  local key="$1"
  portable_read_config "$key" "$CONFIG_FILE"
}

write_config() {
  local key="$1" value="$2"
  if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
    portable_sed_i "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
  else
    echo "${key}=${value}" >> "$CONFIG_FILE"
  fi
}

# ── Source: connect, status, sync operations ─────────────────────
source "$SCRIPTS_DIR/company-repo-ops.sh"

# ── Create: CEO/CTO initializes company repo ──────────────────────
do_create() {
  local repo_url="${1:?Uso: company-repo.sh create <git_url> <org_name> <admin_handle>}"
  local org_name="${2:?Falta org_name}"
  local admin_handle="${3:?Falta admin_handle}"

  ensure_config
  local local_path="$CONFIG_DIR/company-savia"

  if [ -d "$local_path/.git" ]; then
    log_warn "Company repo already exists at $local_path"
    log_info "Use 'sync' to update or delete the directory to start fresh."
    return 1
  fi

  log_info "Creating Company Savia repo for $org_name..."

  # Clone empty repo (or init if it fails)
  if git clone "$repo_url" "$local_path" 2>/dev/null; then
    log_ok "Cloned from $repo_url"
  else
    mkdir -p "$local_path"
    git -C "$local_path" init 2>/dev/null
    git -C "$local_path" remote add origin "$repo_url" 2>/dev/null || true
    log_info "Initialized new repo (remote: $repo_url)"
  fi

  # Generate main branch structure only (no users/ or teams/)
  bash "$SCRIPTS_DIR/company-repo-templates.sh" init "$local_path" "$org_name" "$admin_handle"

  # Create first admin user on user/{admin_handle} orphan branch
  bash "$SCRIPTS_DIR/company-repo-templates.sh" user-folders "$local_path" "$admin_handle" "$org_name Admin" "Admin"

  # Initial commit and push to main branch only
  git -C "$local_path" add -A
  git -C "$local_path" commit -m "feat: initialize Company Savia for $org_name" 2>/dev/null || true

  if git -C "$local_path" push -u origin main 2>/dev/null; then
    log_ok "Pushed main branch to $repo_url"
  else
    log_warn "Could not push main (check repo permissions). Local repo ready."
  fi

  # Push user/{admin_handle} and exchange branches
  git -C "$local_path" push -u origin "user/$admin_handle" 2>/dev/null || true
  git -C "$local_path" push -u origin exchange 2>/dev/null || true

  # Save config
  write_config "REPO_URL" "$repo_url"
  write_config "USER_HANDLE" "$admin_handle"
  write_config "LOCAL_PATH" "$local_path"
  write_config "ORG_NAME" "$org_name"
  write_config "ROLE" "admin"

  log_ok "Company Savia created for $org_name"
  echo -e "\n${CYAN}Next steps:${NC}"
  echo "  1. Share the repo URL with your team"
  echo "  2. Team members run: /company-repo connect"
  echo "  3. Generate encryption keys: /savia-send --setup-keys"
}

# ── Main ────────────────────────────────────────────────────────────
main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    create)  do_create "$@" ;;
    connect) do_connect "$@" ;;
    status)  do_status ;;
    sync)    do_sync ;;
    help|*)
      echo "company-repo.sh — Company Savia repo lifecycle"
      echo ""
      echo "Uso: bash scripts/company-repo.sh {command} [args]"
      echo ""
      echo "Commands:"
      echo "  create <url> <org> <admin>          — Initialize company repo"
      echo "  connect <url> <handle> <name> [role] — Join company repo"
      echo "  status                               — Show sync state"
      echo "  sync                                 — Pull + push changes"
      ;;
  esac
}

main "$@"
