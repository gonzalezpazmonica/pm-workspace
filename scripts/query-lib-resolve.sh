#!/usr/bin/env bash
# query-lib-resolve.sh — SE-031
# Resolves a query from .claude/queries/ by ID with optional param substitution.
# Ref: docs/propuestas/SE-031-query-library-nl.md
#
# Usage:
#   bash scripts/query-lib-resolve.sh --id ID [--param key=value ...] [--json]
#   bash scripts/query-lib-resolve.sh --list [--lang wiql|jql|savia-flow] [--json]
#
# Exit codes:
#   0 = query resolved/listed
#   1 = query not found
#   2 = input error

set -uo pipefail

ID=""
LIST=false
LANG_FILTER=""
JSON_OUT=false
declare -A PARAMS

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID="$2"; shift 2 ;;
    --list) LIST=true; shift ;;
    --lang) LANG_FILTER="$2"; shift 2 ;;
    --param)
      kv="$2"
      k="${kv%%=*}"
      v="${kv#*=}"
      PARAMS["$k"]="$v"
      shift 2 ;;
    --json) JSON_OUT=true; shift ;;
    --help|-h) usage ;;
    *) echo "Error: unknown flag $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}" || REPO_ROOT="."
QUERIES_DIR="$REPO_ROOT/.claude/queries"

[[ ! -d "$QUERIES_DIR" ]] && { echo "Error: queries dir not found: $QUERIES_DIR" >&2; exit 2; }

# ── List mode ────────────────────────────────────────────────────────────────
if $LIST; then
  entries=()
  while IFS= read -r file; do
    qid=$(grep -E '^id:' "$file" 2>/dev/null | head -1 | sed 's/^id:[[:space:]]*//' | tr -d '"')
    qlang=$(grep -E '^lang:' "$file" 2>/dev/null | head -1 | sed 's/^lang:[[:space:]]*//' | tr -d '"')
    qdesc=$(grep -E '^description:' "$file" 2>/dev/null | head -1 | sed 's/^description:[[:space:]]*//' | tr -d '"')
    qtags=$(grep -E '^tags:' "$file" 2>/dev/null | head -1 | sed 's/^tags:[[:space:]]*//' | tr -d '[]"')

    # Filter by lang if specified
    if [[ -n "$LANG_FILTER" && "$qlang" != "$LANG_FILTER" ]]; then
      continue
    fi

    entries+=("${qid}|${qlang}|${qtags}|${qdesc}")
  done < <(find "$QUERIES_DIR" -type f \( -name "*.wiql" -o -name "*.jql" -o -name "*.yaml" \) 2>/dev/null | sort)

  if $JSON_OUT; then
    printf '['
    first=true
    for e in "${entries[@]}"; do
      IFS='|' read -r id lang tags desc <<< "$e"
      $first && first=false || printf ','
      printf '{"id":"%s","lang":"%s","tags":"%s","description":"%s"}' \
        "$id" "$lang" "$tags" "$desc"
    done
    printf ']\n'
  else
    printf "%-30s %-12s %-30s %s\n" "ID" "LANG" "TAGS" "DESCRIPTION"
    echo "------------------------------------------------------------------------------------"
    for e in "${entries[@]}"; do
      IFS='|' read -r id lang tags desc <<< "$e"
      printf "%-30s %-12s %-30s %s\n" "$id" "$lang" "$tags" "${desc:0:50}"
    done
  fi
  exit 0
fi

# ── Resolve mode ─────────────────────────────────────────────────────────────
[[ -z "$ID" ]] && { echo "Error: --id required (or use --list)" >&2; exit 2; }

# Find the file matching the id
MATCH_FILE=""
while IFS= read -r file; do
  qid=$(grep -E '^id:' "$file" 2>/dev/null | head -1 | sed 's/^id:[[:space:]]*//' | tr -d '"')
  if [[ "$qid" == "$ID" ]]; then
    MATCH_FILE="$file"
    break
  fi
done < <(find "$QUERIES_DIR" -type f \( -name "*.wiql" -o -name "*.jql" -o -name "*.yaml" \) 2>/dev/null)

[[ -z "$MATCH_FILE" ]] && { echo "Error: query not found: $ID" >&2; exit 1; }

# Extract query body (everything after the second '---')
QUERY_BODY=$(python3 <<PY
with open("$MATCH_FILE") as f:
    content = f.read()
# Find the end of frontmatter
import re
m = re.search(r'^---\n.*?\n---\n', content, re.DOTALL | re.MULTILINE)
if m:
    print(content[m.end():].strip())
else:
    print(content.strip())
PY
)

# Param substitution
for key in "${!PARAMS[@]}"; do
  value="${PARAMS[$key]}"
  # Escape special chars for sed
  value_esc=$(printf '%s\n' "$value" | sed -e 's/[&/\]/\\&/g')
  QUERY_BODY=$(echo "$QUERY_BODY" | sed "s/{{${key}}}/${value_esc}/g")
done

# Warn about unsubstituted placeholders
UNSUB=$(echo "$QUERY_BODY" | grep -oE '\{\{[a-zA-Z_][a-zA-Z0-9_]*\}\}' | sort -u || true)

if $JSON_OUT; then
  # JSON-safe via python
  python3 -c "
import json
print(json.dumps({
  'id': '$ID',
  'file': '$MATCH_FILE',
  'query': '''$QUERY_BODY''',
  'unsubstituted': '''$UNSUB'''.split() if '''$UNSUB''' else []
}))
"
else
  echo "$QUERY_BODY"
  if [[ -n "$UNSUB" ]]; then
    echo "" >&2
    echo "# WARN: unsubstituted placeholders: $UNSUB" >&2
  fi
fi

exit 0
