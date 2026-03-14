#!/usr/bin/env bash
# backlog-query.sh — Query local backlog PBIs by frontmatter fields
# Usage: ./scripts/backlog-query.sh [options]
# ─────────────────────────────────────────────────────────────────
set -uo pipefail
cat /dev/stdin > /dev/null 2>&1 || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."

PROJECT=""
STATE="" SPRINT="" ASSIGNED="" PRIORITY="" TYPE="" FORMAT="table"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --state) STATE="$2"; shift 2 ;;
    --sprint) SPRINT="$2"; shift 2 ;;
    --assigned) ASSIGNED="$2"; shift 2 ;;
    --priority) PRIORITY="$2"; shift 2 ;;
    --type) TYPE="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# ── Find backlog ──
BACKLOG=""
if [ -n "$PROJECT" ]; then
  BACKLOG="${ROOT}/projects/${PROJECT}/backlog"
else
  for p in "${ROOT}"/projects/*/backlog; do
    [ -d "$p" ] && BACKLOG="$p" && break
  done
fi
[ -d "$BACKLOG" ] || { echo "Error: No backlog found" >&2; exit 1; }

# ── Extract field from frontmatter ──
get_field() {
  local file="$1" field="$2"
  grep "^${field}:" "$file" 2>/dev/null | head -1 | sed "s/${field}: *//;s/^\"//;s/\"$//"
}

# ── Collect matching PBIs ──
RESULTS=()
for f in "$BACKLOG"/pbi/PBI-*.md; do
  [ -f "$f" ] || continue
  [ -n "$STATE" ] && [[ "$(get_field "$f" state)" != "$STATE" ]] && continue
  [ -n "$SPRINT" ] && [[ "$(get_field "$f" sprint)" != "$SPRINT" ]] && continue
  [ -n "$ASSIGNED" ] && [[ "$(get_field "$f" assigned_to)" != "$ASSIGNED" ]] && continue
  [ -n "$PRIORITY" ] && [[ "$(get_field "$f" priority)" != "$PRIORITY" ]] && continue
  [ -n "$TYPE" ] && [[ "$(get_field "$f" type)" != "$TYPE" ]] && continue
  RESULTS+=("$f")
done

# ── Output ──
if [ "$FORMAT" = "json" ]; then
  echo "["
  first=true
  for f in "${RESULTS[@]:-}"; do
    [ -z "$f" ] && continue
    $first && first=false || echo ","
    printf '  {"id":"%s","title":"%s","state":"%s","priority":"%s","sprint":"%s","assigned":"%s"}' \
      "$(get_field "$f" id)" "$(get_field "$f" title)" "$(get_field "$f" state)" \
      "$(get_field "$f" priority)" "$(get_field "$f" sprint)" "$(get_field "$f" assigned_to)"
  done
  echo ""
  echo "]"
elif [ "$FORMAT" = "count" ]; then
  echo "${#RESULTS[@]}"
else
  echo "| ID | Title | State | Priority | Sprint | Assigned |"
  echo "|----|-------|-------|----------|--------|----------|"
  for f in "${RESULTS[@]:-}"; do
    [ -z "$f" ] && continue
    printf "| %s | %s | %s | %s | %s | %s |\n" \
      "$(get_field "$f" id)" "$(get_field "$f" title)" "$(get_field "$f" state)" \
      "$(get_field "$f" priority)" "$(get_field "$f" sprint)" "$(get_field "$f" assigned_to)"
  done
  echo ""
  echo "Total: ${#RESULTS[@]} items"
fi
