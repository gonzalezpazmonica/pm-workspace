#!/usr/bin/env bash
# doc-health-audit.sh — Documentation Health Auditor
# Ref: SPEC-SE-094-DOC-AUDIT
#
# Scans all .md files in docs/ and .opencode/skills/*/ for:
#   - Broken internal links
#   - Stale spec refs (SPEC-NNN / SE-NNN without matching file)
#   - TBD/TODO sections
#   - Orphan refs (ROADMAP mentions without docs/specs/ file)
#
# Usage: bash scripts/doc-health-audit.sh [--json]
# Exit:  0 if score >= 70, 1 if score < 70
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
JSON_MODE=false

for arg in "${@:-}"; do
  case "$arg" in
    --json) JSON_MODE=true ;;
    --help)
      echo "Usage: doc-health-audit.sh [--json]"
      echo "  --json   Output results as JSON"
      exit 0
      ;;
  esac
done

# ── Collect scan targets ──────────────────────────────────────────────────────

mapfile -t MD_FILES < <(
  find "$ROOT/docs" -name "*.md" 2>/dev/null
  find "$ROOT/.opencode/skills" -name "*.md" 2>/dev/null
)

BROKEN_LINKS=0
STALE_REFS=0
TBD_COUNT=0
ORPHAN_REFS=0

SPECS_DIR="$ROOT/docs/specs"

# ── REQ-01a: Broken internal links ───────────────────────────────────────────
# Match ](./path) and ](../path) — relative links only
# grep extracts the raw link destinations, sed strips wrapper chars

for md in "${MD_FILES[@]}"; do
  [[ -f "$md" ]] || continue
  dir="$(dirname "$md")"

  # Extract all relative link targets from the file
  link_targets=$(grep -oE '\]\(\.[^)]+\)' "$md" 2>/dev/null | sed 's/^](//' | sed 's/)$//' || true)
  [[ -z "$link_targets" ]] && continue

  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    # Strip anchor fragment
    target="${target%%#*}"
    target="${target%% }"
    target="${target## }"
    [[ -z "$target" ]] && continue
    resolved="$dir/$target"
    if [[ ! -e "$resolved" ]]; then
      BROKEN_LINKS=$((BROKEN_LINKS + 1))
    fi
  done <<< "$link_targets"
done

# ── REQ-01b: Stale spec refs ─────────────────────────────────────────────────
# Mentions of SPEC-NNN or SE-NNN where docs/specs/SPEC-NNN*.md does not exist

# ── REQ-01b: Stale spec refs ─────────────────────────────────────────────────
# Mentions of SPEC-NNN where docs/specs/SPEC-NNN*.md does not exist
# Count unique refs (not per-mention) to avoid inflating score

declare -A seen_stale_refs

for md in "${MD_FILES[@]}"; do
  [[ -f "$md" ]] || continue
  # Skip the spec files themselves to avoid self-referential false positives
  [[ "$md" == "$SPECS_DIR"* ]] && continue

  # SPEC-WORD refs (e.g. SPEC-127, SPEC-SE-094-DOC-AUDIT)
  spec_refs=$(grep -oE 'SPEC-[A-Z0-9-]+' "$md" 2>/dev/null | sort -u || true)
  if [[ -n "$spec_refs" ]]; then
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      ref=$(echo "$ref" | tr -d '.,;:)"')
      [[ -z "$ref" ]] && continue
      # Skip if already counted
      [[ -n "${seen_stale_refs[$ref]+x}" ]] && continue
      matches=$(ls "$SPECS_DIR"/${ref}*.md 2>/dev/null | wc -l)
      if [[ "$matches" -eq 0 ]]; then
        STALE_REFS=$((STALE_REFS + 1))
        seen_stale_refs[$ref]=1
      fi
    done <<< "$spec_refs"
  fi

  # SPEC-SE-NNN-NAME refs that don't have a spec file
  spec_se_refs=$(grep -oE 'SPEC-SE-[0-9]+-[A-Z0-9-]+' "$md" 2>/dev/null | sort -u || true)
  if [[ -n "$spec_se_refs" ]]; then
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      ref=$(echo "$ref" | tr -d '.,;:)"')
      [[ -z "$ref" ]] && continue
      [[ -n "${seen_stale_refs[$ref]+x}" ]] && continue
      matches=$(ls "$SPECS_DIR"/${ref}*.md 2>/dev/null | wc -l)
      if [[ "$matches" -eq 0 ]]; then
        STALE_REFS=$((STALE_REFS + 1))
        seen_stale_refs[$ref]=1
      fi
    done <<< "$spec_se_refs"
  fi
done

# ── REQ-01c: TBD/TODO sections ───────────────────────────────────────────────

for md in "${MD_FILES[@]}"; do
  [[ -f "$md" ]] || continue
  count=$(grep -ciE '\b(TODO|TBD)\b' "$md" 2>/dev/null || true)
  TBD_COUNT=$((TBD_COUNT + count))
done

# ── REQ-01d: Orphan refs in ROADMAP ──────────────────────────────────────────
# IDs mentioned in ROADMAP that have no file in docs/specs/

ROADMAP="$ROOT/docs/ROADMAP.md"
if [[ -f "$ROADMAP" ]]; then
  roadmap_refs=$(grep -oE '(SPEC-SE-[0-9]+-[A-Z-]+|SPEC-[A-Z0-9-]+|SE-[0-9]+)' "$ROADMAP" 2>/dev/null | sort -u || true)
  if [[ -n "$roadmap_refs" ]]; then
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      ref=$(echo "$ref" | tr -d '.,;:)"')
      [[ -z "$ref" ]] && continue
      matches=$(ls "$SPECS_DIR"/${ref}*.md 2>/dev/null | wc -l)
      if [[ "$matches" -eq 0 ]]; then
        ORPHAN_REFS=$((ORPHAN_REFS + 1))
      fi
    done <<< "$roadmap_refs"
  fi
fi

# ── REQ-02: Score calculation ─────────────────────────────────────────────────
# Penalty weights (unique-ref based):
# HIGH:   broken links  = 10 pts each (cap 30)
# HIGH:   orphan refs   =  1 pt  each (cap 20)  -- expected: many historical
# MEDIUM: stale refs    =  1 pt  each (cap 20)  -- unique only, many are historical
# LOW:    TBD/TODO      =  1 pt  each (cap 10)

PENALTY_BROKEN=$(( BROKEN_LINKS * 10 ))
PENALTY_ORPHAN=$(( ORPHAN_REFS  *  1 ))
PENALTY_STALE=$((  STALE_REFS   *  1 ))
PENALTY_TBD=$((    TBD_COUNT    *  1 ))

[[ $PENALTY_BROKEN -gt 30 ]] && PENALTY_BROKEN=30
[[ $PENALTY_ORPHAN -gt 20 ]] && PENALTY_ORPHAN=20
[[ $PENALTY_STALE  -gt 20 ]] && PENALTY_STALE=20
[[ $PENALTY_TBD    -gt 10 ]] && PENALTY_TBD=10

TOTAL_PENALTY=$(( PENALTY_BROKEN + PENALTY_ORPHAN + PENALTY_STALE + PENALTY_TBD ))
SCORE=$(( 100 - TOTAL_PENALTY ))
[[ $SCORE -lt 0 ]] && SCORE=0

# ── REQ-05: JSON output ───────────────────────────────────────────────────────

if $JSON_MODE; then
  PASS_STR="false"
  [[ "$SCORE" -ge 70 ]] && PASS_STR="true"
  printf '{\n'
  printf '  "score": %d,\n' "$SCORE"
  printf '  "broken_links": {"count": %d, "severity": "HIGH"},\n'   "$BROKEN_LINKS"
  printf '  "stale_refs":   {"count": %d, "severity": "MEDIUM"},\n' "$STALE_REFS"
  printf '  "tbd_sections": {"count": %d, "severity": "LOW"},\n'    "$TBD_COUNT"
  printf '  "orphan_refs":  {"count": %d, "severity": "HIGH"},\n'   "$ORPHAN_REFS"
  printf '  "pass": %s\n' "$PASS_STR"
  printf '}\n'
   # AC-03: CI Gate is WARN-only — never block
   exit 0
 fi

# ── REQ-02: Human-readable output ────────────────────────────────────────────

echo "=== Documentation Health Audit ==="
printf "Broken links:  %d (HIGH)\n"   "$BROKEN_LINKS"
printf "Stale refs:    %d (MEDIUM)\n" "$STALE_REFS"
printf "TBD sections:  %d (LOW)\n"    "$TBD_COUNT"
printf "Orphan refs:   %d (HIGH)\n"   "$ORPHAN_REFS"
echo "Score: ${SCORE}/100"
[[ "$SCORE" -lt 70 ]] && echo "WARN: score below 70 — documentation debt detected"

# AC-03: CI Gate is WARN-only — never block
exit 0
