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

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Source: init repo structure ──────────────────────────────────
source "$SCRIPTS_DIR/company-repo-templates-init.sh"

# ── User folders: create personal directories ──────────────────────
do_user_folders() {
  local repo_dir="${1:?Uso: company-repo-templates.sh user-folders <dir> <handle> <name> <role>}"
  local handle="${2:?Falta handle}"
  local name="${3:?Falta name}"
  local role="${4:-Member}"

  local user_dir="$repo_dir/team/$handle"
  mkdir -p "$user_dir"/{public,documents,savia-state,private,savia-inbox/{unread,read}}

  # Public profile
  cat > "$user_dir/public/profile.md" <<EOF
# @${handle}

- **Name**: ${name}
- **Role**: ${role}
- **Joined**: $(date +%Y-%m-%d)
- **Status**: active
EOF

  # Savia state
  cat > "$user_dir/savia-state/state.md" <<EOF
# Savia State — @${handle}
last_sync: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

  # Add to CODEOWNERS
  if [ -f "$repo_dir/CODEOWNERS" ]; then
    echo "team/${handle}/ @${handle}" >> "$repo_dir/CODEOWNERS"
  fi

  # Add to directory.md
  if [ -f "$repo_dir/directory.md" ] && ! grep -q "@${handle}" "$repo_dir/directory.md"; then
    echo "| @${handle} | ${name} | ${role} | active |" >> "$repo_dir/directory.md"
  fi

  log_ok "User folders created for @${handle}"
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
