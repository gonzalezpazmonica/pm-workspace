#!/bin/bash
# company-repo-templates.sh — Heredoc templates for company repo init
# Uso: bash scripts/company-repo-templates.sh {init|user-folders} <args>
#
# Generates directory structure and template files for Company Savia repos.

set -euo pipefail

# ── Colores ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info()  { echo -e "${BLUE}ℹ${NC}  $1"; }
log_ok()    { echo -e "${GREEN}✅${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Source: init repo structure ──────────────────────────────────
source "$SCRIPTS_DIR/company-repo-templates-init.sh"

# ── User folders: create personal branch with isolated data ──────────────────────
do_user_folders() {
  local repo_dir="${1:?Uso: company-repo-templates.sh user-folders <dir> <handle> <name> <role>}"
  local handle="${2:?Falta handle}"
  local name="${3:?Falta name}"
  local role="${4:-Member}"

  # Create user/{handle} orphan branch
  if [ -f "$SCRIPTS_DIR/savia-branch.sh" ]; then
    bash "$SCRIPTS_DIR/savia-branch.sh" ensure-orphan "$repo_dir" "user/$handle" "init: user/$handle branch"
  fi

  # Write profile.md to user branch
  local profile_content="# @${handle}

- **Name**: ${name}
- **Role**: ${role}
- **Joined**: $(date +%Y-%m-%d)
- **Status**: active"
  bash "$SCRIPTS_DIR/savia-branch.sh" write "$repo_dir" "user/$handle" "profile.md" "$profile_content" "init: profile for @$handle"

  # Write state/state.md to user branch
  local state_content="# Savia State — @${handle}
last_sync: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  bash "$SCRIPTS_DIR/savia-branch.sh" write "$repo_dir" "user/$handle" "state/state.md" "$state_content" "init: savia state for @$handle"

  # Write inbox placeholders to user branch
  bash "$SCRIPTS_DIR/savia-branch.sh" write "$repo_dir" "user/$handle" "inbox/unread/.gitkeep" "" "init: unread inbox"
  bash "$SCRIPTS_DIR/savia-branch.sh" write "$repo_dir" "user/$handle" "inbox/read/.gitkeep" "" "init: read inbox"
  bash "$SCRIPTS_DIR/savia-branch.sh" write "$repo_dir" "user/$handle" "outbox/.gitkeep" "" "init: outbox"
  bash "$SCRIPTS_DIR/savia-branch.sh" write "$repo_dir" "user/$handle" "flow/assigned/.gitkeep" "" "init: flow assigned"
  bash "$SCRIPTS_DIR/savia-branch.sh" write "$repo_dir" "user/$handle" "flow/timesheet/.gitkeep" "" "init: flow timesheet"
  bash "$SCRIPTS_DIR/savia-branch.sh" write "$repo_dir" "user/$handle" "documents/.gitkeep" "" "init: documents"
  bash "$SCRIPTS_DIR/savia-branch.sh" write "$repo_dir" "user/$handle" "private/.gitkeep" "" "init: private"

  # Publish pubkey to main branch
  if [ -f "$HOME/.pm-workspace/savia-keys/public.pem" ]; then
    cp "$HOME/.pm-workspace/savia-keys/public.pem" "$repo_dir/pubkeys/${handle}.pem" 2>/dev/null || true
  fi

  # Update directory.md on main branch
  if [ -f "$repo_dir/directory.md" ] && ! grep -q "@${handle}" "$repo_dir/directory.md"; then
    echo "| @${handle} | ${name} | ${role} | active |" >> "$repo_dir/directory.md"
  fi

  # Update CODEOWNERS on main branch
  if [ -f "$repo_dir/CODEOWNERS" ]; then
    echo "pubkeys/${handle}.pem @${handle}" >> "$repo_dir/CODEOWNERS"
  fi

  log_ok "User branch user/$handle created for @${handle}"
}

# ── Main ────────────────────────────────────────────────────────────
main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    init)         do_init "$@" ;;
    user-folders) do_user_folders "$@" ;;
    help|*)
      echo "company-repo-templates.sh — Templates for Company Savia repos"
      echo ""
      echo "Uso: bash scripts/company-repo-templates.sh {command} [args]"
      echo ""
      echo "Commands:"
      echo "  init <dir> <org> <admin>   — Create full repo structure"
      echo "  user-folders <dir> <handle> <name> [role] — Create personal folders"
      ;;
  esac
}

main "$@"
