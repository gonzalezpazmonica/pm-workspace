#!/usr/bin/env bash
# corporate-fleet-dashboard.sh — SE-271 S5: Derive fleet dashboard from attestations
set -uo pipefail
#
# Usage:
#   scripts/corporate-fleet-dashboard.sh --corp-registry PATH [--json]
#
# Derives a fleet-level dashboard from all attestation files in the registry.
# Shows:
#   - Adoption by body
#   - Versions in use
#   - Walls with incidents
#   - Instances without attestation
#   - Declinations visible with reasons (aggregate, not individual)
#
# No inference: missing attestation shows as missing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

CORP_REGISTRY=""
JSON_OUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --corp-registry) CORP_REGISTRY="$2"; shift 2 ;;
    --json) JSON_OUT=true; shift ;;
    --help|-h)
      echo "Usage: corporate-fleet-dashboard.sh --corp-registry PATH [--json]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$CORP_REGISTRY" ]]; then
  echo '{"error":"--corp-registry is required"}' >&2
  exit 2
fi

ATTEST_DIR="$CORP_REGISTRY/attestations"
KNOWN_BODIES_FILE="$CORP_REGISTRY/bodies.txt"

# ── collect known bodies ──────────────────────────────────────────────────────
KNOWN_BODIES_LIST=""
if [[ -f "$KNOWN_BODIES_FILE" ]]; then
  KNOWN_BODIES_LIST=$(grep -v '^#' "$KNOWN_BODIES_FILE" | grep -v '^$' | tr '\n' '|')
fi
export CORP_REGISTRY KNOWN_BODIES="$KNOWN_BODIES_LIST"

# ── parse all attestations ────────────────────────────────────────────────────
python3 << PYEOF
import json, os, sys, glob
from datetime import datetime, timezone

registry = os.environ.get('CORP_REGISTRY', '')
attest_dir = os.path.join(registry, 'attestations')
known_bodies_raw = os.environ.get('KNOWN_BODIES', '')

json_mode = '--json' in sys.argv

# Parse attestations
attestations = []
if os.path.isdir(attest_dir):
    for fpath in sorted(glob.glob(os.path.join(attest_dir, '*.json'))):
        try:
            with open(fpath) as f:
                doc = json.load(f)
            attestations.append(doc)
        except Exception:
            continue

# Aggregate
adoption = {}
versions = {}
walls_with_incidents = []
attested_bodies = set()
declinations_agg = {}

for a in attestations:
    body = a.get('body', {}).get('id', 'unknown')
    attested_bodies.add(body)
    ver = a.get('body', {}).get('savia_version', 'unknown')

    # Adoption
    if body not in adoption:
        adoption[body] = {'attested': True, 'version': ver}
    else:
        # Keep most recent version
        adoption[body]['version'] = ver

    # Versions
    if ver not in versions:
        versions[ver] = []
    if body not in versions[ver]:
        versions[ver].append(body)

    # Wall incidents
    wall = a.get('wall_integrity', {})
    if wall.get('status') == 'breached' or wall.get('incidents', 0) > 0:
        walls_with_incidents.append({
            'body': body,
            'incidents': wall.get('incidents', 0),
            'status': wall.get('status', 'unknown')
        })

    # Declinations
    for d in a.get('declinations', []):
        reason = d.get('reason', 'unspecified')
        declinations_agg[reason] = declinations_agg.get(reason, 0) + 1

# Bodies without attestation
missing_bodies = []
if known_bodies_raw:
    known_list = [b.strip() for b in known_bodies_raw.split('|') if b.strip()]
else:
    known_list = []
for b in known_list:
    if b not in attested_bodies:
        missing_bodies.append(b)

dashboard = {
    "generated_at": datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    "total_attestations": len(attestations),
    "total_known_bodies": len(known_list),
    "adoption_by_body": adoption,
    "bodies_without_attestation": missing_bodies,
    "versions_in_use": versions,
    "walls_with_incidents": walls_with_incidents,
    "declinations": {
        "aggregated_reasons": declinations_agg,
        "note": "Aggregate only — no individual declination data"
    },
    "zero_inference_principle": "Missing attestation shows as missing. No imputation, no guesswork."
}

print(json.dumps(dashboard, indent=2))
PYEOF
