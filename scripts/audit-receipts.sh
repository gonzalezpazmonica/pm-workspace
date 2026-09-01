#!/usr/bin/env bash
# audit-receipts.sh — SE-355: Audit Ledger metadata-only + decision receipts.
# set -uo pipefail
#
# Registro append-only de decisiones de auditoría. Metadata-only: identidad,
# orden, acción y outcome — JAMÁS prompts, bodies, argumentos ni filenames.
# Los receipts marcan `enforced: true` solo cuando un gate de código gobernó
# la decisión (un éxito desnudo nunca se promueve a prueba de autorización).
#
# Ledger: data/audit/actions.jsonl (local, CRIT-001, sin egress)
#
# Modos:
#   write  --action ACTION --actor ACTOR [--outcome O] [--gate G] [--session S]
#          --outcome ∈ enforced_deny|enforced_allow|success|failure
#          --gate opcional; si se da → enforced=true (gate gobernó la acción)
#   query  [--actor A] [--gate G] [--action A] [--days N] [--all]
#          default: cutoff 30 días
#   governed    → lista receipts con enforced=true (decisiones gobernadas)
#   prune  [--days N]   → borra en batch registros más viejos que N días (default 30)
#   stats          → resumen de counts
#
# Prohibido escribir en el ledger: prompts, bodies, args, filenames, secrets.
# Ref: SE-355 — Audit Ledger metadata-only + decision receipts
set -uo pipefail

LEDGER_DIR="${SAVIA_AUDIT_DIR:-$PWD/data/audit}"
LEDGER_FILE="$LEDGER_DIR/actions.jsonl"
DEFAULT_DAYS=30
SEQ_FILE="$LEDGER_DIR/.seq"

_mk_dir() { mkdir -p "$LEDGER_DIR" 2>/dev/null || { echo "ERROR: no se puede crear $LEDGER_DIR" >&2; exit 1; }; }

_next_seq() {
  _mk_dir
  local seq=1
  if [[ -f "$SEQ_FILE" ]]; then
    seq=$(cat "$SEQ_FILE" 2>/dev/null | tr -d '[:space:]')
    seq=$((seq + 1))
  fi
  printf '%s' "$seq" > "$SEQ_FILE"
  echo "$seq"
}

# ── write: append receipt (metadata-only) ─────────────────────────────────────
cmd_write() {
  local action="" actor="" outcome="success" gate="" session="unknown"
  while [[ $# -gt 0 ]]; do case "$1" in
    --action) action="$2"; shift 2 ;;
    --actor) actor="$2"; shift 2 ;;
    --outcome) outcome="$2"; shift 2 ;;
    --gate) gate="$2"; shift 2 ;;
    --session) session="$2"; shift 2 ;;
    *) shift ;;
  esac; done

  [[ -z "$action" || -z "$actor" ]] && { echo "Uso: audit-receipts.sh write --action A --actor X [--outcome O] [--gate G] [--session S]" >&2; exit 1; }
  case "$outcome" in
    enforced_deny|enforced_allow|success|failure) ;;
    *) echo "ERROR: --outcome '$outcome' inválido. Válidos: enforced_deny|enforced_allow|success|failure." >&2; exit 1 ;;
  esac

  _mk_dir
  local seq ts enforced="false"
  seq=$(_next_seq)
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "now")
  [[ -n "$gate" ]] && enforced="true"

  printf '{"seq":%s,"ts":"%s","session_id":"%s","actor":"%s","action":"%s","outcome":"%s","enforced":%s,"gate_id":"%s"}\n' \
    "$seq" "$ts" "$session" "$actor" "$action" "$outcome" "$enforced" "${gate:-null}" >> "$LEDGER_FILE"
  echo "receipt $seq: $action ($actor) → $outcome${gate:+ via $gate}"
}

# ── query: metadata-only filter with 30-day default cutoff ────────────────────
cmd_query() {
  [[ -f "$LEDGER_FILE" ]] || { echo "Ledger vacío: $LEDGER_FILE"; return 0; }
  local actor= gate= action= days="$DEFAULT_DAYS" all=false
  while [[ $# -gt 0 ]]; do case "$1" in
    --actor) actor="$2"; shift 2 ;;
    --gate) gate="$2"; shift 2 ;;
    --action) action="$2"; shift 2 ;;
    --days) days="$2"; shift 2 ;;
    --all) all=true; shift ;;
    *) shift ;;
  esac; done

  local cutoff_epoch
  if $all; then cutoff_epoch=0; else cutoff_epoch=$(date -u -d "${days} days ago" +%s 2>/dev/null || echo 0); fi

  local count=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local ts actor_f gate_f action_f
    ts=$(echo "$line" | grep -o '"ts":"[^"]*"' | cut -d'"' -f4)
    actor_f=$(echo "$line" | grep -o '"actor":"[^"]*"' | cut -d'"' -f4)
    gate_f=$(echo "$line" | grep -o '"gate_id":"[^"]*"' | cut -d'"' -f4)
    action_f=$(echo "$line" | grep -o '"action":"[^"]*"' | cut -d'"' -f4)
    [[ "$gate_f" == "null" ]] && gate_f=""

    if ! $all; then
      local ts_epoch
      ts_epoch=$(date -d "$ts" +%s 2>/dev/null || echo 9999999999)
      [[ $ts_epoch -lt $cutoff_epoch ]] && continue
    fi
    [[ -n "$actor" && "$actor_f" != "$actor" ]] && continue
    [[ -n "$gate" && "$gate_f" != "$gate" ]] && continue
    [[ -n "$action" && "$action_f" != "$action" ]] && continue
    echo "$line"
    count=$((count + 1))
  done < "$LEDGER_FILE"
  echo "($count receipts)" >&2
}

# ── governed: solo decisiones gobernadas (enforced=true) ─────────────────────
cmd_governed() {
  [[ -f "$LEDGER_FILE" ]] || { echo "Ledger vacío: $LEDGER_FILE"; return 0; }
  grep '"enforced":true' "$LEDGER_FILE" | grep -v '"gate_id":"null"'
}

# ── prune: batch delete older than N days ─────────────────────────────────────
cmd_prune() {
  [[ -f "$LEDGER_FILE" ]] || { echo "Ledger vacío: $LEDGER_FILE"; return 0; }
  local days="$DEFAULT_DAYS"
  while [[ $# -gt 0 ]]; do case "$1" in --days) days="$2"; shift 2 ;; *) shift ;; esac; done
  local cutoff_epoch removed=0 kept=0 tmp_file
  cutoff_epoch=$(date -u -d "${days} days ago" +%s 2>/dev/null || echo 0)
  tmp_file=$(mktemp)
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local ts ts_epoch
    ts=$(echo "$line" | grep -o '"ts":"[^"]*"' | cut -d'"' -f4)
    ts_epoch=$(date -d "$ts" +%s 2>/dev/null || echo 9999999999)
    if [[ $ts_epoch -lt $cutoff_epoch ]]; then
      removed=$((removed + 1))
    else
      echo "$line" >> "$tmp_file"
      kept=$((kept + 1))
    fi
  done < "$LEDGER_FILE"
  if [[ $removed -gt 0 ]]; then
    mv "$tmp_file" "$LEDGER_FILE"
    echo "Pruned $removed receipts (older than ${days}d), kept $kept."
  else
    rm -f "$tmp_file"
    echo "No receipts to prune (${days}d window). Kept $kept."
  fi
}

# ── stats ─────────────────────────────────────────────────────────────────────
cmd_stats() {
  [[ -f "$LEDGER_FILE" ]] || { echo "Ledger vacío: $LEDGER_FILE"; return 0; }
  local total governed enforced_deny enforced_allow success failure
  total=$(wc -l < "$LEDGER_FILE")
  governed=$(grep -c '"enforced":true' "$LEDGER_FILE" 2>/dev/null || echo 0)
  enforced_deny=$(grep -c '"outcome":"enforced_deny"' "$LEDGER_FILE" 2>/dev/null || echo 0)
  enforced_allow=$(grep -c '"outcome":"enforced_allow"' "$LEDGER_FILE" 2>/dev/null || echo 0)
  success=$(grep -c '"outcome":"success"' "$LEDGER_FILE" 2>/dev/null || echo 0)
  failure=$(grep -c '"outcome":"failure"' "$LEDGER_FILE" 2>/dev/null || echo 0)
  echo "Audit ledger: $total receipts"
  echo "  gobernadas (enforced=true): $governed"
  echo "  enforced_deny: $enforced_deny | enforced_allow: $enforced_allow"
  echo "  success: $success | failure: $failure"
}

case "${1:-help}" in
  write)   shift; cmd_write "$@" ;;
  query)   shift; cmd_query "$@" ;;
  governed) shift; cmd_governed "$@" ;;
  prune)   shift; cmd_prune "$@" ;;
  stats)   cmd_stats ;;
  help|*) cat <<'USAGE'
audit-receipts.sh {write|query|governed|prune|stats}

  write --action A --actor X [--outcome O] [--gate G] [--session S]
    outcome ∈ enforced_deny|enforced_allow|success|failure
    gate presente → enforced=true (gate gobernó la acción)
  query [--actor X] [--gate G] [--action A] [--days N] [--all]
    default cutoff 30 días; --all ignora cutoff
  governed          → solo receipts enforced=true (decisiones gobernadas)
  prune [--days N]  → borra en batch registros > N días (default 30)
  stats             → resumen de counts
USAGE
    exit 0 ;;
esac
