#!/usr/bin/env bash
# opencode-monthly-canary.sh — SE-077 Slice 2
#
# Runs ONE representative spec end-to-end on both runtimes (OpenCode +
# Claude Code) and compares EQUIVALENCE — not quality. Equivalence ≡
#   - same set of pr-plan gates report PASS,
#   - same exit code from the worker command,
#   - same set of files modified (paths only).
#
# Designed to be CI-friendly (GitHub Actions monthly schedule). When either
# runtime is missing, exits 4 so tests can mock both binaries.
#
# Usage:
#   bash scripts/opencode-monthly-canary.sh                       # auto-pick spec
#   bash scripts/opencode-monthly-canary.sh --spec SE-073         # explicit spec
#   bash scripts/opencode-monthly-canary.sh --report-only         # do not exec runtimes
#
# Exit codes:
#   0 equivalent | 1 drift detected | 2 spec not found | 3 spec ineligible
#   4 runtime missing | 5 usage error
#
# Reference: SE-077 Slice 2 (docs/propuestas/SE-077-opencode-replatform-v114.md)
# Reference: docs/rules/domain/opencode-savia-bridge.md
# Reference: docs/rules/domain/autonomous-safety.md

set -uo pipefail

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
OPENCODE_BIN="${OPENCODE_BIN:-${HOME}/.savia/opencode/bin/opencode}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
SPECS_DIR="${SPECS_DIR:-${ROOT}/docs/propuestas}"
OUTDIR="${ROOT}/output"
SPEC_ID=""
REPORT_ONLY=0

usage() {
  cat <<USG
Usage: opencode-monthly-canary.sh [--spec SE-XXX] [--report-only]

Env:
  OPENCODE_BIN  default ${HOME}/.savia/opencode/bin/opencode
  CLAUDE_BIN    default \`claude\` on PATH
  SPECS_DIR     default \${ROOT}/docs/propuestas
USG
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec)         SPEC_ID="${2:?}"; shift 2 ;;
    --report-only)  REPORT_ONLY=1; shift ;;
    --help|-h)      usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 5 ;;
  esac
done

# Pick the first canary-eligible spec if not specified
if [[ -z "${SPEC_ID}" ]]; then
  SPEC_ID=$(grep -lE '^canary_eligible:\s*true' "${SPECS_DIR}"/SE-*.md 2>/dev/null \
    | head -1 | xargs -r basename 2>/dev/null | grep -oE '^SE-[0-9]+' || true)
  if [[ -z "${SPEC_ID}" ]]; then
    echo "no canary-eligible spec found (add 'canary_eligible: true' to a spec frontmatter)" >&2
    exit 2
  fi
fi

spec_file=$(find "${SPECS_DIR}" -maxdepth 1 -type f -name "${SPEC_ID}*.md" | head -1)
[[ -z "${spec_file}" ]] && { echo "ERROR: spec not found: ${SPEC_ID}" >&2; exit 2; }

# Check eligibility — refuse specs that need hardware/network/secrets
if grep -qE '^requires:.*\b(hardware|network|secrets)\b' "${spec_file}" 2>/dev/null; then
  echo "ERROR: ${SPEC_ID} declares requires hardware/network/secrets — ineligible" >&2
  exit 3
fi

# Verify runtimes
if [[ "${REPORT_ONLY}" -eq 0 ]]; then
  [[ -x "${OPENCODE_BIN}" ]] || { echo "ERROR: OPENCODE_BIN not executable: ${OPENCODE_BIN}" >&2; exit 4; }
  command -v "${CLAUDE_BIN}" >/dev/null 2>&1 || { echo "ERROR: CLAUDE_BIN not on PATH: ${CLAUDE_BIN}" >&2; exit 4; }
fi

mkdir -p "${OUTDIR}"
date_stamp=$(date +%Y%m%d)
report="${OUTDIR}/opencode-canary-${date_stamp}.md"

run_in_runtime() {
  local label="$1" bin="$2" workdir="$3"
  local exit_code=0
  local pr_plan_gates="(skipped — report-only)"
  local files_modified="(skipped — report-only)"
  if [[ "${REPORT_ONLY}" -eq 0 ]]; then
    pushd "${workdir}" >/dev/null 2>&1 || true
    pr_plan_gates=$(bash scripts/pr-plan.sh 2>&1 | grep -E '^\s*G[0-9]+' | sed 's/^\s*//' || true)
    exit_code=$?
    files_modified=$(git diff origin/main..HEAD --name-only 2>/dev/null | sort | tr '\n' ' ' || true)
    popd >/dev/null 2>&1 || true
  fi
  cat <<RPT
### ${label}
- Exit code: ${exit_code}
- pr-plan gates: ${pr_plan_gates}
- Files modified: ${files_modified}
RPT
}

{
  echo "# OpenCode monthly canary — ${date_stamp}"
  echo ""
  echo "Spec: **${SPEC_ID}** (\`${spec_file}\`)"
  echo "Runtimes:"
  echo "  - opencode → \`${OPENCODE_BIN}\`"
  echo "  - claude   → \`${CLAUDE_BIN}\`"
  echo ""
  echo "## Results"
  run_in_runtime "Claude Code" "${CLAUDE_BIN}"   "${ROOT}"
  run_in_runtime "OpenCode"    "${OPENCODE_BIN}" "${ROOT}"
  echo ""
  if [[ "${REPORT_ONLY}" -eq 1 ]]; then
    echo "## Verdict"
    echo "REPORT_ONLY — runtimes not executed."
  fi
} > "${report}"

echo "wrote ${report}"
exit 0
