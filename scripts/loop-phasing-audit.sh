#!/usr/bin/env bash
# loop-phasing-audit.sh — Audita el nivel loop_level declarado vs inferido
# de skills autónomas en pm-workspace.
#
# Uso:
#   bash scripts/loop-phasing-audit.sh                   # todos los skills
#   bash scripts/loop-phasing-audit.sh --skill <nombre>  # skill específico
#   bash scripts/loop-phasing-audit.sh --json            # output JSON
#
# Exit: 0 siempre (informativo)
# Ref: docs/rules/domain/loop-phasing.md (SE-228)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.opencode/skills"
OUTPUT_DIR="$REPO_ROOT/output"

# ── Parse args ────────────────────────────────────────────────────────────────
SKILL_FILTER=""
JSON_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)
      SKILL_FILTER="$2"
      shift 2
      ;;
    --json)
      JSON_MODE=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# ── Helper: read loop_level from SKILL.md frontmatter ─────────────────────────
read_declared_level() {
  local skill_md="$1"
  local level
  level=$(grep -m1 '^loop_level:' "$skill_md" 2>/dev/null | \
    sed 's/loop_level:[[:space:]]*//' | \
    sed 's/#.*//' | \
    tr -d '[:space:]"' || true)
  if [[ -z "$level" ]]; then
    echo "L0"
  else
    echo "$level"
  fi
}

# ── Helper: infer level from filesystem evidence ──────────────────────────────
infer_level() {
  local skill_name="$1"
  local skill_md="$2"
  local inferred="L0"

  local state_dir="$OUTPUT_DIR/loop-state/$skill_name"
  local runlog_dir="$OUTPUT_DIR/loop-run-log/$skill_name"

  if [[ -f "$state_dir/STATE.md" ]] || { [[ -d "$runlog_dir" ]] && [[ -n "$(ls -A "$runlog_dir" 2>/dev/null)" ]]; }; then
    inferred="L1"
  fi

  local budget_dir="$OUTPUT_DIR/loop-budget/$skill_name"
  local has_maker_checker=false
  local has_budget=false

  if grep -q "maker-checker-protocol" "$skill_md" 2>/dev/null; then
    has_maker_checker=true
  fi

  if [[ -d "$budget_dir" ]] && [[ -n "$(ls -A "$budget_dir" 2>/dev/null)" ]]; then
    has_budget=true
  fi

  if [[ "$inferred" == "L1" ]] && $has_maker_checker && $has_budget; then
    inferred="L2"
  fi

  echo "$inferred"
}

# ── Helper: compute gap ───────────────────────────────────────────────────────
compute_gap() {
  local declared="$1"
  local inferred="$2"
  local d_num i_num
  case "$declared" in L0) d_num=0;; L1) d_num=1;; L2) d_num=2;; L3) d_num=3;; *) d_num=0;; esac
  case "$inferred" in L0) i_num=0;; L1) i_num=1;; L2) i_num=2;; L3) i_num=3;; *) i_num=0;; esac

  if [[ $d_num -eq $i_num ]]; then echo "OK"
  elif [[ $d_num -gt $i_num ]]; then echo "OVER"
  else echo "UNDER"
  fi
}

# ── Collect candidate SKILL.md paths (-L follows symlinks) ───────────────────
declare -a candidate_mds=()

if [[ -n "$SKILL_FILTER" ]]; then
  if [[ -d "$SKILLS_DIR/$SKILL_FILTER" ]]; then
    candidate_mds=("$SKILLS_DIR/$SKILL_FILTER/SKILL.md")
  else
    echo "ERROR: skill '$SKILL_FILTER' not found in $SKILLS_DIR" >&2
    exit 0
  fi
else
  mapfile -d '' candidate_mds < <(find -L "$SKILLS_DIR" -name "SKILL.md" -print0 2>/dev/null | sort -z)
fi

# ── Collect results ───────────────────────────────────────────────────────────
declare -a rows=()
declare -a json_rows=()

for skill_md in "${candidate_mds[@]}"; do
  [[ -f "$skill_md" ]] || continue

  # Only include skills with loop_level declared OR tagged autonomous
  if ! grep -qE '^loop_level:|"autonomous"' "$skill_md" 2>/dev/null; then
    continue
  fi

  skill_name="$(basename "$(dirname "$skill_md")")"
  declared=$(read_declared_level "$skill_md")
  inferred=$(infer_level "$skill_name" "$skill_md")
  gap=$(compute_gap "$declared" "$inferred")

  rows+=("$skill_name|$declared|$inferred|$gap")
  json_rows+=("{\"skill\":\"$skill_name\",\"declared\":\"$declared\",\"inferred\":\"$inferred\",\"gap\":\"$gap\"}")
done

# ── Output ─────────────────────────────────────────────────────────────────────
if $JSON_MODE; then
  echo "["
  count=${#json_rows[@]}
  for i in "${!json_rows[@]}"; do
    if [[ $i -lt $((count - 1)) ]]; then
      echo "  ${json_rows[$i]},"
    else
      echo "  ${json_rows[$i]}"
    fi
  done
  echo "]"
else
  printf "%-35s %-12s %-12s %-6s\n" "skill" "declared" "inferred" "gap"
  printf "%-35s %-12s %-12s %-6s\n" \
    "$(printf '%35s' | tr ' ' '-')" \
    "$(printf '%12s' | tr ' ' '-')" \
    "$(printf '%12s' | tr ' ' '-')" \
    "------"

  for row in "${rows[@]}"; do
    IFS='|' read -r s_name s_declared s_inferred s_gap <<< "$row"
    printf "%-35s %-12s %-12s %-6s\n" "$s_name" "$s_declared" "$s_inferred" "$s_gap"
  done

  if [[ ${#rows[@]} -eq 0 ]]; then
    echo "(no autonomous skills found)"
  fi
fi

exit 0
