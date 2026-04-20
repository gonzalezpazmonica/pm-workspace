#!/usr/bin/env bash
# specs-frontmatter-normalize.sh — SE-054 Slice 2+3 frontmatter normalization.
#
# Normaliza YAML frontmatter de docs/propuestas/*.md:
#   1. Añade `status:` missing (infiere desde "> Status:" en body, default PROPOSED)
#   2. Normaliza case: Proposed → PROPOSED, Draft → DRAFT, Accepted → ACCEPTED, etc.
#   3. Añade `id:` missing (infiere desde filename SPEC-XXX o SE-XXX)
#
# Modos:
#   --scan      Report drift sin modificar (default)
#   --apply     Re-escribir ficheros en-place
#   --json      JSON output
#
# Usage:
#   specs-frontmatter-normalize.sh
#   specs-frontmatter-normalize.sh --apply
#   specs-frontmatter-normalize.sh --apply --limit 20   # batch size
#
# Exit codes:
#   0 — sin drift (o --apply exitoso)
#   1 — drift detectado (en --scan mode)
#   2 — usage error
#
# Ref: SE-054, SE-036, audit-arquitectura-20260420.md D16/D17
# Safety: --apply único modo que escribe. set -uo pipefail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROPUESTAS_DIR="$PROJECT_ROOT/docs/propuestas"

MODE="scan"
LIMIT=0  # 0 = unlimited
JSON=0

CANONICAL_STATUSES="PROPOSED DRAFT APPROVED ACCEPTED IMPLEMENTED REJECTED DEPRECATED SUPERSEDED DONE ENTERPRISE_ONLY"

usage() {
  cat <<EOF
Usage:
  $0 [--scan|--apply] [options]

Modes:
  --scan        Report drift (default). Exit 1 if drift found.
  --apply       Rewrite files in-place.

Options:
  --limit N     Process first N files only (0=unlimited, default)
  --json        JSON output

Normaliza YAML frontmatter de docs/propuestas/:
  1. Missing 'status:' → infer from body or default PROPOSED
  2. Status case: Proposed → PROPOSED (all canonical statuses uppercase)
  3. Missing 'id:' → infer from filename (SPEC-XXX / SE-XXX)

Ref: SE-054 Slice 2+3, SE-036, audit-arquitectura-20260420.md D16/D17
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scan) MODE="scan"; shift ;;
    --apply) MODE="apply"; shift ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --limit must be non-negative integer" >&2; exit 2
fi

[[ ! -d "$PROPUESTAS_DIR" ]] && { echo "ERROR: docs/propuestas not found" >&2; exit 2; }

# Normalize a status string to canonical uppercase
normalize_status() {
  local s="$1"
  # Strip quotes + trailing noise
  s=$(echo "$s" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '"')
  # Take first word if multi-word (e.g. "REJECTED (2026-04-17)")
  s=$(echo "$s" | awk '{print $1}')
  # Uppercase
  echo "$s" | tr '[:lower:]' '[:upper:]'
}

# Infer status from body "> Status: X"
infer_status_from_body() {
  local f="$1"
  grep -oE '^> Status:[[:space:]]*[A-Za-z_]+' "$f" 2>/dev/null | head -1 | awk '{print $3}' | tr '[:lower:]' '[:upper:]'
}

# Infer id from filename
infer_id_from_filename() {
  local f="$1"
  basename "$f" .md | grep -oE '^(SPEC|SE)-[0-9]+[a-z]?' | head -1
}

process_file() {
  local f="$1"
  local has_frontmatter=0
  local has_status=0
  local has_id=0
  local current_status=""
  local needs_fix=0

  # Check frontmatter presence
  if head -1 "$f" | grep -q "^---$"; then
    has_frontmatter=1
    # Extract status + id from frontmatter
    current_status=$(awk 'NR==1 && $0=="---" {inside=1; next} inside && $0=="---" {exit} inside && /^status:/ {sub(/^status:[[:space:]]*/, ""); print; exit}' "$f" 2>/dev/null)
    [[ -n "$current_status" ]] && has_status=1
    local current_id=$(awk 'NR==1 && $0=="---" {inside=1; next} inside && $0=="---" {exit} inside && /^id:/ {sub(/^id:[[:space:]]*/, ""); print; exit}' "$f" 2>/dev/null)
    [[ -n "$current_id" ]] && has_id=1
  fi

  # Detect normalization needs
  local new_status=""
  if [[ "$has_status" -eq 1 ]]; then
    local normalized
    normalized=$(normalize_status "$current_status")
    if [[ "$normalized" != "$current_status" ]]; then
      new_status="$normalized"
      needs_fix=1
    fi
  elif [[ "$has_frontmatter" -eq 1 ]]; then
    # Has frontmatter but no status → infer or default
    local inferred
    inferred=$(infer_status_from_body "$f")
    new_status="${inferred:-PROPOSED}"
    needs_fix=1
  else
    # No frontmatter at all
    local inferred
    inferred=$(infer_status_from_body "$f")
    new_status="${inferred:-PROPOSED}"
    needs_fix=1
  fi

  # Return needs_fix + details
  echo "$needs_fix|$has_frontmatter|$has_status|$has_id|$current_status|$new_status"
}

apply_file() {
  local f="$1"
  local info="$2"
  IFS='|' read -r needs_fix has_fm has_status has_id cur_status new_status <<< "$info"

  [[ "$needs_fix" -eq 0 ]] && return 0

  local inferred_id
  inferred_id=$(infer_id_from_filename "$f")
  local tmp="${f}.tmp.$$"

  if [[ "$has_fm" -eq 1 ]]; then
    if [[ "$has_status" -eq 1 ]]; then
      # Update existing status
      awk -v new_s="$new_status" '
        NR==1 && $0=="---" {inside=1; print; next}
        inside && /^status:/ {print "status: " new_s; got=1; next}
        inside && $0=="---" {inside=0; print; next}
        {print}
      ' "$f" > "$tmp"
    else
      # Add status after first ---
      awk -v new_s="$new_status" -v new_id="$inferred_id" '
        NR==1 && $0=="---" {print; inside=1; added_status=0; next}
        inside && !added_status { print "status: " new_s; added_status=1 }
        {print}
      ' "$f" > "$tmp"
    fi
  else
    # Add full frontmatter at top
    {
      echo "---"
      [[ -n "$inferred_id" ]] && echo "id: $inferred_id"
      echo "status: $new_status"
      echo "---"
      echo ""
      cat "$f"
    } > "$tmp"
  fi

  mv "$tmp" "$f"
}

# Collect files
FILES=()
while IFS= read -r f; do
  [[ -f "$f" ]] && FILES+=("$f")
done < <(find "$PROPUESTAS_DIR" -maxdepth 3 -name "*.md" -type f 2>/dev/null | sort)

processed=0
drift=0
fixed=0

for f in "${FILES[@]}"; do
  [[ "$LIMIT" -gt 0 && "$processed" -ge "$LIMIT" ]] && break
  processed=$((processed + 1))

  info=$(process_file "$f")
  IFS='|' read -r needs_fix _ _ _ _ _ <<< "$info"

  if [[ "$needs_fix" -eq 1 ]]; then
    drift=$((drift + 1))
    if [[ "$MODE" == "apply" ]]; then
      apply_file "$f" "$info"
      fixed=$((fixed + 1))
    fi
  fi
done

EXIT_CODE=0
[[ "$MODE" == "scan" && "$drift" -gt 0 ]] && EXIT_CODE=1

if [[ "$JSON" -eq 1 ]]; then
  cat <<JSON
{"mode":"$MODE","processed":$processed,"drift":$drift,"fixed":$fixed,"limit":$LIMIT,"total_files":${#FILES[@]}}
JSON
else
  echo "=== SE-054 Specs Frontmatter Normalize ==="
  echo ""
  echo "Mode:            $MODE"
  echo "Total files:     ${#FILES[@]}"
  echo "Processed:       $processed"
  echo "Drift found:     $drift"
  [[ "$MODE" == "apply" ]] && echo "Fixed:           $fixed"
  echo ""
  if [[ "$MODE" == "scan" ]]; then
    if [[ "$drift" -eq 0 ]]; then
      echo "VERDICT: PASS (no drift)"
    else
      echo "VERDICT: FAIL ($drift files need normalization)"
      echo "Fix: bash $0 --apply"
    fi
  else
    echo "Applied: $fixed files normalized in-place."
  fi
fi

exit $EXIT_CODE
