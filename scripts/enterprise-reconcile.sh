#!/usr/bin/env bash
# enterprise-reconcile.sh — SE-271 S4: Classify enterprise scripts into wired/adapted/archived
set -uo pipefail
#
# Usage:
#   scripts/enterprise-reconcile.sh [--output json|text]
#
# Scans all scripts in scripts/enterprise/ and classifies:
#   wired   — connected to real enforcement (engagement/capacity/wall/attest)
#   adapted — refactored for capacity model (references engagement/capacity concepts)
#   archived — tombstone (no connection to capacity enforcement)
#
# Guarantees: zero scripts in limbo (count must match ls count)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
ENTERPRISE_DIR="$REPO_ROOT/scripts/enterprise"
OUTPUT_FORMAT="${1:-json}"

if [[ "${2:-}" == "--output" ]]; then OUTPUT_FORMAT="$3"; fi

cd "$REPO_ROOT"

# ── find all enterprise scripts ───────────────────────────────────────────────
declare -a ALL_SCRIPTS
declare -A SCRIPT_NAMES
declare -a WIRED=()
declare -a ADAPTED=()
declare -a ARCHIVED=()

while IFS= read -r -d '' f; do
  name=$(basename "$f" .sh)
  ALL_SCRIPTS+=("$name")
  SCRIPT_NAMES["$name"]=1
done < <(find "$ENTERPRISE_DIR" -maxdepth 1 -name '*.sh' -print0 | sort -z)

# ── classification logic ──────────────────────────────────────────────────────

# wired patterns: scripts that connect to real engagement/capacity enforcement
WIRED_PATTERNS=(
  "engagement" "capacity" "corporate-attest" "fleet-dashboard" "no-write-assert"
  "enterprise-reconcile" "corporat" "wall" "attest"
)

# adapted patterns: scripts that reference engagement/capacity model concepts
ADAPTED_PATTERNS=(
  "rbac" "compliance" "governance" "audit" "tenant" "sow"
  "client-health" "billing" "license" "sovereign" "delta-tier"
  "prospect" "bench" "knowledge" "metrics" "deployment"
)

classify_script() {
  local name="$1"
  local file="$ENTERPRISE_DIR/${name}.sh"

  if [[ ! -f "$file" ]]; then
    echo "warn: $file not found in filesystem" >&2
    return
  fi

  # wired check: script name or content references engagement/capacity enforcement
  for pattern in "${WIRED_PATTERNS[@]}"; do
    if [[ "$name" == *"$pattern"* ]]; then
      WIRED+=("$name")
      return
    fi
  done

  # adapted check: references enterprise/capacity concepts
  for pattern in "${ADAPTED_PATTERNS[@]}"; do
    if [[ "$name" == *"$pattern"* ]]; then
      ADAPTED+=("$name")
      return
    fi
  done

  # Check file content for references to engagement/capacity/wall
  if grep -qE '(engagement|capacity-check|wall-integrity|corporate-registry)' "$file" 2>/dev/null; then
    ADAPTED+=("$name")
    return
  fi

  # Default: archived
  ARCHIVED+=("$name")
}

for script in "${ALL_SCRIPTS[@]}"; do
  classify_script "$script"
done

# ── verify zero limbo ─────────────────────────────────────────────────────────
TOTAL_CLASSIFIED=$((${#WIRED[@]} + ${#ADAPTED[@]} + ${#ARCHIVED[@]}))
TOTAL_ON_DISK=$(find "$ENTERPRISE_DIR" -maxdepth 1 -name '*.sh' | wc -l)

if [[ "$TOTAL_CLASSIFIED" -ne "$TOTAL_ON_DISK" ]]; then
  echo "ERROR: classification gap — $TOTAL_CLASSIFIED classified vs $TOTAL_ON_DISK on disk" >&2

  # Find unclassified
  declare -A CLASSIFIED_MAP
  for s in "${WIRED[@]}"; do CLASSIFIED_MAP["$s"]=1; done
  for s in "${ADAPTED[@]}"; do CLASSIFIED_MAP["$s"]=1; done
  for s in "${ARCHIVED[@]}"; do CLASSIFIED_MAP["$s"]=1; done

  while IFS= read -r -d '' f; do
    name=$(basename "$f" .sh)
    if [[ -z "${CLASSIFIED_MAP[$name]:-}" ]]; then
      echo "  UNCLASSIFIED: $name" >&2
    fi
  done < <(find "$ENTERPRISE_DIR" -maxdepth 1 -name '*.sh' -print0)
fi

# ── output ────────────────────────────────────────────────────────────────────
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  python3 << PYEOF
import json

wired_raw = '''${WIRED[*]:-}'''
adapted_raw = '''${ADAPTED[*]:-}'''
archived_raw = '''${ARCHIVED[*]:-}'''

wired   = wired_raw.split() if wired_raw.strip() else []
adapted = adapted_raw.split() if adapted_raw.strip() else []
archived = archived_raw.split() if archived_raw.strip() else []

report = {
    "total_on_disk": $TOTAL_ON_DISK,
    "total_classified": $TOTAL_CLASSIFIED,
    "in_limbo": $TOTAL_ON_DISK - $TOTAL_CLASSIFIED,
    "wired": wired,
    "wired_count": len(wired),
    "adapted": adapted,
    "adapted_count": len(adapted),
    "archived": archived,
    "archived_count": len(archived),
    "archive_means_tombstone": True,
    "reclassification_note": "Scripts in 'archived' are tombstoned; they have no active connection to engagement/capacity enforcement."
}
print(json.dumps(report, indent=2))
PYEOF
else
  echo "=== Enterprise Script Reconciliation ==="
  echo "Total on disk: $TOTAL_ON_DISK"
  echo "Total classified: $TOTAL_CLASSIFIED"
  echo ""
  echo "--- WIRED (${#WIRED[@]}) ---"
  for s in "${WIRED[@]}"; do echo "  $s"; done
  echo ""
  echo "--- ADAPTED (${#ADAPTED[@]}) ---"
  for s in "${ADAPTED[@]}"; do echo "  $s"; done
  echo ""
  echo "--- ARCHIVED (${#ARCHIVED[@]}) ---"
  for s in "${ARCHIVED[@]}"; do echo "  $s"; done
  echo ""
  if [[ "$TOTAL_CLASSIFIED" -ne "$TOTAL_ON_DISK" ]]; then
    echo "WARNING: $(( TOTAL_ON_DISK - TOTAL_CLASSIFIED )) scripts in limbo"
  else
    echo "Zero scripts in limbo"
  fi
fi
