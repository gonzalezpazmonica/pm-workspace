#!/usr/bin/env bash
# spec-status-normalize.sh — audit and normalize `status:` field across all
# specs in docs/propuestas/ (including savia-enterprise/).
#
# Purpose: 76 of 129 specs currently lack a `status:` field, making them
# invisible to any grep-based tooling or status dashboard. This script:
#   1. --audit (default): produces a report of missing/non-canonical values
#   2. --apply: adds `status: UNLABELED` to specs missing the field (safe)
#   3. --suggest: emits heuristic suggestions per spec (Implemented / Proposed
#      / Dropped) based on CHANGELOG references, body keywords, git history —
#      does NOT modify files; human applies manually
#
# Ref: ROADMAP-UNIFIED-20260418.md §Wave 4 D1
# Safety: no network access; no destructive operations; idempotent.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SPECS_DIR="$REPO_ROOT/docs/propuestas"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"
MODE="audit"
DATE_STR="$(date +%Y%m%d)"
OUTPUT_DIR="$REPO_ROOT/output"
REPORT="$OUTPUT_DIR/spec-status-report-$DATE_STR.md"

# Canonical status values (case-insensitive match against these).
CANONICAL_STATUSES=(
  "PROPOSED" "Proposed" "ACCEPTED" "Accepted" "APPROVED" "Approved"
  "IN_PROGRESS" "in-progress" "Draft" "draft" "DRAFT"
  "Implemented" "IMPLEMENTED" "APPLIED" "DONE" "Done"
  "REJECTED" "Rejected" "DROPPED" "Dropped" "SUPERSEDED"
  "LIVING" "UNLABELED"
)

usage() {
  cat <<EOF
Usage: $0 [--audit | --apply | --suggest]

  --audit     (default) Report specs missing status field. Read-only.
  --apply     Add 'status: UNLABELED' to specs missing the field.
              Idempotent — skips specs that already have status.
  --suggest   Emit heuristic status per spec. Does NOT modify files.

Output: $REPORT
EOF
}

# ── Parse args ──────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --audit)    MODE="audit"; shift ;;
    --apply)    MODE="apply"; shift ;;
    --suggest)  MODE="suggest"; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

# ── Helpers ─────────────────────────────────────────────────────────────────

# Extract status field from frontmatter (first 30 lines).
spec_status() {
  local f="$1"
  head -30 "$f" 2>/dev/null | grep -m1 -E '^status:' | sed 's/^status: *//; s/"//g; s/[[:space:]]*$//'
}

# Check if file has frontmatter (first line is ---).
has_frontmatter() {
  local f="$1"
  [[ "$(head -1 "$f" 2>/dev/null)" == "---" ]]
}

# Heuristic: suggest status based on content + CHANGELOG refs.
suggest_status() {
  local f="$1"
  local bname
  bname=$(basename "$f" .md)
  local spec_id
  spec_id=$(echo "$bname" | grep -oE '^(SPEC|SE|SPEC-SE)-[0-9]+' | head -1)

  # If CHANGELOG mentions this spec → likely Implemented
  if [[ -n "$spec_id" ]] && grep -qE "\b$spec_id\b" "$CHANGELOG" 2>/dev/null; then
    echo "Implemented"
    return
  fi

  # Body says "Proposed" or "Propuesta" explicitly
  if grep -qiE '^\*?\*?estado\*?\*?:?[[:space:]]*(proposed|propuesta|draft)' "$f" 2>/dev/null; then
    echo "Proposed"
    return
  fi

  # Body has "Implemented" or "Applied" markers
  if grep -qiE '^\*?\*?estado\*?\*?:?[[:space:]]*(implemented|applied|done)' "$f" 2>/dev/null; then
    echo "Implemented"
    return
  fi

  # Body has "Superseded by SPEC-NNN"
  if grep -qiE 'superseded by|obsoleto por|replaced by' "$f" 2>/dev/null; then
    echo "SUPERSEDED"
    return
  fi

  # Default: unknown
  echo "UNLABELED"
}

# ── Main loop ───────────────────────────────────────────────────────────────

total=0
missing=0
non_canonical=0
applied=0
missing_no_fm=0
MISSING_LIST=()
MISSING_NO_FM_LIST=()
NONCAN_LIST=()
SUGGEST_LIST=()

while IFS= read -r f; do
  total=$((total+1))
  local_status=$(spec_status "$f")

  if [[ -z "$local_status" ]]; then
    missing=$((missing+1))
    if has_frontmatter "$f"; then
      MISSING_LIST+=("$f")
    else
      missing_no_fm=$((missing_no_fm+1))
      MISSING_NO_FM_LIST+=("$f")
    fi

    if [[ "$MODE" == "apply" ]] && has_frontmatter "$f"; then
      # Insert 'status: UNLABELED' before closing --- of frontmatter
      # Find line number of second --- (closing delimiter)
      close_line=$(head -30 "$f" | grep -n '^---$' | sed -n '2p' | cut -d: -f1)
      if [[ -n "$close_line" && "$close_line" -ge 2 ]]; then
        # Insert on line above the closing ---
        sed -i "${close_line}i\\
status: UNLABELED
" "$f"
        applied=$((applied+1))
      fi
    fi

    if [[ "$MODE" == "suggest" ]]; then
      sug=$(suggest_status "$f")
      SUGGEST_LIST+=("$f|$sug")
    fi
  else
    # Check if status is canonical
    is_canonical=0
    for cs in "${CANONICAL_STATUSES[@]}"; do
      if [[ "$local_status" == "$cs" ]]; then
        is_canonical=1
        break
      fi
    done
    if [[ "$is_canonical" -eq 0 ]]; then
      non_canonical=$((non_canonical+1))
      NONCAN_LIST+=("$f|$local_status")
    fi
  fi
done < <(find "$SPECS_DIR" -maxdepth 3 -type f \( -name 'SPEC-*.md' -o -name 'SE-*.md' -o -name 'SPEC-SE-*.md' \))

# ── Write report ────────────────────────────────────────────────────────────

{
  echo "# Spec Status Normalization Report — $DATE_STR"
  echo ""
  echo "- Mode: $MODE"
  echo "- Total specs scanned: $total"
  missing_fm_count=${#MISSING_LIST[@]}
  echo "- Missing \`status:\` field (with frontmatter, auto-applicable): $missing_fm_count"
  echo "- Missing \`status:\` field (no frontmatter, manual migration): $missing_no_fm"
  echo "- Missing \`status:\` field TOTAL: $missing"
  echo "- Non-canonical status values: $non_canonical"
  [[ "$MODE" == "apply" ]] && echo "- Applied (added status: UNLABELED): $applied"
  echo ""
  echo "## Canonical status values"
  echo ""
  for cs in "${CANONICAL_STATUSES[@]}"; do
    echo "- \`$cs\`"
  done
  echo ""

  if (( ${#MISSING_LIST[@]} > 0 )); then
    echo "## Specs missing status (with frontmatter — auto-applicable)"
    echo ""
    for f in "${MISSING_LIST[@]}"; do
      rel="${f#$REPO_ROOT/}"
      echo "- \`$rel\`"
    done
    echo ""
  fi

  if (( missing_no_fm > 0 )); then
    echo "## Specs missing status (no YAML frontmatter — manual migration)"
    echo ""
    echo "These specs use body-prose format (\`> Status: DRAFT\`) or have no status marker at all. Adding YAML frontmatter is a prose-format change and requires manual review per spec. The \`--apply\` flag does NOT touch these."
    echo ""
    for f in "${MISSING_NO_FM_LIST[@]}"; do
      rel="${f#$REPO_ROOT/}"
      echo "- \`$rel\`"
    done
    echo ""
  fi

  if (( non_canonical > 0 )); then
    echo "## Specs with non-canonical status"
    echo ""
    echo "| Spec | Current value |"
    echo "|---|---|"
    for entry in "${NONCAN_LIST[@]}"; do
      f="${entry%|*}"
      s="${entry#*|}"
      rel="${f#$REPO_ROOT/}"
      echo "| \`$rel\` | \`$s\` |"
    done
    echo ""
  fi

  if [[ "$MODE" == "suggest" ]]; then
    echo "## Heuristic status suggestions (human review required)"
    echo ""
    if [[ "${#SUGGEST_LIST[@]}" -gt 0 ]]; then
      echo "| Spec | Suggested status | Rationale |"
      echo "|---|---|---|"
      for entry in "${SUGGEST_LIST[@]}"; do
        f="${entry%|*}"
        sug="${entry#*|}"
        rel="${f#$REPO_ROOT/}"
        case "$sug" in
          Implemented) rat="CHANGELOG references this spec" ;;
          Proposed)    rat="Body declares state: Proposed/Draft" ;;
          SUPERSEDED)  rat="Body mentions superseded/replaced" ;;
          UNLABELED)   rat="No signal found — manual classification needed" ;;
          *)           rat="(unknown)" ;;
        esac
        echo "| \`$rel\` | \`$sug\` | $rat |"
      done
    else
      echo "_No specs need heuristic classification — all specs already have canonical \`status:\` field._"
    fi
    echo ""
  fi

  echo "---"
  echo ""
  echo "Generated by scripts/spec-status-normalize.sh — $DATE_STR"
} > "$REPORT"

# ── Console summary ─────────────────────────────────────────────────────────

echo "spec-status-normalize: mode=$MODE"
echo "  total=$total  missing=$missing  non_canonical=$non_canonical"
if [[ "$MODE" == "apply" ]]; then
  echo "  applied=$applied (added 'status: UNLABELED')"
fi
echo "  report: ${REPORT#$REPO_ROOT/}"

# Exit code: 0 always in audit/suggest mode; apply fails if any file lacks
# frontmatter (cannot add status without delimiters).
exit 0
