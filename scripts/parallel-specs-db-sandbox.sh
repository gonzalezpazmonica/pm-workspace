#!/usr/bin/env bash
# parallel-specs-db-sandbox.sh — SE-074 Slice 3 — DB sandbox per worker
#
# Provides an isolated database per parallel-specs worker so concurrent
# integration tests can run against their own data without colliding.
# SQLite by default (zero-config); Postgres is opt-in via SPEC_DB_BACKEND
# and requires an admin URL plus a template database.
#
# The orchestrator invokes `init` inside spawn_worker's subshell and
# `eval`s the output to export DATABASE_URL into the worker. Workers read
# $DATABASE_URL per 12-factor; they never know they are sandboxed.
#
# Hard safety boundaries (autonomous-safety.md):
#   - No worktree_name with shell metacharacters → reject early
#   - SQLite path always inside SPEC_DB_SANDBOX_DIR (no path traversal)
#   - Postgres dbname sanitized to [a-z0-9_], max 63 chars
#   - destroy is idempotent (no-op on missing)
#
# Subcommands:
#   init <worktree_name>      Create the sandbox; print `DATABASE_URL=...` to stdout
#   path <worktree_name>      Print absolute SQLite path; do not create
#   destroy <worktree_name>   Remove SQLite file (or DROP DATABASE for Postgres)
#   list                      List existing sandboxes
#   --help                    Show usage
#
# Env (all optional):
#   SPEC_DB_BACKEND           sqlite (default) | postgres
#   SPEC_DB_SANDBOX_DIR       default ${ROOT}/.claude/db-sandboxes
#   SPEC_DB_PG_TEMPLATE       Postgres template DB to clone (default savia_template)
#   SPEC_DB_PG_ADMIN_URL      required if backend=postgres
#
# Exit codes:
#   0 ok | 2 usage | 3 backend/environment error
#
# Reference: SE-074 Slice 3 (docs/propuestas/SE-074-parallel-spec-execution.md)
# Reference: docs/rules/domain/parallel-spec-execution.md
# Reference: docs/rules/domain/autonomous-safety.md

set -uo pipefail

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SPEC_DB_BACKEND="${SPEC_DB_BACKEND:-sqlite}"
SPEC_DB_SANDBOX_DIR="${SPEC_DB_SANDBOX_DIR:-${ROOT}/.claude/db-sandboxes}"
SPEC_DB_PG_TEMPLATE="${SPEC_DB_PG_TEMPLATE:-savia_template}"

usage() {
  cat <<USG
Usage: parallel-specs-db-sandbox.sh <subcommand> [args]

Subcommands:
  init <worktree_name>     Create sandbox; print DATABASE_URL=... to stdout
  path <worktree_name>     Print SQLite path (idempotent, no creation)
  destroy <worktree_name>  Remove the sandbox (idempotent)
  list                     Enumerate existing sandboxes

Env:
  SPEC_DB_BACKEND          ${SPEC_DB_BACKEND} (sqlite | postgres)
  SPEC_DB_SANDBOX_DIR      ${SPEC_DB_SANDBOX_DIR}
  SPEC_DB_PG_TEMPLATE      ${SPEC_DB_PG_TEMPLATE}
  SPEC_DB_PG_ADMIN_URL     (required when backend=postgres)
USG
}

die() { echo "ERROR: $*" >&2; exit "${2:-3}"; }

# Reject worktree_name with shell metachars or path traversal hints.
# Allowed: [a-zA-Z0-9._-] only. Rejecting early is cheaper than escaping later.
validate_name() {
  local name="$1"
  [[ -z "$name" ]] && die "worktree_name required" 2
  [[ "$name" =~ ^[a-zA-Z0-9._-]+$ ]] || die "invalid worktree_name (allowed: [a-zA-Z0-9._-]): $name" 2
  [[ "${#name}" -le 100 ]] || die "worktree_name too long (max 100 chars)" 2
}

sqlite_path() {
  local name="$1"
  printf '%s/%s.sqlite\n' "${SPEC_DB_SANDBOX_DIR}" "${name}"
}

# Sanitize for Postgres database identifiers: lowercase, [a-z0-9_], max 63
pg_sanitize() {
  local name="$1"
  local sanitized
  sanitized=$(echo "spec_${name}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_\n' '_' | head -c 63)
  echo "${sanitized}"
}

# ── Subcommands ───────────────────────────────────────────────────────────────

cmd_init() {
  local name="${1:-}"
  validate_name "$name"

  case "${SPEC_DB_BACKEND}" in
    sqlite)
      mkdir -p "${SPEC_DB_SANDBOX_DIR}"
      local path; path=$(sqlite_path "$name")
      # touch is idempotent — re-init returns the same path
      : > "${path}".lock 2>/dev/null || true
      [[ -f "${path}" ]] || : > "${path}"
      printf 'DATABASE_URL=sqlite:///%s\n' "${path}"
      ;;
    postgres)
      [[ -z "${SPEC_DB_PG_ADMIN_URL:-}" ]] && die "SPEC_DB_PG_ADMIN_URL required for backend=postgres" 3
      command -v psql >/dev/null 2>&1 || die "psql not installed (required for backend=postgres)" 3
      local dbname; dbname=$(pg_sanitize "$name")
      # Ensure template exists (fail fast with actionable message)
      local template_exists
      template_exists=$(psql "${SPEC_DB_PG_ADMIN_URL}" -tAc \
        "SELECT 1 FROM pg_database WHERE datname='${SPEC_DB_PG_TEMPLATE}'" 2>/dev/null || echo "")
      [[ "$template_exists" == "1" ]] || die "template DB '${SPEC_DB_PG_TEMPLATE}' not found — create it via: createdb ${SPEC_DB_PG_TEMPLATE}" 3
      # Idempotent create: skip if already exists
      local exists
      exists=$(psql "${SPEC_DB_PG_ADMIN_URL}" -tAc \
        "SELECT 1 FROM pg_database WHERE datname='${dbname}'" 2>/dev/null || echo "")
      if [[ "$exists" != "1" ]]; then
        psql "${SPEC_DB_PG_ADMIN_URL}" -c \
          "CREATE DATABASE \"${dbname}\" TEMPLATE \"${SPEC_DB_PG_TEMPLATE}\"" >/dev/null 2>&1 \
          || die "CREATE DATABASE ${dbname} failed" 3
      fi
      # Build URL preserving credentials from admin URL but swapping db name
      local base; base="${SPEC_DB_PG_ADMIN_URL%/*}"
      printf 'DATABASE_URL=%s/%s\n' "${base}" "${dbname}"
      ;;
    *)
      die "unknown SPEC_DB_BACKEND: ${SPEC_DB_BACKEND} (expected sqlite | postgres)" 2
      ;;
  esac
}

cmd_path() {
  local name="${1:-}"
  validate_name "$name"
  sqlite_path "$name"
}

cmd_destroy() {
  local name="${1:-}"
  validate_name "$name"
  case "${SPEC_DB_BACKEND}" in
    sqlite)
      local path; path=$(sqlite_path "$name")
      rm -f "${path}" "${path}".lock 2>/dev/null || true
      ;;
    postgres)
      [[ -z "${SPEC_DB_PG_ADMIN_URL:-}" ]] && die "SPEC_DB_PG_ADMIN_URL required for backend=postgres" 3
      local dbname; dbname=$(pg_sanitize "$name")
      psql "${SPEC_DB_PG_ADMIN_URL}" -c "DROP DATABASE IF EXISTS \"${dbname}\"" >/dev/null 2>&1 || true
      ;;
    *)
      die "unknown SPEC_DB_BACKEND: ${SPEC_DB_BACKEND}" 2
      ;;
  esac
}

cmd_list() {
  case "${SPEC_DB_BACKEND}" in
    sqlite)
      [[ -d "${SPEC_DB_SANDBOX_DIR}" ]] || { echo "(no sandboxes)"; return 0; }
      local count=0
      while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        count=$((count + 1))
        printf '  %s\n' "$(basename "$f" .sqlite)"
      done < <(find "${SPEC_DB_SANDBOX_DIR}" -maxdepth 1 -type f -name '*.sqlite' 2>/dev/null | sort)
      if [[ "$count" -eq 0 ]]; then echo "(no sandboxes)"; fi
      return 0
      ;;
    postgres)
      [[ -z "${SPEC_DB_PG_ADMIN_URL:-}" ]] && die "SPEC_DB_PG_ADMIN_URL required" 3
      psql "${SPEC_DB_PG_ADMIN_URL}" -tAc \
        "SELECT datname FROM pg_database WHERE datname LIKE 'spec\_%' ORDER BY datname" 2>/dev/null | sed 's/^/  /'
      return 0
      ;;
  esac
}

# ── Dispatcher ────────────────────────────────────────────────────────────────

CMD="${1:-}"
shift || true

case "${CMD}" in
  init)         cmd_init "$@" ;;
  path)         cmd_path "$@" ;;
  destroy)      cmd_destroy "$@" ;;
  list)         cmd_list "$@" ;;
  --help|-h|help) usage; exit 0 ;;
  "") usage >&2; exit 2 ;;
  *) echo "Unknown subcommand: ${CMD}" >&2; usage >&2; exit 2 ;;
esac
