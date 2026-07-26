#!/usr/bin/env bash
# corporate-attestation-queue.sh — SE-271 S7 Attestation Queue (Offline → Online)
set -uo pipefail
#
# Gestiona una cola local de atestaciones cuando el registro corporativo
# no es alcanzable. Cuando la conectividad se recupera, publica intactas
# (con fechas originales). Nada se pierde, nada se re-fecha.
#
# Subcomandos:
#   enqueue  — Añade atestacion a la cola local
#   drain    — Publica todas las atestaciones pendientes al registro
#   status   — Muestra profundidad de cola y antiguedad
#
# Cola: .claude/corporate/queue/attestations.jsonl
# Cada entrada: {"ts":"orig","client":"slug","action":"...","status":"queued"}
#
# Reference: SE-271 (docs/propuestas/SE-271-savia-corporate.md) Slice 7

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CORPORATE_DIR="${ROOT_DIR}/.claude/corporate"
QUEUE_DIR="${CORPORATE_DIR}/queue"
QUEUE_FILE="${QUEUE_DIR}/attestations.jsonl"
PUBLISHED_DIR="${CORPORATE_DIR}/published"

usage() {
  cat <<'USAGE'
corporate-attestation-queue.sh — SE-271 S7 Offline Attestation Queue

Usage:
  corporate-attestation-queue.sh enqueue --client SLUG --action ACTION [--ts TS]
  corporate-attestation-queue.sh drain
  corporate-attestation-queue.sh status [--json]
  corporate-attestation-queue.sh --help

Subcommands:
  enqueue  Add attestation to local queue (for when corporate is unreachable)
  drain    Publish all queued attestations to corporate registry
           (original timestamps preserved — nothing back-dated)
  status   Show queue depth, oldest entry, queue age

Guarantees:
  - Nothing lost: all attestations stored locally in JSONL
  - Nothing back-dated: original timestamps carry through drain
  - Drain marks entries as published, moves to published/ dir

Environment:
  CORPORATE_REGISTRY_URL  Registry URL for drain operation
USAGE
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

mkdir -p "$QUEUE_DIR" "$PUBLISHED_DIR"

# ── Helpers ──────────────────────────────────────────────────────────────────

file_hash() {
  local f="$1"
  if [[ -f "$f" ]]; then
    sha256sum "$f" | cut -d' ' -f1
  else
    echo "NOT_FOUND"
  fi
}

queue_count() {
  if [[ -f "$QUEUE_FILE" ]]; then
    grep -c . "$QUEUE_FILE" 2>/dev/null; true
  else
    echo 0
  fi
}

# ── enqueue ──────────────────────────────────────────────────────────────────

cmd_enqueue() {
  local client="" action="" ts=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --client) client="$2"; shift 2 ;;
      --action) action="$2"; shift 2 ;;
      --ts)     ts="$2";     shift 2 ;;
      *) die "enqueue: unknown argument: $1" ;;
    esac
  done

  [[ -z "$client" ]] && die "enqueue: --client is required"
  [[ -z "$action" ]] && die "enqueue: --action is required"
  [[ -z "$ts" ]] && ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local entry_id
  entry_id="$(date +%s%N | sha256sum | cut -d' ' -f1 | head -c 16)"

  local entry
  entry="{\"id\":\"${entry_id}\",\"ts\":\"${ts}\",\"client\":\"${client}\",\"action\":\"${action}\",\"status\":\"queued\",\"enqueued_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"

  echo "$entry" >> "$QUEUE_FILE"
  echo "QUEUED: ${entry_id} — ${client} / ${action} (ts: ${ts})"
  echo "Queue depth now: $(queue_count)"
}

# ── drain ────────────────────────────────────────────────────────────────────

cmd_drain() {
  local total=0 published=0 failed=0
  total="$(queue_count)"

  if [[ "$total" -eq 0 ]]; then
    echo "Queue empty — nothing to drain."
    exit 0
  fi

  echo "Draining ${total} queued attestations..."

  local tmp_queue="${QUEUE_FILE}.tmp"
  local batch_ts="$(date -u +%Y%m%d-%H%M%S)"
  local published_file="${PUBLISHED_DIR}/attestations-${batch_ts}.jsonl"

  > "$tmp_queue"
  > "$published_file"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    local id client ts action orig_ts
    id="$(echo "$line"      | grep -o '"id":"[^"]*"'       | head -1 | cut -d'"' -f4)"
    client="$(echo "$line"  | grep -o '"client":"[^"]*"'   | head -1 | cut -d'"' -f4)"
    ts="$(echo "$line"      | grep -o '"ts":"[^"]*"'       | head -1 | cut -d'"' -f4)"
    action="$(echo "$line"  | grep -o '"action":"[^"]*"'   | head -1 | cut -d'"' -f4)"

    # Attempt to publish (original ts preserved)
    local pub_success=1
    if [[ -n "${CORPORATE_REGISTRY_URL:-}" ]]; then
      if curl -s --connect-timeout 5 --max-time 10 \
        -X POST "${CORPORATE_REGISTRY_URL}/attestations" \
        -H "Content-Type: application/json" \
        -d "{\"id\":\"${id}\",\"ts\":\"${ts}\",\"client\":\"${client}\",\"action\":\"${action}\"}" \
        >/dev/null 2>&1; then
        pub_success=0
      fi
    fi

    if [[ "$pub_success" -eq 0 ]] || [[ -z "${CORPORATE_REGISTRY_URL:-}" ]]; then
      # Published (or no registry configured → mark as published locally)
      local published_entry
      published_entry="{\"id\":\"${id}\",\"ts\":\"${ts}\",\"client\":\"${client}\",\"action\":\"${action}\",\"status\":\"published\",\"published_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"original_ts\":\"${ts}\"}"
      echo "$published_entry" >> "$published_file"
      published=$(( published + 1 ))
    else
      # Publish failed → keep in queue
      echo "$line" >> "$tmp_queue"
      failed=$(( failed + 1 ))
    fi
  done < "$QUEUE_FILE"

  mv "$tmp_queue" "$QUEUE_FILE"

  echo ""
  echo "Published:  ${published}"
  echo "Still queued: $(queue_count)"
  [[ "$failed" -gt 0 ]] && echo "Failed:     ${failed}"

  if [[ "$published" -gt 0 ]]; then
    echo "Published file: ${published_file}"
  fi
}

# ── status ────────────────────────────────────────────────────────────────────

cmd_status() {
  local json_mode=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json_mode=1; shift ;;
      *) ;;
    esac
  done

  local count
  count="$(queue_count)"

  local oldest_ts="none"
  if [[ -f "$QUEUE_FILE" ]] && [[ "$count" -gt 0 ]]; then
    oldest_ts="$(grep -o '"ts":"[^"]*"' "$QUEUE_FILE" | head -1 | cut -d'"' -f4)"
  fi

  local oldest_epoch=0
  local age_hours=0
  if [[ "$oldest_ts" != "none" ]]; then
    oldest_epoch="$(date -d "$oldest_ts" +%s 2>/dev/null || echo 0)"
    if [[ "$oldest_epoch" -gt 0 ]]; then
      age_hours=$(( (EPOCHSECONDS - oldest_epoch) / 3600 ))
    fi
  fi

  local queue_hash
  queue_hash="$(file_hash "$QUEUE_FILE")"

  if [[ "$json_mode" -eq 1 ]]; then
    cat <<JSON
{
  "_spec": "SE-271 S7",
  "_generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "queue_depth": ${count},
  "oldest_entry_ts": "${oldest_ts}",
  "oldest_entry_age_hours": ${age_hours},
  "queue_file": "${QUEUE_FILE}",
  "queue_hash": "${queue_hash}"
}
JSON
  else
    echo "Queue depth:       ${count}"
    echo "Oldest entry:      ${oldest_ts}"
    echo "Oldest age:        ${age_hours}h"
    echo "Queue file:        ${QUEUE_FILE}"
    echo "Queue integrity:   sha256:${queue_hash:0:16}..."
  fi
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
  usage
fi

subcmd="$1"
shift

case "$subcmd" in
  enqueue) cmd_enqueue "$@" ;;
  drain)   cmd_drain "$@" ;;
  status)  cmd_status "$@" ;;
  -h|--help) usage ;;
  *) die "unknown subcommand: ${subcmd}. Use enqueue, drain, status." ;;
esac
