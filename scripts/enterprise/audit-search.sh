#!/usr/bin/env bash
set -uo pipefail
# audit-search.sh — SPEC-SE-037 Audit Log CLI Inspector
#
# Busca en audit_log con filtros. Sin SAVIA_ENTERPRISE_DSN: exit 3.
# Pattern re-implemented clean-room from dreamxist/balance (MIT, no source copied).
#
# Usage:
#   audit-search.sh --tenant <uuid> --table <name> [--agent <id>]
#                   [--since 7d|30d|90d|YYYY-MM-DD] [--limit 50] [--json]
#   audit-search.sh --help
#
# Output: tabular -- ts | table | record_id | operation | user_id | diff_summary
# diff_summary: numero de keys que cambiaron entre old_row y new_row
#
# Requires: SAVIA_ENTERPRISE_DSN env (Postgres DSN, required; exit 3 if missing).
#
# Reference: SPEC-SE-037 (docs/propuestas/savia-enterprise/SPEC-SE-037-audit-jsonb-trigger.md)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TENANT=""
TABLE=""
AGENT=""
SINCE="7d"
LIMIT=50
JSON_MODE=0

# ── Usage ────────────────────────────────────────────────────────────────────

usage() {
  cat <<EOF
audit-search.sh -- search audit_log (SPEC-SE-037)

Usage:
  audit-search.sh --tenant <uuid> --table <name> [options]

Options:
  --tenant <uuid>   Filter by tenant_id
  --table  <name>   Filter by table_name
  --agent  <id>     Filter by agent_id
  --since  <val>    Time window: 7d, 30d, 90d, or YYYY-MM-DD (default: 7d)
  --limit  <n>      Max rows to return (default: 50)
  --json            Output as JSON (uses row_to_json)
  --help            Show this help and exit 0

Environment:
  SAVIA_ENTERPRISE_DSN  Postgres connection DSN (required; exit 3 if missing).

Output columns: ts | table | record_id | operation | user_id | diff_summary
  diff_summary: count of keys changed between old_row and new_row (UPDATE only)
EOF
  exit 0
}

# ── Argument parsing ─────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
  # No args: check DSN first, then usage
  if [[ -z "${SAVIA_ENTERPRISE_DSN:-}" ]]; then
    echo "ERROR: SAVIA_ENTERPRISE_DSN is not set." >&2
    exit 3
  fi
  usage
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant) TENANT="$2";   shift 2 ;;
    --table)  TABLE="$2";    shift 2 ;;
    --agent)  AGENT="$2";    shift 2 ;;
    --since)  SINCE="$2";    shift 2 ;;
    --limit)  LIMIT="$2";    shift 2 ;;
    --json)   JSON_MODE=1;   shift   ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown arg: $1" >&2; echo "Run with --help for usage." >&2; exit 2 ;;
  esac
done

# ── DSN check (required) ─────────────────────────────────────────────────────

if [[ -z "${SAVIA_ENTERPRISE_DSN:-}" ]]; then
  echo "ERROR: SAVIA_ENTERPRISE_DSN is not set. Export the DSN before running." >&2
  exit 3
fi

# ── parse_since: Nd/Nh/Nm → interval, ISO-8601 → timestamptz ────────────────

parse_since() {
  local since="$1"
  if [[ "$since" =~ ^([0-9]+)d$ ]]; then
    echo "NOW() - interval '${BASH_REMATCH[1]} days'"
  elif [[ "$since" =~ ^([0-9]+)h$ ]]; then
    echo "NOW() - interval '${BASH_REMATCH[1]} hours'"
  elif [[ "$since" =~ ^([0-9]+)m$ ]]; then
    echo "NOW() - interval '${BASH_REMATCH[1]} minutes'"
  else
    echo "'${since}'::timestamptz"
  fi
}

SINCE_SQL="$(parse_since "$SINCE")"

# ── Build WHERE clause ───────────────────────────────────────────────────────
# Base filter: created_at >= <window>
# Additional filters: tenant_id, table_name, agent_id (all quote-doubled against injection)

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

if [[ "$JSON_MODE" -eq 1 ]]; then
  SQL="SELECT row_to_json(t) FROM (
    SELECT
        created_at::text                        AS ts,
        table_name,
        record_id,
        operation,
        COALESCE(user_id, '-')                  AS user_id,
        ${DIFF_EXPR}                            AS diff_summary
      FROM audit_log
      ${WHERE}
      ORDER BY created_at DESC
      LIMIT ${LIMIT}
  ) t;"
else
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
fi

# ── Execute ──────────────────────────────────────────────────────────────────

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql not found. Install postgresql-client." >&2
  exit 1
fi

psql "${SAVIA_ENTERPRISE_DSN}" -P pager=off -P border=2 -c "$SQL"
