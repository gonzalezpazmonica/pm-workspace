#!/bin/bash
set -uo pipefail
# ua-install.sh — Install Understand-Anything plugin for Savia
# Usage: bash scripts/ua-install.sh [--force]

UA_REPO="https://github.com/Lum1104/Understand-Anything"
UA_DIR="$HOME/.opencode/understand-anything"
SKILLS_DIR="$HOME/.agents/skills"

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

if [[ -d "$UA_DIR" ]] && ! $FORCE; then
  echo "Understand-Anything already installed at $UA_DIR"
  echo "Use --force to reinstall"
  exit 0
fi

echo "=== Installing Understand-Anything ==="
echo "Repo:  $UA_REPO"
echo "Path:  $UA_DIR"
echo ""

# Clone
if [[ -d "$UA_DIR" ]]; then
  echo "Updating existing clone..."
  git -C "$UA_DIR" pull
else
  echo "Cloning..."
  git clone --depth 1 "$UA_REPO" "$UA_DIR"
fi

# Install dependencies
cd "$UA_DIR"
if command -v pnpm &>/dev/null; then
  echo "Installing with pnpm..."
  pnpm install --frozen-lockfile 2>/dev/null || pnpm install
elif command -v npm &>/dev/null; then
  echo "pnpm not found, trying npm..."
  npm install --legacy-peer-deps 2>/dev/null || npm install
else
  echo "WARNING: neither pnpm nor npm found. Plugin may not work without dependencies."
  echo "Install Node.js + pnpm: https://pnpm.io/installation"
fi

# Create symlinks for skills
mkdir -p "$SKILLS_DIR"
for skill_dir in "$UA_DIR/understand-anything-plugin/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  ln -sfn "$skill_dir" "$SKILLS_DIR/$skill_name" 2>/dev/null && \
    echo "  linked skill: $skill_name"
done

# Create symlink for plugin
ln -sfn "$UA_DIR/understand-anything-plugin" "$HOME/.understand-anything-plugin" 2>/dev/null && \
  echo "  linked plugin: ~/.understand-anything-plugin"

echo ""
echo "=== Installation complete ==="
echo "Skills installed in: $SKILLS_DIR"
echo "Plugin installed in: $HOME/.understand-anything-plugin"
echo ""
echo "Try: /ua-analyze ~/claude"
