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
SKILLS_DIR="$(cd -P "$ROOT/.opencode/skills" && pwd)"
OUTPUT_DIR="$ROOT/output"
DATE_STAMP="$(date +%Y%m%d)"

# ── Flags ────────────────────────────────────────────────────────────────────
MODE_JSON=false
FILTER_SKILL=""
FIX_REPORT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)        MODE_JSON=true ;;
    --skill)       shift; FILTER_SKILL="${1:-}" ;;
    --fix-report)  FIX_REPORT=true ;;
    --help|-h)
      sed -n '2,12p' "$0" | sed 's/^# //'
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
    has_name=$(awk '/^---/{p++} p==1 && /^name:/' "$skill_md" | wc -l)
    has_desc=$(awk '/^---/{p++} p==1 && /^description:/' "$skill_md" | wc -l)
    if [[ "$has_name" -eq 0 || "$has_desc" -eq 0 ]]; then
      status="FAIL"
      [[ "$has_name" -eq 0 ]] && reasons+=("SKILL.md: missing frontmatter 'name'")
      [[ "$has_desc" -eq 0 ]] && reasons+=("SKILL.md: missing frontmatter 'description'")
    fi

    # 4. SKILL.md <= 150 lines
    local skill_lines
    skill_lines=$(wc -l < "$skill_md")
    if [[ "$skill_lines" -gt 150 ]]; then
      [[ "$status" == "OK" ]] && status="WARN"
      reasons+=("SKILL.md: ${skill_lines} lines (max 150)")
    fi

    # 7. SKILL.md references at least one file path (contains /)
    if ! grep -qE '[a-zA-Z0-9_.\-]+/[a-zA-Z0-9_.\-]' "$skill_md"; then
      [[ "$status" == "OK" ]] && status="WARN"
      reasons+=("SKILL.md: no file path reference found")
    fi
  fi

  if [[ -f "$domain_md" ]]; then
    # 5. DOMAIN.md <= 60 lines
    local domain_lines
    domain_lines=$(wc -l < "$domain_md")
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
    local reason_json
    reason_json="${reason_str//\"/\\\"}"
    results_json+=("{\"skill\":\"$name\",\"status\":\"$status\",\"reason\":\"$reason_json\"}")
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
  [[ "$bname" == "_template" ]] && continue
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
