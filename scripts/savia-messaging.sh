#!/bin/bash
# savia-messaging.sh — Message creation, delivery, and inbox management
# Uso: bash scripts/savia-messaging.sh {send|inbox|reply|announce|broadcast|read|directory} [args]
#
# Async messaging for Company Savia. Messages are markdown files
# with YAML frontmatter, stored in the company git repo.

set -euo pipefail

# ── Constantes ──────────────────────────────────────────────────────
CONFIG_DIR="$HOME/.pm-workspace"
CONFIG_FILE="$CONFIG_DIR/company-repo"
READ_LOG="$CONFIG_DIR/company-inbox-read.log"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS_DIR/savia-compat.sh"

# ── Colores ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info()  { echo -e "${BLUE}ℹ${NC}  $1"; }
log_ok()    { echo -e "${GREEN}✅${NC} $1"; }
log_warn()  { echo -e "${YELLOW}⚠️${NC}  $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

# ── Config helpers ──────────────────────────────────────────────────
read_config() {
  local key="$1"
  portable_read_config "$key" "$CONFIG_FILE"
}

get_repo() {
  local path
  path=$(read_config "LOCAL_PATH")
  if [ -z "$path" ] || [ ! -d "$path/.git" ]; then
    log_error "No company repo. Run /company-repo connect first."
    exit 1
  fi
  echo "$path"
}

get_handle() {
  read_config "USER_HANDLE"
}

# ── Generate message ID ────────────────────────────────────────────
gen_id() {
  date +%Y%m%d-%H%M%S-$$
}

# ── Resolve @handle → inbox path ───────────────────────────────────
resolve_handle() {
  local repo_dir="$1" handle="$2"
  local inbox="$repo_dir/team/$handle/savia-inbox/unread"
  if [ ! -d "$repo_dir/team/$handle" ]; then
    log_error "Handle @$handle not found in team directory"
    return 1
  fi
  mkdir -p "$inbox"
  echo "$inbox"
}

# ── Source: inbox, read, reply, announce, broadcast, directory ────
source "$SCRIPTS_DIR/savia-messaging-inbox.sh"
source "$SCRIPTS_DIR/savia-messaging-actions.sh"

# ── Send: direct message to @handle ────────────────────────────────
do_send() {
  local recipient="${1:?Uso: savia-messaging.sh send <handle> <subject> <body> [--encrypt]}"
  local subject="${2:?Falta subject}"
  local body="${3:?Falta body}"
  local encrypt="false" priority="normal" thread="" reply_to=""

  shift 3
  while [ $# -gt 0 ]; do
    case "$1" in
      --encrypt)  encrypt="true" ;;
      --priority) shift; priority="${1:-normal}" ;;
      --thread)   shift; thread="${1:-}" ;;
      --reply-to) shift; reply_to="${1:-}" ;;
    esac
    shift
  done

  local repo_dir handle msg_id
  repo_dir=$(get_repo)
  handle=$(get_handle)
  msg_id=$(gen_id)

  local inbox
  inbox=$(resolve_handle "$repo_dir" "$recipient") || return 1

  # Encrypt body if requested
  local final_body="$body"
  if [ "$encrypt" = "true" ]; then
    local pubkey="$repo_dir/team/$recipient/public/pubkey.pem"
    if [ ! -f "$pubkey" ]; then
      log_error "@$recipient has no public key. Cannot encrypt."
      return 1
    fi
    final_body=$(bash "$SCRIPTS_DIR/savia-crypto.sh" encrypt "$pubkey" "$body")
  fi

  cat > "$inbox/${msg_id}.md" <<EOF
---
id: "${msg_id}"
from: "${handle}"
to: "${recipient}"
date: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
subject: "${subject}"
priority: "${priority}"
thread: "${thread}"
reply_to: "${reply_to}"
encrypted: ${encrypt}
---

${final_body}
EOF

  log_ok "Message sent to @$recipient: $subject"
  echo "  ID: $msg_id"
}

# ── Main ────────────────────────────────────────────────────────────
main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    send)      do_send "$@" ;;
    inbox)     do_inbox ;;
    reply)     do_reply "$@" ;;
    announce)  do_announce "$@" ;;
    broadcast) do_broadcast "$@" ;;
    read)      do_read "$@" ;;
    directory) do_directory ;;
    help|*)
      echo "savia-messaging.sh — Async messaging for Company Savia"
      echo ""
      echo "Commands:"
      echo "  send <handle> <subject> <body> [--encrypt] — Send DM"
      echo "  inbox                                       — View inbox"
      echo "  reply <msg_id> <body> [--encrypt]           — Reply"
      echo "  announce <subject> <body>                   — Announcement"
      echo "  broadcast <subject> <body>                  — Send to all"
      echo "  read <msg_id>                               — Read message"
      echo "  directory                                   — List members"
      ;;
  esac
}

main "$@"
