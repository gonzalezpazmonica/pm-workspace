#!/usr/bin/env bash
# code-twin-load.sh — SPEC-190 Slice 8 (AC-10)
# Token-budget-aware CTF loader. In summary mode (CODE_TWIN_CONTEXT_USED ≥ 80),
# strips **Logic** blocks and numbered steps to reduce token cost ≥ 50 %.
#
# Usage:
#   code-twin-load.sh <module_id> [--twin <dir>]
#
# Environment:
#   CODE_TWIN_CONTEXT_USED  — percent (0-100) of context window consumed
#   CODE_TWIN_DIR           — default twin directory (overridden by --twin)
#
# Exit codes:
#   0 — CTF found and printed
#   1 — module not found
#   2 — argument / IO error
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODULE_ID=""
TWIN_DIR="${CODE_TWIN_DIR:-code-twin}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --twin)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --twin requires an argument" >&2
        exit 2
      fi
      TWIN_DIR="$2"
      shift 2
      ;;
    -*)
      echo "ERROR: unknown option: $1" >&2
      exit 2
      ;;
    *)
      MODULE_ID="$1"
      shift
      ;;
  esac
done

if [[ -z "$MODULE_ID" ]]; then
  echo "Usage: code-twin-load.sh <module_id> [--twin <dir>]" >&2
  exit 2
fi

if [[ ! -d "$TWIN_DIR" ]]; then
  echo "ERROR: twin directory not found: $TWIN_DIR" >&2
  exit 2
fi

# Find CTF file by scanning module_id frontmatter
CTF_FILE=""
while IFS= read -r -d '' f; do
  if grep -q "^module_id: ${MODULE_ID}$" "$f" 2>/dev/null; then
    CTF_FILE="$f"
    break
  fi
done < <(find "$TWIN_DIR" -name "*.md" ! -name "index.md" -print0)

if [[ -z "$CTF_FILE" ]]; then
  echo "ERROR: module not found: ${MODULE_ID}" >&2
  exit 1
fi

# Token budget check (env var CODE_TWIN_CONTEXT_USED, default 0)
CONTEXT_USED="${CODE_TWIN_CONTEXT_USED:-0}"

if [[ "$CONTEXT_USED" -ge 80 ]]; then
  echo "[WARN] token budget ${CONTEXT_USED}% — loading CTF summary mode" >&2
  # Summary mode: strip Logic blocks and numbered steps
  python3 - "$CTF_FILE" << 'PYEOF'
import sys, re

with open(sys.argv[1], encoding='utf-8') as fh:
    content = fh.read()

# Remove numbered list items (logic steps: "1. some text")
content = re.sub(r'\n\d+\. [^\n]+', '', content)
# Remove **Logic**: label lines
content = re.sub(r'\n\*\*Logic\*\*:\s*', '\n', content)
# Remove **Returns**: lines
content = re.sub(r'\n\*\*Returns\*\*: [^\n]+', '', content)
# Collapse runs of 3+ blank lines to 2
content = re.sub(r'\n{3,}', '\n\n', content)

print(content.rstrip())
PYEOF
else
  cat "$CTF_FILE"
fi
