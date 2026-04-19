#!/usr/bin/env bash
# dag-typing-validate.sh — SE-034 Slice 1 prototype validator.
#
# Reads skill frontmatter for declared `input:` and `output:` types. Given
# a DAG of skills (via `dag-plan` output or manual --upstream/--downstream),
# validates that downstream's `input:` is compatible with upstream's `output:`.
#
# Schema subset (inspired by Dify workflow nodes): types are string keys
# "text" | "json" | "markdown" | "yaml" | "binary" | "any".
# Compatibility: `any` accepts anything; same-type is direct match.
#
# Usage:
#   dag-typing-validate.sh --skills skill-a,skill-b    # validate pair
#   dag-typing-validate.sh --audit                      # scan all skills, report gaps
#   dag-typing-validate.sh --infer skill-a             # print declared I/O
#
# Ref: SE-034, ROADMAP.md §Tier 4.3
# Safety: `set -uo pipefail`. Read-only.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SKILLS_DIR="$REPO_ROOT/.claude/skills"
OUTPUT_DIR="$REPO_ROOT/output"
DATE_STR="$(date +%Y%m%d)"
REPORT="$OUTPUT_DIR/dag-typing-audit-$DATE_STR.md"

MODE=""
SKILLS_ARG=""
INFER_SKILL=""

usage() {
  cat <<EOF
Usage:
  $0 --skills SKILL_A,SKILL_B    Validate edge A→B
  $0 --audit                      Scan all skills, report which lack I/O typing
  $0 --infer SKILL                Print declared I/O for SKILL

Types: text | json | markdown | yaml | binary | any
Compatibility: same type direct, 'any' accepts anything.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skills) SKILLS_ARG="$2"; MODE="validate"; shift 2 ;;
    --audit) MODE="audit"; shift ;;
    --infer) INFER_SKILL="$2"; MODE="infer"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

[[ -z "$MODE" ]] && { usage; exit 2; }

mkdir -p "$OUTPUT_DIR"

# Read I/O declaration from skill's SKILL.md frontmatter.
# Recognizes: input: <type>, output: <type>, or multi-line block.
read_io() {
  local skill="$1"
  local file="$SKILLS_DIR/$skill/SKILL.md"
  if [[ ! -f "$file" ]]; then
    echo "__missing__|__missing__"
    return
  fi
  # Only parse first 30 lines (frontmatter area).
  local input output
  input=$(head -30 "$file" | grep -E '^input:' | head -1 | sed 's/^input:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')
  output=$(head -30 "$file" | grep -E '^output:' | head -1 | sed 's/^output:[[:space:]]*//' | tr -d '"' | tr -d "'" | awk '{print $1}')
  echo "${input:-__untyped__}|${output:-__untyped__}"
}

type_compatible() {
  local from="$1"
  local to="$2"
  [[ "$to" == "any" ]] && return 0
  [[ "$from" == "any" ]] && return 0
  [[ "$from" == "$to" ]] && return 0
  # markdown is a superset of text.
  [[ "$from" == "markdown" && "$to" == "text" ]] && return 0
  return 1
}

case "$MODE" in
  infer)
    io=$(read_io "$INFER_SKILL")
    in="${io%|*}"
    out="${io#*|}"
    echo "Skill: $INFER_SKILL"
    echo "  input:  $in"
    echo "  output: $out"
    ;;

  validate)
    a="${SKILLS_ARG%,*}"
    b="${SKILLS_ARG#*,}"
    if [[ "$a" == "$b" ]]; then
      echo "ERROR: need two distinct skills" >&2
      exit 2
    fi
    io_a=$(read_io "$a")
    io_b=$(read_io "$b")
    out_a="${io_a#*|}"
    in_b="${io_b%|*}"
    echo "Edge: $a → $b"
    echo "  $a output: $out_a"
    echo "  $b input:  $in_b"
    if [[ "$out_a" == "__untyped__" ]] || [[ "$in_b" == "__untyped__" ]]; then
      echo "  VERDICT: UNTYPED (either skill missing declaration) — advisory only"
      exit 0
    fi
    if type_compatible "$out_a" "$in_b"; then
      echo "  VERDICT: COMPATIBLE"
      exit 0
    else
      echo "  VERDICT: MISMATCH — $a outputs '$out_a' but $b expects '$in_b'"
      exit 1
    fi
    ;;

  audit)
    total=0
    typed=0
    untyped=0
    missing=0
    UNTYPED_LIST=()
    TYPED_LIST=()

    for dir in "$SKILLS_DIR"/*/; do
      [[ -d "$dir" ]] || continue
      skill=$(basename "$dir")
      [[ "$skill" == "_archived" ]] && continue
      total=$((total+1))
      io=$(read_io "$skill")
      in="${io%|*}"
      out="${io#*|}"
      if [[ "$in" == "__missing__" ]]; then
        missing=$((missing+1))
      elif [[ "$in" == "__untyped__" && "$out" == "__untyped__" ]]; then
        untyped=$((untyped+1))
        UNTYPED_LIST+=("$skill")
      else
        typed=$((typed+1))
        TYPED_LIST+=("$skill|$in|$out")
      fi
    done

    {
      echo "# DAG Typing Audit — $DATE_STR"
      echo ""
      echo "- Skills scanned: $total"
      echo "- Typed (input + output declared): $typed"
      echo "- Untyped (no I/O frontmatter): $untyped"
      echo "- Missing SKILL.md: $missing"
      echo ""
      pct=0
      [[ "$total" -gt 0 ]] && pct=$(( typed * 100 / total ))
      echo "Coverage: $pct% (target ≥ 40% para Slice 2 viability)"
      echo ""

      if (( typed > 0 )); then
        echo "## Typed skills"
        echo ""
        echo "| Skill | input | output |"
        echo "|---|---|---|"
        for entry in "${TYPED_LIST[@]}"; do
          IFS='|' read -r s in out <<< "$entry"
          echo "| \`$s\` | \`$in\` | \`$out\` |"
        done
        echo ""
      fi

      if (( untyped > 0 )); then
        echo "## Untyped skills (candidates for Slice 2 migration)"
        echo ""
        for s in "${UNTYPED_LIST[@]}"; do
          echo "- \`$s\`"
        done
        echo ""
      fi

      echo "## Interpretation"
      echo ""
      if (( pct >= 40 )); then
        echo "Coverage $pct% ≥ 40% target. SE-034 Slice 2 (validator integration in dag-plan) viable."
      else
        echo "Coverage $pct% < 40% target. SE-034 Slice 2 blocked; Slice 1 remediation needed: extend frontmatter of at least $(( total * 40 / 100 - typed )) additional skills."
      fi
      echo ""
      echo "---"
      echo "Generated by scripts/dag-typing-validate.sh --audit — $DATE_STR"
    } > "$REPORT"

    echo "dag-typing-validate: total=$total typed=$typed untyped=$untyped missing=$missing"
    echo "  coverage=${pct}%  report: ${REPORT#$REPO_ROOT/}"
    ;;
esac

exit 0
