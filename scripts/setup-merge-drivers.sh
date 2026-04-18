#!/usr/bin/env bash
# setup-merge-drivers.sh — configure local git with the custom merge drivers
# referenced in .gitattributes. Idempotent: safe to run repeatedly.
#
# `merge=ours` in .gitattributes only works when `merge.ours.driver` is
# configured. Without this, git silently falls back to regular 3-way merge
# and conflicts reappear for .confidentiality-signature, .scm/*, etc.
#
# Ref: .gitattributes, CHANGELOG.d/README.md
# Safety: `set -uo pipefail`. Operates only on local repo git config.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# Register built-in no-op driver that always keeps "ours".
current=$(git config merge.ours.driver 2>/dev/null || echo "")
if [[ "$current" == "true" ]]; then
  echo "setup-merge-drivers: merge.ours.driver already configured"
else
  git config merge.ours.driver true
  echo "setup-merge-drivers: merge.ours.driver = true  (keeps branch version)"
fi

# Verify .gitattributes references our drivers.
if ! grep -q 'merge=ours' .gitattributes 2>/dev/null; then
  echo "WARNING: .gitattributes doesn't reference merge=ours — setup has no effect" >&2
  exit 1
fi

echo "setup-merge-drivers: ✅ drivers configured. merge=ours + merge=union will work."
