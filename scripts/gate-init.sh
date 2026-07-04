#!/usr/bin/env bash
# scripts/gate-init.sh — SE-255
# Activates the Savia Push Gate via remote swap.
# Runs ONCE per repo. Idempotent.
#
# Usage:
#   bash scripts/gate-init.sh
#
# What it does:
#   1. Renames origin -> origin-upstream (GitHub real)
#   2. Creates bare repo gate at ~/.savia/gate.git
#   3. Installs post-receive hook
#   4. Points origin to the gate
#
# Revert with: bash scripts/gate-teardown.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GATE_DIR="${SAVIA_GATE_DIR:-$HOME/.savia/gate.git}"
UPSTREAM_NAME="origin-upstream"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --gate-dir) GATE_DIR="$2"; shift 2 ;;
    *) shift ;;
  esac
done

cd "$REPO_ROOT"

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[0;33m'; NC='\033[0m'

# ── Pre-flight ────────────────────────────────────────────────────────────

if ! git rev-parse --git-dir &>/dev/null; then
  echo -e "${RED}ERROR${NC}: not a git repository"
  exit 1
fi

CURRENT_ORIGIN=$(git remote get-url origin 2>/dev/null || echo "")

# Check if gate is already active
if git config --get savia.gate.enabled &>/dev/null; then
  echo -e "${YEL}SKIP${NC}: gate already active (savia.gate.enabled=true)"
  echo "  origin: $(git remote get-url origin 2>/dev/null)"
  echo "  upstream: $(git remote get-url origin-upstream 2>/dev/null || echo 'not set')"
  echo ""
  echo "  To re-initialize: bash scripts/gate-teardown.sh && bash scripts/gate-init.sh"
  echo "  To deactivate:    bash scripts/gate-teardown.sh"
  exit 0
fi

# Check origin exists and is not already a local path
if [[ -z "$CURRENT_ORIGIN" ]]; then
  echo -e "${RED}ERROR${NC}: no 'origin' remote found"
  exit 1
fi

if [[ "$CURRENT_ORIGIN" == "$GATE_DIR" ]]; then
  echo -e "${YEL}SKIP${NC}: origin already points to gate dir"
  exit 0
fi

# Check origin-upstream doesn't already exist
if git remote get-url "$UPSTREAM_NAME" &>/dev/null; then
  echo -e "${RED}ERROR${NC}: remote '$UPSTREAM_NAME' already exists. Unclean state."
  echo "  Run 'git remote -v' to inspect."
  exit 1
fi

# ── Activate ──────────────────────────────────────────────────────────────

echo "=== Savia Push Gate Init ==="
echo ""

if $DRY_RUN; then
  echo -e "${YEL}DRY-RUN${NC}: would do:"
  echo "  1. git remote rename origin -> $UPSTREAM_NAME"
  echo "  2. git init --bare $GATE_DIR"
  echo "  3. cp scripts/gate-post-receive.sh -> $GATE_DIR/hooks/post-receive"
  echo "  4. git remote add origin $GATE_DIR"
  echo "  5. git --git-dir=$GATE_DIR remote add upstream <url>"
  echo "  6. git config savia.gate.enabled true"
  echo ""
  echo "  Current origin: $CURRENT_ORIGIN"
  exit 0
fi

# 1. Rename origin -> origin-upstream
echo -n "1. Renaming origin -> $UPSTREAM_NAME ... "
git remote rename origin "$UPSTREAM_NAME"
echo -e "${GRN}done${NC} (upstream: $(git remote get-url $UPSTREAM_NAME | head -c 50)...)"

# 2. Create bare repo gate
echo -n "2. Creating gate at $GATE_DIR ... "
mkdir -p "$(dirname "$GATE_DIR")"
git init --bare --quiet "$GATE_DIR"
echo -e "${GRN}done${NC}"

# 3. Install post-receive hook
echo -n "3. Installing post-receive hook ... "
HOOK_SRC="$SCRIPT_DIR/gate-post-receive.sh"
if [[ ! -f "$HOOK_SRC" ]]; then
  echo -e "${RED}ERROR${NC}: $HOOK_SRC not found"
  exit 1
fi
cp "$HOOK_SRC" "$GATE_DIR/hooks/post-receive"
chmod +x "$GATE_DIR/hooks/post-receive"
echo -e "${GRN}done${NC}"

# 4. Point origin to gate
echo -n "4. Pointing origin to gate ... "
git remote add origin "$GATE_DIR"
echo -e "${GRN}done${NC}"

# 5. Configure upstream remote in the bare repo so the hook can forward
echo -n "5. Configuring upstream in bare repo ... "
git --git-dir="$GATE_DIR" remote add upstream "$CURRENT_ORIGIN"
echo -e "${GRN}done${NC}"

# 6. Register metadata
echo -n "6. Registering gate config ... "
git config savia.gate.enabled true
git config savia.gate.upstream "$UPSTREAM_NAME"
git config savia.gate.dir "$GATE_DIR"
echo -e "${GRN}done${NC}"

echo ""
echo -e "${GRN}=== Gate activated ===${NC}"
echo ""
echo "  origin:   $GATE_DIR (gate)"
echo "  upstream: $(git --git-dir="$GATE_DIR" remote get-url upstream | head -c 60)..."
echo ""
echo "  git push origin <rama>  -> gate runs pr-plan -> forwards if green"
echo "  Revert: bash scripts/gate-teardown.sh"
