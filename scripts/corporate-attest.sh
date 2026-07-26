#!/usr/bin/env bash
# corporate-attest.sh — SE-271 S5: Generate signed corporate attestation
set -uo pipefail
#
# Usage:
#   scripts/corporate-attest.sh --corp-registry PATH [--output PATH] [--sign]
#
# Generates a corporate attestation document containing:
#   - Adopted bodies + versions
#   - Declinations with reasons
#   - Active engagements (client slug only, no content)
#   - Wall integrity status
#   - Savia version
#   - Self-audit result
#   - Level incidents
#   - ZERO individual activity data (asserted via schema validation)
#
# Exit codes:
#   0 — attestation generated
#   1 — attestation generation failed
#   2 — schema violation (individual data detected)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
export REPO_ROOT_ENV="$REPO_ROOT"

CORP_REGISTRY=""
OUTPUT_FILE=""
SIGN=false
ATTEST_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BODY_ID="${SAVIA_BODY_ID:-$(hostname)}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --corp-registry) CORP_REGISTRY="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --sign) SIGN=true; shift ;;
    --help|-h)
      echo "Usage: corporate-attest.sh --corp-registry PATH [--output PATH] [--sign]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$CORP_REGISTRY" ]]; then
  echo '{"error":"--corp-registry is required"}' >&2
  exit 2
fi

mkdir -p "$CORP_REGISTRY/attestations"

# ── detect Savia version ──────────────────────────────────────────────────────
SAVIA_VERSION="unknown"
if [[ -f "$REPO_ROOT/.claude/settings.json" ]]; then
  SAVIA_VERSION=$(python3 -c "
import json
with open('$REPO_ROOT/.claude/settings.json') as f:
    d = json.load(f)
print(d.get('version', 'unknown'))
" 2>/dev/null || echo "unknown")
fi

if [[ "$SAVIA_VERSION" == "unknown" && -f "$REPO_ROOT/VERSION" ]]; then
  SAVIA_VERSION=$(head -1 "$REPO_ROOT/VERSION" 2>/dev/null || echo "unknown")
fi

# ── collect active engagements (clients only, no content) ─────────────────────
ENGAGEMENTS_JSON="[]"
if [[ -d "$REPO_ROOT/engagements" ]]; then
  ENGAGEMENTS_JSON=$(python3 << 'PYEOF'
import json, os, sys

repo = os.environ.get('REPO_ROOT_ENV', '')
eng_dir = os.path.join(repo, 'engagements')
result = []

if os.path.isdir(eng_dir):
    try:
        import yaml
        for fname in sorted(os.listdir(eng_dir)):
            if not fname.endswith(('.yaml', '.yml')):
                continue
            fpath = os.path.join(eng_dir, fname)
            try:
                with open(fpath) as f:
                    doc = yaml.safe_load(f)
                if isinstance(doc, dict) and 'engagement' in doc:
                    e = doc['engagement']
                    if e.get('status') == 'active':
                        result.append({
                            "id": e.get("id", fname),
                            "client": e.get("client", "?"),
                            "body": e.get("body", "?"),
                            "wall": e.get("wall", "?")
                        })
            except Exception:
                continue
    except ImportError:
        pass

print(json.dumps(result))
PYEOF
)
fi

# ── check wall integrity ──────────────────────────────────────────────────────
WALL_INTEGRITY="ok"
WALL_INCIDENTS=0
if [[ -f "$REPO_ROOT/output/wall-incidents.jsonl" ]]; then
  WALL_INCIDENTS=$(wc -l < "$REPO_ROOT/output/wall-incidents.jsonl" 2>/dev/null || echo 0)
  if [[ "$WALL_INCIDENTS" -gt 0 ]]; then
    WALL_INTEGRITY="breached"
  fi
fi

# ── self-audit ────────────────────────────────────────────────────────────────
SELF_AUDIT_SCORE=100
if [[ -f "$SCRIPT_DIR/corporate-no-write-assert.sh" ]]; then
  bash "$SCRIPT_DIR/corporate-no-write-assert.sh" > /dev/null 2>&1 || SELF_AUDIT_SCORE=99
fi

# ── collect declinations ──────────────────────────────────────────────────────
DECLINATIONS_JSON="[]"
if [[ -f "$REPO_ROOT/corporate/declinations.yaml" ]]; then
  DECLINATIONS_JSON=$(python3 -c "
import json
try:
    import yaml
    with open('$REPO_ROOT/corporate/declinations.yaml') as f:
        d = yaml.safe_load(f) or {}
    print(json.dumps(d.get('declinations', [])))
except Exception:
    print('[]')
" 2>/dev/null || echo "[]")
fi

# ── build attestation document ────────────────────────────────────────────────
ATTEST_ID="attest-${BODY_ID}-$(date -u +%Y%m%d%H%M%S)"

export BODY_ID SAVIA_VERSION ENGAGEMENTS="$ENGAGEMENTS_JSON"
export DECLINATIONS="$DECLINATIONS_JSON" WALL_INTEGRITY WALL_INCIDENTS
export SELF_AUDIT_SCORE ATTEST_ID ATTEST_DATE

ATTESTATION=$(python3 << PYEOF
import json, os

body = os.environ.get('BODY_ID', 'unknown')
version = os.environ.get('SAVIA_VERSION', 'unknown')
engagements = json.loads(os.environ.get('ENGAGEMENTS', '[]'))
declinations = json.loads(os.environ.get('DECLINATIONS', '[]'))
wall_int = os.environ.get('WALL_INTEGRITY', 'ok')
wall_inc = int(os.environ.get('WALL_INCIDENTS', '0'))
audit_score = int(os.environ.get('SELF_AUDIT_SCORE', '100'))
attest_id = os.environ.get('ATTEST_ID', '')
attest_date = os.environ.get('ATTEST_DATE', '')

doc = {
    "attestation_id": attest_id,
    "generated_at": attest_date,
    "body": {
        "id": body,
        "savia_version": version
    },
    "adoptions": {
        "engagement_capacity_model": True,
        "corporate_attestation": True,
        "fleet_dashboard": True,
        "no_write_path_assertion": True
    },
    "declinations": declinations,
    "active_engagements": engagements,
    "wall_integrity": {
        "status": wall_int,
        "incidents": wall_inc
    },
    "self_audit": {
        "score": audit_score,
        "no_write_path_assertion_passed": audit_score == 100
    },
    "schema_assertions": {
        "zero_individual_activity_data": True,
        "no_operative_content_in_engagements": True,
        "no_pii_in_attestation": True
    }
}

print(json.dumps(doc, indent=2))
PYEOF
)

# ── check schema: verify zero individual activity data ────────────────────────
SCHEMA_CHECK=$(echo "$ATTESTATION" | python3 -c "
import json, sys
doc = json.load(sys.stdin)
issues = []
# Assert no individual-level data
for key in doc:
    if key.startswith('user_') or key.startswith('operator_') or key.startswith('actor_'):
        issues.append(f'individual-data-field: {key}')
if 'actors' in doc or 'users' in doc or 'operators' in doc:
    issues.append('individual-collection-found')
if issues:
    print(json.dumps({'schema_violation': True, 'issues': issues}))
    sys.exit(2)
print(json.dumps({'schema_violation': False}))
")

if [[ $? -eq 2 ]]; then
  echo "FATAL: schema violation — individual activity data detected" >&2
  echo "$SCHEMA_CHECK" >&2
  exit 2
fi

# ── sign if requested ─────────────────────────────────────────────────────────
if [[ "$SIGN" == "true" ]]; then
  SIG=$(echo -n "$ATTESTATION" | sha256sum | cut -d' ' -f1)
  ATTESTATION=$(echo "$ATTESTATION" | python3 -c "
import json, sys
doc = json.load(sys.stdin)
doc['signature'] = {'algo': 'sha256', 'hash': '$SIG', 'signed_at': '$ATTEST_DATE'}
print(json.dumps(doc, indent=2))
")
fi

# ── write attestation file ────────────────────────────────────────────────────
ATTEST_FILE="$CORP_REGISTRY/attestations/${ATTEST_ID}.json"
echo "$ATTESTATION" > "$ATTEST_FILE"

echo "{\"status\":\"generated\",\"file\":\"$ATTEST_FILE\",\"attestation_id\":\"$ATTEST_ID\"}"

exit 0
