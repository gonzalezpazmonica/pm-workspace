#!/usr/bin/env bash
set -uo pipefail
# bench-match.sh — SE-022 Resource Bench Management
#
# Encuentra recursos disponibles que coincidan con skills requeridas.
#
# Usage:
#   bash scripts/enterprise/bench-match.sh \
#     --skills "python,azure" --from DATE --tenant SLUG [--json] [--threshold PCT]
#
# Busca en tenants/{tenant}/bench/*.yaml
# Output: [{user, skills_match_pct, available_from, available_until, matched_skills, missing_skills}]
#
# Exit codes: 0 ok (≥1 match) | 1 no matches | 2 usage error
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-022-resource-bench.md

SKILLS=""
FROM_DATE=""
TENANT=""
JSON_MODE=false
THRESHOLD=0  # minimum skills_match_pct (0 = return all)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skills)    SKILLS="$2";    shift 2 ;;
    --from)      FROM_DATE="$2"; shift 2 ;;
    --tenant)    TENANT="$2";    shift 2 ;;
    --json)      JSON_MODE=true; shift ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$SKILLS" || -z "$FROM_DATE" || -z "$TENANT" ]]; then
  echo "ERROR: --skills, --from, and --tenant are required" >&2
  exit 2
fi

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BENCH_DIR="${REPO_ROOT}/tenants/${TENANT}/bench"

if [[ ! -d "$BENCH_DIR" ]]; then
  if [[ "$JSON_MODE" == true ]]; then
    printf '{"tenant":"%s","required_skills":"%s","matches":[]}\n' "$TENANT" "$SKILLS"
  else
    echo "No bench directory found for tenant '${TENANT}'"
  fi
  exit 1
fi

# Parse required skills
IFS=',' read -ra required_skills <<< "$SKILLS"
req_count="${#required_skills[@]}"
# Normalize: trim whitespace, lowercase
declare -a required_norm=()
for s in "${required_skills[@]}"; do
  s="${s// /}"
  s="${s,,}"
  required_norm+=("$s")
done

results_json="["
first=true
match_found=false

for bench_file in "${BENCH_DIR}"/*.yaml; do
  [[ -f "$bench_file" ]] || continue

  user=""
  avail_from=""
  avail_until=""
  status="available"
  bench_skills=()

  # Parse YAML
  in_skills=false
  while IFS= read -r line; do
    if echo "$line" | grep -q "^user:"; then
      user=$(echo "$line" | sed 's/^user:\s*//' | tr -d '"')
    elif echo "$line" | grep -q "^available_from:"; then
      avail_from=$(echo "$line" | sed 's/^available_from:\s*//' | tr -d '"')
    elif echo "$line" | grep -q "^available_until:"; then
      avail_until=$(echo "$line" | sed 's/^available_until:\s*//' | tr -d '"')
    elif echo "$line" | grep -q "^status:"; then
      status=$(echo "$line" | sed 's/^status:\s*//' | tr -d '"')
    elif echo "$line" | grep -q "^skills:"; then
      in_skills=true
    elif [[ "$in_skills" == true ]]; then
      if echo "$line" | grep -q "^\s*-"; then
        skill=$(echo "$line" | sed 's/^\s*-\s*//' | tr -d '"' | tr -d ' ' | tr '[:upper:]' '[:lower:]')
        [[ -n "$skill" ]] && bench_skills+=("$skill")
      elif echo "$line" | grep -qv "^\s"; then
        in_skills=false
      fi
    fi
  done < "$bench_file"

  # Skip if not available or from date is after requested
  if [[ "$status" != "available" ]]; then continue; fi
  if [[ -n "$avail_from" && "$avail_from" > "$FROM_DATE" ]]; then continue; fi
  if [[ -n "$avail_until" && "$avail_until" < "$FROM_DATE" ]]; then continue; fi

  # Calculate skills match
  matched=0
  matched_skills=()
  missing_skills=()

  for req in "${required_norm[@]}"; do
    found=false
    for bs in "${bench_skills[@]}"; do
      if [[ "$bs" == "$req" ]]; then
        found=true
        break
      fi
    done
    if [[ "$found" == true ]]; then
      matched=$((matched + 1))
      matched_skills+=("$req")
    else
      missing_skills+=("$req")
    fi
  done

  if [[ "$req_count" -gt 0 ]]; then
    match_pct=$(awk -v m="$matched" -v t="$req_count" 'BEGIN{printf "%.0f", m/t*100}')
  else
    match_pct=100
  fi

  # Apply threshold filter
  if (( $(awk -v p="$match_pct" -v t="$THRESHOLD" 'BEGIN{print (p >= t) ? 1 : 0}') == 0 )); then
    continue
  fi

  match_found=true

  # Build matched/missing JSON arrays
  matched_json="["
  mfirst=true
  for s in "${matched_skills[@]}"; do
    if [[ "$mfirst" == false ]]; then matched_json="${matched_json},"; fi
    matched_json="${matched_json}\"${s}\""
    mfirst=false
  done
  matched_json="${matched_json}]"

  missing_json="["
  mfirst=true
  for s in "${missing_skills[@]}"; do
    if [[ "$mfirst" == false ]]; then missing_json="${missing_json},"; fi
    missing_json="${missing_json}\"${s}\""
    mfirst=false
  done
  missing_json="${missing_json}]"

  if [[ "$JSON_MODE" == true ]]; then
    if [[ "$first" == false ]]; then results_json="${results_json},"; fi
    results_json="${results_json}{\"user\":\"${user}\",\"skills_match_pct\":${match_pct},\"available_from\":\"${avail_from}\",\"available_until\":\"${avail_until}\",\"matched_skills\":${matched_json},\"missing_skills\":${missing_json}}"
    first=false
  else
    printf "%-20s  %3d%%  available_from: %-12s  matched: %s\n" \
      "$user" "$match_pct" "$avail_from" "${matched_skills[*]:-none}"
  fi
done

results_json="${results_json}]"

if [[ "$JSON_MODE" == true ]]; then
  printf '{"tenant":"%s","required_skills":"%s","threshold_pct":%s,"matches":%s}\n' \
    "$TENANT" "$SKILLS" "$THRESHOLD" "$results_json"
fi

if [[ "$match_found" == false ]]; then
  [[ "$JSON_MODE" == false ]] && echo "No matches found for skills '${SKILLS}' with threshold ${THRESHOLD}%"
  exit 1
fi
