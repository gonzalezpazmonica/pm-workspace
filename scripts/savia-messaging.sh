#!/bin/bash
# savia-messaging.sh — Message creation, delivery, and inbox management
# Uso: bash scripts/savia-messaging.sh {send|inbox|reply|announce|broadcast|read|directory} [args]
#      El cuerpo NUNCA va en argv: --body-file <fichero 0600|-> o stdin.
#        printf '%s' "$cuerpo" | savia-messaging.sh send <handle> <asunto> [--encrypt]
#
# Async messaging for Company Savia via exchange orphan branch.
# Messages flow through exchange:pending/, then to user/:handle/inbox/

set -euo pipefail

# ── Constantes ──────────────────────────────────────────────────────
CONFIG_DIR="$HOME/.pm-workspace"
CONFIG_FILE="$CONFIG_DIR/company-repo"
READ_LOG="$CONFIG_DIR/company-inbox-read.log"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS_DIR/savia-compat.sh"
source "$SCRIPTS_DIR/savia-branch.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; NC='\033[0m'
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
# Timestamp + PID + random suffix: a broadcast sends several messages from
# the same process in the same second, and they must not share an ID.
gen_id() {
  printf '%s-%s-%s\n' "$(date +%Y%m%d-%H%M%S)" "$$" \
    "$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
}

# ── Handles: [A-Za-z0-9_-] only (they become branch names and paths) ──
valid_handle() {
  [[ "${1:-}" =~ ^[A-Za-z0-9_-]+$ ]]
}

# ── Handles listed in directory.md (table "| @h | ..." or bare "@h") ──
directory_handles() {
  sed -n -E 's/^[|[:space:]]*@([A-Za-z0-9_-]+)([[:space:]|].*)?$/\1/p'
}

# ── Resolve @handle via directory.md on main branch (exact match) ──
resolve_handle() {
  local repo_dir="$1" handle="$2"
  if ! valid_handle "$handle"; then
    log_error "Invalid handle: @$handle"
    return 1
  fi
  bash "$SCRIPTS_DIR/savia-branch.sh" read "$repo_dir" main "directory.md" 2>/dev/null \
    | directory_handles | grep -qx -- "$handle" \
    || { log_error "Handle @$handle not found"; return 1; }
  return 0
}

# ── Source: inbox, read, reply, announce, broadcast, directory ────
source "$SCRIPTS_DIR/savia-messaging-inbox.sh"
source "$SCRIPTS_DIR/savia-messaging-actions.sh"
source "$SCRIPTS_DIR/savia-messaging-privacy.sh"

# ── Send: direct message to @handle via exchange branch ────────────
do_send() {
  local recipient="${1:?Uso: savia-messaging.sh send <handle> <subject> [--body-file f] [--encrypt] < body}"
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

  # Fresh directory and pubkeys: a rotated or revoked key must not be used.
  # Offline, the last fetched view is used and the user is told so.
  git -C "$repo_dir" fetch -q origin main 2>/dev/null \
    || log_warn "Could not refresh main: using the last fetched directory and keys"
  resolve_handle "$repo_dir" "$recipient" || return 1

  # Subject sensitivity check (warn, don't block)
  check_subject_sensitivity "$subject" "$encrypt" || true

  # Encrypt body if requested
  local final_body="$body"
  if [ "$encrypt" = "true" ]; then
    local pubkey_content
    pubkey_content=$(bash "$SCRIPTS_DIR/savia-branch.sh" read "$repo_dir" main "pubkeys/$recipient.pem") \
      || { log_error "@$recipient has no public key"; return 1; }
    local pubkey_file
    pubkey_file=$(mktemp)
    echo "$pubkey_content" > "$pubkey_file"
    # Body through stdin, not argv (/proc/<pid>/cmdline is world-readable)
    final_body=$(printf '%s' "$body" | bash "$SCRIPTS_DIR/savia-crypto.sh" encrypt "$pubkey_file") \
      || { rm -f "$pubkey_file"; log_error "Encryption for @$recipient failed"; return 1; }
    rm -f "$pubkey_file"
  fi

  local msg_content
  msg_content=$(cat <<EOF
---
id: "${msg_id}"
from: "@${handle}"
to: "@${recipient}"
date: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
subject: "${subject}"
priority: "${priority}"
thread: "${thread}"
reply_to: "${reply_to}"
encrypted: ${encrypt}
type: "message"
---

${final_body}
EOF
)

  # Privacy gate before any push (secrets, keys, private IPs...)
  printf '%s\n' "$msg_content" | bash "$SCRIPTS_DIR/privacy-check-company.sh" --stdin \
    || { log_error "Message to @$recipient blocked by privacy check"; return 1; }

  # Write to exchange:pending/ (explicit returns: do_send also runs
  # inside "&&" in broadcast, where set -e does not apply)
  # Content through stdin ("-"): it holds the body, which must not reach argv
  printf '%s\n' "$msg_content" | bash "$SCRIPTS_DIR/savia-branch.sh" write "$repo_dir" exchange "pending/${msg_id}.md" - \
    "[exchange] msg: @$handle → @$recipient" \
    || { log_error "Delivery to exchange failed: message NOT sent"; return 1; }

  # Save copy to sender's outbox
  printf '%s\n' "$msg_content" | bash "$SCRIPTS_DIR/savia-branch.sh" write "$repo_dir" "user/$handle" "outbox/${msg_id}.md" - \
    "[user/$handle] outbox: sent to @$recipient" \
    || log_warn "Message delivered, but the outbox copy could not be saved"

  log_ok "Message sent to @$recipient: $subject"
  echo "  ID: $msg_id"
}

# ── CLI body: --body-file <0600 file|-> or stdin, never argv ───────
# /proc/<pid>/cmdline is readable by every local user for the whole run
# (fetch, privacy gate, push), so a body passed as an argument would leak
# even when the message is sent with --encrypt. Leaves CLI_POS (positional
# args), CLI_OPTS (options to forward) and CLI_BODY.
cli_body() {
  local max_pos="$1" file="" mode
  shift
  CLI_POS=(); CLI_OPTS=(); CLI_BODY=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --body-file) file="${2:-}"; [ -n "$file" ] || { log_error "--body-file needs a path"; exit 2; }; shift 2 ;;
      --priority|--thread|--reply-to) CLI_OPTS+=("$1" "${2:-}"); shift; [ $# -gt 0 ] && shift ;;
      --*) CLI_OPTS+=("$1"); shift ;;
      *) CLI_POS+=("$1"); shift ;;
    esac
  done
  if [ "${#CLI_POS[@]}" -gt "$max_pos" ]; then
    log_error "The message body is not accepted as an argument (visible in /proc/<pid>/cmdline)."
    log_error "Use --body-file <file with mode 0600> or pipe the body on stdin."
    exit 2
  fi
  if [ -n "$file" ] && [ "$file" != "-" ]; then
    [ -f "$file" ] || { log_error "Body file not found: $file"; exit 1; }
    mode=$(stat -c '%a' "$file" 2>/dev/null || stat -f '%Lp' "$file")
    case "$mode" in
      600|400) ;;
      *) log_error "Body file must be 0600 (it is $mode): $file"; exit 1 ;;
    esac
    CLI_BODY=$(cat -- "$file")
  else
    if [ -z "$file" ] && [ -t 0 ]; then
      log_error "No message body: use --body-file <file> or pipe it on stdin"
      exit 1
    fi
    CLI_BODY=$(cat)
  fi
  [ -n "$CLI_BODY" ] || { log_error "Empty message body"; exit 1; }
}

# ── Main ────────────────────────────────────────────────────────────
main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    send)      cli_body 2 "$@"
               do_send "${CLI_POS[0]:-}" "${CLI_POS[1]:-}" "$CLI_BODY" "${CLI_OPTS[@]}" ;;
    inbox)     do_inbox ;;
    reply)     cli_body 1 "$@"
               do_reply "${CLI_POS[0]:-}" "$CLI_BODY" "${CLI_OPTS[@]}" ;;
    announce)  cli_body 1 "$@"
               do_announce "${CLI_POS[0]:-}" "$CLI_BODY" "${CLI_OPTS[@]}" ;;
    broadcast) cli_body 1 "$@"
               do_broadcast "${CLI_POS[0]:-}" "$CLI_BODY" "${CLI_OPTS[@]}" ;;
    read)      do_read "$@" ;;
    directory) do_directory ;;
    help|*) echo "Usage: savia-messaging.sh {send|inbox|reply|announce|broadcast|read|directory} [args]" ;;
  esac
}
main "$@"
