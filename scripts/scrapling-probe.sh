#!/usr/bin/env bash
# scrapling-probe.sh — SE-061 Slice 1 Scrapling viability probe.
#
# Evalúa preconditions para integrar Scrapling (adaptive web scraping, BSD-3).
# Output: VIABLE / NEEDS_INSTALL / BLOCKED.
#
# Usage:
#   scrapling-probe.sh
#   scrapling-probe.sh --json
#   scrapling-probe.sh --check-browser     # also checks Chromium/Playwright availability
#
# Exit codes:
#   0 — VIABLE o NEEDS_INSTALL
#   1 — BLOCKED (Python < 3.10 o no python3)
#   2 — usage error
#
# Ref: SE-061, output/research/scrapling-20260421.md, ROADMAP §Era 183 Tier 3
# Safety: read-only. set -uo pipefail. Zero egress.

set -uo pipefail

JSON=0
CHECK_BROWSER=0

usage() {
  cat <<EOF
Usage:
  $0 [--json] [--check-browser]

Probe preconditions for Scrapling (adaptive scraping backend) integration.
Ref: SE-061, output/research/scrapling-20260421.md.

Options:
  --json            Machine-readable output
  --check-browser   Also probe Chromium/Playwright availability (opt-in, fetchers extra)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --check-browser) CHECK_BROWSER=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

PYTHON_VERSION=""
PYTHON_MAJOR=0
PYTHON_MINOR=0
PIP_OK=0
SCRAPLING_INSTALLED=0
LXML_OK=0
PLAYWRIGHT_OK=0
CHROMIUM_OK=0
DISK_FREE_GB=0

if command -v python3 >/dev/null 2>&1; then
  PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>/dev/null)
  PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
  PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)
  python3 -c "import scrapling" 2>/dev/null && SCRAPLING_INSTALLED=1
  python3 -c "import lxml" 2>/dev/null && LXML_OK=1
  if [[ "$CHECK_BROWSER" -eq 1 ]]; then
    python3 -c "import playwright" 2>/dev/null && PLAYWRIGHT_OK=1
  fi
fi
command -v pip3 >/dev/null 2>&1 && PIP_OK=1

if [[ "$CHECK_BROWSER" -eq 1 ]]; then
  command -v chromium >/dev/null 2>&1 && CHROMIUM_OK=1
  command -v chromium-browser >/dev/null 2>&1 && CHROMIUM_OK=1
  command -v google-chrome >/dev/null 2>&1 && CHROMIUM_OK=1
fi

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

if [[ "$PYTHON_MAJOR" -eq 3 && "$PYTHON_MINOR" -lt 10 ]]; then
  VERDICT="BLOCKED"
  EXIT_CODE=1
  REASONS+=("Scrapling requires Python >= 3.10, found $PYTHON_VERSION")
fi

if [[ "$SCRAPLING_INSTALLED" -eq 0 && "$EXIT_CODE" -eq 0 ]]; then
  VERDICT="NEEDS_INSTALL"
  REASONS+=("scrapling not installed (pip install scrapling)")
fi

if [[ "$LXML_OK" -eq 0 && "$EXIT_CODE" -eq 0 ]]; then
  [[ "$VERDICT" == "VIABLE" ]] && VERDICT="NEEDS_INSTALL"
  REASONS+=("lxml not installed (scrapling core dependency)")
fi

if [[ "$CHECK_BROWSER" -eq 1 ]]; then
  if [[ "$PLAYWRIGHT_OK" -eq 0 ]]; then
    REASONS+=("playwright not installed (scrapling[fetchers] extra, optional)")
  fi
  if [[ "$CHROMIUM_OK" -eq 0 ]]; then
    REASONS+=("no chromium browser found (required for anti-bot bypass fetchers)")
  fi
fi

if [[ "${DISK_FREE_GB:-0}" -lt 2 ]]; then
  REASONS+=("disk free < 2GB (scrapling core ~50MB; fetchers + browser ~500MB)")
fi

if [[ "$JSON" -eq 1 ]]; then
  reasons_json=""
  for r in "${REASONS[@]}"; do
    r_esc=$(echo "$r" | sed 's/"/\\"/g')
    reasons_json+="\"$r_esc\","
  done
  reasons_json="[${reasons_json%,}]"
  cat <<JSON
{"verdict":"$VERDICT","python_version":"$PYTHON_VERSION","scrapling_installed":$SCRAPLING_INSTALLED,"lxml":$LXML_OK,"playwright":$PLAYWRIGHT_OK,"chromium":$CHROMIUM_OK,"pip_ok":$PIP_OK,"disk_free_gb":$DISK_FREE_GB,"check_browser":$CHECK_BROWSER,"reasons":$reasons_json}
JSON
else
  echo "=== SE-061 Scrapling Viability Probe ==="
  echo ""
  echo "Python:            ${PYTHON_VERSION:-not installed}"
  echo "scrapling:         $([ $SCRAPLING_INSTALLED -eq 1 ] && echo 'installed' || echo 'not installed')"
  echo "lxml:              $([ $LXML_OK -eq 1 ] && echo 'installed' || echo 'not installed')"
  if [[ "$CHECK_BROWSER" -eq 1 ]]; then
    echo "playwright:        $([ $PLAYWRIGHT_OK -eq 1 ] && echo 'installed' || echo 'not installed')"
    echo "chromium:          $([ $CHROMIUM_OK -eq 1 ] && echo 'available' || echo 'not found')"
  fi
  echo "Disk free:         ${DISK_FREE_GB}GB"
  echo ""
  echo "VERDICT: $VERDICT"
  for r in "${REASONS[@]}"; do
    echo "  - $r"
  done
  echo ""
  if [[ "$VERDICT" == "NEEDS_INSTALL" ]]; then
    echo "Install (core, sin browser):"
    echo "  pip install scrapling"
    if [[ "$CHECK_BROWSER" -eq 1 && "$PLAYWRIGHT_OK" -eq 0 ]]; then
      echo ""
      echo "Install fetchers (anti-bot bypass):"
      echo "  pip install 'scrapling[fetchers]'"
      echo "  playwright install chromium"
    fi
  fi
fi

exit $EXIT_CODE
