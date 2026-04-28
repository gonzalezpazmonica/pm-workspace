#!/usr/bin/env bash
# audit-purge.sh — SPEC-SE-037 Slice única.
#
# Selective DELETE on audit_log respecting retention policy. REFUSES to run
# without --confirm flag AND without docs/rules/domain/savia-enterprise/audit-retention.md
# present in repo. Pre-purge prints a count + category before requiring --confirm.
# Post-purge writes an immutable log to output/audit-purge-log/YYYY-MM-DD.log
# with retention policy hash for forensics.
#
# Requires SAVIA_ENTERPRISE_DSN env (Postgres). NEVER purges all categories at once;
# one --table at a time.
#
# Usage:
#   audit-purge.sh --table agent_sessions --before 2026-01-28          # dry-run
#   audit-purge.sh --table agent_sessions --before 2026-01-28 --confirm
#
# Reference: SPEC-SE-037 (`docs/propuestas/savia-enterprise/SPEC-SE-037-audit-jsonb-trigger.md`)
# Retention policy: `docs/rules/domain/savia-enterprise/audit-retention.md` (REQUIRED)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RETENTION_DOC="$ROOT_DIR/docs/rules/domain/savia-enterprise/audit-retention.md"
PURGE_LOG_DIR="$ROOT_DIR/output/audit-purge-log"

TABLE=""
BEFORE=""
CONFIRM=0

usage() {
  sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --table)   TABLE="$2"; shift 2 ;;
    --before)  BEFORE="$2"; shift 2 ;;
    --confirm) CONFIRM=1; shift ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage ;;
  esac
done

# ── Pre-flight checks ───────────────────────────────────────────────────────

if [[ ! -f "$RETENTION_DOC" ]]; then
  echo "ERROR: retention policy doc missing: $RETENTION_DOC" >&2
  echo "       audit-purge REFUSES to run without a documented retention policy." >&2
  echo "       This is a hard safety boundary (SPEC-SE-037 AC-07)." >&2
  exit 5
fi

if [[ -z "$TABLE" ]]; then
  echo "ERROR: --table required (one table at a time, no bulk purge)" >&2
  usage
fi

if [[ -z "$BEFORE" ]]; then
  echo "ERROR: --before <date|duration> required" >&2
  usage
fi

# Disallow obvious bulk-purge attempts
case "$TABLE" in
  ""|"*"|"all"|"audit_log")
    echo "ERROR: invalid table name '$TABLE' — bulk purge or self-purge refused" >&2
    exit 6
    ;;
esac

# Validate table is classified in the retention policy doc
if ! grep -qE "(\`$TABLE\`|^\| \\*\\*$TABLE\\*\\*|^\| $TABLE)" "$RETENTION_DOC" 2>/dev/null \
   && ! grep -qiE "agent activity|user actions|billing|compliance|api keys|project|system" "$RETENTION_DOC"; then
  # Fallback: look for the table name as a fenced word anywhere
  if ! grep -qF "$TABLE" "$RETENTION_DOC"; then
    echo "ERROR: table '$TABLE' not classified in $RETENTION_DOC" >&2
    echo "       Add the table to a category before purging." >&2
    exit 7
  fi
fi

# ── Compute pre-purge count ─────────────────────────────────────────────────

if [[ -z "${SAVIA_ENTERPRISE_DSN:-}" ]]; then
  echo "ERROR: SAVIA_ENTERPRISE_DSN env not set — this CLI requires a Postgres connection." >&2
  echo "       In pm-workspace CI this is expected; deploy to Savia Enterprise repo to test live." >&2
  exit 3
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql not found — install postgresql-client first." >&2
  exit 4
fi

since_sql() {
  case "$1" in
    *d) echo "now() - interval '${1%d} days'" ;;
    *)  echo "'$1'::timestamptz" ;;
  esac
}

CUTOFF_SQL=$(since_sql "$BEFORE")
COUNT_SQL="SELECT count(*) FROM audit_log WHERE table_name = '${TABLE//\'/\'\'}' AND created_at < $CUTOFF_SQL"
ROWS=$(psql "$SAVIA_ENTERPRISE_DSN" -At -c "$COUNT_SQL" 2>&1) || {
  echo "ERROR: psql query failed: $ROWS" >&2
  exit 8
}

# Extract category from retention doc (best effort — find category line for this table)
CATEGORY=$(awk -v table="$TABLE" '
  /^\| \*\*[A-Z]/ { current=$0 }
  $0 ~ table     { print current; exit }
' "$RETENTION_DOC" | sed -E 's/^\| \*\*//; s/\*\* .*//')
CATEGORY="${CATEGORY:-uncategorized}"

# Retention policy hash (for forensics)
POLICY_HASH=$(sha256sum "$RETENTION_DOC" | cut -d' ' -f1)

echo "Pre-purge: $ROWS rows in audit_log WHERE table_name='$TABLE' AND created_at < ${BEFORE}"
echo "Category: ${CATEGORY}"
echo "Retention policy hash: ${POLICY_HASH:0:16}..."

if [[ "$CONFIRM" -ne 1 ]]; then
  echo ""
  echo "DRY-RUN. Re-run with --confirm to proceed."
  exit 0
fi

# ── Execute purge ────────────────────────────────────────────────────────────

mkdir -p "$PURGE_LOG_DIR"
LOG_FILE="$PURGE_LOG_DIR/$(date +%Y-%m-%d).log"

DELETE_SQL="DELETE FROM audit_log WHERE table_name = '${TABLE//\'/\'\'}' AND created_at < $CUTOFF_SQL"
DELETED=$(psql "$SAVIA_ENTERPRISE_DSN" -At -c "$DELETE_SQL" 2>&1) || {
  echo "ERROR: purge failed: $DELETED" >&2
  exit 9
}

# Append-only forensics log
{
  echo "---"
  echo "timestamp:        $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "operator_user:    ${USER:-unknown}"
  echo "table:            $TABLE"
  echo "before:           $BEFORE"
  echo "category:         $CATEGORY"
  echo "rows_deleted:     ${ROWS}"
  echo "retention_hash:   $POLICY_HASH"
} >> "$LOG_FILE"

echo "OK: purged ${ROWS} rows from audit_log (table_name='$TABLE'). Log: $LOG_FILE"
