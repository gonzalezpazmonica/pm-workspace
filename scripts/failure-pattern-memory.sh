#!/usr/bin/env bash
# failure-pattern-memory.sh — SPEC-188 Fase 1: Failure Pattern Memory store
# Ref: docs/propuestas/SPEC-188-root-cause-investigation-architecture.md
# Feature flag: SAVIA_FAILURE_PATTERN_MEMORY_ENABLED (default 0)
#
# Usage:
#   failure-pattern-memory.sh init
#   failure-pattern-memory.sh add --agent <name> --error <signature> [--file-glob <glob>] [--lesson <text>]
#   failure-pattern-memory.sh list [--agent <name>] [--status open|acknowledged|resolved]
#   failure-pattern-memory.sh show <pattern_id>
#   failure-pattern-memory.sh resolve <pattern_id> [--lesson <text>]
#   failure-pattern-memory.sh stats
#
# Schema (SQLite):
#   failure_patterns(pattern_id, agent, error_signature, file_glob,
#                   occurrences, first_seen, last_seen, human_lesson, status)
#
# pattern_id = first 8 chars of sha256(agent + error_signature + file_glob)
# status: open | acknowledged | resolved
# Bridge SE-072: every insert carries verified_source = tool:post-tool-failure-log
# Bridge feedback_*.md: occurrences >= 10 → suggest promotion to permanent rule
set -uo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────
DB_FILE="${PROJECT_ROOT:-.}/.claude/external-memory/failure-patterns/patterns.db"
ENABLED="${SAVIA_FAILURE_PATTERN_MEMORY_ENABLED:-0}"

# ── Helpers ───────────────────────────────────────────────────────────────────
die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "INFO: $*"; }

iso8601_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Compute pattern_id: first 8 chars of sha256(agent + error_signature + file_glob)
compute_pattern_id() {
    local agent="$1" error_sig="$2" file_glob="${3:-}"
    printf '%s' "${agent}${error_sig}${file_glob}" | sha256sum | cut -c1-8
}

# python3 sqlite3 runner — avoids dependency on sqlite3 CLI binary
run_sql() {
    local db="$1" sql="$2"
    python3 - "$db" "$sql" <<'PYEOF'
import sys, sqlite3
db_path, sql = sys.argv[1], sys.argv[2]
conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
cur = conn.cursor()
cur.executescript(sql) if sql.strip().upper().startswith(('CREATE','DROP','INSERT','UPDATE','DELETE','BEGIN','COMMIT','PRAGMA')) and ';' in sql[sql.find(';')+1:] else cur.execute(sql)
results = cur.fetchall() if not sql.strip().upper().startswith(('CREATE','DROP','INSERT','UPDATE','DELETE','BEGIN','COMMIT','PRAGMA')) else []
conn.commit()
for row in results:
    print('|'.join(str(v) if v is not None else '' for v in row))
conn.close()
PYEOF
}

# python3 sqlite3 runner for parameterised queries (uses ? placeholders)
# Args: db sql param1 param2 ...
run_sql_params() {
    local db="$1" sql="$2"
    shift 2
    python3 - "$db" "$sql" "$@" <<'PYEOF'
import sys, sqlite3
db_path = sys.argv[1]
sql     = sys.argv[2]
params  = sys.argv[3:]
conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
cur = conn.cursor()
cur.execute(sql, params)
results = cur.fetchall()
conn.commit()
for row in results:
    print('|'.join(str(v) if v is not None else '' for v in row))
conn.close()
PYEOF
}

_ensure_db_dir() {
    mkdir -p "$(dirname "$DB_FILE")"
}

# ── Feature flag guard ────────────────────────────────────────────────────────
# Returns 0 if enabled, 1 if disabled (and prints info message unless quiet)
_check_enabled() {
    local cmd="${1:-}"
    if [[ "$ENABLED" != "1" ]]; then
        echo "INFO: SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=0 — failure pattern memory is disabled. Set to 1 to activate."
        return 1
    fi
    return 0
}

# ── Subcommands ───────────────────────────────────────────────────────────────

cmd_init() {
    # init is always allowed (idempotent schema creation)
    _ensure_db_dir
    python3 - "$DB_FILE" <<'PYEOF'
import sys, sqlite3
db_path = sys.argv[1]
conn = sqlite3.connect(db_path)
conn.executescript("""
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS failure_patterns (
  pattern_id     TEXT PRIMARY KEY,
  agent          TEXT NOT NULL,
  error_signature TEXT NOT NULL,
  file_glob      TEXT,
  occurrences    INTEGER DEFAULT 1,
  first_seen     TEXT NOT NULL,
  last_seen      TEXT NOT NULL,
  human_lesson   TEXT,
  status         TEXT DEFAULT 'open',
  verified_source TEXT DEFAULT 'tool:post-tool-failure-log'
);
CREATE INDEX IF NOT EXISTS idx_fp_agent  ON failure_patterns(agent);
CREATE INDEX IF NOT EXISTS idx_fp_status ON failure_patterns(status);
""")
conn.commit()
conn.close()
print("OK: schema initialised at", db_path)
PYEOF
}

cmd_add() {
    _check_enabled "add" || return 0

    local agent="" error_sig="" file_glob="" lesson=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agent)     agent="$2";     shift 2 ;;
            --error)     error_sig="$2"; shift 2 ;;
            --file-glob) file_glob="$2"; shift 2 ;;
            --lesson)    lesson="$2";    shift 2 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    [[ -z "$agent" ]]     && die "add requires --agent <name>"
    [[ -z "$error_sig" ]] && die "add requires --error <signature>"

    _ensure_db_dir
    [[ -f "$DB_FILE" ]] || cmd_init >/dev/null

    local pattern_id
    pattern_id="$(compute_pattern_id "$agent" "$error_sig" "$file_glob")"
    local now
    now="$(iso8601_now)"

    python3 - "$DB_FILE" "$pattern_id" "$agent" "$error_sig" "$file_glob" "$now" "$lesson" <<'PYEOF'
import sys, sqlite3
db_path, pid, agent, err_sig, fglob, now, lesson = sys.argv[1:8]
conn = sqlite3.connect(db_path)
# Upsert: insert or increment occurrences
existing = conn.execute(
    "SELECT occurrences FROM failure_patterns WHERE pattern_id = ?", (pid,)
).fetchone()
if existing:
    new_occ = existing[0] + 1
    conn.execute(
        "UPDATE failure_patterns SET occurrences=?, last_seen=?, human_lesson=COALESCE(NULLIF(?,''), human_lesson) WHERE pattern_id=?",
        (new_occ, now, lesson, pid)
    )
    print(f"UPDATED: {pid} occurrences={new_occ}")
    if new_occ >= 10:
        print(f"BRIDGE: occurrences >= 10 — consider promoting to feedback_*.md permanent rule")
else:
    conn.execute(
        "INSERT INTO failure_patterns (pattern_id, agent, error_signature, file_glob, occurrences, first_seen, last_seen, human_lesson, status) VALUES (?,?,?,?,1,?,?,?,?)",
        (pid, agent, err_sig, fglob if fglob else None, now, now, lesson if lesson else None, 'open')
    )
    print(f"INSERTED: {pid} agent={agent}")
conn.commit()
conn.close()
PYEOF
}

cmd_list() {
    _check_enabled "list" || return 0

    [[ ! -f "$DB_FILE" ]] && { echo "0 entries (store not initialised)"; return 0; }

    local filter_agent="" filter_status=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --agent)  filter_agent="$2";  shift 2 ;;
            --status) filter_status="$2"; shift 2 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    python3 - "$DB_FILE" "$filter_agent" "$filter_status" <<'PYEOF'
import sys, sqlite3
db_path, f_agent, f_status = sys.argv[1:4]
conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
sql = "SELECT pattern_id, agent, error_signature, occurrences, status, last_seen FROM failure_patterns WHERE 1=1"
params = []
if f_agent:
    sql += " AND agent = ?"
    params.append(f_agent)
if f_status:
    sql += " AND status = ?"
    params.append(f_status)
sql += " ORDER BY occurrences DESC, last_seen DESC"
rows = conn.execute(sql, params).fetchall()
if not rows:
    print("0 entries")
else:
    print(f"{'ID':<10} {'AGENT':<30} {'OCCURRENCES':>11}  {'STATUS':<15} {'LAST_SEEN':<22}  ERROR_SIGNATURE")
    print("-" * 120)
    for r in rows:
        err = r['error_signature'][:60] + ('...' if len(r['error_signature']) > 60 else '')
        print(f"{r['pattern_id']:<10} {r['agent']:<30} {r['occurrences']:>11}  {r['status']:<15} {r['last_seen']:<22}  {err}")
    print(f"\n{len(rows)} pattern(s) found")
conn.close()
PYEOF
}

cmd_show() {
    _check_enabled "show" || return 0

    local pattern_id="${1:-}"
    [[ -z "$pattern_id" ]] && die "show requires <pattern_id>"
    [[ ! -f "$DB_FILE" ]] && { echo "Store not initialised"; return 0; }

    python3 - "$DB_FILE" "$pattern_id" <<'PYEOF'
import sys, sqlite3
db_path, pid = sys.argv[1], sys.argv[2]
conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
row = conn.execute("SELECT * FROM failure_patterns WHERE pattern_id = ?", (pid,)).fetchone()
if not row:
    print(f"NOT_FOUND: pattern_id={pid}")
    sys.exit(0)
print(f"pattern_id:      {row['pattern_id']}")
print(f"agent:           {row['agent']}")
print(f"error_signature: {row['error_signature']}")
print(f"file_glob:       {row['file_glob'] or '(none)'}")
print(f"occurrences:     {row['occurrences']}")
print(f"first_seen:      {row['first_seen']}")
print(f"last_seen:       {row['last_seen']}")
print(f"status:          {row['status']}")
print(f"human_lesson:    {row['human_lesson'] or '(none)'}")
print(f"verified_source: {row['verified_source']}")
conn.close()
PYEOF
}

cmd_resolve() {
    _check_enabled "resolve" || return 0

    local pattern_id="${1:-}"
    [[ -z "$pattern_id" ]] && die "resolve requires <pattern_id>"
    shift

    local lesson=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lesson) lesson="$2"; shift 2 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    [[ ! -f "$DB_FILE" ]] && die "Store not initialised — run init first"

    python3 - "$DB_FILE" "$pattern_id" "$lesson" <<'PYEOF'
import sys, sqlite3
db_path, pid, lesson = sys.argv[1], sys.argv[2], sys.argv[3]
conn = sqlite3.connect(db_path)
row = conn.execute("SELECT pattern_id FROM failure_patterns WHERE pattern_id = ?", (pid,)).fetchone()
if not row:
    print(f"NOT_FOUND: pattern_id={pid}")
    sys.exit(0)
if lesson:
    conn.execute("UPDATE failure_patterns SET status='resolved', human_lesson=? WHERE pattern_id=?", (lesson, pid))
else:
    conn.execute("UPDATE failure_patterns SET status='resolved' WHERE pattern_id=?", (pid,))
conn.commit()
print(f"RESOLVED: {pid}")
conn.close()
PYEOF
}

cmd_stats() {
    # stats is always allowed (read-only summary, flag-independent)
    if [[ ! -f "$DB_FILE" ]]; then
        echo "Store: not initialised"
        echo "SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=${ENABLED}"
        return 0
    fi

    python3 - "$DB_FILE" <<'PYEOF'
import sys, sqlite3
db_path = sys.argv[1]
conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
total  = conn.execute("SELECT COUNT(*) FROM failure_patterns").fetchone()[0]
open_  = conn.execute("SELECT COUNT(*) FROM failure_patterns WHERE status='open'").fetchone()[0]
ack    = conn.execute("SELECT COUNT(*) FROM failure_patterns WHERE status='acknowledged'").fetchone()[0]
res    = conn.execute("SELECT COUNT(*) FROM failure_patterns WHERE status='resolved'").fetchone()[0]
top3   = conn.execute(
    "SELECT pattern_id, agent, error_signature, occurrences FROM failure_patterns ORDER BY occurrences DESC LIMIT 3"
).fetchall()
print(f"total:        {total}")
print(f"open:         {open_}")
print(f"acknowledged: {ack}")
print(f"resolved:     {res}")
print()
if top3:
    print("top-3 by occurrences:")
    for i, r in enumerate(top3, 1):
        err = r['error_signature'][:50] + ('...' if len(r['error_signature']) > 50 else '')
        print(f"  {i}. [{r['pattern_id']}] {r['agent']} — {err} ({r['occurrences']} times)")
else:
    print("top-3: (no patterns recorded)")
conn.close()
PYEOF
    echo ""
    echo "SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=${ENABLED}"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
SUBCMD="${1:-}"
[[ -z "$SUBCMD" ]] && { echo "Usage: failure-pattern-memory.sh <init|add|list|show|resolve|stats> [args]"; exit 1; }
shift

case "$SUBCMD" in
    init)    cmd_init "$@" ;;
    add)     cmd_add  "$@" ;;
    list)    cmd_list "$@" ;;
    show)    cmd_show "$@" ;;
    resolve) cmd_resolve "$@" ;;
    stats)   cmd_stats "$@" ;;
    *) die "Unknown subcommand: $SUBCMD. Valid: init add list show resolve stats" ;;
esac
