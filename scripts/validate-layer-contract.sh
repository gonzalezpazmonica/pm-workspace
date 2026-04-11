#!/usr/bin/env bash
# validate-layer-contract.sh — SE-001 layer contract validator
#
# Enforces Savia Enterprise layer contract:
#   Core NEVER imports from .claude/enterprise/
#   Enterprise MAY import from .claude/rules/domain/ and other Core paths
#
# Usage:
#   bash scripts/validate-layer-contract.sh                    # scan all files
#   bash scripts/validate-layer-contract.sh <file> [<file>...] # scan specific files
#
# Exit codes:
#   0 — no violations
#   1 — violations detected
#   2 — usage error

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 2

# Core paths that must NOT reference .claude/enterprise/
CORE_PATHS=(
  ".claude/agents"
  ".claude/commands"
  ".claude/skills"
  ".claude/rules"
  ".claude/hooks"
  "CLAUDE.md"
)

# Pattern that indicates a Core→Enterprise import (forbidden)
FORBIDDEN_PATTERN='@\.claude/enterprise/|\.claude/enterprise/'

violations=0
scanned=0

scan_file() {
  local file="$1"
  [[ ! -f "$file" ]] && return 0
  scanned=$((scanned + 1))

  # Skip the hook and script themselves (they legitimately mention the path)
  case "$file" in
    scripts/validate-layer-contract.sh) return 0 ;;
    .claude/hooks/validate-layer-contract.sh) return 0 ;;
    .claude/enterprise/*) return 0 ;;
    docs/*) return 0 ;;
    tests/*) return 0 ;;
    CHANGELOG.md) return 0 ;;
  esac

  # Only check files that belong to Core paths
  local is_core=0
  for core_path in "${CORE_PATHS[@]}"; do
    if [[ "$file" == "$core_path"* ]] || [[ "$file" == "$core_path" ]]; then
      is_core=1
      break
    fi
  done
  [[ $is_core -eq 0 ]] && return 0

  if grep -qE "$FORBIDDEN_PATTERN" "$file" 2>/dev/null; then
    echo "VIOLATION: $file references .claude/enterprise/" >&2
    grep -nE "$FORBIDDEN_PATTERN" "$file" 2>/dev/null | sed 's/^/    /' >&2
    violations=$((violations + 1))
  fi
}

if [[ $# -gt 0 ]]; then
  for f in "$@"; do
    scan_file "$f"
  done
else
  # Full scan: walk Core paths
  while IFS= read -r f; do
    scan_file "$f"
  done < <(find "${CORE_PATHS[@]}" -type f \( -name "*.md" -o -name "*.sh" -o -name "*.json" \) 2>/dev/null)
fi

if [[ $violations -gt 0 ]]; then
  echo "" >&2
  echo "Layer contract violated: $violations file(s) in Core reference Enterprise." >&2
  echo "Core must never depend on .claude/enterprise/ (SE-001)." >&2
  echo "Fix: remove the reference or move the file into .claude/enterprise/" >&2
  exit 1
fi

echo "Layer contract OK ($scanned file(s) scanned, 0 violations)"
exit 0
