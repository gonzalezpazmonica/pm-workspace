#!/bin/bash
# install.sh — OpenCode installer wrapper (redirects to main installer)
# Usage: curl -fsSL https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/.opencode/install.sh | bash
#
# DEPRECATED: The main install.sh is now OpenCode-first.
# This wrapper exists for backward compatibility with existing docs/links.
# It delegates to the root install.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_INSTALLER="${SCRIPT_DIR}/../install.sh"

if [[ -f "$ROOT_INSTALLER" ]]; then
  exec bash "$ROOT_INSTALLER" "$@"
else
  echo "ERROR: root installer not found at $ROOT_INSTALLER" >&2
  echo "Download it from: https://raw.githubusercontent.com/gonzalezpazmonica/pm-workspace/main/install.sh" >&2
  exit 1
fi
