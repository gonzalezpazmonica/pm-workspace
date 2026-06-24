#!/usr/bin/env bash
set -uo pipefail
# bench-register.sh — SE-022 Resource Bench Management
#
# Registra un recurso en bench (disponible para asignación).
#
# Usage:
#   bash scripts/enterprise/bench-register.sh \
#     --user SLUG --tenant SLUG \
#     --skills "python,terraform,azure" \
#     --available-from DATE [--until DATE]
#
# Crea/actualiza: tenants/{tenant}/bench/{user}.yaml
#
# Exit codes: 0 ok | 1 error | 2 usage error
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-022-resource-bench.md

USER_SLUG=""
TENANT=""
SKILLS=""
AVAILABLE_FROM=""
AVAILABLE_UNTIL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)            USER_SLUG="$2";       shift 2 ;;
    --tenant)          TENANT="$2";          shift 2 ;;
    --skills)          SKILLS="$2";          shift 2 ;;
    --available-from)  AVAILABLE_FROM="$2";  shift 2 ;;
    --until)           AVAILABLE_UNTIL="$2"; shift 2 ;;
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$USER_SLUG" || -z "$TENANT" || -z "$SKILLS" || -z "$AVAILABLE_FROM" ]]; then
  echo "ERROR: --user, --tenant, --skills, and --available-from are required" >&2
  exit 2
fi

# Validate date format (YYYY-MM-DD)
if ! [[ "$AVAILABLE_FROM" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "ERROR: --available-from must be YYYY-MM-DD" >&2
  exit 2
fi

if [[ -n "$AVAILABLE_UNTIL" ]] && ! [[ "$AVAILABLE_UNTIL" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "ERROR: --until must be YYYY-MM-DD" >&2
  exit 2
fi

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
BENCH_DIR="${REPO_ROOT}/tenants/${TENANT}/bench"
mkdir -p "$BENCH_DIR"

BENCH_FILE="${BENCH_DIR}/${USER_SLUG}.yaml"
REGISTERED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Build skills YAML list
skills_yaml=""
IFS=',' read -ra skill_arr <<< "$SKILLS"
for skill in "${skill_arr[@]}"; do
  skill="${skill// /}"  # trim whitespace
  [[ -z "$skill" ]] && continue
  skills_yaml="${skills_yaml}  - ${skill}"$'\n'
done

cat > "$BENCH_FILE" <<EOF
user: "${USER_SLUG}"
tenant: "${TENANT}"
registered_at: "${REGISTERED_AT}"
available_from: "${AVAILABLE_FROM}"
available_until: "${AVAILABLE_UNTIL:-}"
skills:
${skills_yaml}status: available
allocation_pct: 0
current_project: null
bench_days: 0
EOF

echo "Bench entry created/updated: ${BENCH_FILE}"
echo "  user:            ${USER_SLUG}"
echo "  tenant:          ${TENANT}"
echo "  skills:          ${SKILLS}"
echo "  available_from:  ${AVAILABLE_FROM}"
echo "  available_until: ${AVAILABLE_UNTIL:-open}"
