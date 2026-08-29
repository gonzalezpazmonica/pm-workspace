#!/usr/bin/env bash
# savia-runs.sh — SE-349: Agent Runs Operations Ledger (ARO)
# Ledger operativo de runs autónomos: hechos durables + estado DERIVADO en lectura.
# Inspirado en Untrivial-ai/agent-orchestrator (derive, don't store status;
# "failed probes are NOT proof of death"). Rechaza su telemetría cloud (CRIT-001).
# Ref: docs/specs/SE-349-agent-runs-ledger.spec.md
#
# Subcommands:
#   init    → asegura ledger existente
#   start   <mode> <agent> <task> [--project P] [--branch B] [--url U]  → imprime run_id
#   state   <run_id> <activity_state>      spawning|active|waiting_input|blocked|exited
#   pr      <run_id> <number> [--state..] [--ci..] [--review..] [--mergeable..] [--url U]
#   pr      <run_id> clear                 → desposee el PR
#   finish  <run_id> [--force]             → guardrail de terminación
#   status  [--json]                       → board derivado
#   list    [--mode M] [--json]            → tabla de runs con estado derivado
#   show    <run_id>                       → hechos + estado derivado + traza de precedencia
#   reset                                  → vacía ledger (dev/test)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SAVIA_WORKSPACE_DIR:-${CLAUDE_PROJECT_DIR:-${OPENCODE_PROJECT_DIR:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)}}}"
LEDGER="${SAVIA_RUNS_LEDGER:-$WORKSPACE_DIR/data/agent-runs-ledger.jsonl}"

# ── Helpers ──────────────────────────────────────────────────────────────
_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

_gen_id() {
  if command -v uuidgen &>/dev/null; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    printf '%s-%s' "$(date +%s%N)" "$$"
  fi
}

_py3() { command -v python3 &>/dev/null; }

_ensure_ledger() {
  mkdir -p "$(dirname "$LEDGER")" 2>/dev/null || true
  [[ -f "$LEDGER" ]] || touch "$LEDGER"
}

# Read a single record by run_id; echoes JSON line or empty string.
_read_record() {
  local run_id="$1"
  [[ -f "$LEDGER" ]] || return 0
  python3 - "$LEDGER" "$run_id" <<'PY'
import sys, json
ledger, run_id = sys.argv[1], sys.argv[2]
last = None
try:
    with open(ledger, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            if rec.get("run_id") == run_id:
                last = rec
except OSError:
    pass
if last:
    print(json.dumps(last, ensure_ascii=False))
PY
}

# Upsert: rewrite ledger replacing the record for run_id (append-only per run).
_upsert_record() {
  local run_id="$1"
  local new_json="$2"
  local tmp
  tmp="$(mktemp)"
  python3 - "$LEDGER" "$run_id" "$new_json" "$tmp" <<'PY'
import sys, json
ledger, run_id, new_json, tmp = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
replaced = False
with open(ledger, encoding="utf-8", errors="replace") as fh, open(tmp, "w", encoding="utf-8") as out:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except Exception:
            out.write(line + "\n")
            continue
        if rec.get("run_id") == run_id:
            out.write(json.dumps(json.loads(new_json), ensure_ascii=False) + "\n")
            replaced = True
        else:
            out.write(line + "\n")
    if not replaced:
        out.write(json.dumps(json.loads(new_json), ensure_ascii=False) + "\n")
PY
  if [[ $? -ne 0 ]]; then
    echo "ERROR: ledger update failed for run_id '$run_id'" >&2
    return 1
  fi
  mv "$tmp" "$LEDGER"
}

# Derive display status from durable facts — ALWAYS at read time, never stored.
# Echoes: STATUS<TAB>TRACE
_derive() {
  local record="$1"
  python3 -c '
import sys, json
def derive(r):
    if r.get("is_terminated"):
        pr = r.get("pr") or {}
        if pr.get("state") == "merged":
            return "merged", "is_terminated=true and pr.state=merged"
        return "terminated", "is_terminated=true and pr.state!=\u0027merged\u0027"
    act = r.get("activity_state", "spawning")
    if act in ("waiting_input", "blocked"):
        return "needs_input", "activity_state=%s in (waiting_input, blocked)" % act
    pr = r.get("pr")
    if pr:
        if pr.get("ci") == "failing": return "ci_failed", "pr.ci=failing"
        if pr.get("state") == "draft": return "draft", "pr.state=draft"
        if pr.get("review") == "changes_requested": return "changes_requested", "pr.review=changes_requested"
        if pr.get("mergeable") == "false": return "merge_conflict", "pr.mergeable=false"
        if pr.get("review") == "approved": return "approved", "pr.review=approved"
        if pr.get("review") == "requested": return "review_pending", "pr.review=requested"
        return "pr_open", "pr.state=open (no other signal)"
    if act == "active": return "working", "activity_state=active"
    return "idle", "no pr and activity_state=" + act
s, t = derive(json.loads(sys.stdin.read()))
print(s + "\t" + t)
' <<< "$record"
}

# ── Subcommand: init ─────────────────────────────────────────────────────
cmd_init() {
  _ensure_ledger
  echo "ledger=$LEDGER"
}

# ── Subcommand: start ────────────────────────────────────────────────────
cmd_start() {
  local mode="${1:?mode required (overnight|improve|research|agent-task|sdd)}"
  local agent="${2:?agent required}"
  local task="${3:?task description required}"
  shift 3

  local project="" branch="" url=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project)  project="${2:-}";  shift 2 ;;
      --branch)   branch="${2:-}";   shift 2 ;;
      --url)      url="${2:-}";      shift 2 ;;
      *) echo "ERROR: unknown flag '$1'" >&2; exit 1 ;;
    esac
  done

  case "$mode" in
    overnight|improve|research|agent-task|sdd) ;;
    *) echo "ERROR: invalid mode '$mode'. Use: overnight|improve|research|agent-task|sdd" >&2; exit 1 ;;
  esac

  _ensure_ledger
  local run_id now
  run_id="$(_gen_id)"
  now="$(_now)"

  if _py3; then
    local record
    record="$(python3 -c '
import sys, json
mode, agent, task, project, branch, url, run_id, now = sys.argv[1:9]
print(json.dumps({
  "schema_version": "1",
  "run_id": run_id,
  "mode": mode,
  "agent": agent,
  "project": project or None,
  "branch": branch or None,
  "task": task,
  "url": url or None,
  "activity_state": "spawning",
  "is_terminated": False,
  "started_at": now,
  "updated_at": now,
  "ended_at": None,
  "pr": None
}, ensure_ascii=False))' "$mode" "$agent" "$task" "$project" "$branch" "$url" "$run_id" "$now")"
    echo "$record" >> "$LEDGER"
  else
    # Degradado: JSON mínimo sin python3
    echo "{\"schema_version\":\"1\",\"run_id\":\"$run_id\",\"mode\":\"$mode\",\"agent\":\"$agent\",\"project\":null,\"branch\":null,\"task\":\"$task\",\"url\":null,\"activity_state\":\"spawning\",\"is_terminated\":false,\"started_at\":\"$now\",\"updated_at\":\"$now\",\"ended_at\":null,\"pr\":null}" >> "$LEDGER"
  fi

  echo "$run_id"
}

# ── Subcommand: state ────────────────────────────────────────────────────
cmd_state() {
  local run_id="${1:?run_id required}"
  local activity="${2:?activity_state required}"

  case "$activity" in
    spawning|active|waiting_input|blocked|exited) ;;
    *) echo "ERROR: invalid activity_state '$activity'. Use: spawning|active|waiting_input|blocked|exited" >&2; exit 1 ;;
  esac

  if ! _py3; then
    echo "ERROR: python3 required for state update" >&2; exit 1
  fi

  local existing
  existing="$(_read_record "$run_id")"
  [[ -z "$existing" ]] && { echo "ERROR: run_id '$run_id' not found in $LEDGER" >&2; exit 1; }

  local now
  now="$(_now)"
  local updated
  updated="$(echo "$existing" | python3 -c '
import sys, json
r = json.loads(sys.stdin.read())
r["activity_state"] = sys.argv[1]
r["updated_at"] = sys.argv[2]
print(json.dumps(r, ensure_ascii=False))' "$activity" "$now")"

  _upsert_record "$run_id" "$updated" || { echo "ERROR: ledger update failed" >&2; exit 1; }
  echo "run_id=$run_id activity_state=$activity"
}

# ── Subcommand: pr ───────────────────────────────────────────────────────
cmd_pr() {
  local run_id="${1:?run_id required}"
  local number="${2:-}"

  if ! _py3; then
    echo "ERROR: python3 required for pr update" >&2; exit 1
  fi

  local existing
  existing="$(_read_record "$run_id")"
  [[ -z "$existing" ]] && { echo "ERROR: run_id '$run_id' not found in $LEDGER" >&2; exit 1; }

  # pr <run_id> clear → desposee el PR
  if [[ "$number" == "clear" ]]; then
    local now
    now="$(_now)"
    local updated
    updated="$(echo "$existing" | python3 -c '
import sys, json
r = json.loads(sys.stdin.read())
r["pr"] = None
r["updated_at"] = sys.argv[1]
print(json.dumps(r, ensure_ascii=False))' "$now")"
    _upsert_record "$run_id" "$updated" || { echo "ERROR: ledger update failed" >&2; exit 1; }
    echo "run_id=$run_id pr=cleared"
    return 0
  fi

  [[ "$number" =~ ^[0-9]+$ ]] || { echo "ERROR: pr number must be an integer" >&2; exit 1; }

  local state="open" ci="unknown" review="none" mergeable="unknown" url=""
  while [[ $# -gt 2 ]]; do
    case "$3" in
      --state)     state="${4:-}";     shift 2 ;;
      --ci)        ci="${4:-}";        shift 2 ;;
      --review)    review="${4:-}";    shift 2 ;;
      --mergeable) mergeable="${4:-}"; shift 2 ;;
      --url)       url="${4:-}";       shift 2 ;;
      *) echo "ERROR: unknown flag '$3'" >&2; exit 1 ;;
    esac
  done

  case "$state" in
    open|draft|merged|closed) ;;
    *) echo "ERROR: invalid pr state '$state'. Use: open|draft|merged|closed" >&2; exit 1 ;;
  esac
  case "$ci" in
    unknown|pending|passing|failing) ;;
    *) echo "ERROR: invalid ci '$ci'. Use: unknown|pending|passing|failing" >&2; exit 1 ;;
  esac
  case "$review" in
    none|requested|changes_requested|approved) ;;
    *) echo "ERROR: invalid review '$review'. Use: none|requested|changes_requested|approved" >&2; exit 1 ;;
  esac
  case "$mergeable" in
    unknown|true|false) ;;
    *) echo "ERROR: invalid mergeable '$mergeable'. Use: unknown|true|false" >&2; exit 1 ;;
  esac

  local now
  now="$(_now)"
  local updated
  updated="$(echo "$existing" | python3 -c '
import sys, json
r = json.loads(sys.stdin.read())
r["pr"] = {
  "number": int(sys.argv[1]),
  "state": sys.argv[2],
  "ci": sys.argv[3],
  "review": sys.argv[4],
  "mergeable": sys.argv[5],
  "url": sys.argv[6] or None
}
r["updated_at"] = sys.argv[7]
print(json.dumps(r, ensure_ascii=False))' "$number" "$state" "$ci" "$review" "$mergeable" "$url" "$now")"

  _upsert_record "$run_id" "$updated" || { echo "ERROR: ledger update failed" >&2; exit 1; }
  echo "run_id=$run_id pr=#$number state=$state ci=$ci review=$review mergeable=$mergeable"
}

# ── Subcommand: finish (guardrail) ───────────────────────────────────────
cmd_finish() {
  local run_id="${1:?run_id required}"
  local force=""
  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force="1"; shift ;;
      *) echo "ERROR: unknown flag '$1'" >&2; exit 1 ;;
    esac
  done

  if ! _py3; then
    echo "ERROR: python3 required for finish" >&2; exit 1
  fi

  local existing
  existing="$(_read_record "$run_id")"
  [[ -z "$existing" ]] && { echo "ERROR: run_id '$run_id' not found in $LEDGER" >&2; exit 1; }

  # Idempotente: ya terminado → no-op con éxito
  if echo "$existing" | python3 -c 'import sys,json; sys.exit(0 if json.load(sys.stdin).get("is_terminated") else 1)'; then
    echo "run_id=$run_id already terminated"
    return 0
  fi

  # Guardrail AO #2: failed probes are NOT proof of death.
  # Un run que posee un PR vivo (open/draft, no merged) NO es terminable.
  if [[ -z "$force" ]]; then
    local pr_line
    pr_line="$(echo "$existing" | python3 -c '
import sys, json
r = json.loads(sys.stdin.read())
pr = r.get("pr")
if not pr:
    sys.exit(0)
if pr.get("state") in ("open", "draft"):
    print("%s\t%s\t%s\t%s" % (pr.get("number"), pr.get("state"), pr.get("ci"), pr.get("review")))
    sys.exit(1)
sys.exit(0)')"
    if [[ $? -eq 1 ]]; then
      local num st ci rv
      num="${pr_line%%$'\t'*}"
      st="$(echo "$pr_line" | cut -f2)"
      ci="$(echo "$pr_line" | cut -f3)"
      rv="$(echo "$pr_line" | cut -f4)"
      echo "BLOCKED: run $run_id owns PR #$num (state=$st, ci=$ci, review=$rv) — still live." >&2
      echo "Termination would orphan its PR. AO guardrail: failed probes are not proof of death; an owned PR keeps the run alive." >&2
      echo "Finish it with --force only after the PR is merged/closed, or run 'savia-runs.sh pr $run_id clear' to disown it." >&2
      exit 1
    fi
  fi

  local now
  now="$(_now)"
  local updated
  updated="$(echo "$existing" | python3 -c '
import sys, json
r = json.loads(sys.stdin.read())
r["is_terminated"] = True
r["ended_at"] = sys.argv[1]
r["updated_at"] = sys.argv[1]
print(json.dumps(r, ensure_ascii=False))' "$now")"

  _upsert_record "$run_id" "$updated" || { echo "ERROR: ledger update failed" >&2; exit 1; }
  echo "run_id=$run_id terminated"
}

# ── Subcommand: status (board derivado) ──────────────────────────────────
cmd_status() {
  local json_mode=""
  [[ "${1:-}" == "--json" ]] && json_mode="1"
  [[ -f "$LEDGER" ]] || { echo "ledger=$LEDGER (empty)"; return 0; }

  if ! _py3; then
    echo "ERROR: python3 required for status" >&2; exit 1
  fi

  if [[ -n "$json_mode" ]]; then
    python3 - "$LEDGER" <<'PY'
import sys, json, datetime

def derive(r):
    if r.get("is_terminated"):
        pr = r.get("pr") or {}
        return "merged" if pr.get("state") == "merged" else "terminated"
    act = r.get("activity_state", "spawning")
    if act in ("waiting_input", "blocked"):
        return "needs_input"
    pr = r.get("pr")
    if pr:
        if pr.get("ci") == "failing": return "ci_failed"
        if pr.get("state") == "draft": return "draft"
        if pr.get("review") == "changes_requested": return "changes_requested"
        if pr.get("mergeable") == "false": return "merge_conflict"
        if pr.get("review") == "approved": return "approved"
        if pr.get("review") == "requested": return "review_pending"
        return "pr_open"
    if act == "active": return "working"
    return "idle"

cols = ["working", "needs_input", "ci_failed", "changes_requested", "merge_conflict",
        "draft", "review_pending", "pr_open", "approved", "merged", "terminated", "idle"]
runs = []
with open(sys.argv[1], encoding="utf-8", errors="replace") as fh:
    for line in fh:
        line = line.strip()
        if not line: continue
        try:
            r = json.loads(line)
        except Exception:
            continue
        r["derived_status"] = derive(r)
        runs.append(r)

out = {"as_of": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
       "columns": {c: [x["run_id"] for x in runs if x["derived_status"] == c] for c in cols},
       "runs": sorted(runs, key=lambda x: x.get("started_at", ""))}
print(json.dumps(out, ensure_ascii=False))
PY
    return 0
  fi

  python3 - "$LEDGER" <<'PY'
import sys, json, datetime

COLUMN_ORDER = [
    ("WORKING",         "working"),
    ("NEEDS YOU",       "needs_input"),
    ("NEEDS YOU",       "ci_failed"),
    ("NEEDS YOU",       "changes_requested"),
    ("NEEDS YOU",       "merge_conflict"),
    ("IN REVIEW",       "draft"),
    ("IN REVIEW",       "review_pending"),
    ("IN REVIEW",       "pr_open"),
    ("READY TO MERGE",  "approved"),
    ("DONE",            "merged"),
    ("TERMINATED",      "terminated"),
]

def derive(r):
    if r.get("is_terminated"):
        pr = r.get("pr") or {}
        return "merged" if pr.get("state") == "merged" else "terminated"
    act = r.get("activity_state", "spawning")
    if act in ("waiting_input", "blocked"):
        return "needs_input"
    pr = r.get("pr")
    if pr:
        if pr.get("ci") == "failing": return "ci_failed"
        if pr.get("state") == "draft": return "draft"
        if pr.get("review") == "changes_requested": return "changes_requested"
        if pr.get("mergeable") == "false": return "merge_conflict"
        if pr.get("review") == "approved": return "approved"
        if pr.get("review") == "requested": return "review_pending"
        return "pr_open"
    if act == "active": return "working"
    return "idle"

def short_task(t, n=26):
    t = t or ""
    return t if len(t) <= n else t[:n-1] + "…"

def card(r):
    parts = [r.get("run_id", "?")]
    mode = r.get("mode") or ""
    agent = r.get("agent") or ""
    parts.append("%s@%s" % (mode, agent))
    if r.get("branch"): parts.append(r["branch"])
    parts.append(short_task(r.get("task")))
    return " · ".join(parts)

runs = []
with open(sys.argv[1], encoding="utf-8", errors="replace") as fh:
    for line in fh:
        line = line.strip()
        if not line: continue
        try:
            r = json.loads(line)
        except Exception:
            continue
        r["derived_status"] = derive(r)
        runs.append(r)
runs.sort(key=lambda x: x.get("started_at", ""))

columns = {}
for label, st in COLUMN_ORDER:
    columns.setdefault(label, [])
    columns[label] += [r for r in runs if r["derived_status"] == st]
idle = [r for r in runs if r["derived_status"] == "idle"]

header = ["WORKING", "NEEDS YOU", "IN REVIEW", "READY TO MERGE", "DONE", "TERMINATED"]
widths = {h: max(len(h), 4) for h in header}
as_of = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

print("=== Agent Runs Board (derived) — as of %s ===" % as_of)
print("ledger: %s" % sys.argv[1])
print("")
for h in header:
    print("%-*s| " % (widths[h], "%s (%d)" % (h, len(columns.get(h, [])))), end="")
print()
print("-" * (sum(widths[h] + 2 for h in header)))
nrows = max((len(columns.get(h, [])) for h in header), default=0)
for i in range(nrows):
    for h in header:
        c = columns.get(h, [])
        cell = card(c[i]) if i < len(c) else ""
        print("%-*s| " % (widths[h], cell[:widths[h]]), end="")
    print()
if not runs:
    print("(no runs)")
if idle:
    print("")
    print("idle (sin actividad): %d" % len(idle))
    for r in idle:
        print("  " + card(r))
PY
}

# ── Subcommand: list ─────────────────────────────────────────────────────
cmd_list() {
  local mode_filter="" json_mode=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode) mode_filter="${2:-}"; shift 2 ;;
      --json) json_mode="1"; shift ;;
      *) echo "ERROR: unknown flag '$1'" >&2; exit 1 ;;
    esac
  done

  [[ -f "$LEDGER" ]] || { echo "(no ledger)"; return 0; }
  if ! _py3; then
    echo "ERROR: python3 required for list" >&2; exit 1
  fi

  python3 - "$LEDGER" "$mode_filter" "$json_mode" <<'PY'
import sys, json

def derive(r):
    if r.get("is_terminated"):
        pr = r.get("pr") or {}
        return "merged" if pr.get("state") == "merged" else "terminated"
    act = r.get("activity_state", "spawning")
    if act in ("waiting_input", "blocked"):
        return "needs_input"
    pr = r.get("pr")
    if pr:
        if pr.get("ci") == "failing": return "ci_failed"
        if pr.get("state") == "draft": return "draft"
        if pr.get("review") == "changes_requested": return "changes_requested"
        if pr.get("mergeable") == "false": return "merge_conflict"
        if pr.get("review") == "approved": return "approved"
        if pr.get("review") == "requested": return "review_pending"
        return "pr_open"
    if act == "active": return "working"
    return "idle"

ledger, mode_filter, json_mode = sys.argv[1], sys.argv[2], sys.argv[3]
rows = []
with open(ledger, encoding="utf-8", errors="replace") as fh:
    for line in fh:
        line = line.strip()
        if not line: continue
        try:
            r = json.loads(line)
        except Exception:
            continue
        if mode_filter and r.get("mode") != mode_filter:
            continue
        r["derived_status"] = derive(r)
        rows.append(r)
rows.sort(key=lambda x: x.get("started_at", ""))

if json_mode:
    print(json.dumps(rows, ensure_ascii=False))
    sys.exit(0)

if not rows:
    print("(no runs)%s" % (" for mode=" + mode_filter if mode_filter else ""))
    sys.exit(0)

print("%-38s %-10s %-18s %-12s %-28s %s" % ("RUN_ID", "MODE", "AGENT", "STATUS", "BRANCH", "STARTED"))
for r in rows:
    rid = r.get("run_id", "?")
    print("%-38s %-10s %-18s %-12s %-28s %s" % (
        rid[:38], (r.get("mode") or "")[:10], (r.get("agent") or "")[:18],
        r["derived_status"], (r.get("branch") or "")[:28], (r.get("started_at") or "")[:19]))
PY
}

# ── Subcommand: show ─────────────────────────────────────────────────────
cmd_show() {
  local run_id="${1:?run_id required}"
  [[ -f "$LEDGER" ]] || { echo "ERROR: no ledger at $LEDGER" >&2; exit 1; }
  if ! _py3; then
    echo "ERROR: python3 required for show" >&2; exit 1
  fi

  local existing
  existing="$(_read_record "$run_id")"
  [[ -z "$existing" ]] && { echo "ERROR: run_id '$run_id' not found in $LEDGER" >&2; exit 1; }

  local derived trace
  derived="$(_derive "$existing")"
  trace="${derived#*$'\t'}"
  derived="${derived%%$'\t'*}"

  echo "run_id      : $run_id"
  echo "mode        : $(echo "$existing" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("mode") or "")')"
  echo "agent       : $(echo "$existing" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("agent") or "")')"
  echo "project     : $(echo "$existing" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("project") or "")')"
  echo "branch      : $(echo "$existing" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("branch") or "")')"
  echo "task        : $(echo "$existing" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("task") or "")')"
  echo "started_at  : $(echo "$existing" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("started_at") or "")')"
  echo "ended_at    : $(echo "$existing" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("ended_at") or "")')"
  echo "activity    : $(echo "$existing" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("activity_state") or "")')"
  echo "terminated  : $(echo "$existing" | python3 -c 'import sys,json;print("true" if json.load(sys.stdin).get("is_terminated") else "false")')"
  echo "pr          : $(echo "$existing" | python3 -c '
import sys, json
pr = json.load(sys.stdin).get("pr")
if not pr: print("(none)")
else: print("#%(number)s state=%(state)s ci=%(ci)s review=%(review)s mergeable=%(mergeable)s" % pr)')"
  echo ""
  echo "derived_status : $derived"
  echo "trace          : $trace"
}

# ── Subcommand: reset ────────────────────────────────────────────────────
cmd_reset() {
  : > "$LEDGER"
  echo "ledger=$LEDGER reset"
}

# ── Dispatcher ───────────────────────────────────────────────────────────
SUBCOMMAND="${1:-}"
shift || true

case "$SUBCOMMAND" in
  init)   cmd_init   "$@" ;;
  start)  cmd_start  "$@" ;;
  state)  cmd_state  "$@" ;;
  pr)     cmd_pr     "$@" ;;
  finish) cmd_finish "$@" ;;
  status) cmd_status "$@" ;;
  list)   cmd_list   "$@" ;;
  show)   cmd_show   "$@" ;;
  reset)  cmd_reset  "$@" ;;
  *)
    echo "Usage: savia-runs.sh <init|start|state|pr|finish|status|list|show|reset> [args...]" >&2
    echo "" >&2
    echo "  init" >&2
    echo "  start   <mode> <agent> <task> [--project P] [--branch B] [--url U]   → imprime run_id" >&2
    echo "  state   <run_id> <spawning|active|waiting_input|blocked|exited>" >&2
    echo "  pr      <run_id> <number> [--state open|draft|merged|closed] [--ci passing|failing|pending|unknown]" >&2
    echo "          [--review none|requested|changes_requested|approved] [--mergeable true|false|unknown] [--url U]" >&2
    echo "  pr      <run_id> clear" >&2
    echo "  finish  <run_id> [--force]" >&2
    echo "  status  [--json]" >&2
    echo "  list    [--mode M] [--json]" >&2
    echo "  show    <run_id>" >&2
    echo "  reset" >&2
    exit 1 ;;
esac
