#!/bin/bash
# company-repo-ops.sh — Connect, status, and sync operations
# Sourced by company-repo.sh — do NOT run directly.

# ── Connect: employee joins company repo ──────────────────────────
do_connect() {
  local repo_url="${1:?Uso: company-repo.sh connect <git_url> <handle> <name> [role]}"
  local handle="${2:?Falta handle}"
  local name="${3:?Falta name}"
  local role="${4:-Member}"

  ensure_config
  local local_path="$CONFIG_DIR/company-savia"

  if [ -d "$local_path/.git" ]; then
    log_warn "Already connected. Use 'sync' to update."
    return 1
  fi

  log_info "Connecting to Company Savia..."

  git clone "$repo_url" "$local_path" 2>/dev/null
  log_ok "Cloned company repo"

  # Create user/{handle} orphan branch with personal folders
  bash "$SCRIPTS_DIR/company-repo-templates.sh" user-folders "$local_path" "$handle" "$name" "$role"

  # Push user/{handle} branch
  git -C "$local_path" push -u origin "user/$handle" 2>/dev/null || {
    log_warn "Could not push user branch (check permissions). Local changes saved."
  }

  # Save config
  write_config "REPO_URL" "$repo_url"
  write_config "USER_HANDLE" "$handle"
  write_config "LOCAL_PATH" "$local_path"
  write_config "ROLE" "$role"

  log_ok "Connected as @$handle"
}

# ── Status: show sync state ────────────────────────────────────────
do_status() {
  ensure_config
  local local_path
  local_path=$(read_config "LOCAL_PATH")

  if [ -z "$local_path" ] || [ ! -d "$local_path/.git" ]; then
    log_error "No company repo configured. Run 'create' or 'connect' first."
    return 1
  fi

  local handle repo_url role
  handle=$(read_config "USER_HANDLE")
  repo_url=$(read_config "REPO_URL")
  role=$(read_config "ROLE")

  echo -e "${CYAN}━━━ Company Savia Status ━━━${NC}"
  echo -e "  Handle:  @$handle ($role)"
  echo -e "  Repo:    $repo_url"
  echo -e "  Local:   $local_path"

  # Unread messages from user branch
  local unread=0
  if [ -f "$SCRIPTS_DIR/savia-branch.sh" ]; then
    local inbox_items
    inbox_items=$(bash "$SCRIPTS_DIR/savia-branch.sh" list "$local_path" "user/$handle" "inbox/unread" 2>/dev/null || echo "")
    unread=$(echo "$inbox_items" | grep -c '\.md$' 2>/dev/null || echo "0")
  fi
  echo -e "  Inbox:   $unread unread message(s)"

  # Company announcements from main branch
  local read_log="$CONFIG_DIR/company-inbox-read.log"
  if [ -d "$local_path/company/inbox" ]; then
    local total_ann read_count announcements
    total_ann=$(find "$local_path/company/inbox" -name '*.md' 2>/dev/null | wc -l)
    read_count=0
    [ -f "$read_log" ] && read_count=$(wc -l < "$read_log" | tr -d ' ')
    announcements=$((total_ann - read_count))
    [ "$announcements" -lt 0 ] && announcements=0
    echo -e "  Announce: $announcements new announcement(s)"
  fi

  # Last sync
  local last_commit
  last_commit=$(git -C "$local_path" log -1 --format='%ci' 2>/dev/null || echo "never")
  echo -e "  Last:    $last_commit"
}

# ── Sync: pull + push by branch ───────────────────────────────────
do_sync() {
  ensure_config
  local local_path handle
  local_path=$(read_config "LOCAL_PATH")
  handle=$(read_config "USER_HANDLE")

  if [ -z "$local_path" ] || [ ! -d "$local_path/.git" ]; then
    log_error "No company repo configured."
    return 1
  fi

  log_info "Syncing company repo..."

  # Privacy check before push (check user branch only)
  if [ -f "$SCRIPTS_DIR/privacy-check-company.sh" ]; then
    bash "$SCRIPTS_DIR/privacy-check-company.sh" "$local_path" "$handle" || {
      log_error "Privacy check failed. Fix violations before syncing."
      return 1
    }
  fi

  # Fetch all branches
  git -C "$local_path" fetch origin 2>/dev/null || true

  # Process pending messages from exchange branch
  if [ -f "$SCRIPTS_DIR/savia-branch.sh" ]; then
    local msg_count
    msg_count=$(bash "$SCRIPTS_DIR/savia-branch.sh" fetch-messages "$local_path" "$handle" 2>/dev/null || echo "0")
    [ "$msg_count" -gt 0 ] && log_ok "Fetched $msg_count pending message(s)"
  fi

  # Push user/{handle} branch changes
  git -C "$local_path" push origin "user/$handle" 2>/dev/null || {
    log_warn "Could not push user/$handle branch (check permissions)"
  }

  log_ok "Sync complete"
}
