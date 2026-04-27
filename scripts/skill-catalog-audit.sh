#!/usr/bin/env bash
# skill-catalog-audit.sh — SE-084 Slice 1.
#
# Static auditor over `.claude/skills/*/SKILL.md` enforcing the
# `mattpocock/skills/write-a-skill` discipline (MIT pattern, clean-room):
# - frontmatter with `name:` + `description:` required
# - description must contain a "Use when ..." trigger (or equivalent
#   "Activa cuando", "Trigger", "Use ... when") so the agent has
#   enough signal to pick the right skill
# - SKILL.md ≤ 100 LOC (warn) / ≤ 200 LOC (fail)
# - description ≥ 30 chars
#
# Modes:
#   skill-catalog-audit.sh                # --report (default)
#   skill-catalog-audit.sh --gate         # exit 1 on any fail-severity
#   skill-catalog-audit.sh --gate --skill PATH  # gate over a single skill (Slice 2 G14)
#   skill-catalog-audit.sh --baseline-write     # update .ci-baseline/skill-quality-violations.count
#   skill-catalog-audit.sh --json         # machine-readable JSON output
#
# Output TSV (default --report) goes to stdout AND to:
#   output/skill-catalog-audit-YYYYMMDD.tsv
#
# Columns: skill | issue | severity | line_count | description_preview
#
# Reference: SE-084 (`docs/propuestas/SE-084-skill-catalog-quality-audit.md`)
# Pattern source: `mattpocock/skills/write-a-skill/SKILL.md` (MIT, clean-room)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Allow the caller to override SKILLS_DIR for tests / dogfooding.
SKILLS_DIR="${SKILLS_DIR:-$ROOT_DIR/.claude/skills}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output}"
BASELINE_FILE="${BASELINE_FILE:-$ROOT_DIR/.ci-baseline/skill-quality-violations.count}"

WARN_LOC_THRESHOLD="${SKILL_AUDIT_WARN_LOC:-100}"
FAIL_LOC_THRESHOLD="${SKILL_AUDIT_FAIL_LOC:-200}"
DESC_MIN_CHARS="${SKILL_AUDIT_DESC_MIN_CHARS:-30}"

MODE="report"          # report | gate | baseline-write
JSON_OUT=0
SINGLE_SKILL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report)         MODE="report"; shift ;;
    --gate)           MODE="gate"; shift ;;
    --baseline-write) MODE="baseline-write"; shift ;;
    --json)           JSON_OUT=1; shift ;;
    --skill)          SINGLE_SKILL="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ── Helpers ─────────────────────────────────────────────────────────────────

# Extract a frontmatter field value (first occurrence). Empty if missing.
# Args: $1=file, $2=field
fm_field() {
  local file="$1" field="$2"
  awk -v field="$field" '
    BEGIN { in_fm=0; line=0 }
    /^---[[:space:]]*$/ {
      line++
      if (line==1) { in_fm=1; next }
      if (line==2) { exit }
    }
    in_fm && $0 ~ "^"field":" {
      sub("^"field":[[:space:]]*", "")
      gsub(/^"/, ""); gsub(/"$/, "")
      print
      exit
    }
  ' "$file"
}

# True (0) if file has frontmatter (opens with `---`).
has_frontmatter() {
  head -1 "$1" 2>/dev/null | grep -q '^---[[:space:]]*$'
}

# True (0) if `description` value contains a trigger phrase.
has_use_when() {
  local desc="$1"
  echo "$desc" | grep -qiE 'use when|activa cuando|trigger when|use .* when|invokes /|when .* says|when user'
}

# Truncate string to N chars adding ellipsis.
preview() {
  local s="$1" n="${2:-60}"
  if [ "${#s}" -gt "$n" ]; then
    echo "${s:0:$((n-3))}..."
  else
    echo "$s"
  fi
}

# Audit a single SKILL.md. Emits one TSV line per issue (or none).
# Args: $1 = path/to/SKILL.md
audit_one() {
  local file="$1"
  local skill_name
  skill_name=$(basename "$(dirname "$file")")

  if [ ! -f "$file" ]; then
    printf "%s\tmissing-skill-md\tFAIL\t0\t-\n" "$skill_name"
    return
  fi

  local lines
  lines=$(wc -l <"$file" | tr -d ' ')

  if ! has_frontmatter "$file"; then
    printf "%s\tmissing-frontmatter\tFAIL\t%s\t-\n" "$skill_name" "$lines"
    return
  fi

  local name desc
  name=$(fm_field "$file" "name")
  desc=$(fm_field "$file" "description")

  if [ -z "$name" ]; then
    printf "%s\tmissing-name-field\tFAIL\t%s\t-\n" "$skill_name" "$lines"
  fi

  if [ -z "$desc" ]; then
    printf "%s\tmissing-description-field\tFAIL\t%s\t-\n" "$skill_name" "$lines"
  else
    local desc_preview; desc_preview=$(preview "$desc" 60)
    if [ "${#desc}" -lt "$DESC_MIN_CHARS" ]; then
      printf "%s\tdescription-too-short\tFAIL\t%s\t%s\n" "$skill_name" "$lines" "$desc_preview"
    fi
    if ! has_use_when "$desc"; then
      printf "%s\tdescription-missing-use-when\tWARN\t%s\t%s\n" "$skill_name" "$lines" "$desc_preview"
    fi
  fi

  if [ "$lines" -gt "$FAIL_LOC_THRESHOLD" ]; then
    printf "%s\tskill-overlong\tFAIL\t%s\t-\n" "$skill_name" "$lines"
  elif [ "$lines" -gt "$WARN_LOC_THRESHOLD" ]; then
    printf "%s\tskill-long\tWARN\t%s\t-\n" "$skill_name" "$lines"
  fi
}

# ── Discover targets ────────────────────────────────────────────────────────

declare -a TARGETS
if [ -n "$SINGLE_SKILL" ]; then
  if [ -d "$SINGLE_SKILL" ]; then
    TARGETS+=("$SINGLE_SKILL/SKILL.md")
  elif [ -f "$SINGLE_SKILL" ]; then
    TARGETS+=("$SINGLE_SKILL")
  else
    echo "ERROR: --skill path not found: $SINGLE_SKILL" >&2; exit 2
  fi
else
  if [ ! -d "$SKILLS_DIR" ]; then
    echo "ERROR: skills dir not found: $SKILLS_DIR" >&2; exit 2
  fi
  while IFS= read -r d; do
    TARGETS+=("$d/SKILL.md")
  done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
fi

# ── Run audit ───────────────────────────────────────────────────────────────

mkdir -p "$OUTPUT_DIR"
TODAY=$(date +%Y%m%d)
TSV_FILE="$OUTPUT_DIR/skill-catalog-audit-$TODAY.tsv"

# Header
{
  printf "skill\tissue\tseverity\tline_count\tdescription_preview\n"
  for t in ${TARGETS[@]+"${TARGETS[@]}"}; do
    audit_one "$t"
  done
} > "$TSV_FILE"

WARN_COUNT=$(awk -F'\t' '$3=="WARN"' "$TSV_FILE" | wc -l | tr -d ' ')
FAIL_COUNT=$(awk -F'\t' '$3=="FAIL"' "$TSV_FILE" | wc -l | tr -d ' ')
SKILL_COUNT=0
if [ -n "${TARGETS+x}" ]; then SKILL_COUNT=${#TARGETS[@]}; fi

# ── Output ──────────────────────────────────────────────────────────────────

emit_summary_text() {
  echo "=== skill-catalog-audit (SE-084 Slice 1) ==="
  echo "  skills audited: $SKILL_COUNT"
  echo "  WARN: $WARN_COUNT (long ≤200 LOC, missing use-when)"
  echo "  FAIL: $FAIL_COUNT (overlong, missing frontmatter/name/description, description-too-short)"
  echo "  TSV: $TSV_FILE"
}

emit_summary_json() {
  printf '{"skill_count":%s,"warn":%s,"fail":%s,"tsv":"%s"}\n' \
    "$SKILL_COUNT" "$WARN_COUNT" "$FAIL_COUNT" "$TSV_FILE"
}

case "$MODE" in
  report)
    if [ "$JSON_OUT" -eq 1 ]; then
      emit_summary_json
    else
      emit_summary_text
      cat "$TSV_FILE"
    fi
    exit 0
    ;;
  gate)
    if [ "$JSON_OUT" -eq 1 ]; then emit_summary_json; else emit_summary_text; fi
    if [ "$FAIL_COUNT" -gt 0 ]; then
      echo "GATE FAIL: $FAIL_COUNT fail-severity issues — fix or override before merge" >&2
      awk -F'\t' '$3=="FAIL"' "$TSV_FILE" | head -20 >&2
      exit 1
    fi
    exit 0
    ;;
  baseline-write)
    mkdir -p "$(dirname "$BASELINE_FILE")"
    TOTAL=$((WARN_COUNT + FAIL_COUNT))
    echo "$TOTAL" > "$BASELINE_FILE"
    echo "baseline written: $BASELINE_FILE = $TOTAL (warn=$WARN_COUNT fail=$FAIL_COUNT)"
    exit 0
    ;;
esac
