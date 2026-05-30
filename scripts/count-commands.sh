#!/usr/bin/env bash
# count-commands.sh — SE-095: canonical counter for slash commands.
#
# Rule: a "command" is an invokable `.md` file under `.claude/commands/`,
# excluding catalogs, indexes and READMEs (which are documentation, not
# invokable commands). This is the single source of truth for any document
# (pm-workflow.md, AGENTS.md, README.md, audits) that needs to cite a
# command count. Drift between docs and filesystem is detected by piping
# this output into the relevant check script.
#
# Ref: SE-095, ROADMAP.md §Tier 0
# Safety: `set -uo pipefail`. Read-only. No destructive ops.
#
# Usage:
#   scripts/count-commands.sh              # prints just the integer count
#   scripts/count-commands.sh --verbose    # prints count + breakdown
#   scripts/count-commands.sh --list       # prints one path per line

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
COMMANDS_DIR="$REPO_ROOT/.claude/commands"

if [[ ! -d "$COMMANDS_DIR" ]]; then
  echo "ERROR: $COMMANDS_DIR not found" >&2
  exit 1
fi

# Exclusion criteria (canonical):
#  - README* (case-insensitive)        -> documentation
#  - *catalog*.md (case-insensitive)   -> command/intent/tool/product catalogs
#  - index-*.md                        -> index utilities (rebuild/compact/status)
#
# Note: index-*.md are excluded because they are framework plumbing exposed
# as slash commands but not user-facing workflow commands. If criterion ever
# changes, update this script AND re-run drift check.

list_commands() {
  find "$COMMANDS_DIR" -name '*.md' -type f \
    ! -iname 'README*' \
    ! -iname '*catalog*' \
    ! -iname 'index-*' \
    -print
}

count_total_raw() {
  find "$COMMANDS_DIR" -name '*.md' -type f | wc -l | tr -d ' '
}

count_commands() {
  list_commands | wc -l | tr -d ' '
}

mode="${1:-count}"
case "$mode" in
  --list)
    list_commands | sort
    ;;
  --verbose|-v)
    total=$(count_total_raw)
    cmds=$(count_commands)
    excluded=$((total - cmds))
    echo "Repository    : $REPO_ROOT"
    echo "Commands dir  : $COMMANDS_DIR"
    echo "Total .md     : $total"
    echo "Excluded      : $excluded (README/catalog/index-*)"
    echo "Commands      : $cmds"
    ;;
  count|*)
    count_commands
    ;;
esac
