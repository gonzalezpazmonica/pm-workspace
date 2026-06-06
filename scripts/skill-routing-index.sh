#!/usr/bin/env bash
# skill-routing-index.sh — SE-152
# Scans all .opencode/skills/*/SKILL.md, extracts consumes/produces from
# YAML frontmatter, and generates output/skill-routing-index.json
#
# Usage:
#   bash scripts/skill-routing-index.sh              # generate index
#   bash scripts/skill-routing-index.sh --check      # verify index is up-to-date
#   bash scripts/skill-routing-index.sh --json       # same as default (JSON to stdout)
#
# Output: output/skill-routing-index.json
#   {
#     "consumes": { "spec": ["skill-a", "skill-b"], ... },
#     "produces": { "report": ["skill-c"], ... },
#     "skills": { "skill-a": { "consumes": [...], "produces": [...] } }
#   }
#
# Exit 0 on success, exit 1 on --check mismatch or error.
#
# Ref: SE-152

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$(cd -P "$ROOT/.opencode/skills" && pwd)"
OUTPUT_DIR="$ROOT/output"
INDEX_FILE="$OUTPUT_DIR/skill-routing-index.json"

MODE_CHECK=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE_CHECK=true ;;
    --json)  : ;;  # default mode, accepted for compatibility
    --help|-h)
      sed -n '2,16p' "$0" | sed 's/^# //'
      exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

# ── Parse frontmatter lists ───────────────────────────────────────────────────
# Extract a YAML list field from frontmatter content.
# Usage: parse_yaml_list "field_name" "frontmatter_block"
# Returns: space-separated values
parse_yaml_list() {
  local field="$1"
  local fm="$2"
  local in_field=false
  local values=()

  while IFS= read -r line; do
    if [[ "$line" =~ ^${field}:[[:space:]]* ]]; then
      in_field=true
      # inline: field: [a, b, c]
      local inline
      inline="${line#*:}"
      inline="${inline//[[:space:]]/}"
      if [[ "$inline" =~ ^\[.*\]$ ]]; then
        inline="${inline#[}"
        inline="${inline%]}"
        IFS=',' read -ra parts <<< "$inline"
        for p in "${parts[@]}"; do
          p="${p//\"/}"
          p="${p//\'/}"
          [[ -n "$p" ]] && values+=("$p")
        done
        in_field=false
      fi
      continue
    fi
    if $in_field; then
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*(.*) ]]; then
        local val="${BASH_REMATCH[1]}"
        val="${val//\"/}"
        val="${val//\'/}"
        [[ -n "$val" ]] && values+=("$val")
      elif [[ "$line" =~ ^[^[:space:]] ]]; then
        in_field=false
      fi
    fi
  done <<< "$fm"

  echo "${values[@]+"${values[@]}"}"
}

# ── Collect skill data ────────────────────────────────────────────────────────
declare -A skill_consumes  # skill -> space-separated list
declare -A skill_produces  # skill -> space-separated list
declare -A consumes_index  # value -> space-separated skill list
declare -A produces_index  # value -> space-separated skill list

mapfile -t skill_dirs < <(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d | sort)

for dir in "${skill_dirs[@]}"; do
  name="$(basename "$dir")"
  [[ "$name" == "_template" ]] && continue

  skill_md="$dir/SKILL.md"
  [[ ! -f "$skill_md" ]] && continue

  # Extract frontmatter block
  fm_block=""
  in_fm=false
  line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    if [[ $line_num -eq 1 && "$line" == "---" ]]; then
      in_fm=true; continue
    fi
    if $in_fm && [[ "$line" == "---" ]]; then
      break
    fi
    if $in_fm; then
      fm_block="${fm_block}${line}"$'\n'
    fi
    [[ $line_num -gt 40 ]] && break
  done < "$skill_md"

  [[ -z "$fm_block" ]] && continue

  # Parse consumes
  read -ra c_vals <<< "$(parse_yaml_list "consumes" "$fm_block")"
  if [[ ${#c_vals[@]} -gt 0 ]]; then
    skill_consumes["$name"]="${c_vals[*]}"
    for v in "${c_vals[@]}"; do
      if [[ -n "${consumes_index[$v]+x}" ]]; then
        consumes_index["$v"]="${consumes_index[$v]} $name"
      else
        consumes_index["$v"]="$name"
      fi
    done
  fi

  # Parse produces
  read -ra p_vals <<< "$(parse_yaml_list "produces" "$fm_block")"
  if [[ ${#p_vals[@]} -gt 0 ]]; then
    skill_produces["$name"]="${p_vals[*]}"
    for v in "${p_vals[@]}"; do
      if [[ -n "${produces_index[$v]+x}" ]]; then
        produces_index["$v"]="${produces_index[$v]} $name"
      else
        produces_index["$v"]="$v"  # BUG guard — reset below
        produces_index["$v"]="$name"
      fi
    done
  fi
done

# ── Build JSON ────────────────────────────────────────────────────────────────
json_array_from_space() {
  local items=()
  read -ra items <<< "$1"
  local out=""
  local first=true
  for item in "${items[@]}"; do
    [[ -z "$item" ]] && continue
    $first || out+=", "
    out+="\"$item\""
    first=false
  done
  echo "[$out]"
}

build_json() {
  local out='{'
  out+='"consumes": {'
  local first=true
  for key in $(echo "${!consumes_index[@]}" | tr ' ' '\n' | sort); do
    $first || out+=', '
    local arr
    arr="$(json_array_from_space "${consumes_index[$key]}")"
    out+="\"$key\": $arr"
    first=false
  done
  out+='}, '

  out+='"produces": {'
  first=true
  for key in $(echo "${!produces_index[@]}" | tr ' ' '\n' | sort); do
    $first || out+=', '
    local arr
    arr="$(json_array_from_space "${produces_index[$key]}")"
    out+="\"$key\": $arr"
    first=false
  done
  out+='}, '

  out+='"skills": {'
  first=true
  for sk in $(echo "${!skill_consumes[*]} ${!skill_produces[*]}" | tr ' ' '\n' | sort -u); do
    $first || out+=', '
    local c_arr='[]'
    local p_arr='[]'
    [[ -n "${skill_consumes[$sk]+x}" ]] && c_arr="$(json_array_from_space "${skill_consumes[$sk]}")"
    [[ -n "${skill_produces[$sk]+x}" ]] && p_arr="$(json_array_from_space "${skill_produces[$sk]}")"
    out+="\"$sk\": {\"consumes\": $c_arr, \"produces\": $p_arr}"
    first=false
  done
  out+='}'
  out+='}'
  echo "$out"
}

new_json="$(build_json)"

# ── --check mode ──────────────────────────────────────────────────────────────
if $MODE_CHECK; then
  if [[ ! -f "$INDEX_FILE" ]]; then
    echo "FAIL: $INDEX_FILE does not exist. Run without --check to generate." >&2
    exit 1
  fi
  existing="$(cat "$INDEX_FILE")"
  if [[ "$existing" == "$new_json" ]]; then
    echo "OK: skill-routing-index.json is up-to-date."
    exit 0
  else
    echo "FAIL: skill-routing-index.json is stale. Run without --check to regenerate." >&2
    exit 1
  fi
fi

# ── Write output ─────────────────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"
echo "$new_json" > "$INDEX_FILE"
echo "Generated: $INDEX_FILE" >&2

# Pretty-print to stdout
if command -v python3 &>/dev/null; then
  python3 -c "import json,sys; print(json.dumps(json.loads(sys.stdin.read()), indent=2))" < "$INDEX_FILE"
else
  cat "$INDEX_FILE"
fi
