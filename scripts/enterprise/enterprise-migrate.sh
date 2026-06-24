#!/usr/bin/env bash
# enterprise-migrate.sh — Unified migration command: Core -> Enterprise
# SPEC: SPEC-SE-010 Migration Path & Backward Compat
#
# Usage:
#   scripts/enterprise/enterprise-migrate.sh <subcommand> [args]
#
# Subcommands:
#   check              -- validates Core installation compatibility
#   enable  MODULE     -- activates a module (updates manifest.json)
#   disable MODULE     -- deactivates a module with rollback
#   status             -- lists state of all modules
#
# All output is JSON.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
MANIFEST="$PROJECT_DIR/.claude/enterprise/manifest.json"
PY_HELPERS="$SCRIPT_DIR/../lib/enterprise-migrate-helpers.py"

die_json() {
  python3 -c "import json,sys; print(json.dumps({'error': sys.argv[1]}))" "$1" >&2
  exit 1
}

require_manifest() {
  [[ -f "$MANIFEST" ]] || die_json "manifest.json not found -- Savia Enterprise not installed"
}

cmd_check() {
  require_manifest
  python3 "$PY_HELPERS" check "$PROJECT_DIR" "$MANIFEST"
}

cmd_status() {
  require_manifest
  python3 "$PY_HELPERS" status "$MANIFEST"
}

cmd_enable() {
  local module="$1"
  require_manifest
  python3 "$PY_HELPERS" enable "$MANIFEST" "$module"
}

cmd_disable() {
  local module="$1"
  require_manifest
  "$SCRIPT_DIR/rollback-module.sh" --module "$module"
}

SUBCMD="${1:-}"

case "$SUBCMD" in
  check)
    cmd_check ;;
  status)
    cmd_status ;;
  enable)
    [[ $# -lt 2 ]] && die_json "enable requires MODULE argument"
    cmd_enable "$2" ;;
  disable)
    [[ $# -lt 2 ]] && die_json "disable requires MODULE argument"
    cmd_disable "$2" ;;
  --help|-h|help)
    python3 "$PY_HELPERS" help ;;
  "")
    cmd_status ;;
  *)
    die_json "Unknown subcommand: $SUBCMD. Use: check, enable, disable, status" ;;
esac
