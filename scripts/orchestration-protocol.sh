#!/usr/bin/env bash
# scripts/orchestration-protocol.sh — SE-205: typed inter-agent messaging
# Inspired by Orca's worker_done/dispatch/escalation/gates pattern
# Ref: docs/rules/domain/orchestration-protocol.md
# Ref: output/research/orca-savia-20260607.md §7.1
set -uo pipefail

# ── Storage ───────────────────────────────────────────────────────────────────
# Support override via env (for tests: SAVIA_ORCA_DB_DIR)
if [[ -n "${SAVIA_ORCA_DB_DIR:-}" ]]; then
  ORCH_DIR="${SAVIA_ORCA_DB_DIR}"
else
  ORCH_DIR="${PROJECT_ROOT:-$(pwd)}/.savia/orchestration"
fi
mkdir -p "$ORCH_DIR"

# ── Helpers ───────────────────────────────────────────────────────────────────
_short_uuid() {
  # Generate an 8-char hex ID without external deps
  printf '%08x' "$(( RANDOM * RANDOM + RANDOM ))"
}

_ts() {
  date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ'
}

_task_file() {
  echo "${ORCH_DIR}/task-${1}.json"
}

_msg_file() {
  echo "${ORCH_DIR}/msg-${1}.json"
}

_task_exists() {
  local id="$1"
  [[ -f "$(_task_file "$id")" ]]
}

_read_task_field() {
  local file="$1" field="$2"
  # Portable field extraction from JSON without jq dependency
  grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null \
    | head -1 | sed 's/.*"[^"]*"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
}

_count_task_failures() {
  local task_id="$1" count=0
  # Count msg files for this task with type=worker_done and status=failed
  # Use while-read to avoid xargs portability issues
  while IFS= read -r f; do
    grep -q "\"status\"[[:space:]]*:[[:space:]]*\"failed\"" "$f" 2>/dev/null && (( count++ )) || true
  done < <(grep -rl "\"taskId\"[[:space:]]*:[[:space:]]*\"${task_id}\"" "${ORCH_DIR}" 2>/dev/null)
  echo "$count"
}

_die() {
  echo "ERROR: $*" >&2
  exit 1
}

_usage() {
  cat >&2 <<'EOF'
Usage: orchestration-protocol.sh <subcommand> [options]

Subcommands:
  task-create  --spec "description" [--deps "id1,id2"]
  task-list    [--status pending|dispatched|completed|failed|blocked]
  task-update  --id <id> --status <status>
  dispatch     --task <id> --to <agent_name>
  send         --type worker_done|escalation|heartbeat|decision_gate \
               --task <id> --dispatch <id> --summary "3 sentences" \
               [--files "a,b,c"] [--status failed|completed]
  check        [--wait] [--types worker_done,escalation] [--timeout 300]
  status

Environment:
  SAVIA_ORCA_DB_DIR   Override storage directory (used in tests)
  PROJECT_ROOT        Base path for .savia/ (default: cwd)
EOF
  exit 1
}

# ── Subcommand: task-create ───────────────────────────────────────────────────
cmd_task_create() {
  local spec="" deps=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --spec)    spec="$2";  shift 2 ;;
      --deps)    deps="$2";  shift 2 ;;
      *)         _die "task-create: unknown option: $1" ;;
    esac
  done
  [[ -n "$spec" ]] || _die "task-create: --spec is required"

  local id
  id="$(_short_uuid)"
  local ts
  ts="$(_ts)"

  # Build deps JSON array
  local deps_json="[]"
  if [[ -n "$deps" ]]; then
    deps_json="[$(echo "$deps" | tr ',' '\n' | sed 's/.*/"&"/' | paste -sd ',' -)]"
  fi

  cat > "$(_task_file "$id")" <<EOF
{
  "taskId": "${id}",
  "spec": $(printf '%s' "$spec" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$spec"),
  "status": "pending",
  "deps": ${deps_json},
  "createdAt": "${ts}",
  "updatedAt": "${ts}",
  "dispatchCount": 0,
  "assignedTo": "",
  "dispatchId": ""
}
EOF

  echo "$id"
}

# ── Subcommand: task-list ─────────────────────────────────────────────────────
cmd_task_list() {
  local filter_status=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status) filter_status="$2"; shift 2 ;;
      *)        _die "task-list: unknown option: $1" ;;
    esac
  done

  local found=0
  for f in "${ORCH_DIR}"/task-*.json; do
    [[ -f "$f" ]] || continue
    found=1
    if [[ -n "$filter_status" ]]; then
      local s
      s="$(_read_task_field "$f" "status")"
      [[ "$s" == "$filter_status" ]] || continue
    fi
    local id spec status
    id="$(_read_task_field "$f" "taskId")"
    spec="$(_read_task_field "$f" "spec")"
    status="$(_read_task_field "$f" "status")"
    # If python3 encoded the spec as JSON, try to decode it simply
    printf "%-10s %-12s %s\n" "$id" "$status" "$spec"
  done

  if [[ $found -eq 0 ]]; then
    echo "No tasks found."
  fi
}

# ── Subcommand: task-update ───────────────────────────────────────────────────
cmd_task_update() {
  local id="" new_status=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id)     id="$2";         shift 2 ;;
      --status) new_status="$2"; shift 2 ;;
      *)        _die "task-update: unknown option: $1" ;;
    esac
  done
  [[ -n "$id" ]]         || _die "task-update: --id is required"
  [[ -n "$new_status" ]] || _die "task-update: --status is required"
  _task_exists "$id"     || _die "task-update: task '${id}' not found"

  local ts
  ts="$(_ts)"
  local file
  file="$(_task_file "$id")"

  # Update status and updatedAt in place (portable sed)
  local tmp
  tmp="$(mktemp)"
  sed "s/\"status\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"status\": \"${new_status}\"/" "$file" \
    | sed "s/\"updatedAt\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"updatedAt\": \"${ts}\"/" \
    > "$tmp"
  mv "$tmp" "$file"

  echo "updated"
}

# ── Subcommand: dispatch ──────────────────────────────────────────────────────
cmd_dispatch() {
  local task_id="" agent_name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task) task_id="$2";   shift 2 ;;
      --to)   agent_name="$2"; shift 2 ;;
      *)      _die "dispatch: unknown option: $1" ;;
    esac
  done
  [[ -n "$task_id" ]]   || _die "dispatch: --task is required"
  [[ -n "$agent_name" ]] || _die "dispatch: --to is required"
  _task_exists "$task_id" || _die "dispatch: task '${task_id}' not found"

  local dispatch_id
  dispatch_id="d$(_short_uuid)"
  local ts
  ts="$(_ts)"
  local file
  file="$(_task_file "$task_id")"

  local tmp
  tmp="$(mktemp)"
  sed "s/\"status\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"status\": \"dispatched\"/" "$file" \
    | sed "s/\"assignedTo\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"assignedTo\": \"${agent_name}\"/" \
    | sed "s/\"dispatchId\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"dispatchId\": \"${dispatch_id}\"/" \
    | sed "s/\"updatedAt\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"updatedAt\": \"${ts}\"/" \
    > "$tmp"
  mv "$tmp" "$file"

  echo "$dispatch_id"
}

# ── Subcommand: send ──────────────────────────────────────────────────────────
cmd_send() {
  local msg_type="" task_id="" dispatch_id="" summary="" files="" msg_status="completed"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type)     msg_type="$2";    shift 2 ;;
      --task)     task_id="$2";     shift 2 ;;
      --dispatch) dispatch_id="$2"; shift 2 ;;
      --summary)  summary="$2";     shift 2 ;;
      --files)    files="$2";       shift 2 ;;
      --status)   msg_status="$2";  shift 2 ;;
      *)          _die "send: unknown option: $1" ;;
    esac
  done

  # Validate type
  case "$msg_type" in
    worker_done|escalation|heartbeat|decision_gate|handoff) ;;
    "") _die "send: --type is required" ;;
    *)  _die "send: invalid type '${msg_type}'. Valid: worker_done escalation heartbeat decision_gate handoff" ;;
  esac

  [[ -n "$task_id" ]]     || _die "send: --task is required"
  [[ -n "$dispatch_id" ]] || _die "send: --dispatch is required"
  [[ -n "$summary" ]]     || _die "send: --summary is required"
  _task_exists "$task_id" || _die "send: task '${task_id}' not found"

  local msg_id
  msg_id="m$(_short_uuid)"
  local ts
  ts="$(_ts)"

  # Build files JSON array
  local files_json="[]"
  if [[ -n "$files" ]]; then
    files_json="[$(echo "$files" | tr ',' '\n' | sed 's/.*/"&"/' | paste -sd ',' -)]"
  fi

  local summary_json
  summary_json=$(printf '%s' "$summary" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null \
    || printf '"%s"' "$(echo "$summary" | sed 's/"/\\"/g')")

  cat > "$(_msg_file "$msg_id")" <<EOF
{
  "msgId": "${msg_id}",
  "type": "${msg_type}",
  "taskId": "${task_id}",
  "dispatchId": "${dispatch_id}",
  "summary": ${summary_json},
  "filesModified": ${files_json},
  "status": "${msg_status}",
  "read": false,
  "createdAt": "${ts}"
}
EOF

  # ── Circuit breaker: 3 failed worker_done → task=failed ───────────────────
  if [[ "$msg_type" == "worker_done" && "$msg_status" == "failed" ]]; then
    local fail_count
    fail_count="$(_count_task_failures "$task_id")"
    if [[ "$fail_count" -ge 3 ]]; then
      cmd_task_update --id "$task_id" --status "failed" 2>/dev/null || true
      echo "CIRCUIT_BREAKER: task ${task_id} set to failed after ${fail_count} failures"
    fi
  fi

  echo "$msg_id"
}

# ── Subcommand: check ─────────────────────────────────────────────────────────
cmd_check() {
  local do_wait=0 filter_types="" timeout_sec=300
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --wait)    do_wait=1;           shift ;;
      --types)   filter_types="$2";   shift 2 ;;
      --timeout) timeout_sec="$2";    shift 2 ;;
      *)         _die "check: unknown option: $1" ;;
    esac
  done

  # Convert comma-separated types to patterns
  local type_patterns=()
  if [[ -n "$filter_types" ]]; then
    IFS=',' read -ra type_patterns <<< "$filter_types"
  fi

  local deadline=$(( $(date +%s) + timeout_sec ))

  while true; do
    local found_any=0
    for f in "${ORCH_DIR}"/msg-*.json; do
      [[ -f "$f" ]] || continue
      # Check if unread
      local is_read
      is_read=$(grep -o '"read"[[:space:]]*:[[:space:]]*[^,}]*' "$f" | head -1 | grep -o 'true\|false')
      [[ "$is_read" == "false" ]] || continue

      # Filter by type if requested
      if [[ ${#type_patterns[@]} -gt 0 ]]; then
        local msg_type
        msg_type="$(_read_task_field "$f" "type")"
        local type_match=0
        for t in "${type_patterns[@]}"; do
          [[ "$msg_type" == "$t" ]] && type_match=1 && break
        done
        [[ $type_match -eq 1 ]] || continue
      fi

      found_any=1
      cat "$f"
      echo ""

      # Mark as read
      local tmp
      tmp="$(mktemp)"
      sed 's/"read"[[:space:]]*:[[:space:]]*false/"read": true/' "$f" > "$tmp"
      mv "$tmp" "$f"
    done

    if [[ $found_any -eq 1 ]] || [[ $do_wait -eq 0 ]]; then
      break
    fi

    # --wait: poll until timeout
    local now
    now=$(date +%s)
    if [[ $now -ge $deadline ]]; then
      echo "TIMEOUT: no messages received within ${timeout_sec}s"
      break
    fi
    sleep 2
  done
}

# ── Subcommand: status ────────────────────────────────────────────────────────
cmd_status() {
  local pending=0 dispatched=0 completed=0 failed=0 blocked=0 total=0

  for f in "${ORCH_DIR}"/task-*.json; do
    [[ -f "$f" ]] || continue
    (( total++ )) || true
    local s
    s="$(_read_task_field "$f" "status")"
    case "$s" in
      pending)    (( pending++    )) || true ;;
      dispatched) (( dispatched++ )) || true ;;
      completed)  (( completed++  )) || true ;;
      failed)     (( failed++     )) || true ;;
      blocked)    (( blocked++    )) || true ;;
    esac
  done

  local unread_msgs=0
  for f in "${ORCH_DIR}"/msg-*.json; do
    [[ -f "$f" ]] || continue
    local is_read
    is_read=$(grep -o '"read"[[:space:]]*:[[:space:]]*[^,}]*' "$f" | head -1 | grep -o 'true\|false')
    [[ "$is_read" == "false" ]] && (( unread_msgs++ )) || true
  done

  cat <<EOF
Orchestration status — SE-205
  Storage: ${ORCH_DIR}
  Tasks total: ${total}
    pending:    ${pending}
    dispatched: ${dispatched}
    completed:  ${completed}
    failed:     ${failed}
    blocked:    ${blocked}
  Unread messages: ${unread_msgs}
EOF
}

# ── Router ────────────────────────────────────────────────────────────────────
SUBCMD="${1:-}"
[[ -n "$SUBCMD" ]] || _usage
shift

case "$SUBCMD" in
  task-create) cmd_task_create "$@" ;;
  task-list)   cmd_task_list   "$@" ;;
  task-update) cmd_task_update "$@" ;;
  dispatch)    cmd_dispatch    "$@" ;;
  send)        cmd_send        "$@" ;;
  check)       cmd_check       "$@" ;;
  status)      cmd_status      "$@" ;;
  --help|-h)   _usage ;;
  *)           _die "Unknown subcommand: ${SUBCMD}. Run with --help." ;;
esac
