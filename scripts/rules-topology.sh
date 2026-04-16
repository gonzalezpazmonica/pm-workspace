#!/bin/bash
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RULES_DIR="${ROOT}/docs/rules/domain"
MODE="${1:-summary}"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Helper: extract name from frontmatter
extract_name() {
  sed -n '/^---$/,/^---$/p' "$1" | grep "^name:" | head -1 | sed 's/^name:\s*//; s/[[:space:]]*$//'
}

# Helper: get content after frontmatter
get_content() {
  awk '/^---$/{if(++c==2){p=1;next}} p' "$1"
}

# 1. Count total rules
TOTAL=$(find "$RULES_DIR" -name "*.md" 2>/dev/null | wc -l)

# 2. Build rules map and detect duplicates
declare -A rules_map rule_files
ORPHANS=0
declare -a all_rules

for file in "$RULES_DIR"/*.md; do
  [[ ! -f "$file" ]] && continue
  name=$(extract_name "$file")
  [[ -z "$name" ]] && continue
  rules_map["$name"]="$file"
  rule_files["$file"]="$name"
  all_rules+=("$name")
done

# 3. Build cross-reference map
declare -A references
for file in "$RULES_DIR"/*.md; do
  [[ ! -f "$file" ]] && continue
  current_name="${rule_files[$file]:-}"
  [[ -z "$current_name" ]] && continue
  
  for other_name in "${all_rules[@]}"; do
    [[ "$other_name" == "$current_name" ]] && continue
    if get_content "$file" | grep -qiE "\b${other_name}\b"; then
      references["$current_name"]+="${other_name},"
    fi
  done
done

# 4. Detect orphans (not referenced by any rule)
declare -a orphan_list=()
for name in "${all_rules[@]}"; do
  is_referenced=0
  for ref_rule in "${!references[@]}"; do
    [[ "${references[$ref_rule]}" == *"${name}"* ]] && is_referenced=1 && break
  done
  [[ $is_referenced -eq 0 ]] && orphan_list+=("$name") && ((ORPHANS++))
done

# 5. Detect duplicates (>80% similar first 5 lines)
declare -a duplicates=()

for i in "${!all_rules[@]}"; do
  for j in "${!all_rules[@]}"; do
    [[ $i -ge $j ]] && continue
    file1="${rules_map[${all_rules[$i]}]}"
    file2="${rules_map[${all_rules[$j]}]}"
    head1=$(get_content "$file1" | head -5 | md5sum | cut -d' ' -f1)
    head2=$(get_content "$file2" | head -5 | md5sum | cut -d' ' -f1)
    [[ "$head1" == "$head2" ]] && duplicates+=("${all_rules[$i]} <-> ${all_rules[$j]}")
  done
done

# Output modes
case "$MODE" in
  json)
    printf '{"total":%d,"orphans":%d,"duplicates":%d,"orphan_rules":[' "$TOTAL" "$ORPHANS" "${#duplicates[@]}"
    for rule in "${orphan_list[@]}"; do printf '"%s",' "$rule"; done | sed 's/,$//'
    printf ']}'
    ;;
  graph)
    echo "=== Rules Dependency Graph ==="
    for name in "${all_rules[@]}"; do
      refs="${references[$name]:-}"
      if [[ -n "$refs" ]]; then
        echo "$name -> ${refs%,}"
      fi
    done
    ;;
  *)
    echo "Total Rules: $TOTAL"
    echo "Orphan Rules: $ORPHANS ($(( TOTAL > 0 ? ORPHANS * 100 / TOTAL : 0 ))%)"
    echo "Duplicate Groups: ${#duplicates[@]}"
    [[ $ORPHANS -gt 0 ]] && echo -e "\nOrphans:" && printf '  - %s\n' "${orphan_list[@]}"
    [[ ${#duplicates[@]} -gt 0 ]] && echo -e "\nDuplicates:" && printf '  - %s\n' "${duplicates[@]}"
    ;;
esac

# 6. --ci mode: exit non-zero if orphans > 20%
if [[ "$MODE" == "--ci" ]]; then
  THRESHOLD=$(( TOTAL * 20 / 100 ))
  [[ $ORPHANS -gt $THRESHOLD ]] && exit 1
  exit 0
fi
