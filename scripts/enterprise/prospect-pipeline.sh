#!/usr/bin/env bash
set -uo pipefail
# prospect-pipeline.sh — SE-015 Project Prospect (Pipeline-as-Code)
#
# Muestra el pipeline de prospects para un tenant.
#
# Usage:
#   bash scripts/enterprise/prospect-pipeline.sh [--tenant SLUG] [--stage STAGE] [--json]
#
# Output: tabla o JSON con todos los prospects y su estado
#
# Exit codes: 0 ok | 2 usage error
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-015-project-prospect.md

TENANT="${SAVIA_TENANT:-default}"
FILTER_STAGE=""
JSON_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant) TENANT="$2"; shift 2 ;;
    --stage)  FILTER_STAGE="$2"; shift 2 ;;
    --json)   JSON_MODE=true; shift ;;
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PROSPECTS_DIR="${REPO_ROOT}/tenants/${TENANT}/prospects"

if [[ ! -d "$PROSPECTS_DIR" ]]; then
  if [[ "$JSON_MODE" == true ]]; then
    echo '{"tenant":"'"${TENANT}"'","count":0,"prospects":[]}'
  else
    echo "No prospects found for tenant '${TENANT}'"
  fi
  exit 0
fi

# Collect prospect data
prospects_json="["
first=true
count=0

for prospect_file in "${PROSPECTS_DIR}"/*/prospect.yaml; do
  [[ -f "$prospect_file" ]] || continue

  # Parse YAML fields
  slug=""
  client=""
  value_eur=""
  stage=""
  created_at=""

  while IFS=': ' read -r key val; do
    key="${key#"${key%%[![:space:]]*}"}"  # ltrim
    val="${val#"${val%%[![:space:]]*}"}"  # ltrim
    val="${val//\"/}"
    case "$key" in
      slug)       slug="$val" ;;
      client)     client="$val" ;;
      value_eur)  value_eur="$val" ;;
      stage)      stage="$val" ;;
      created_at) created_at="$val" ;;
    esac
  done < "$prospect_file"

  # Apply stage filter if provided
  if [[ -n "$FILTER_STAGE" && "$stage" != "$FILTER_STAGE" ]]; then
    continue
  fi

  count=$((count + 1))

  if [[ "$JSON_MODE" == true ]]; then
    if [[ "$first" == false ]]; then
      prospects_json="${prospects_json},"
    fi
    prospects_json="${prospects_json}{\"slug\":\"${slug}\",\"client\":\"${client}\",\"value_eur\":${value_eur:-0},\"stage\":\"${stage}\",\"created_at\":\"${created_at}\"}"
    first=false
  else
    printf "%-25s %-30s %12s EUR  %-15s  %s\n" \
      "$slug" "$client" "$value_eur" "$stage" "$created_at"
  fi
done

if [[ "$JSON_MODE" == true ]]; then
  prospects_json="${prospects_json}]"
  printf '{"tenant":"%s","count":%d,"prospects":%s}\n' "$TENANT" "$count" "$prospects_json"
else
  if [[ "$count" -eq 0 ]]; then
    echo "No prospects found${FILTER_STAGE:+ with stage '$FILTER_STAGE'} for tenant '${TENANT}'"
  else
    echo "Total: ${count} prospect(s)"
  fi
fi
