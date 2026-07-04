#!/usr/bin/env bash
# scripts/gate-teardown.sh — SE-255
# Reverts the Savia Push Gate, restoring direct origin -> GitHub.
#
# Usage:
#   bash scripts/gate-teardown.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[0;33m'; NC='\033[0m'

DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

# ── Pre-flight ────────────────────────────────────────────────────────────

if ! git config --get savia.gate.enabled &>/dev/null; then
  echo -e "${YEL}SKIP${NC}: gate is not active (savia.gate.enabled not set)"
  exit 0
fi

UPSTREAM_NAME=$(git config --get savia.gate.upstream 2>/dev/null || echo "origin-upstream")
GATE_DIR=$(git config --get savia.gate.dir 2>/dev/null || echo "")

# Verify origin-upstream exists
if ! git remote get-url "$UPSTREAM_NAME" &>/dev/null; then
  echo -e "${RED}ERROR${NC}: upstream remote '$UPSTREAM_NAME' not found"
  echo "  Cannot restore origin. Run 'git remote -v' to inspect."
  exit 1
fi

UPSTREAM_URL=$(git remote get-url "$UPSTREAM_NAME")

if $DRY_RUN; then
  echo -e "${YEL}DRY-RUN${NC}: would do:"
  echo "  1. git remote remove origin"
  echo "  2. git remote rename $UPSTREAM_NAME -> origin"
  echo "  3. git config --unset savia.gate.enabled"
  echo "  4. git config --unset savia.gate.upstream"
  [[ -n "$GATE_DIR" ]] && echo "  5. rm -rf $GATE_DIR (optional)"
  echo ""
  echo "  origin would be: $UPSTREAM_URL"
  exit 0
fi

# ── Deactivate ────────────────────────────────────────────────────────────

echo "=== Savia Push Gate Teardown ==="
echo ""

# 1. Remove origin (which points to gate)
echo -n "1. Removing gate remote (origin) ... "
git remote remove origin
echo -e "${GRN}done${NC}"

# 2. Rename upstream back to origin
echo -n "2. Renaming $UPSTREAM_NAME -> origin ... "
git remote rename "$UPSTREAM_NAME" origin
echo -e "${GRN}done${NC} (origin: $(git remote get-url origin | head -c 60)...)"

# 3. Unset gate config
echo -n "3. Removing gate config ... "
git config --unset savia.gate.enabled || true
git config --unset savia.gate.upstream || true
git config --unset savia.gate.dir || true
echo -e "${GRN}done${NC}"

# 4. Note about bare repo cleanup
if [[ -n "$GATE_DIR" && -d "$GATE_DIR" ]]; then
  echo ""
  echo -e "${YEL}Note${NC}: gate dir still exists: $GATE_DIR"
  echo "  Remove manually if no longer needed: rm -rf $GATE_DIR"
fi

echo ""
echo -e "${GRN}=== Gate deactivated ===${NC}"
echo "  origin now points directly to: $UPSTREAM_URL"
