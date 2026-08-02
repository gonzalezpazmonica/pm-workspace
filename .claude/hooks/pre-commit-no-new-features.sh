#!/usr/bin/env bash
set -uo pipefail

# pre-commit-no-new-features.sh — Blocks new development in open PRs
#
# If the current branch has an open PR, this hook prevents committing
# new features (specs, packages, providers, new source modules) that
# were not part of the original PR scope.
#
# Allowed commits in open PR branches:
#   - Modifications to existing files
#   - .confidentiality-signature updates
#   - Regenerated files (SKILLS.md, AGENTS.md, RESOLVER.md)
#   - Bugfixes and CI fixes
#
# Blocked:
#   - New spec files with different SE number than the branch
#   - New source directories (src/*/ or packages/)
#   - New test files in new directories
#
# Bypass: BRANCH_PROTECTION_BYPASS=1 git commit ...

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
[ -z "$BRANCH" ] && exit 0

# Only check agent/* branches (not main, not feature/*, etc.)
[[ "$BRANCH" != agent/* ]] && exit 0

# Check if there's an open PR for this branch
OPEN_PR=$(gh pr list --head "$BRANCH" --state open --json number --jq '.[0].number' 2>/dev/null || echo "")
[ -z "$OPEN_PR" ] && exit 0

# Extract SE number from branch name (agent/se291-* -> 291)
BRANCH_SE=$(echo "$BRANCH" | grep -oP 'se\d+' | head -1 | grep -oP '\d+' || echo "")

# Get staged files
STAGED=$(git diff --cached --name-only)

NEW_FILES=$(echo "$STAGED" | grep -v '^.confidentiality-signature$' | grep -v '^CHANGELOG' || true)

BLOCKED=0
REASONS=""

# Check for new files in specs/ that don't match the branch's SE number
SPEC_FILES=$(echo "$STAGED" | grep -E 'projects/.*/specs/SE-\d+.*\.spec\.md$' || true)
if [ -n "$SPEC_FILES" ] && [ -n "$BRANCH_SE" ]; then
  for f in $SPEC_FILES; do
    FILE_SE=$(echo "$f" | grep -oP 'SE-\d+' | head -1 | grep -oP '\d+' || echo "")
    if [ "$FILE_SE" != "$BRANCH_SE" ]; then
      BLOCKED=1
      REASONS+="  $f (SE-$FILE_SE ≠ branch SE-$BRANCH_SE)\n"
    fi
  done
fi

# Check for new source directories (new feature modules)
NEW_DIRS=$(echo "$STAGED" | grep -E '^(src/|packages/)\w+/' | sed 's|/[^/]*$||' | sort -u || true)
if [ -n "$NEW_DIRS" ]; then
  for d in $NEW_DIRS; do
    # Check if this directory existed before the PR
    if ! git ls-tree -r "origin/main" --name-only 2>/dev/null | grep -q "^$d/"; then
      BLOCKED=1
      REASONS+="  New directory: $d/ (not in main)\n"
    fi
  done
fi

# Check for new test directories
NEW_TEST_DIRS=$(echo "$STAGED" | grep '^tests/' | sed 's|/[^/]*$||' | sort -u || true)
if [ -n "$NEW_TEST_DIRS" ]; then
  for d in $NEW_TEST_DIRS; do
    if ! git ls-tree -r "origin/main" --name-only 2>/dev/null | grep -q "^$d/"; then
      BLOCKED=1
      REASONS+="  New test dir: $d/ (not in main)\n"
    fi
  done
fi

if [ "$BLOCKED" -eq 1 ]; then
  echo ""
  echo "============================================================"
  echo "  BLOCKED: New feature detected in open PR branch"
  echo "============================================================"
  echo ""
  echo "  PR:    #$OPEN_PR"
  echo "  Branch: $BRANCH"
  echo ""
  echo "  This branch has an open PR. New features must go in their"
  echo "  own branch. Create a separate branch for new development:"
  echo ""
  echo "    git checkout -b savia/seXXX-description main"
  echo ""
  echo "  Blocked changes:"
  echo -e "$REASONS"
  echo ""
  echo "  Allowed in this branch: bugfixes, CI fixes, regenerated"
  echo "  catalogs, confidentiality signatures."
  echo ""
  echo "  Bypass (only for legitimate fixes):"
  echo "    BRANCH_PROTECTION_BYPASS=1 git commit ..."
  echo "============================================================"
  exit 1
fi

exit 0
