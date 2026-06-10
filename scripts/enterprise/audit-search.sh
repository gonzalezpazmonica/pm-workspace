#!/usr/bin/env bash
set -uo pipefail
# audit-search.sh — SPEC-SE-037 Audit Log CLI Inspector
#
# Busca en audit_log con filtros. Sin PGDATABASE: dry-run (muestra SQL).
#
# Usage:
#   audit-search.sh --tenant <uuid> --table <name> [--agent <id>]
#                   [--since 7d|30d|90d|YYYY-MM-DD] [--limit 50]
#   audit-search.sh --help
#
# Output: tabular — ts | table | record_id | operation | user_id | diff_summary
# diff_summary: número de keys que cambiaron entre old_row y new_row
#
# Requires: PGDATABASE env (Postgres DB name / DSN).
# Without PGDATABASE: prints the SQL that would be executed (dry-run).
#
# Reference: SPEC-SE-037 (docs/propuestas/savia-enterprise/SPEC-SE-037-audit-jsonb-trigger.md)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TENANT=""
TABLE=""
AGENT=""
SINCE="7d"
LIMIT=50

# ── Usage ────────────────────────────────────────────────────────────────────

usage() {
  cat <<'USAGE'
audit-search.sh — search audit_log (SPEC-SE-037)

Usage:
  audit-search.sh --tenant <uuid> --table <name> [options]

Options:
  --tenant <uuid>   Filter by tenant_id
  --table  <name>   Filter by table_name
  --agent  <id>     Filter by agent_id
  --since  <val>    Time window: 7d, 30d, 90d, or YYYY-MM-DD (default: 7d)
  --limit  <n>      Max rows to return (default: 50)
  --help            Show this help and exit 0

Environment:
  PGDATABASE        Postgres database name (or connection string).
                    If not set: dry-run mode — prints SQL without executing.

Output columns: ts | table | record_id | operation | user_id | diff_summary
  diff_summary: count of keys changed between old_row and new_row (UPDATE only)
USAGE
  exit 0
}

# ── Argument parsing ─────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
  usage
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant) TENANT="$2";   shift 2 ;;
    --table)  TABLE="$2";    shift 2 ;;
    --agent)  AGENT="$2";    shift 2 ;;
    --since)  SINCE="$2";    shift 2 ;;
    --limit)  LIMIT="$2";    shift 2 ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown argument: $1" >&2; echo "Run with --help for usage." >&2; exit 1 ;;
  esac
done

# ── Validate --since ─────────────────────────────────────────────────────────

since_to_sql() {
  local val="$1"
  case "$val" in
    # Numeric duration: Nd | Nh | Nm (N must be a positive integer)
    [0-9]*d) echo "now() - interval '${val%d} days'"  ;;
    [0-9]*h) echo "now() - interval '${val%h} hours'" ;;
    [0-9]*m) echo "now() - interval '${val%m} minutes'" ;;
    # ISO-8601 date: YYYY-MM-DD
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) echo "'${val}'::timestamptz" ;;
    *)
      echo "ERROR: invalid --since value '${val}'. Use Nd/Nh/Nm or YYYY-MM-DD." >&2
      exit 1
      ;;
  esac
}

SINCE_SQL="$(since_to_sql "$SINCE")" || exit $?

# ── Build WHERE clause ───────────────────────────────────────────────────────

WHERE="WHERE created_at >= ${SINCE_SQL}"
[[ -n "$TENANT" ]] && WHERE="${WHERE} AND tenant_id = '${TENANT//\'/\'\'}'::uuid"
[[ -n "$TABLE"  ]] && WHERE="${WHERE} AND table_name = '${TABLE//\'/\'\'}'"
[[ -n "$AGENT"  ]] && WHERE="${WHERE} AND agent_id = '${AGENT//\'/\'\'}'"

# ── diff_summary: count of changed keys in UPDATE ───────────────────────────

DIFF_EXPR="CASE
  WHEN operation = 'UPDATE' THEN (
    SELECT count(*)::text
    FROM (
      SELECT key FROM jsonb_each(COALESCE(new_row, '{}'::jsonb))
      WHERE COALESCE(new_row->key, 'null'::jsonb)
            IS DISTINCT FROM COALESCE(old_row->key, 'null'::jsonb)
        AND key NOT IN ('updated_at', 'last_modified')
    ) sub
  )
  ELSE '-'
END"

# ── Build SQL ────────────────────────────────────────────────────────────────

SQL="SELECT
    created_at::text                        AS ts,
    table_name,
    record_id,
    operation,
    COALESCE(user_id, '-')                  AS user_id,
    ${DIFF_EXPR}                            AS diff_summary
  FROM audit_log
  ${WHERE}
  ORDER BY created_at DESC
  LIMIT ${LIMIT};"

# ── Execute or dry-run ───────────────────────────────────────────────────────

if [[ -z "${PGDATABASE:-}" ]]; then
  echo "-- DRY-RUN: PGDATABASE not set. SQL that would be executed:"
  echo ""
  echo "$SQL"
  exit 0
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql not found. Install postgresql-client." >&2
  exit 1
fi

psql "${PGDATABASE}" -P pager=off -P border=2 -c "$SQL"
