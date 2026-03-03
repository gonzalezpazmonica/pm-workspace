#!/bin/bash
# savia-messaging-inbox.sh — Inbox, read, and reply operations
# Sourced by savia-messaging.sh — do NOT run directly.

# ── Inbox: list personal messages ──────────────────────────────────
do_inbox() {
  local repo_dir handle
  repo_dir=$(get_repo)
  handle=$(get_handle)

  local unread_dir="$repo_dir/users/$handle/inbox/unread"
  local read_dir="$repo_dir/users/$handle/inbox/read"
  mkdir -p "$unread_dir" "$read_dir"

  echo -e "${CYAN}━━━ Inbox — @$handle ━━━${NC}"

  # Unread messages
  local unread_count=0
  echo -e "\n${YELLOW}📬 Unread:${NC}"
  for msg in "$unread_dir"/*.md; do
    [ -f "$msg" ] || continue
    unread_count=$((unread_count + 1))
    local from subject date priority
    from=$(portable_yaml_field "from" "$msg")
    [ -z "$from" ] && from="?"
    subject=$(portable_yaml_field "subject" "$msg")
    [ -z "$subject" ] && subject="(no subject)"
    date=$(portable_yaml_field "date" "$msg")
    [ -z "$date" ] && date="?"
    priority=$(portable_yaml_field "priority" "$msg")
    [ -z "$priority" ] && priority="normal"
    local pri_icon=""
    [ "$priority" = "high" ] && pri_icon="🔴 "
    echo "  ${pri_icon}[$date] @$from: $subject  ($(basename "$msg" .md))"
  done
  [ "$unread_count" -eq 0 ] && echo "  (no unread messages)"

  # Company announcements
  echo -e "\n${CYAN}📢 Company Announcements:${NC}"
  local ann_count=0
  if [ -d "$repo_dir/company/inbox" ]; then
    touch "$READ_LOG"
    for ann in "$repo_dir/company/inbox"/*.md; do
      [ -f "$ann" ] || continue
      local ann_id
      ann_id=$(basename "$ann" .md)
      local is_read="false"
      grep -q "$ann_id" "$READ_LOG" 2>/dev/null && is_read="true"
      if [ "$is_read" = "false" ]; then
        ann_count=$((ann_count + 1))
        local from subject date
        from=$(portable_yaml_field "from" "$ann")
        [ -z "$from" ] && from="admin"
        subject=$(portable_yaml_field "subject" "$ann")
        [ -z "$subject" ] && subject="(no subject)"
        date=$(portable_yaml_field "date" "$ann")
        [ -z "$date" ] && date="?"
        echo "  🆕 [$date] @$from: $subject  ($ann_id)"
      fi
    done
  fi
  [ "$ann_count" -eq 0 ] && echo "  (no new announcements)"

  echo -e "\n  Total: $unread_count unread · $ann_count new announcements"
}

# ── Read: read a specific message ──────────────────────────────────
do_read() {
  local msg_id="${1:?Uso: savia-messaging.sh read <message_id>}"
  local repo_dir handle
  repo_dir=$(get_repo)
  handle=$(get_handle)

  local msg_file="$repo_dir/users/$handle/inbox/unread/${msg_id}.md"
  local is_announcement="false"

  [ ! -f "$msg_file" ] && msg_file="$repo_dir/users/$handle/inbox/read/${msg_id}.md"
  if [ ! -f "$msg_file" ]; then
    msg_file="$repo_dir/company/inbox/${msg_id}.md"
    is_announcement="true"
  fi
  if [ ! -f "$msg_file" ]; then
    log_error "Message $msg_id not found"
    return 1
  fi

  cat "$msg_file"

  # Move to read (personal) or mark as read (announcement)
  if [ "$is_announcement" = "true" ]; then
    touch "$READ_LOG"
    grep -q "$msg_id" "$READ_LOG" 2>/dev/null || \
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)|$msg_id" >> "$READ_LOG"
  else
    local unread_path="$repo_dir/users/$handle/inbox/unread/${msg_id}.md"
    if [ -f "$unread_path" ]; then
      mkdir -p "$repo_dir/users/$handle/inbox/read"
      mv "$unread_path" "$repo_dir/users/$handle/inbox/read/"
    fi
  fi
}

# ── Reply: respond to a message ────────────────────────────────────
do_reply() {
  local msg_id="${1:?Uso: savia-messaging.sh reply <msg_id> <body> [--encrypt]}"
  local body="${2:?Falta body}"
  shift 2

  local repo_dir handle
  repo_dir=$(get_repo)
  handle=$(get_handle)

  local orig_file=""
  for dir in "users/$handle/inbox/unread" "users/$handle/inbox/read" "company/inbox"; do
    [ -f "$repo_dir/$dir/${msg_id}.md" ] && orig_file="$repo_dir/$dir/${msg_id}.md" && break
  done

  if [ -z "$orig_file" ]; then
    log_error "Original message $msg_id not found"
    return 1
  fi

  local orig_from orig_subject orig_thread
  orig_from=$(portable_yaml_field "from" "$orig_file")
  orig_subject=$(portable_yaml_field "subject" "$orig_file")
  orig_thread=$(portable_yaml_field "thread" "$orig_file")
  [ -z "$orig_thread" ] && orig_thread="$msg_id"
  [ -z "$orig_thread" ] && orig_thread="$msg_id"

  do_send "$orig_from" "Re: $orig_subject" "$body" --thread "$orig_thread" --reply-to "$msg_id" "$@"
}
