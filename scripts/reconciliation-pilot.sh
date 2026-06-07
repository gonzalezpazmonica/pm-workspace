#!/usr/bin/env bash
# reconciliation-pilot.sh — SPEC-183 Slice 4: run reconciler pilot on pm-workspace docs
# Ref: docs/propuestas/SPEC-183-reconciliation-3bucket.md
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TODAY="$(date +%Y%m%d)"
OUTPUT_DIR="$WORKSPACE_ROOT/output"
OUTPUT_FILE="$OUTPUT_DIR/reconciliation-pilot-${TODAY}.md"
STATS_SCRIPT="$SCRIPT_DIR/reconciliation-stats.sh"

DRY_RUN=false
STATS_ONLY=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Scans pm-workspace docs for potential term contradictions and classifies
them into 3 reconciliation buckets: evolution / auto-resolve / conflict-doc.

Sources scanned:
  1. docs/rules/domain/*.md
  2. .claude/skills/*/SKILL.md
  3. docs/propuestas/*.md

Outputs: output/reconciliation-pilot-YYYYMMDD.md

Options:
  --dry-run   Print report to stdout, do not create output file
  --stats     Show metrics only (counts per bucket), no details
  --help      Show this help
EOF
  exit 0
}

for arg in "$@"; do
  case "$arg" in
    --dry-run)  DRY_RUN=true ;;
    --stats)    STATS_ONLY=true ;;
    --help|-h)  usage ;;
    *) echo "ERROR: unknown option: $arg" >&2; exit 1 ;;
  esac
done

# ── Term extraction helpers ───────────────────────────────────────────────────

# Extract definition lines: lines matching "^- **term**" or "^**term**:" or
# "^### term" followed by a definition (heuristic for glossary/decision docs)
_extract_definitions() {
  local file="$1"
  # Extract terms defined via bold headers or level-3 headers
  grep -nE '^\*\*[A-Za-z][A-Za-z0-9 _-]{2,40}\*\*[: ]|^### [A-Za-z][A-Za-z0-9 _-]{2,40}$' "$file" 2>/dev/null \
    | sed "s|^|${file}:|" || true
}

# Normalise a term: lowercase, collapse spaces/dashes/underscores
_norm() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -s ' _-' ' ' | sed 's/[*#:]//g' | xargs
}

# ── Scan sources ─────────────────────────────────────────────────────────────

declare -A TERM_FILES   # term_norm -> "file1 file2 ..."
declare -A TERM_RAW     # term_norm -> first raw form

scan_source() {
  local dir="$1"
  local glob_pattern="${2:-*.md}"

  if [[ ! -d "$dir" ]]; then
    return 0
  fi

  while IFS= read -r -d '' file; do
    while IFS= read -r line; do
      # Extract term from match
      raw_term="$(echo "$line" | sed -E 's/^[^:]+:[0-9]+://;
        s/^\*\*([A-Za-z][A-Za-z0-9 _-]*)\*\*.*$/\1/;
        s/^### ([A-Za-z][A-Za-z0-9 _-]*)$/\1/;
        s/[*#]//g' | xargs)"
      [[ -z "$raw_term" ]] && continue

      norm="$(_norm "$raw_term")"
      [[ -z "$norm" ]] && continue

      src_file="${line%%:*}"

      if [[ -n "${TERM_FILES[$norm]+x}" ]]; then
        # Already seen — add file if not duplicate
        if [[ "${TERM_FILES[$norm]}" != *"$src_file"* ]]; then
          TERM_FILES[$norm]="${TERM_FILES[$norm]} $src_file"
        fi
      else
        TERM_FILES[$norm]="$src_file"
        TERM_RAW[$norm]="$raw_term"
      fi
    done < <(_extract_definitions "$file")
  done < <(find "$dir" -name "$glob_pattern" -type f -print0 2>/dev/null)
}

# Scan the three sources
scan_source "$WORKSPACE_ROOT/docs/rules/domain"
scan_source "$WORKSPACE_ROOT/.claude/skills" "SKILL.md"
scan_source "$WORKSPACE_ROOT/docs/propuestas"

# ── Classify contradictions ───────────────────────────────────────────────────

COUNT_EVOLUTION=0
COUNT_AUTO=0
COUNT_CONFLICT=0
COUNT_TOTAL=0

declare -a REPORT_LINES_EVOLUTION
declare -a REPORT_LINES_AUTO
declare -a REPORT_LINES_CONFLICT

classify_entry() {
  local norm="$1"
  local raw="$2"
  local files_str="$3"

  # Count distinct files
  read -ra files_arr <<< "$files_str"
  local n="${#files_arr[@]}"
  [[ "$n" -lt 2 ]] && return   # Only one file → no contradiction

  COUNT_TOTAL=$((COUNT_TOTAL + 1))

  # ── Bucket classification heuristic ──────────────────────────────────────
  # 1. Evolution: if files include a propuestas/ spec and a rules/ doc
  #    (spec supersedes rule = temporal coherent change)
  local has_spec=false
  local has_rule=false
  local has_skill=false
  local newest_file=""
  local newest_ts=0

  for f in "${files_arr[@]}"; do
    [[ "$f" == *"/propuestas/"* ]] && has_spec=true
    [[ "$f" == *"/rules/"* ]] && has_rule=true
    [[ "$f" == *"/skills/"* ]] && has_skill=true
    # Get modification time for recency comparison
    ts="$(stat -c '%Y' "$f" 2>/dev/null || echo 0)"
    if [[ "$ts" -gt "$newest_ts" ]]; then
      newest_ts="$ts"
      newest_file="$f"
    fi
  done

  local bucket
  if [[ "$has_spec" == "true" && ("$has_rule" == "true" || "$has_skill" == "true") ]]; then
    # Spec defines newer version of a rule/skill term → evolution
    bucket="evolution"
    COUNT_EVOLUTION=$((COUNT_EVOLUTION + 1))
    REPORT_LINES_EVOLUTION+=("| \`$raw\` | $files_str | spec supersedes rule/skill |")
  elif [[ "$has_rule" == "true" && "$has_skill" == "true" ]]; then
    # Rule vs skill — rule is more authoritative → auto-resolve (rule wins)
    bucket="auto-resolve"
    COUNT_AUTO=$((COUNT_AUTO + 1))
    REPORT_LINES_AUTO+=("| \`$raw\` | $files_str | rule > skill (authority) |")
  else
    # Ambiguous — same tier collision → conflict-doc
    bucket="conflict-doc"
    COUNT_CONFLICT=$((COUNT_CONFLICT + 1))
    REPORT_LINES_CONFLICT+=("| \`$raw\` | $files_str | same tier ambiguous |")
  fi

  # Log to stats
  if [[ "$DRY_RUN" == "false" ]] && [[ -x "$STATS_SCRIPT" ]]; then
    bash "$STATS_SCRIPT" --bucket "$bucket" --file "${files_arr[0]}" \
      --source "reconciliation-pilot-${TODAY}" --confidence 0.6 2>/dev/null || true
  fi
}

# Classify each multi-file term
for norm in "${!TERM_FILES[@]}"; do
  classify_entry "$norm" "${TERM_RAW[$norm]}" "${TERM_FILES[$norm]}"
done

# ── Build report ──────────────────────────────────────────────────────────────

build_report() {
  cat <<REPORT
---
generated_by: reconciliation-pilot.sh
date: $(date -u +%Y-%m-%d)
spec: SPEC-183
---

# Reconciliation Pilot — pm-workspace (${TODAY})

## Summary

| Bucket | Count | % |
|---|---|---|
| evolution | ${COUNT_EVOLUTION} | $(python3 -c "print(f'{${COUNT_EVOLUTION}/${COUNT_TOTAL}*100:.1f}%')" 2>/dev/null || echo "n/a") |
| auto-resolve | ${COUNT_AUTO} | $(python3 -c "print(f'{${COUNT_AUTO}/${COUNT_TOTAL}*100:.1f}%')" 2>/dev/null || echo "n/a") |
| conflict-doc | ${COUNT_CONFLICT} | $(python3 -c "print(f'{${COUNT_CONFLICT}/${COUNT_TOTAL}*100:.1f}%')" 2>/dev/null || echo "n/a") |
| **total** | **${COUNT_TOTAL}** | |

## Evolution (temporal-coherent change)

| Term | Files | Rationale |
|---|---|---|
REPORT

  for line in "${REPORT_LINES_EVOLUTION[@]+"${REPORT_LINES_EVOLUTION[@]}"}"; do
    echo "$line"
  done
  [[ "${#REPORT_LINES_EVOLUTION[@]}" -eq 0 ]] && echo "_(none detected)_"

  cat <<REPORT2

## Auto-resolve (clear winner — rule > skill authority)

| Term | Files | Rationale |
|---|---|---|
REPORT2

  for line in "${REPORT_LINES_AUTO[@]+"${REPORT_LINES_AUTO[@]}"}"; do
    echo "$line"
  done
  [[ "${#REPORT_LINES_AUTO[@]}" -eq 0 ]] && echo "_(none detected)_"

  cat <<REPORT3

## Conflict-doc (ambiguous — requires human)

| Term | Files | Rationale |
|---|---|---|
REPORT3

  for line in "${REPORT_LINES_CONFLICT[@]+"${REPORT_LINES_CONFLICT[@]}"}"; do
    echo "$line"
  done
  [[ "${#REPORT_LINES_CONFLICT[@]}" -eq 0 ]] && echo "_(none detected)_"

  echo ""
  echo "---"
  echo "_Generated by \`scripts/reconciliation-pilot.sh\` — SPEC-183 Slice 4_"
}

# ── Stats-only mode ───────────────────────────────────────────────────────────

if [[ "$STATS_ONLY" == "true" ]]; then
  echo "Reconciliation pilot metrics:"
  echo "  total:          $COUNT_TOTAL"
  echo "  evolution:      $COUNT_EVOLUTION"
  echo "  auto-resolve:   $COUNT_AUTO"
  echo "  conflict-doc:   $COUNT_CONFLICT"
  exit 0
fi

# ── Output ────────────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == "true" ]]; then
  build_report
else
  mkdir -p "$OUTPUT_DIR"
  build_report > "$OUTPUT_FILE"
  echo "Report written: $OUTPUT_FILE"
  echo "  total=$COUNT_TOTAL auto=$COUNT_AUTO evolution=$COUNT_EVOLUTION conflict=$COUNT_CONFLICT"
fi

exit 0
