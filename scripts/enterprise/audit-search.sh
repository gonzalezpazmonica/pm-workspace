#!/usr/bin/env bash
# audit-search.sh — SPEC-SE-037 Slice única.
#
# Tabular search over the append-only audit_log captured by audit_trigger_fn().
# Filters: tenant / table / agent / since (duration or absolute date).
# Output: TSV-style table with diff column (computed JSONB old vs new).
#
# Requires SAVIA_ENTERPRISE_DSN env (Postgres connection string). In pm-workspace
# CI this is unset — the script fails gracefully with a documented exit code.
#
# Usage:
#   audit-search.sh --tenant <uuid> --table tenants --since 7d
#   audit-search.sh --agent worker-1 --since 2026-04-01 --limit 100
#   audit-search.sh --json
#
# Reference: SPEC-SE-037 (`docs/propuestas/savia-enterprise/SPEC-SE-037-audit-jsonb-trigger.md`)
# Pattern source: `dreamxist/balance` `supabase/migrations/00006_audit_log.sql` (MIT, clean-room)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TENANT=""
TABLE=""
AGENT=""
SINCE="7d"
LIMIT=50
JSON_OUT=0

usage() {
  sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant) TENANT="$2"; shift 2 ;;
    --table)  TABLE="$2"; shift 2 ;;
    --agent)  AGENT="$2"; shift 2 ;;
    --since)  SINCE="$2"; shift 2 ;;
    --limit)  LIMIT="$2"; shift 2 ;;
    --json)   JSON_OUT=1; shift ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage ;;
  esac
done

# ── DSN check ────────────────────────────────────────────────────────────────

if [[ -z "${SAVIA_ENTERPRISE_DSN:-}" ]]; then
  echo "ERROR: SAVIA_ENTERPRISE_DSN env not set — this CLI requires a Postgres connection." >&2
  echo "       In pm-workspace CI this is expected; deploy to Savia Enterprise repo to test live." >&2
  exit 3
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql not found — install postgresql-client first." >&2
  exit 4
fi

# ── Build SQL ────────────────────────────────────────────────────────────────

# Convert --since to a SQL interval. Accepts "Nd" / "Nh" / "Nm" / ISO-8601 date.
since_sql() {
  case "$1" in
    *d) echo "now() - interval '${1%d} days'" ;;
    *h) echo "now() - interval '${1%h} hours'" ;;
    *m) echo "now() - interval '${1%m} minutes'" ;;
    *)  echo "'$1'::timestamptz" ;;
  esac
}

WHERE="WHERE created_at >= $(since_sql "$SINCE")"
[[ -n "$TENANT" ]] && WHERE="$WHERE AND tenant_id = '${TENANT//\'/\'\'}'::uuid"
[[ -n "$TABLE"  ]] && WHERE="$WHERE AND table_name = '${TABLE//\'/\'\'}'"
[[ -n "$AGENT"  ]] && WHERE="$WHERE AND agent_id = '${AGENT//\'/\'\'}'"

# Diff column: keys whose value changed between old_row and new_row
DIFF_EXPR="
CASE WHEN operation = 'UPDATE' THEN
  (
    SELECT string_agg(k, ',' ORDER BY k)
    FROM (
      SELECT key AS k FROM jsonb_each(COALESCE(new_row, '{}'::jsonb))
      WHERE key NOT IN ('updated_at','last_modified')
        AND COALESCE(new_row->key, 'null'::jsonb)
            IS DISTINCT FROM COALESCE(old_row->key, 'null'::jsonb)
    ) sub
  )
  ELSE NULL
END"

if [[ "$JSON_OUT" -eq 1 ]]; then
  SQL="SELECT to_jsonb(row_to_json(t)) FROM (
    SELECT id, table_name, record_id, operation,
           user_id, agent_id, session_id, tenant_id::text,
           created_at, $DIFF_EXPR AS diff_keys
    FROM audit_log
    $WHERE
    ORDER BY created_at DESC
    LIMIT $LIMIT
  ) t"
  psql "$SAVIA_ENTERPRISE_DSN" -At -c "$SQL"
else
  SQL="SELECT id, table_name, record_id, operation,
              COALESCE(agent_id, '-') AS agent,
              COALESCE(user_id, '-') AS user,
              created_at,
              COALESCE($DIFF_EXPR, '-') AS diff_keys
       FROM audit_log
       $WHERE
       ORDER BY created_at DESC
       LIMIT $LIMIT"
  psql "$SAVIA_ENTERPRISE_DSN" -P pager=off -P border=2 -c "$SQL"
fi
