#!/usr/bin/env bash
# graph-temporal-ops.sh — SPEC-123
# Temporal edge operations for knowledge-graph skill.
# Adds valid_from / invalid_at pattern (Graphiti-inspired).
#
# Usage:
#   bash scripts/graph-temporal-ops.sh add_edge --from X --to Y --rel R [--graph PATH]
#   bash scripts/graph-temporal-ops.sh invalidate_edge --from X --to Y --rel R [--graph PATH]
#   bash scripts/graph-temporal-ops.sh query_at_time --when ISO --entity X [--relation R] [--graph PATH]
#
# Graph format: JSONL (one edge per line) at .knowledge-graph/edges.jsonl by default.
#
# Exit codes:
#   0 = success
#   1 = warning (edge already invalid, no match)
#   2 = error (malformed input, missing args)

set -uo pipefail

GRAPH_PATH="${GRAPH_PATH:-.knowledge-graph/edges.jsonl}"
CMD=""
FROM=""
TO=""
REL=""
WHEN=""
ENTITY=""

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \?//'
  exit 0
}

parse() {
  [[ $# -lt 1 ]] && usage
  case "$1" in
    --help|-h) usage ;;
  esac
  CMD="$1"; shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) FROM="$2"; shift 2 ;;
      --to) TO="$2"; shift 2 ;;
      --rel|--relation) REL="$2"; shift 2 ;;
      --when) WHEN="$2"; shift 2 ;;
      --entity) ENTITY="$2"; shift 2 ;;
      --graph) GRAPH_PATH="$2"; shift 2 ;;
      --help|-h) usage ;;
      *) echo "Error: unknown arg '$1'" >&2; exit 2 ;;
    esac
  done
}

now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

ensure_graph() {
  mkdir -p "$(dirname "$GRAPH_PATH")"
  [[ -f "$GRAPH_PATH" ]] || : > "$GRAPH_PATH"
}

# ── commands ──────────────────────────────────────────────────────────────

cmd_add_edge() {
  [[ -z "$FROM" || -z "$TO" || -z "$REL" ]] && { echo "Error: --from, --to, --rel required" >&2; exit 2; }
  ensure_graph
  local ts; ts=$(now_iso)
  local edge
  edge=$(python3 -c "
import json,sys
print(json.dumps({
  'from': '$FROM',
  'to': '$TO',
  'relation': '$REL',
  'valid_from': '$ts',
  'invalid_at': None,
  'evidence': 'graph-temporal-ops.sh'
}))")
  echo "$edge" >> "$GRAPH_PATH"
  echo "OK added: $FROM --[$REL]--> $TO (valid_from=$ts)"
}

cmd_invalidate_edge() {
  [[ -z "$FROM" || -z "$TO" || -z "$REL" ]] && { echo "Error: --from, --to, --rel required" >&2; exit 2; }
  ensure_graph
  local ts; ts=$(now_iso)
  local tmp; tmp=$(mktemp)
  local found=0
  python3 <<PY > "$tmp"
import json, sys
with open("$GRAPH_PATH") as f:
    for line in f:
        line = line.rstrip()
        if not line: continue
        try:
            e = json.loads(line)
        except Exception:
            print(line); continue
        if (e.get('from') == "$FROM" and e.get('to') == "$TO"
            and e.get('relation') == "$REL" and e.get('invalid_at') is None):
            e['invalid_at'] = "$ts"
            sys.stderr.write("FOUND\n")
        print(json.dumps(e))
PY
  if grep -q "FOUND" <(python3 -c "" 2>&1) 2>/dev/null; then :; fi
  # Re-check using grep for marker on the tmp file content
  if python3 -c "
import json
hit=False
with open('$tmp') as f:
    for line in f:
        try:
            e=json.loads(line)
        except: continue
        if (e.get('from')=='$FROM' and e.get('to')=='$TO' and e.get('relation')=='$REL'
            and e.get('invalid_at')=='$ts'):
            hit=True; break
print(1 if hit else 0)
" | grep -q "^1$"; then
    mv "$tmp" "$GRAPH_PATH"
    echo "OK invalidated: $FROM --[$REL]--> $TO at $ts"
    return 0
  fi
  rm -f "$tmp"
  echo "WARN: no active edge found for $FROM --[$REL]--> $TO" >&2
  exit 1
}

cmd_query_at_time() {
  [[ -z "$WHEN" ]] && { echo "Error: --when required (ISO-8601)" >&2; exit 2; }
  ensure_graph
  python3 <<PY
import json
when = "$WHEN"
entity = "$ENTITY" or None
relation = "$REL" or None
results = []
try:
    with open("$GRAPH_PATH") as f:
        for line in f:
            line = line.rstrip()
            if not line: continue
            try:
                e = json.loads(line)
            except: continue
            vf = e.get('valid_from')
            ia = e.get('invalid_at')
            if vf and vf > when:
                continue
            if ia and ia <= when:
                continue
            if entity and e.get('from') != entity and e.get('to') != entity:
                continue
            if relation and e.get('relation') != relation:
                continue
            results.append(e)
except FileNotFoundError:
    pass
for r in results:
    vf = r.get('valid_from', '?')
    ia = r.get('invalid_at') or 'present'
    print(f"{r.get('from')} --[{r.get('relation')}]--> {r.get('to')} (valid {vf} -> {ia})")
print(f"# {len(results)} edge(s) active at {when}")
PY
}

main() {
  parse "$@"
  case "$CMD" in
    add_edge) cmd_add_edge ;;
    invalidate_edge) cmd_invalidate_edge ;;
    query_at_time) cmd_query_at_time ;;
    *) echo "Error: unknown command '$CMD'. Use: add_edge | invalidate_edge | query_at_time" >&2; exit 2 ;;
  esac
}

main "$@"
