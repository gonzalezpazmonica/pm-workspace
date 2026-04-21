#!/usr/bin/env bash
# oumi-probe.sh — SE-028 Slice 1 oumi integration viability probe.
#
# Evalúa preconditions para integrar oumi (framework de fine-tuning, synth, eval).
# Output: OUMI_AVAILABLE / NEEDS_INSTALL / BLOCKED.
#
# Usage:
#   oumi-probe.sh
#   oumi-probe.sh --json
#
# Exit codes:
#   0 — VIABLE o NEEDS_INSTALL
#   1 — BLOCKED
#   2 — usage error
#
# Ref: SE-028, ROADMAP §Tier 3 Champions
# Safety: read-only. set -uo pipefail.

set -uo pipefail

JSON=0

usage() {
  cat <<EOF
Usage:
  $0 [--json]

Probe preconditions for oumi (fine-tuning + synth + eval framework) integration.
Ref: SE-028.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

PYTHON_VERSION=""
PYTHON_MAJOR=0
PYTHON_MINOR=0
PIP_OK=0
OUMI_INSTALLED=0
TORCH_OK=0
DISK_FREE_GB=0

if command -v python3 >/dev/null 2>&1; then
  PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>/dev/null)
  PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
  PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)
  python3 -c "import oumi" 2>/dev/null && OUMI_INSTALLED=1
  python3 -c "import torch" 2>/dev/null && TORCH_OK=1
fi
command -v pip3 >/dev/null 2>&1 && PIP_OK=1

if command -v df >/dev/null 2>&1; then
  DISK_FREE_GB=$(df -BG "$HOME" 2>/dev/null | awk 'NR==2 {gsub("G",""); print $4}' | head -1)
  DISK_FREE_GB="${DISK_FREE_GB:-0}"
fi

VERDICT="VIABLE"
EXIT_CODE=0
REASONS=()

if [[ "$PYTHON_MAJOR" -lt 3 ]]; then
  VERDICT="BLOCKED"
  EXIT_CODE=1
  REASONS+=("Python 3 not found")
fi

if [[ "$PYTHON_MAJOR" -eq 3 && "$PYTHON_MINOR" -lt 9 ]]; then
  VERDICT="BLOCKED"
  EXIT_CODE=1
  REASONS+=("oumi requires Python ≥ 3.9, found $PYTHON_VERSION")
fi

if [[ "$OUMI_INSTALLED" -eq 0 ]]; then
  [[ "$VERDICT" == "VIABLE" ]] && VERDICT="NEEDS_INSTALL"
  REASONS+=("oumi not installed (pip install oumi)")
fi

if [[ "$TORCH_OK" -eq 0 ]]; then
  [[ "$VERDICT" == "VIABLE" ]] && VERDICT="NEEDS_INSTALL"
  REASONS+=("torch not installed (oumi dependency)")
fi

if [[ "${DISK_FREE_GB:-0}" -lt 10 ]]; then
  REASONS+=("disk free < 10GB (oumi + models require substantial space)")
fi

if [[ "$JSON" -eq 1 ]]; then
  reasons_json=""
  for r in "${REASONS[@]}"; do
    r_esc=$(echo "$r" | sed 's/"/\\"/g')
    reasons_json+="\"$r_esc\","
  done
  reasons_json="[${reasons_json%,}]"
  cat <<JSON
{"verdict":"$VERDICT","python_version":"$PYTHON_VERSION","oumi_installed":$OUMI_INSTALLED,"torch":$TORCH_OK,"pip_ok":$PIP_OK,"disk_free_gb":$DISK_FREE_GB,"reasons":$reasons_json}
JSON
else
  echo "=== SE-028 oumi Viability Probe ==="
  echo ""
  echo "Python:            ${PYTHON_VERSION:-not installed}"
  echo "oumi installed:    $([ $OUMI_INSTALLED -eq 1 ] && echo '✅' || echo '❌')"
  echo "torch:             $([ $TORCH_OK -eq 1 ] && echo '✅' || echo '❌')"
  echo "Disk free:         ${DISK_FREE_GB}GB"
  echo ""
  echo "VERDICT: $VERDICT"
  for r in "${REASONS[@]}"; do
    echo "  • $r"
  done
  echo ""
  if [[ "$VERDICT" == "NEEDS_INSTALL" ]]; then
    echo "Install:"
    echo "  pip install oumi torch"
  fi
fi

exit $EXIT_CODE
