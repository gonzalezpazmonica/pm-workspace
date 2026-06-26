#!/usr/bin/env bash
set -uo pipefail
# prospect-create.sh — SE-015 Project Prospect (Pipeline-as-Code)
#
# Crea un prospect/oportunidad de proyecto.
#
# Usage:
#   bash scripts/enterprise/prospect-create.sh \
#     --slug NAME --client "Empresa" --value EUR \
#     [--tenant SLUG] [--stage discovery|qualified|proposal|won|lost]
#
# Crea: tenants/{tenant}/prospects/{slug}/prospect.yaml
#
# Exit codes: 0 ok | 1 error | 2 usage error
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-015-project-prospect.md

SLUG=""
CLIENT=""
VALUE=""
TENANT="${SAVIA_TENANT:-default}"
STAGE="discovery"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug)    SLUG="$2";    shift 2 ;;
    --client)  CLIENT="$2";  shift 2 ;;
    --value)   VALUE="$2";   shift 2 ;;
    --tenant)  TENANT="$2";  shift 2 ;;
    --stage)   STAGE="$2";   shift 2 ;;
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$SLUG" || -z "$CLIENT" || -z "$VALUE" ]]; then
  echo "ERROR: --slug, --client, and --value are required" >&2
  exit 2
fi

# Validate stage
case "$STAGE" in
  discovery|qualified|proposal|won|lost) ;;
  *) echo "ERROR: --stage must be discovery|qualified|proposal|won|lost" >&2; exit 2 ;;
esac

# Validate value is numeric
if ! [[ "$VALUE" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "ERROR: --value must be a positive number (EUR)" >&2
  exit 2
fi

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PROSPECT_DIR="${REPO_ROOT}/tenants/${TENANT}/prospects/${SLUG}"

if [[ -d "$PROSPECT_DIR" ]]; then
  echo "ERROR: Prospect '${SLUG}' already exists for tenant '${TENANT}'" >&2
  exit 1
fi

mkdir -p "$PROSPECT_DIR"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "${PROSPECT_DIR}/prospect.yaml" <<EOF
slug: "${SLUG}"
tenant: "${TENANT}"
client: "${CLIENT}"
value_eur: ${VALUE}
stage: "${STAGE}"
created_at: "${CREATED_AT}"
bant:
  budget: null
  authority: null
  need: null
  timeline: null
probability_pct: 0
notes: ""
EOF

echo "Prospect created: ${PROSPECT_DIR}/prospect.yaml"
echo "  slug:   ${SLUG}"
echo "  client: ${CLIENT}"
echo "  value:  ${VALUE} EUR"
echo "  stage:  ${STAGE}"
