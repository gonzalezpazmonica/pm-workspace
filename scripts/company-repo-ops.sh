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

  # Create personal folders
  bash "$SCRIPTS_DIR/company-repo-templates.sh" user-folders "$local_path" "$handle" "$name" "$role"

  # Export pubkey if available
  if [ -f "$HOME/.pm-workspace/savia-keys/public.pem" ]; then
    bash "$SCRIPTS_DIR/savia-crypto.sh" export-pubkey "$local_path" "$handle" "users"
  fi

  # Commit and push
  git -C "$local_path" add -A
  git -C "$local_path" commit -m "feat: @$handle joined the team" 2>/dev/null

  if git -C "$local_path" push 2>/dev/null; then
    log_ok "Registration pushed"
  else
    log_warn "Could not push (check permissions). Local changes saved."
  fi

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

  # Unread messages
  local unread=0
  [ -d "$local_path/users/$handle/inbox/unread" ] && \
    unread=$(find "$local_path/users/$handle/inbox/unread" -name '*.md' 2>/dev/null | wc -l)
  echo -e "  Inbox:   $unread unread message(s)"

  # Company announcements
  local read_log="$CONFIG_DIR/company-inbox-read.log"
  if [ -d "$local_path/company/inbox" ]; then
    local total_ann read_count announcements
    total_ann=$(find "$local_path/company-inbox" -name '*.md' 2>/dev/null | wc -l)
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

# ── Sync: pull + push ──────────────────────────────────────────────
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

  # Privacy check before push
  if [ -f "$SCRIPTS_DIR/privacy-check-company.sh" ]; then
    bash "$SCRIPTS_DIR/privacy-check-company.sh" "$local_path" "$handle" || {
      log_error "Privacy check failed. Fix violations before syncing."
      return 1
    }
  fi

  # Pull with rebase
  if git -C "$local_path" pull --rebase 2>/dev/null; then
    log_ok "Pulled latest changes"
  else
    log_warn "Pull failed — possible conflict. Resolve manually in $local_path"
    return 1
  fi

  # Stage and push any local changes
  git -C "$local_path" add -A 2>/dev/null
  if git -C "$local_path" diff --cached --quiet 2>/dev/null; then
    log_info "No local changes to push"
  else
    git -C "$local_path" commit -m "sync: @$handle — $(date +%Y-%m-%d)" 2>/dev/null
    if git -C "$local_path" push 2>/dev/null; then
      log_ok "Pushed local changes"
    else
      log_warn "Push failed (check permissions)"
    fi
  fi

  log_ok "Sync complete"
}
