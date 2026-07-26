#!/usr/bin/env bash
# engagement-init.sh — SE-271 S3: Initialize client engagement with ethical walls
# Creates engagement definition, directory structure, and links to criterion body.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENGAGEMENTS_DIR="$ROOT/engagements"
DATE_NOW=$(date -u +"%Y-%m-%d")

usage() {
  cat <<EOF
Usage: bash scripts/engagement-init.sh --client CLIENT --engagement NAME [options]

Required:
  --client CLIENT          Client slug (lowercase alphanumeric + hyphens)
  --engagement NAME        Engagement name (lowercase alphanumeric + hyphens)

Options:
  --criterion PATH         Path to adopted criterion body (default: docs/corporate-criterion.yaml)
  --min-confidentiality N  Minimum confidentiality level (1-4, default: 3)
  --wall MODE              Wall mode: strict | permeable-declared (default: strict)
  --validity DAYS          Validity period in days (default: 365)
  --capabilities CAPS       Comma-separated scoped capabilities (default: all)
  --force                  Overwrite existing engagement
  --json                   Output JSON only
  --help, -h               This help
EOF
}

CLIENT=""; ENGAGEMENT=""; CRITERION=""; MIN_CONF=3; WALL="strict"
VALIDITY=365; CAPS="all"; FORCE=false; JSON_OUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --client)              CLIENT="$2";         shift 2 ;;
    --engagement)          ENGAGEMENT="$2";     shift 2 ;;
    --criterion)           CRITERION="$2";      shift 2 ;;
    --min-confidentiality) MIN_CONF="$2";       shift 2 ;;
    --wall)                WALL="$2";           shift 2 ;;
    --validity)            VALIDITY="$2";       shift 2 ;;
    --capabilities)        CAPS="$2";           shift 2 ;;
    --force)               FORCE=true;          shift ;;
    --json)                JSON_OUT=true;       shift ;;
    --help|-h)             usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# ── Validation ──────────────────────────────────────────────────────────────────
if [[ -z "$CLIENT" ]]; then
  echo '{"error":"--client is required"}' >&2; exit 1
fi
if [[ -z "$ENGAGEMENT" ]]; then
  echo '{"error":"--engagement is required"}' >&2; exit 1
fi

if ! echo "$CLIENT" | grep -qE '^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$'; then
  echo "{\"error\":\"invalid client slug '$CLIENT' — use lowercase alphanumeric and hyphens\"}" >&2; exit 1
fi
if ! echo "$ENGAGEMENT" | grep -qE '^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$'; then
  echo "{\"error\":\"invalid engagement name '$ENGAGEMENT' — use lowercase alphanumeric and hyphens\"}" >&2; exit 1
fi

case "$WALL" in
  strict|permeable-declared) ;;
  *) echo "{\"error\":\"invalid wall mode '$WALL' — must be: strict, permeable-declared\"}" >&2; exit 1 ;;
esac

if ! echo "$MIN_CONF" | grep -qE '^[1-4]$'; then
  echo '{"error":"min-confidentiality must be 1-4"}' >&2; exit 1
fi
if ! echo "$VALIDITY" | grep -qE '^[0-9]+$'; then
  echo '{"error":"validity must be a positive integer (days)"}' >&2; exit 1
fi

# ── Criterion body resolution ──────────────────────────────────────────────────
CRITERION_BODY="${CRITERION:-}"
if [[ -z "$CRITERION_BODY" ]]; then
  for candidate in \
    "$ROOT/docs/corporate-criterion.yaml" \
    "$ROOT/docs/corporate-model.yaml"; do
    if [[ -f "$candidate" ]]; then
      CRITERION_BODY="$candidate"
      break
    fi
  done
fi
if [[ -z "$CRITERION_BODY" ]]; then
  CRITERION_BODY="docs/corporate-criterion.yaml"  # default path, will be created if missing
fi

CRITERION_ABS="$CRITERION_BODY"
if [[ "$CRITERION_BODY" != /* ]]; then
  CRITERION_ABS="$ROOT/$CRITERION_BODY"
fi

ENGAGEMENT_DIR="$ENGAGEMENTS_DIR/$CLIENT"
ENGAGEMENT_YAML="$ENGAGEMENT_DIR/${ENGAGEMENT}.yaml"

# ── Check existing ──────────────────────────────────────────────────────────────
if [[ -f "$ENGAGEMENT_YAML" ]] && ! $FORCE; then
  echo "{\"error\":\"engagement '$CLIENT/$ENGAGEMENT' already exists at $ENGAGEMENT_YAML — use --force to overwrite\"}" >&2
  exit 1
fi

# ── Calculate expiry date ───────────────────────────────────────────────────────
EXPIRY_DATE=""
if command -v python3 >/dev/null 2>&1; then
  EXPIRY_DATE=$(python3 -c "
from datetime import datetime, timedelta
d = datetime.utcnow() + timedelta(days=$VALIDITY)
print(d.strftime('%Y-%m-%d'))
" 2>/dev/null)
fi
[[ -z "$EXPIRY_DATE" ]] && EXPIRY_DATE=$(date -u -d "+$VALIDITY days" +"%Y-%m-%d" 2>/dev/null || echo "unknown")

# ── Create directory structure ──────────────────────────────────────────────────
mkdir -p "$ENGAGEMENT_DIR/artifacts"
mkdir -p "$ENGAGEMENT_DIR/wall"
mkdir -p "$ENGAGEMENT_DIR/memory"
mkdir -p "$ENGAGEMENT_DIR/ledger"

# ── Create criterion body if missing ────────────────────────────────────────────
if [[ ! -f "$CRITERION_ABS" ]]; then
  mkdir -p "$(dirname "$CRITERION_ABS")"
  cat > "$CRITERION_ABS" << 'YML'
# Corporate Criterion Body — Savia Enterprise
# All engagements inherit from this body by default.
# Override per-engagement via --criterion flag.

corporate_criterion:
  version: "1.0.0"
  name: "Savia Corporate Criterion Body"
  description: "Default criterion adopted by all engagements"
  principles:
    - id: CORP-001
      statement: "Truth as common good — no concealment of conflicts"
      binding: strict
    - id: CORP-002
      statement: "Client data sovereignty — data belongs to client"
      binding: strict
    - id: CORP-003
      statement: "Ethical wall integrity — no cross-contamination between clients"
      binding: strict
    - id: CORP-004
      statement: "Auditability — all actions traceable to criterion"
      binding: strict
    - id: CORP-005
      statement: "Operator sovereignty — human decides, Savia executes"
      binding: strict
  confidentiality_levels:
    1: "Public — shareable outside engagement context"
    2: "Internal — within organization, not external"
    3: "Confidential — within engagement team only"
    4: "Restricted — operator-only, never in shared memory"
  wall_modes:
    strict: "No artifact crosses client boundary — block on detection"
    permeable-declared: "Permeable only via operator-signed declaration of shared scope"
YML
fi

# ── Write engagement YAML ───────────────────────────────────────────────────────
cat > "$ENGAGEMENT_YAML" << YML
# Engagement: $CLIENT / $ENGAGEMENT
# Generated by engagement-init.sh — SE-271 S3
# $(date -u +"%Y-%m-%dT%H:%M:%SZ")

engagement:
  client: "$CLIENT"
  name: "$ENGAGEMENT"
  created_at: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  valid_until: "$EXPIRY_DATE"
  active: true

criterion:
  adopted_body: "$CRITERION_BODY"
  adopted_at: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

confidentiality:
  minimum_level: $MIN_CONF
  description: |
    Min level ${MIN_CONF}: all artifacts within this engagement carry at least
    this confidentiality level. Artifacts tagged below this level are rejected.

capabilities:
  scoped: [$(echo "$CAPS" | tr ',' ' ' | sed 's/\b\w/\*&/g' 2>/dev/null || echo "$CAPS")]

wall:
  mode: "$WALL"
  enforced_since: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  layers:
    - episodic_memory
    - semantic_memory
    - active_context
    - knowledge_graph
    - domes
    - federation_exchange
    - briefs_drafts_engrams

directory_structure:
  artifacts: "$ENGAGEMENT_DIR/artifacts"
  wall: "$ENGAGEMENT_DIR/wall"
  memory: "$ENGAGEMENT_DIR/memory"
  ledger: "$ENGAGEMENT_DIR/ledger"

operator_signature:
  signed: false
  signed_by: ""
  signed_at: ""
YML

# ── Initialize wall ledger ──────────────────────────────────────────────────────
WALL_LEDGER="$ENGAGEMENT_DIR/wall/wall-ledger.jsonl"
if [[ ! -f "$WALL_LEDGER" ]]; then
  python3 -c "
import json
genesis = {
    'ts': '$(date -u +"%Y-%m-%dT%H:%M:%SZ")',
    'event': 'ENGAGEMENT_CREATED',
    'client': '$CLIENT',
    'engagement': '$ENGAGEMENT',
    'wall_mode': '$WALL',
    'min_confidentiality': $MIN_CONF,
    'prev_hash': 'genesis',
    'hash': __import__('hashlib').sha256(
        f'$(date -u +"%Y-%m-%dT%H:%M:%SZ"){$CLIENT}{$ENGAGEMENT}{$WALL}genesis'.encode()
    ).hexdigest()
}
print(json.dumps(genesis))
" > "$WALL_LEDGER" 2>/dev/null || true
fi

# ── Client tag prefix ───────────────────────────────────────────────────────────
TAG_PREFIX="client:${CLIENT}:engagement:${ENGAGEMENT}"
echo "$TAG_PREFIX" > "$ENGAGEMENT_DIR/wall/tag-prefix"

# ── Output ──────────────────────────────────────────────────────────────────────
CRITERION_REL="${CRITERION_BODY#docs/}"
if $JSON_OUT; then
  python3 -c "
import json
print(json.dumps({
    'created': True,
    'client': '$CLIENT',
    'engagement': '$ENGAGEMENT',
    'engagement_dir': '$ENGAGEMENT_DIR',
    'yaml': '$ENGAGEMENT_YAML',
    'criterion_body': '${CRITERION_REL:-$CRITERION_BODY}',
    'wall_mode': '$WALL',
    'min_confidentiality': $MIN_CONF,
    'valid_until': '$EXPIRY_DATE',
    'tag_prefix': '$TAG_PREFIX',
    'directories': ['artifacts', 'wall', 'memory', 'ledger']
}, indent=2))
" 2>/dev/null || echo '{"created":true,"client":"'"$CLIENT"'","engagement":"'"$ENGAGEMENT"'"}'
else
  echo "=== Engagement created: $CLIENT / $ENGAGEMENT ==="
  echo "  YAML:          $ENGAGEMENT_YAML"
  echo "  Dir:           $ENGAGEMENT_DIR"
  echo "  Criterion:     ${CRITERION_REL:-$CRITERION_BODY}"
  echo "  Wall mode:     $WALL"
  echo "  Min conf:      $MIN_CONF"
  echo "  Valid until:   $EXPIRY_DATE"
  echo "  Tag prefix:    $TAG_PREFIX"
  echo "  Directories:   artifacts, wall, memory, ledger"
fi
