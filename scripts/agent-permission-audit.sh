#!/usr/bin/env bash
# agent-permission-audit.sh — SE-270 Slice 4: Audit permission.task declarations.
#
# Checks all 81 agents have permission.task declared in frontmatter.
# Verifies deny-by-default pattern (no task key → no subagent delegation).
# Reports agents without permission declarations.
# Exit 0 if all have it, exit 1 if any missing.
#
# Ref: SE-270, Rule #22
# Safety: set -uo pipefail. Read-only. No destructive ops.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
AGENTS_DIR="${AGENTS_DIR:-$REPO_ROOT/.opencode/agents}"

usage() {
  cat <<EOF
Usage: $0 [--verbose] [--agents-dir PATH]

Audits .opencode/agents/*.md for permission.task declarations.
Checks deny-by-default pattern compliance.

  --verbose       Print per-agent status.
  --agents-dir    Override agents directory (default: $AGENTS_DIR).

Exit codes:
  0 — all agents have permission.task declared
  1 — one or more agents missing permission.task
  2 — usage error
EOF
}

VERBOSE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) VERBOSE=1; shift ;;
    --agents-dir) AGENTS_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

if [[ ! -d "$AGENTS_DIR" ]]; then
  echo "ERROR: agents directory not found: $AGENTS_DIR" >&2
  exit 2
fi

total=0
have_permission=0
missing_permission=0
HAVE_LIST=()
MISSING_LIST=()

while IFS= read -r -d '' agent_file; do
  name=$(basename "$agent_file" .md)
  total=$((total+1))

  # Check for permission.task in frontmatter (between first --- and second ---)
  if awk '
    /^---$/{ if(++c==2) exit; next }
    c==1 && /^[[:space:]]*permission\.task:/ { found=1; exit }
    END { exit found ? 0 : 1 }
  ' "$agent_file" 2>/dev/null; then
    have_permission=$((have_permission+1))
    HAVE_LIST+=("$name")
    if [[ "$VERBOSE" -eq 1 ]]; then
      echo "  OK    $name"
    fi
  else
    missing_permission=$((missing_permission+1))
    MISSING_LIST+=("$name")
    if [[ "$VERBOSE" -eq 1 ]]; then
      echo "  MISS  $name"
    fi
  fi
done < <(find "$AGENTS_DIR" -maxdepth 1 -type f -name '*.md' -print0 | sort -z)

echo "=== Agent Permission Audit ==="
echo "  Total agents:          $total"
echo "  Have permission.task:  $have_permission"
echo "  Missing permission:    $missing_permission"

if [[ "$missing_permission" -gt 0 ]]; then
  echo ""
  echo "Agents without permission.task declaration:"
  for agent in "${MISSING_LIST[@]}"; do
    echo "  - $agent"
  done
  echo ""
  echo "Deny-by-default: agents without task permission cannot delegate to subagents."
  echo "Add 'permission.task: allowlist' with reasonable targets to enable delegation."
  exit 1
else
  echo ""
  echo "All agents have permission.task declared. Deny-by-default compliance: PASS"
fi

exit 0
