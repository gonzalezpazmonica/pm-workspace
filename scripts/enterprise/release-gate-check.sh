#!/usr/bin/env bash
set -uo pipefail
# release-gate-check.sh — SE-014 Release Orchestration
#
# Verifica que un release cumple todos los gates antes del despliegue.
#
# Usage:
#   bash scripts/enterprise/release-gate-check.sh --version V --tenant SLUG
#
# Output JSON: {version, gates: [{name, passed, evidence}], ready_to_deploy: bool}
#
# Exit codes: 0 ready | 1 not ready (gates failing) | 2 usage error | 3 not found
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-014-release-orchestration.md

VERSION=""
TENANT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --tenant)  TENANT="$2";  shift 2 ;;
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$VERSION" || -z "$TENANT" ]]; then
  echo "ERROR: --version and --tenant are required" >&2
  exit 2
fi

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
RELEASE_FILE="${REPO_ROOT}/tenants/${TENANT}/releases/${VERSION}/release.yaml"

if [[ ! -f "$RELEASE_FILE" ]]; then
  echo "ERROR: Release not found: ${RELEASE_FILE}" >&2
  exit 3
fi

# Parse checklist items from YAML (simple grep-based parser)
# Counts items where passed: true vs total
total_gates=0
passed_gates=0
gates_json=""

while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*id:[[:space:]]*(.+)$ ]]; then
    current_id="${BASH_REMATCH[1]}"
    current_id="${current_id//\"/}"
  fi
  if [[ "$line" =~ ^[[:space:]]*description:[[:space:]]*(.+)$ ]]; then
    current_desc="${BASH_REMATCH[1]}"
    current_desc="${current_desc//\"/}"
  fi
  if [[ "$line" =~ ^[[:space:]]*passed:[[:space:]]*(true|false)$ ]]; then
    current_passed="${BASH_REMATCH[1]}"
    total_gates=$((total_gates + 1))
    if [[ "$current_passed" == "true" ]]; then
      passed_gates=$((passed_gates + 1))
      evidence="verified"
    else
      evidence="pending"
    fi
    # Append gate JSON
    if [[ -n "$gates_json" ]]; then
      gates_json="${gates_json},"
    fi
    gates_json="${gates_json}{\"name\":\"${current_id}\",\"description\":\"${current_desc}\",\"passed\":${current_passed},\"evidence\":\"${evidence}\"}"
  fi
done < "$RELEASE_FILE"

if [[ "$total_gates" -gt 0 && "$passed_gates" -eq "$total_gates" ]]; then
  ready="true"
  exit_code=0
else
  ready="false"
  exit_code=1
fi

printf '{"version":"%s","tenant":"%s","total_gates":%d,"passed_gates":%d,"gates":[%s],"ready_to_deploy":%s}\n' \
  "$VERSION" "$TENANT" "$total_gates" "$passed_gates" "$gates_json" "$ready"

exit "$exit_code"
