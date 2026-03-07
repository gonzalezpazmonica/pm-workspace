#!/bin/bash
# run-all.sh — Execute all BATS test suites
# Usage: bash tests/run-all.sh [--tap] [--filter PATTERN]
#
# Options:
#   --tap          Output in TAP format (for CI)
#   --filter PAT   Only run test files matching PAT
#
# Requires: bats (npm install -g bats || brew install bats-core)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Parse args
TAP_FLAG=""
FILTER=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --tap) TAP_FLAG="--tap"; shift ;;
    --filter) FILTER="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Check bats is installed
if ! command -v bats &>/dev/null; then
  echo "❌ bats not found. Install with: npm install -g bats"
  echo "   Or: brew install bats-core (macOS)"
  exit 1
fi

echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 pm-workspace Test Suite"
echo "═══════════════════════════════════════════════════════════════"
echo ""

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0

# Find all .bats files
BATS_FILES=$(find "$SCRIPT_DIR" -name "*.bats" -type f | sort)

if [ -n "$FILTER" ]; then
  BATS_FILES=$(echo "$BATS_FILES" | grep -i "$FILTER" || true)
fi

if [ -z "$BATS_FILES" ]; then
  echo "❌ No test files found"
  exit 1
fi

FILE_COUNT=$(echo "$BATS_FILES" | wc -l | tr -d ' ')
echo "📂 Found $FILE_COUNT test files"
echo ""

FAILED_SUITES=""

for bats_file in $BATS_FILES; do
  SUITE_NAME=$(basename "$bats_file" .bats)
  echo "▶ Running: $SUITE_NAME"

  if bats $TAP_FLAG "$bats_file"; then
    TOTAL_PASS=$((TOTAL_PASS + 1))
  else
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    FAILED_SUITES+="  ❌ $SUITE_NAME\n"
  fi
  echo ""
done

echo "═══════════════════════════════════════════════════════════════"
echo "  📊 Results: $TOTAL_PASS/$FILE_COUNT suites passed"
if [ $TOTAL_FAIL -gt 0 ]; then
  echo ""
  echo "  Failed suites:"
  echo -e "$FAILED_SUITES"
  echo "═══════════════════════════════════════════════════════════════"
  exit 1
else
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  echo "  ✅ All test suites passed"
fi
