#!/usr/bin/env bash
# skill-catalog-auditor.sh — SE-084 Slice 1 — Skill catalog quality auditor
#
# For each skill in .opencode/skills/*/ checks:
#   1. SKILL.md exists
#   2. DOMAIN.md exists
#   3. SKILL.md has YAML frontmatter with `name` and `description`
#   4. SKILL.md has <= 150 lines
#   5. DOMAIN.md has <= 60 lines
#   6. DOMAIN.md is not empty (> 3 lines)
#   7. SKILL.md references at least one real file path (contains /)
#
# Severity: FAIL (exit 1) = missing SKILL.md/DOMAIN.md, empty name/description
# key, SKILL.md > 150 lines, DOMAIN.md <= 3 lines, empty body, malicious
# pattern, empty consumes/produces. WARN (exit 0) = SKILL.md > 100 lines,
# DOMAIN.md > 60 lines, no path reference, description < 20 or > 200 chars or
# without trigger word (SE-209).
# Full scan covers direct children of the skills dir and skips _template;
# an explicit --skill NAME audits that directory whatever its name.
#
# Usage:
#   bash scripts/skill-catalog-auditor.sh              # table output
#   bash scripts/skill-catalog-auditor.sh --json       # JSON array
#   bash scripts/skill-catalog-auditor.sh --skill NAME # single skill
#   bash scripts/skill-catalog-auditor.sh --fix-report # write output/skill-audit-report-YYYYMMDD.md
#
# Exit 0 if FAIL=0, exit 1 if FAIL>0

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Resolve symlink: .opencode/skills -> .claude/skills
# Allow override via SAVIA_SKILLS_DIR for testing
if [[ -n "${SAVIA_SKILLS_DIR:-}" ]]; then
  SKILLS_DIR="$SAVIA_SKILLS_DIR"
else
  SKILLS_DIR="$(cd -P "$ROOT/.opencode/skills" && pwd)"
fi
OUTPUT_DIR="$ROOT/output"
DATE_STAMP="$(date +%Y%m%d)"

# ── Flags ────────────────────────────────────────────────────────────────────
MODE_JSON=false
FILTER_SKILL=""
FIX_REPORT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)        MODE_JSON=true ;;
    --skill)
      shift
      if [[ $# -eq 0 || -z "$1" ]]; then
        echo "ERROR: --skill requires a skill name" >&2
        exit 2
      fi
      FILTER_SKILL="$1" ;;
    --fix-report)  FIX_REPORT=true ;;
    --help|-h)
      sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

# ── Counters ─────────────────────────────────────────────────────────────────
count_pass=0
count_warn=0
count_fail=0
count_total=0

# Storage for --json and --fix-report
results_json=()
results_table=()

# Lines in a file, counting a last line without trailing newline (wc -l does not).
count_lines() {
  awk 'END { print NR }' "$1"
}

# JSON string escaping for names and reasons (backslash first, then quotes).
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# Frontmatter description as plain text. Handles block scalars (>, >-, |, |-):
# the value is the indented lines that follow, joined with single spaces.
extract_description() {
  awk '
    /^---[[:space:]]*$/ { c++; if (c >= 2) exit; next }
    c == 1 {
      if (collecting) {
        if ($0 ~ /^[^[:space:]]/) exit
        line = $0
        sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)
        if (line != "") buf = (buf == "" ? line : buf " " line)
        next
      }
      if ($0 ~ /^description:/) {
        v = $0
        sub(/^description:[[:space:]]*/, "", v)
        if (v ~ /^[>|][-+0-9]*[[:space:]]*$/) { collecting = 1; next }
        print v
        exit
      }
    }
    END { if (collecting) print buf }
  ' "$1"
}

# ── SE-209: Check description format ─────────────────────────────────────────
# Returns: sets global _desc_warn_reasons (array) — caller merges into reasons
# Emits WARN if description < 20 chars or missing trigger keyword
check_description_format() {
  local skill_md="$1"
  _desc_warn_reasons=()

  local raw_desc
  raw_desc=$(extract_description "$skill_md")
  # Strip surrounding quotes (single or double)
  local desc="${raw_desc#[\"\']}"
  desc="${desc%[\"\']}"
  local desc_len="${#desc}"

  if [[ "$desc_len" -lt 20 ]]; then
    _desc_warn_reasons+=("SKILL.md: description < 20 chars (SE-209: too short to be useful)")
  fi

  # Characters, not bytes: under LC_ALL=C ${#desc} counts UTF-8 bytes.
  local desc_chars
  desc_chars=$(printf '%s' "$desc" | LC_ALL=C awk '{ n += gsub(/[^\200-\277]/, "") } END { print n + 0 }')
  if [[ "$desc_chars" -gt 200 ]]; then
    _desc_warn_reasons+=("SKILL.md: description ${desc_chars} chars > 200 (SE-209: keep routing keywords short)")
  fi

  # Whole words, any case: "User"/"house" are not triggers, "When" is.
  if ! printf '%s' "$desc" | grep -qiE '(^|[^[:alnum:]_])(when|cuando|usar|use)([^[:alnum:]_]|$)'; then
    _desc_warn_reasons+=("SKILL.md: description missing trigger keyword (SE-209: add when/cuando/Usar/Use)")
  fi
}

# ── Audit single skill dir ───────────────────────────────────────────────────
audit_skill() {
  local dir="$1"
  local name
  name="$(basename "$dir")"
  local skill_md="$dir/SKILL.md"
  local domain_md="$dir/DOMAIN.md"

  local status="OK"
  local reasons=()

  # 1. SKILL.md exists
  if [[ ! -f "$skill_md" ]]; then
    status="FAIL"
    reasons+=("SKILL.md missing")
  fi

  # 2. DOMAIN.md exists
  if [[ ! -f "$domain_md" ]]; then
    status="FAIL"
    reasons+=("DOMAIN.md missing")
  fi

  # Deeper checks require SKILL.md
  if [[ -f "$skill_md" ]]; then
    # 3. Frontmatter: `name` and `description`
    local has_name has_desc
    # name needs a value: "name:" alone leaves the skill without identity.
    has_name=$(awk '/^---/{p++} p==1 && /^name:[[:space:]]*[^[:space:]#]/' "$skill_md" | wc -l)
    has_desc=$(awk '/^---/{p++} p==1 && /^description:/' "$skill_md" | wc -l)
    if [[ "$has_name" -eq 0 || "$has_desc" -eq 0 ]]; then
      status="FAIL"
      [[ "$has_name" -eq 0 ]] && reasons+=("SKILL.md: missing frontmatter 'name'")
      [[ "$has_desc" -eq 0 ]] && reasons+=("SKILL.md: missing frontmatter 'description'")
    fi

    # 4. SKILL.md <= 150 lines
    local skill_lines
    skill_lines=$(count_lines "$skill_md")
    if [[ "$skill_lines" -gt 150 ]]; then
      [[ "$status" == "OK" ]] && status="FAIL"
      reasons+=("SKILL.md: ${skill_lines} lines > 150 (hard limit exceeded)")
    fi

    # SE-208: WARN if SKILL.md > 100 lines (progressive disclosure recommended)
    if [[ "$skill_lines" -gt 100 && "$skill_lines" -le 150 ]]; then
      [[ "$status" == "OK" ]] && status="WARN"
      reasons+=("SKILL.md: ${skill_lines} lines > 100 (SE-208: progressive disclosure recommended)")
    fi

    # 7. SKILL.md references at least one file path (contains /)
    if ! grep -qE '[a-zA-Z0-9_.\-]+/[a-zA-Z0-9_.\-]' "$skill_md"; then
      [[ "$status" == "OK" ]] && status="WARN"
      reasons+=("SKILL.md: no file path reference found")
    fi

    # SE-152: If consumes: or produces: present, values must be non-empty lists
    # SE-333: canonical form is metadata.savia.consumes/produces (comma string)
    local fm_block=""
    local in_fm=false
    local se152_line_num=0
    while IFS= read -r se152_line; do
      se152_line_num=$((se152_line_num + 1))
      if [[ $se152_line_num -eq 1 && "$se152_line" == "---" ]]; then in_fm=true; continue; fi
      if $in_fm && [[ "$se152_line" == "---" ]]; then break; fi
      $in_fm && fm_block="${fm_block}${se152_line}"$'\n'
      [[ $se152_line_num -gt 40 ]] && break
    done < "$skill_md"

    if echo "$fm_block" | grep -qE '^(consumes:|[[:space:]]*savia\.consumes:)'; then
      if echo "$fm_block" | grep -qE '^(consumes:[[:space:]]*\[\]|consumes:[[:space:]]*"")'; then
        status="FAIL"
        reasons+=("SKILL.md: consumes is empty array []")
      fi
      if echo "$fm_block" | grep -qE '^[[:space:]]*savia\.consumes:[[:space:]]*""'; then
        status="FAIL"
        reasons+=("SKILL.md: savia.consumes is empty string")
      fi
    fi

    if echo "$fm_block" | grep -qE '^(produces:|[[:space:]]*savia\.produces:)'; then
      if echo "$fm_block" | grep -qE '^(produces:[[:space:]]*\[\]|produces:[[:space:]]*"")'; then
        status="FAIL"
        reasons+=("SKILL.md: produces is empty array []")
      fi
      if echo "$fm_block" | grep -qE '^[[:space:]]*savia\.produces:[[:space:]]*""'; then
        status="FAIL"
        reasons+=("SKILL.md: savia.produces is empty string")
      fi
    fi

    # ASM-1: SKILL.md body must have meaningful content (>= 20 chars outside frontmatter)
    local body_content
    body_content=$(awk '/^---$/{p++; next} p>=2' "$skill_md" | tr -d '[:space:]')
    if [[ ${#body_content} -lt 20 ]]; then
      status="FAIL"
      reasons+=("SKILL.md: body too short (< 20 non-whitespace chars)")
    fi

    # ASM-2: SKILL.md must not contain malicious patterns (atob, base64 decode, hex escapes, hardcoded secrets)
    if grep -qE '(atob\(|btoa\(|Buffer\.from\([^,]+,\s*['"'"'"]base64['"'"'"]|\\x[0-9a-fA-F]{2}\\x[0-9a-fA-F]{2}\\x|password\s*=\s*['"'"'"][^'"'"'"]{6,}|api_key\s*=\s*['"'"'"][^'"'"'"]{10,}|secret\s*=\s*['"'"'"][^'"'"'"]{10,})' "$skill_md" 2>/dev/null; then
      status="FAIL"
      reasons+=("SKILL.md: contains potentially malicious pattern (atob/base64-decode/hex-escape/hardcoded-secret)")
    fi

    # SE-209: description format check
    check_description_format "$skill_md"
    for _r in "${_desc_warn_reasons[@]}"; do
      [[ "$status" == "OK" ]] && status="WARN"
      reasons+=("$_r")
    done
  fi

  if [[ -f "$domain_md" ]]; then
    # 5. DOMAIN.md <= 60 lines
    local domain_lines
    domain_lines=$(count_lines "$domain_md")
    if [[ "$domain_lines" -gt 60 ]]; then
      [[ "$status" == "OK" ]] && status="WARN"
      reasons+=("DOMAIN.md: ${domain_lines} lines (max 60)")
    fi

    # 6. DOMAIN.md not empty (> 3 lines)
    if [[ "$domain_lines" -le 3 ]]; then
      status="FAIL"
      reasons+=("DOMAIN.md: empty or too short (${domain_lines} lines, min 4)")
    fi
  fi

  local reason_str
  if [[ ${#reasons[@]} -gt 0 ]]; then
    # join with semicolons
    local IFS_save="$IFS"
    IFS="; "
    reason_str="${reasons[*]}"
    IFS="$IFS_save"
  else
    reason_str="-"
  fi

  count_total=$((count_total + 1))
  case "$status" in
    OK)   count_pass=$((count_pass + 1)) ;;
    WARN) count_warn=$((count_warn + 1)) ;;
    FAIL) count_fail=$((count_fail + 1)) ;;
  esac

  if $MODE_JSON; then
    results_json+=("{\"skill\":\"$(json_escape "$name")\",\"status\":\"$status\",\"reason\":\"$(json_escape "$reason_str")\"}")
  else
    printf "%-42s  %-6s  %s\n" "$name" "$status" "$reason_str"
    if $FIX_REPORT; then
      results_table+=("| $name | $status | $reason_str |")
    fi
  fi
}

# ── Build skill list ─────────────────────────────────────────────────────────
if [[ -n "$FILTER_SKILL" ]]; then
  target_dir="$SKILLS_DIR/$FILTER_SKILL"
  if [[ ! -d "$target_dir" ]]; then
    echo "FAIL: skill '${FILTER_SKILL}' not found in ${SKILLS_DIR}" >&2
    exit 1
  fi
  skill_dirs=("$target_dir")
else
  mapfile -t skill_dirs < <(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d | sort)
fi

# ── Run audit ────────────────────────────────────────────────────────────────
if ! $MODE_JSON; then
  printf "%-42s  %-6s  %s\n" "SKILL" "STATUS" "REASON"
  printf '%0.s-' {1..80}
  echo
fi

for dir in "${skill_dirs[@]}"; do
  bname="$(basename "$dir")"
  [[ -z "$FILTER_SKILL" && "$bname" == "_template" ]] && continue
  audit_skill "$dir"
done

# ── Summary ──────────────────────────────────────────────────────────────────
summary="PASS: ${count_pass} | WARN: ${count_warn} | FAIL: ${count_fail} | TOTAL: ${count_total}"

if $MODE_JSON; then
  echo "["
  for i in "${!results_json[@]}"; do
    if [[ $i -lt $((${#results_json[@]} - 1)) ]]; then
      echo "  ${results_json[$i]},"
    else
      echo "  ${results_json[$i]}"
    fi
  done
  echo "]"
  echo "$summary" >&2
else
  printf '%0.s-' {1..80}
  echo
  echo "$summary"
fi

# ── Fix report ───────────────────────────────────────────────────────────────
if $FIX_REPORT; then
  mkdir -p "$OUTPUT_DIR"
  report_file="${OUTPUT_DIR}/skill-audit-report-${DATE_STAMP}.md"
  {
    echo "# Skill Catalog Audit Report — ${DATE_STAMP}"
    echo ""
    echo "## Summary"
    echo ""
    echo "$summary"
    echo ""
    echo "## Results"
    echo ""
    echo "| Skill | Status | Reason |"
    echo "|---|---|---|"
    for row in "${results_table[@]}"; do
      echo "$row"
    done
  } > "$report_file"
  echo "Report written: $report_file" >&2
fi

# ── Exit code ─────────────────────────────────────────────────────────────────
[[ "$count_fail" -eq 0 ]] && exit 0 || exit 1
