#!/usr/bin/env bash
# Audit: every APPROVED/IMPLEMENTED spec post-2026-04-26 must include
# `## OpenCode Implementation Plan` with the 3 mandatory sub-sections.
# Reads docs/propuestas/SE-*.md and SPEC-*.md.
#
# Reference: docs/rules/domain/spec-opencode-implementation-plan.md
# Cutoff: 2026-04-26 (approved_at >= cutoff means rule applies)
# Frontmatter exemption: exempt_opencode_plan: <reason>
#
# Exit codes:
#   0 — all compliant
#   1 — at least one spec is missing the mandatory section

set -uo pipefail

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PROPUESTAS_DIR="${ROOT}/docs/propuestas"
CUTOFF="2026-04-26"
QUIET="${SPEC_OPENCODE_AUDIT_QUIET:-0}"

if [[ ! -d "${PROPUESTAS_DIR}" ]]; then
  echo "ERROR: ${PROPUESTAS_DIR} no existe" >&2
  exit 2
fi

violations=()
checked=0
exempted=0

while IFS= read -r -d '' spec; do
  # Read frontmatter (between first --- and second ---)
  fm=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "${spec}")
  [[ -z "${fm}" ]] && continue

  status=$(echo "${fm}" | grep -E '^status:' | head -1 | sed 's/^status:[[:space:]]*//' | tr -d '"' | tr '[:upper:]' '[:lower:]' | xargs)
  approved_at=$(echo "${fm}" | grep -E '^approved_at:' | head -1 | sed 's/^approved_at:[[:space:]]*//' | tr -d '"' | xargs)
  exempt=$(echo "${fm}" | grep -E '^exempt_opencode_plan:' | head -1 | sed 's/^exempt_opencode_plan:[[:space:]]*//' | xargs)

  # Apply rule only to APPROVED/IMPLEMENTED specs with approved_at >= CUTOFF
  case "${status}" in
    approved|implemented) ;;
    *) continue ;;
  esac

  if [[ -z "${approved_at}" ]]; then
    continue
  fi

  if [[ "${approved_at}" < "${CUTOFF}" ]]; then
    continue
  fi

  checked=$((checked + 1))

  if [[ -n "${exempt}" ]]; then
    exempted=$((exempted + 1))
    [[ "${QUIET}" != "1" ]] && echo "EXEMPT $(basename "${spec}") — ${exempt}"
    continue
  fi

  # Check heading + 3 mandatory sub-sections
  if ! grep -q '^## OpenCode Implementation Plan' "${spec}"; then
    violations+=("$(basename "${spec}") — missing heading '## OpenCode Implementation Plan'")
    continue
  fi

  missing_subs=()
  grep -q '^### Bindings touched' "${spec}" || missing_subs+=("Bindings touched")
  grep -q '^### Verification protocol' "${spec}" || missing_subs+=("Verification protocol")
  grep -q '^### Portability classification' "${spec}" || missing_subs+=("Portability classification")

  if [[ ${#missing_subs[@]} -gt 0 ]]; then
    violations+=("$(basename "${spec}") — sub-secciones faltantes: ${missing_subs[*]}")
  fi
done < <(find "${PROPUESTAS_DIR}" -maxdepth 1 -type f \( -name 'SE-*.md' -o -name 'SPEC-*.md' \) -print0)

if [[ "${QUIET}" != "1" ]]; then
  echo "spec-opencode-plan audit: ${checked} specs revisados, ${exempted} exempted, ${#violations[@]} violaciones"
fi

if [[ ${#violations[@]} -gt 0 ]]; then
  echo "" >&2
  echo "Violaciones (specs APPROVED/IMPLEMENTED post-${CUTOFF} sin OpenCode Implementation Plan):" >&2
  for v in "${violations[@]}"; do
    echo "  - ${v}" >&2
  done
  echo "" >&2
  echo "Ref: docs/rules/domain/spec-opencode-implementation-plan.md" >&2
  exit 1
fi

exit 0
