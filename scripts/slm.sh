#!/usr/bin/env bash
# slm.sh — Unified SLM (Small Language Model) training toolchain dispatcher.
#
# SE-049 Slice 1 — scaffolding + routing. Slice 2 migrates per-subcommand
# logic into this dispatcher + shared lib. Slice 3 deprecates original
# scripts/slm-*.sh scripts.
#
# Usage:
#   slm.sh <subcommand> [args...]      # route to target script
#   slm.sh list                        # list registered subcommands
#   slm.sh --help | -h | help          # this help text
#   slm.sh --json list                 # JSON output of registry
#
# Exit codes:
#   0 — subcommand succeeded OR help/list
#   1 — subcommand failed (propagates child exit)
#   2 — usage error (unknown subcommand, missing args)
#
# Ref: SE-049 SLM command consolidation
# Safety: read-only dispatcher. Does not modify repo state itself.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared library
LIB="$SCRIPT_DIR/lib/slm-common.sh"
if [[ ! -f "$LIB" ]]; then
  echo "ERROR: shared library not found: $LIB" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$LIB"

usage() {
  cat <<EOF
slm.sh — Unified SLM training toolchain dispatcher (SE-049)

Usage:
  slm.sh <subcommand> [args...]     Route to target script
  slm.sh list                       List registered subcommands
  slm.sh --help | -h | help         Show this help
  slm.sh --json list                JSON registry output

Common subcommands (Slice 1 registry):

$(slm_print_registry_table)

Examples:
  slm.sh collect --source specs --output datasets/raw.jsonl
  slm.sh train --config configs/proj-a.yaml
  slm.sh list

Ref: docs/propuestas/SE-049-slm-command-consolidation-pattern-slm-sh.md
EOF
}

# Parse top-level flags (before subcommand)
JSON_OUT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUT=1; shift ;;
    -h|--help|help) usage; exit 0 ;;
    --) shift; break ;;
    -*) slm_die "unknown top-level flag: $1" 2 ;;
    *) break ;;
  esac
done

# No subcommand provided
if [[ $# -eq 0 ]]; then
  usage
  exit 2
fi

SUBCOMMAND="$1"
shift

# Handle list subcommand (doesn't route to a script)
if [[ "$SUBCOMMAND" == "list" ]]; then
  if [[ "$JSON_OUT" -eq 1 ]]; then
    # Emit JSON array of {subcommand, target}
    printf '{"subcommands":['
    sep=""
    while IFS= read -r k; do
      printf '%s{"name":"%s","target":"%s"}' "$sep" "$k" "${SLM_REGISTRY[$k]}"
      sep=","
    done < <(slm_list_subcommands)
    printf ']}\n'
  else
    slm_list_subcommands
  fi
  exit 0
fi

# Resolve subcommand to target script
TARGET="$(slm_resolve_subcommand "$SUBCOMMAND")" || {
  slm_die "unknown subcommand: $SUBCOMMAND (run: slm.sh list)" 2
}

TARGET_PATH="$SCRIPT_DIR/$TARGET"
if [[ ! -x "$TARGET_PATH" ]]; then
  slm_die "target script not executable: $TARGET_PATH" 2
fi

# Exec dispatch — preserves args, exit code, and signals
exec bash "$TARGET_PATH" "$@"
