#!/usr/bin/env bash
# spec-frontmatter-migrate.sh — SE-036 Slice 1.
#
# Migrates specs in `docs/propuestas/` that use body-prose status markers
# (e.g. `> Status: **DRAFT**`) to canonical YAML frontmatter. Extraction
# is mechanical: reads body claim and injects matching frontmatter. No
# human judgment is substituted — if the body says DRAFT, the frontmatter
# will say Proposed.
#
# Canonical mapping:
#   DRAFT, PROPOSED                     → Proposed
#   ACTIVE, IMPLEMENTING, IN_PROGRESS   → IN_PROGRESS
#   READY, ACCEPTED, APPROVED           → ACCEPTED
#   COMPLETE, COMPLETED, IMPLEMENTED,
#   DONE, "PHASE * DONE"                → Implemented
#   REJECTED, DROPPED                   → Rejected
#   <other>                             → UNLABELED (human review)
#
# Usage:
#   --dry-run (default) Report what would change, no writes.
#   --apply             Write frontmatter to files that match criteria.
#   --limit N           Limit batch size (default 10, max 50).
#   --spec PATH         Migrate exactly one spec (ignores --limit).
#
# Ref: SE-036, ROADMAP Tier 1.4
# Safety: `set -uo pipefail`. No destructive rewrites — appends frontmatter
# at top, preserves all existing body content.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SPECS_DIR="$REPO_ROOT/docs/propuestas"

MODE="dry-run"
LIMIT=10
TARGET_SPEC=""

usage() {
  cat <<EOF
Usage: $0 [--dry-run | --apply] [--limit N] [--spec PATH]

  --dry-run  Report planned migrations without writing (default).
  --apply    Write frontmatter to files.
  --limit N  Max specs to process in one run (default 10, max 50).
  --spec P   Migrate only the given spec path.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run"; shift ;;
    --apply)   MODE="apply"; shift ;;
    --limit)   LIMIT="$2"; shift 2 ;;
    --spec)    TARGET_SPEC="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

if [[ ! "$LIMIT" =~ ^[0-9]+$ ]] || [[ "$LIMIT" -lt 1 ]] || [[ "$LIMIT" -gt 50 ]]; then
  echo "ERROR: --limit must be integer in [1,50]" >&2
  exit 2
fi

# ── Canonical mapping ──────────────────────────────────────────────────────

map_status() {
  local raw="$1"
  # Strip markdown emphasis and whitespace.
  raw=$(echo "$raw" | sed 's/\*//g' | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
  case "$raw" in
    DRAFT|PROPOSED)                                         echo "Proposed" ;;
    ACTIVE|IMPLEMENTING|INPROGRESS|IN_PROGRESS|IN-PROGRESS) echo "IN_PROGRESS" ;;
    READY|ACCEPTED|APPROVED)                                echo "ACCEPTED" ;;
    COMPLETE|COMPLETED|IMPLEMENTED|DONE)                    echo "Implemented" ;;
    PHASE1DONE|PHASE2DONE|PHASE3DONE|PHASE4DONE)            echo "Implemented" ;;
    REJECTED|DROPPED|SUPERSEDED|OBSOLETE)                   echo "Rejected" ;;
    *)                                                      echo "UNLABELED" ;;
  esac
}

# ── Extract body-prose status ──────────────────────────────────────────────

extract_body_status() {
  local f="$1"
  # Match pattern `> Status: **VALUE**` or `> Estado: **VALUE**`. Case-insensitive.
  # Capture the word after the colon up to the next pipe, bullet, or end.
  local line
  line=$(grep -m1 -iE '^>\s*\*?\*?(estado|status)\*?\*?:\s*' "$f" 2>/dev/null || true)
  if [[ -z "$line" ]]; then
    echo ""
    return
  fi
  # Remove the prefix up to and including the colon.
  local after_colon
  after_colon="${line#*:}"
  # Extract the first word-like token (allowing letters, digits, spaces for "PHASE 1 DONE").
  # Strategy: remove ** wrappers, then take up to the first · or | or end.
  local cleaned
  cleaned=$(echo "$after_colon" | sed 's/\*\*//g; s/\*//g' | sed 's/[·|].*$//' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  echo "$cleaned"
}

# ── Extract spec id + title ────────────────────────────────────────────────

extract_id() {
  local f="$1"
  basename "$f" .md | grep -oE '^(SPEC-SE|SPEC|SE)-[0-9]+' | head -1
}

extract_title() {
  local f="$1"
  local h1
  h1=$(grep -m1 -E '^# ' "$f" 2>/dev/null | sed 's/^# *//' | sed 's/"/\\"/g')
  echo "$h1"
}

# ── Inject frontmatter ─────────────────────────────────────────────────────

inject_frontmatter() {
  local f="$1"
  local id="$2"
  local title="$3"
  local status="$4"
  local date_str="$5"
  local tmp
  tmp=$(mktemp)
  {
    echo "---"
    echo "id: $id"
    echo "title: $title"
    echo "status: $status"
    [[ -n "$date_str" ]] && echo "origin_date: \"$date_str\""
    echo "migrated_at: \"$(date +%Y-%m-%d)\""
    echo "migrated_from: body-prose"
    echo "---"
    echo ""
    cat "$f"
  } > "$tmp"
  mv "$tmp" "$f"
}

# ── Extract date from body (best-effort) ───────────────────────────────────

extract_date() {
  local f="$1"
  grep -m1 -oE 'Fecha:[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}' "$f" 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1
}

# ── Main ──────────────────────────────────────────────────────────────────

process_one() {
  local f="$1"
  local first
  first=$(head -1 "$f")
  if [[ "$first" == "---" ]]; then
    echo "SKIP (already has frontmatter): $f"
    return 1
  fi
  local raw_status
  raw_status=$(extract_body_status "$f")
  if [[ -z "$raw_status" ]]; then
    echo "SKIP (no body-prose status): $f"
    return 1
  fi
  local id title status date_str
  id=$(extract_id "$f")
  title=$(extract_title "$f")
  status=$(map_status "$raw_status")
  date_str=$(extract_date "$f")

  if [[ -z "$id" ]]; then
    echo "SKIP (cannot extract id): $f"
    return 1
  fi

  echo "PLAN: $f | $id | status: $raw_status → $status"

  if [[ "$MODE" == "apply" ]]; then
    inject_frontmatter "$f" "$id" "$title" "$status" "$date_str"
    echo "  APPLIED"
  fi
  return 0
}

# Single-spec mode.
if [[ -n "$TARGET_SPEC" ]]; then
  if [[ ! -f "$TARGET_SPEC" ]]; then
    echo "ERROR: spec not found: $TARGET_SPEC" >&2
    exit 2
  fi
  process_one "$TARGET_SPEC"
  exit 0
fi

# Batch mode.
processed=0
applied=0
skipped=0

while IFS= read -r f; do
  if [[ "$processed" -ge "$LIMIT" ]]; then
    echo "... stopped at --limit $LIMIT"
    break
  fi
  if process_one "$f"; then
    processed=$((processed+1))
    [[ "$MODE" == "apply" ]] && applied=$((applied+1))
  else
    skipped=$((skipped+1))
  fi
done < <(find "$SPECS_DIR" -maxdepth 3 -type f \( -name 'SPEC-*.md' -o -name 'SE-*.md' -o -name 'SPEC-SE-*.md' \) | sort)

echo ""
echo "spec-frontmatter-migrate: mode=$MODE processed=$processed applied=$applied skipped=$skipped"

exit 0
