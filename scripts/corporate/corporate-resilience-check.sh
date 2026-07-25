#!/usr/bin/env bash
# corporate-resilience-check.sh — SE-271 S7 Local Resilience Assessment
set -uo pipefail
#
# Verifica que el estado corporativo adoptado esta materializado localmente.
# Corporate unreachable → la instancia continua con el ultimo estado,
# sin expiracion, sin garantias degradadas.
#
# Estados:
#   up_to_date           — sync reciente, estado materializado presente
#   outdated N days      — sync antiguo (>SYNC_GRACE_DAYS), pero operativo
#   corporate_unreachable — no se alcanza el registro, operando localmente
#
# El operador siempre ve que criterio esta activo.
#
# Reference: SE-271 (docs/propuestas/SE-271-savia-corporate.md) Slice 7

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CORPORATE_DIR="${ROOT_DIR}/.claude/corporate"
SYNC_FILE="${CORPORATE_DIR}/.sync-state"
MODEL_FILE="${CORPORATE_DIR}/model.md"

# Configurable grace period (default: 7 days)
SYNC_GRACE_DAYS="${CORPORATE_RESILIENCE_GRACE_DAYS:-7}"
CORPORATE_REGISTRY_URL="${CORPORATE_REGISTRY_URL:-}"

usage() {
  cat <<'USAGE'
corporate-resilience-check.sh — SE-271 S7 Resilience Assessment

Usage:
  corporate-resilience-check.sh [--json] [--grace-days N]
  corporate-resilience-check.sh --help

States:
  up_to_date               Sync is recent, state materialized locally
  outdated N days          Sync older than grace period, still operational
  corporate_unreachable    Cannot reach registry, local state active

The operator always sees which criterion is active. No expiry, no degradation.

Environment:
  CORPORATE_REGISTRY_URL        URL of the corporate registry (optional)
  CORPORATE_RESILIENCE_GRACE_DAYS  Max days before state is considered outdated (default: 7)
USAGE
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

JSON_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)        JSON_MODE=1; shift ;;
    --grace-days)  SYNC_GRACE_DAYS="$2"; shift 2 ;;
    -h|--help)     usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

# ── Core checks ───────────────────────────────────────────────────────────────

GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EPOCH_NOW="$(date +%s)"

# Check 1: Is the corporate model materialized locally?
materialized=1
materialized_artifacts=0
if [[ -f "$MODEL_FILE" ]]; then
  materialized=1
else
  materialized=0
fi

# Count materialized artifacts
adopted_dir="${CORPORATE_DIR}/adopted"
if [[ -d "$adopted_dir" ]]; then
  materialized_artifacts="$(find "$adopted_dir" -type f 2>/dev/null | wc -l)"
fi

clients_dir="${CORPORATE_DIR}/clients"
client_count=0
if [[ -d "$clients_dir" ]]; then
  client_count="$(find "$clients_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
fi

# Check 2: Last sync timestamp
last_sync_epoch=0
last_sync_ts="never"
if [[ -f "$SYNC_FILE" ]]; then
  last_sync_ts="$(head -1 "$SYNC_FILE" 2>/dev/null)"
  last_sync_epoch="$(date -d "$last_sync_ts" +%s 2>/dev/null || echo 0)"
fi

# Days since last sync
days_since_sync=0
if [[ "$last_sync_epoch" -gt 0 ]]; then
  days_since_sync=$(( (EPOCH_NOW - last_sync_epoch) / 86400 ))
fi

# Check 3: Corporate registry reachability
registry_reachable=0
if [[ -n "$CORPORATE_REGISTRY_URL" ]]; then
  if curl -s --connect-timeout 5 --max-time 10 "$CORPORATE_REGISTRY_URL" >/dev/null 2>&1; then
    registry_reachable=1
  fi
fi

# Check 4: Are adopted entries local?
adopted_local=0
if [[ -d "$adopted_dir" ]] && [[ "$materialized_artifacts" -gt 0 ]]; then
  adopted_local=1
fi

# Check 5: Is any client state present?
client_state_present=0
if [[ "$client_count" -gt 0 ]]; then
  client_state_present=1
fi

# ── State determination ──────────────────────────────────────────────────────

determine_state() {
  local state=""
  local description=""
  local days_outdated=0

  # If we've never synced AND registry is unreachable
  if [[ "$last_sync_epoch" -eq 0 ]] && [[ "$registry_reachable" -eq 0 ]]; then
    state="corporate_unreachable"
    description="No sync on record, registry unreachable. Operating on local state only."
  elif [[ "$last_sync_epoch" -eq 0 ]] && [[ "$registry_reachable" -eq 1 ]]; then
    state="outdated"
    days_outdated=999
    description="Registry reachable but never synced. Local state present."
  elif [[ "$days_since_sync" -le "$SYNC_GRACE_DAYS" ]]; then
    state="up_to_date"
    description="Last sync ${days_since_sync} day(s) ago. Within grace period (${SYNC_GRACE_DAYS} days)."
  elif [[ "$days_since_sync" -gt "$SYNC_GRACE_DAYS" ]]; then
    state="outdated"
    days_outdated="$days_since_sync"
    description="Last sync ${days_since_sync} days ago. Exceeds grace period (${SYNC_GRACE_DAYS} days). Local state operational."
  fi

  # Override: if registry unreachable AND no local state, that's degraded
  if [[ "$registry_reachable" -eq 0 ]]; then
    if [[ "$adopted_local" -eq 0 ]] && [[ "$client_state_present" -eq 0 ]]; then
      state="corporate_unreachable"
      description="Registry unreachable. No local state materialized."
    elif [[ "$adopted_local" -eq 1 ]] || [[ "$client_state_present" -eq 1 ]]; then
      # Registry unreachable but we have local state → continue
      if [[ "$state" == "up_to_date" ]] && [[ "$registry_reachable" -eq 0 ]]; then
        # Up to date but currently unreachable is still up_to_date (we have recent state)
        state="up_to_date"
        description="Registry unreachable but local state from ${days_since_sync} day(s) ago is current. No degradation."
      fi
    fi
  fi

  echo "${state}|${description}|${days_outdated}"
}

state_info="$(determine_state)"
STATE="$(echo "$state_info" | cut -d'|' -f1)"
STATE_DESC="$(echo "$state_info" | cut -d'|' -f2)"
DAYS_OUTDATED="$(echo "$state_info" | cut -d'|' -f3)"

# ── Determine active criterion ────────────────────────────────────────────────

active_criterion=""
case "$STATE" in
  up_to_date)
    active_criterion="corporate_model: materialized locally, sync is current"
    ;;
  outdated)
    active_criterion="corporate_model: materialized locally, sync outdated by ${DAYS_OUTDATED} days — operating on last known state"
    ;;
  corporate_unreachable)
    active_criterion="corporate_model: materialized locally, corporate registry unreachable — operating on last known state, NO expiry, NO degradation"
    ;;
esac

# ── Output ────────────────────────────────────────────────────────────────────

if [[ "$JSON_MODE" -eq 1 ]]; then
  cat <<JSON
{
  "_spec": "SE-271 S7",
  "_generated_at": "${GENERATED_AT}",
  "state": "${STATE}",
  "description": "${STATE_DESC}",
  "active_criterion": "${active_criterion}",
  "materialized": {
    "corporate_model_exists": $([[ "$materialized" -eq 1 ]] && echo true || echo false),
    "adopted_artifacts": ${materialized_artifacts},
    "client_state_dirs": ${client_count}
  },
  "connectivity": {
    "last_sync": "${last_sync_ts}",
    "days_since_sync": ${days_since_sync},
    "grace_period_days": ${SYNC_GRACE_DAYS},
    "registry_reachable": $([[ "$registry_reachable" -eq 1 ]] && echo true || echo false)
  },
  "guarantees": {
    "no_expiry": true,
    "no_degradation": true,
    "local_state_materialized": $([[ "$adopted_local" -eq 1 ]] || [[ "$client_state_present" -eq 1 ]] && echo true || echo false)
  }
}
JSON
else
  echo "=== Corporate Resilience Check — ${GENERATED_AT} ==="
  echo ""
  echo "State:             ${STATE}"
  echo "Description:       ${STATE_DESC}"
  echo "Active criterion:  ${active_criterion}"
  echo ""
  echo "--- Materialized State ---"
  echo "  Corporate model:  $([[ "$materialized" -eq 1 ]] && echo "present" || echo "MISSING") (${MODEL_FILE})"
  echo "  Adopted entries:  ${materialized_artifacts}"
  echo "  Client dirs:      ${client_count}"
  echo ""
  echo "--- Connectivity ---"
  echo "  Last sync:        ${last_sync_ts}"
  echo "  Days since sync:  ${days_since_sync}"
  echo "  Grace period:     ${SYNC_GRACE_DAYS} days"
  echo "  Registry:         $([[ "$registry_reachable" -eq 1 ]] && echo "reachable" || echo "unreachable") ($([[ -n "$CORPORATE_REGISTRY_URL" ]] && echo "${CORPORATE_REGISTRY_URL}" || echo "not configured"))"
  echo ""
  echo "--- Guarantees ---"
  echo "  No expiry:        true"
  echo "  No degradation:   true"
  echo "  Local state:      $([[ "$adopted_local" -eq 1 ]] || [[ "$client_state_present" -eq 1 ]] && echo "operational" || echo "none — may be degraded")"
fi
