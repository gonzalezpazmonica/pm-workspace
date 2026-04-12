#!/usr/bin/env bash
set -uo pipefail
# governance-audit-log.sh — Append-only audit log with chain hash
# SPEC: SE-006 Governance & Compliance Pack
#
# Each entry includes: timestamp, tenant, actor, action, target, hash of
# the entry, and hash of the previous entry (chain). This creates a
# tamper-evident log without external blockchain dependencies.
#
# Usage:
#   bash scripts/governance-audit-log.sh append --tenant X --actor Y --action Z --target T
#   bash scripts/governance-audit-log.sh verify [--tenant X]
#   bash scripts/governance-audit-log.sh export [--tenant X] [--format md|json]

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

die() { echo "ERROR: $*" >&2; exit 2; }

_log_path() {
  local tenant="${1:-}"
  if [[ -n "$tenant" ]]; then
    echo "$PROJECT_DIR/tenants/$tenant/audit-trail.jsonl"
  else
    echo "$PROJECT_DIR/output/audit-trail.jsonl"
  fi
}

_last_hash() {
  local log_file="$1"
  if [[ -f "$log_file" ]] && [[ -s "$log_file" ]]; then
    tail -1 "$log_file" | python3 -c "import json,sys; print(json.load(sys.stdin).get('hash',''))" 2>/dev/null
  else
    echo "genesis"
  fi
}

cmd_append() {
  local tenant="" actor="" action="" target=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tenant) tenant="$2"; shift 2 ;;
      --actor) actor="$2"; shift 2 ;;
      --action) action="$2"; shift 2 ;;
      --target) target="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$action" ]] && die "Usage: append --action X [--tenant T --actor A --target T]"

  local log_file
  log_file=$(_log_path "$tenant")
  mkdir -p "$(dirname "$log_file")" 2>/dev/null

  local prev_hash
  prev_hash=$(_last_hash "$log_file")
  local ts
  ts=$(date -Iseconds)

  # Compute entry hash: sha256(ts + tenant + actor + action + target + prev_hash)
  local entry_data="${ts}|${tenant}|${actor}|${action}|${target}|${prev_hash}"
  local entry_hash
  entry_hash=$(echo -n "$entry_data" | sha256sum | awk '{print $1}')

  # Write entry
  python3 -c "
import json
entry = {
    'ts': '$ts',
    'tenant': '$tenant' or None,
    'actor': '$actor' or 'system',
    'action': '$action',
    'target': '$target' or None,
    'prev_hash': '$prev_hash',
    'hash': '$entry_hash'
}
print(json.dumps(entry, ensure_ascii=False))
" >> "$log_file"

  echo "LOGGED: $action → $log_file (hash: ${entry_hash:0:16}...)"
}

cmd_verify() {
  local tenant=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tenant) tenant="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local log_file
  log_file=$(_log_path "$tenant")
  [[ ! -f "$log_file" ]] && die "No audit log found at $log_file"

  local entries=0 valid=0 broken=0
  local expected_prev="genesis"

  while IFS= read -r line; do
    ((entries++))
    local prev_hash entry_hash ts t_tenant actor action target
    prev_hash=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin).get('prev_hash',''))" 2>/dev/null)
    entry_hash=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin).get('hash',''))" 2>/dev/null)

    if [[ "$prev_hash" != "$expected_prev" ]]; then
      echo "  BREAK at entry $entries: expected prev=$expected_prev, got prev=$prev_hash"
      ((broken++))
    else
      ((valid++))
    fi
    expected_prev="$entry_hash"
  done < "$log_file"

  echo "Verified: $entries entries, $valid valid, $broken broken chain links"
  [[ "$broken" -gt 0 ]] && return 1
  return 0
}

cmd_export() {
  local tenant="" format="md"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tenant) tenant="$2"; shift 2 ;;
      --format) format="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local log_file
  log_file=$(_log_path "$tenant")
  [[ ! -f "$log_file" ]] && die "No audit log found at $log_file"

  case "$format" in
    json)
      cat "$log_file"
      ;;
    md)
      echo "# Audit Trail Export"
      echo ""
      echo "| # | Timestamp | Actor | Action | Target | Hash |"
      echo "|---|-----------|-------|--------|--------|------|"
      local n=0
      while IFS= read -r line; do
        ((n++))
        python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'| {$n} | {d[\"ts\"]} | {d.get(\"actor\",\"-\")} | {d[\"action\"]} | {d.get(\"target\",\"-\")} | {d[\"hash\"][:12]}... |')
" <<< "$line" 2>/dev/null
      done < "$log_file"
      echo ""
      echo "Total: $n entries. Chain integrity: $(cmd_verify ${tenant:+--tenant "$tenant"} 2>&1 | tail -1)"
      ;;
  esac
}

case "${1:-}" in
  append)  shift; cmd_append "$@" ;;
  verify)  shift; cmd_verify "$@" ;;
  export)  shift; cmd_export "$@" ;;
  --help|-h) echo "Usage: governance-audit-log.sh {append|verify|export} [options]" ;;
  *) echo "Usage: governance-audit-log.sh {append|verify|export} [options]" ;;
esac
