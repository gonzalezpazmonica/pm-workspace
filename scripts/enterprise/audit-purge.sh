#!/usr/bin/env bash
set -uo pipefail
# audit-purge.sh — SPEC-SE-037 Audit Log Retention Purge CLI
#
# Selective DELETE on audit_log respecting documented retention policy.
# REFUSES to run without --confirm AND without audit-retention.md present.
#
# Usage:
#   audit-purge.sh --before <YYYY-MM-DD> --table <name> --confirm
#   audit-purge.sh --before 2026-01-01  --table agent_sessions --confirm
#   audit-purge.sh --help
#
# --confirm is MANDATORY (exit 2 if missing).
# --before  is MANDATORY (exit 2 if missing).
# --table   is MANDATORY (exit 2 if missing).
#
# Without PGDATABASE: dry-run (shows SQL, does not execute).
# Reads docs/rules/domain/savia-enterprise/audit-retention.md — exits 2 if missing.
#
# Reference: SPEC-SE-037 (docs/propuestas/savia-enterprise/SPEC-SE-037-audit-jsonb-trigger.md)
# Retention policy: docs/rules/domain/savia-enterprise/audit-retention.md (REQUIRED)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RETENTION_DOC="${ROOT_DIR}/docs/rules/domain/savia-enterprise/audit-retention.md"
PURGE_LOG_DIR="${ROOT_DIR}/output/audit-purge-log"

TABLE=""
BEFORE=""
CONFIRM=0

# ── Usage ────────────────────────────────────────────────────────────────────

usage() {
  cat <<'USAGE'
audit-purge.sh — selective DELETE on audit_log (SPEC-SE-037)

Usage:
  audit-purge.sh --before <YYYY-MM-DD> --table <name> --confirm
  audit-purge.sh --help

Options:
  --before  <YYYY-MM-DD>  Purge rows created before this date (required)
  --table   <name>        Table name to purge from audit_log (required)
  --confirm               Required flag to execute; omit for dry-run
  --help                  Show this help and exit 0

Safety:
  --confirm is mandatory to execute purge (exit 2 if missing)
  Requires docs/rules/domain/savia-enterprise/audit-retention.md to exist (exit 2 if missing)
  Shows pre-purge row count before executing
  Without PGDATABASE: dry-run mode — prints SQL without executing

Environment:
  PGDATABASE  Postgres database name (or connection string).
              If not set: dry-run mode.
USAGE
  exit 0
}

# ── Argument parsing ─────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
  usage
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --table)   TABLE="$2";   shift 2 ;;
    --before)  BEFORE="$2";  shift 2 ;;
    --confirm) CONFIRM=1;    shift   ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown argument: $1" >&2; echo "Run with --help for usage." >&2; exit 2 ;;
  esac
done

# ── Mandatory argument checks ────────────────────────────────────────────────

if [[ -z "$TABLE" ]]; then
  echo "ERROR: --table <name> is required." >&2
  exit 2
fi

if [[ -z "$BEFORE" ]]; then
  echo "ERROR: --before <YYYY-MM-DD> is required." >&2
  exit 2
fi

if [[ "$CONFIRM" -ne 1 ]]; then
  echo "ERROR: --confirm is required to execute purge." >&2
  echo "       Re-run with --confirm to proceed, or omit --confirm for dry-run info." >&2
  exit 2
fi

# ── Retention policy gate ─────────────────────────────────────────────────────
# REFUSES to run without documented retention policy (AC-07, SPEC-SE-037).

if [[ ! -f "$RETENTION_DOC" ]]; then
  echo "ERROR: retention policy file not found: ${RETENTION_DOC}" >&2
  echo "       audit-purge REFUSES to run without a documented retention policy." >&2
  echo "       This is a hard compliance boundary (SPEC-SE-037 AC-07)." >&2
  exit 2
fi

# ── Bulk-purge protection ─────────────────────────────────────────────────────

case "$TABLE" in
  ""|"*"|"all"|"audit_log")
    echo "ERROR: invalid table '${TABLE}' — bulk purge and self-purge are refused." >&2
    exit 2
    ;;
esac

# ── Build SQL ─────────────────────────────────────────────────────────────────

SAFE_TABLE="${TABLE//\'/\'\'}"
COUNT_SQL="SELECT count(*) FROM audit_log WHERE table_name = '${SAFE_TABLE}' AND created_at < '${BEFORE}'::timestamptz;"
DELETE_SQL="DELETE FROM audit_log WHERE table_name = '${SAFE_TABLE}' AND created_at < '${BEFORE}'::timestamptz;"

# ── Dry-run when PGDATABASE is not set ───────────────────────────────────────

if [[ -z "${PGDATABASE:-}" ]]; then
  echo "-- DRY-RUN: PGDATABASE not set. SQL that would be executed:"
  echo ""
  echo "-- Pre-purge count:"
  echo "$COUNT_SQL"
  echo ""
  echo "-- Purge:"
  echo "$DELETE_SQL"
  exit 0
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql not found. Install postgresql-client." >&2
  exit 1
fi

# ── Pre-purge count ───────────────────────────────────────────────────────────

ROWS="$(psql "${PGDATABASE}" -At -c "$COUNT_SQL" 2>&1)" || {
  echo "ERROR: psql count query failed: ${ROWS}" >&2
  exit 1
}

POLICY_HASH="$(sha256sum "$RETENTION_DOC" | cut -d' ' -f1)"

echo "Pre-purge: ${ROWS} rows in audit_log WHERE table_name='${TABLE}' AND created_at < '${BEFORE}'"
echo "Retention policy hash: ${POLICY_HASH:0:16}..."

# ── Execute purge ──────────────────────────────────────────────────────────────

DELETED="$(psql "${PGDATABASE}" -At -c "$DELETE_SQL" 2>&1)" || {
  echo "ERROR: purge failed: ${DELETED}" >&2
  exit 1
}

mkdir -p "$PURGE_LOG_DIR"
LOG_FILE="${PURGE_LOG_DIR}/$(date +%Y-%m-%d).log"

{
  echo "---"
  echo "timestamp:      $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "operator:       ${USER:-unknown}"
  echo "table:          ${TABLE}"
  echo "before:         ${BEFORE}"
  echo "rows_deleted:   ${ROWS}"
  echo "retention_hash: ${POLICY_HASH}"
} >> "$LOG_FILE"

echo "OK: purged ${ROWS} rows from audit_log (table_name='${TABLE}', before='${BEFORE}'). Log: ${LOG_FILE}"
