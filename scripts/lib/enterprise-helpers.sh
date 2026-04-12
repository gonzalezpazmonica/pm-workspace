#!/usr/bin/env bash
# enterprise-helpers.sh — Sourceable helpers for Enterprise module checks
# SPEC: SE-010 Migration Path
#
# Source this file from hooks or scripts that need to check module state:
#   source scripts/lib/enterprise-helpers.sh
#   if enterprise_enabled "multi-tenant"; then ... fi

ENTERPRISE_MANIFEST="${CLAUDE_PROJECT_DIR:-.}/.claude/enterprise/manifest.json"

enterprise_enabled() {
  local module="$1"
  [[ ! -f "$ENTERPRISE_MANIFEST" ]] && return 1
  python3 -c "
import json,sys
d=json.load(open('$ENTERPRISE_MANIFEST'))
m=d.get('modules',{}).get('$module',{})
sys.exit(0 if m.get('enabled') else 1)
" 2>/dev/null
}

enterprise_version() {
  [[ ! -f "$ENTERPRISE_MANIFEST" ]] && echo "none" && return
  python3 -c "import json; print(json.load(open('$ENTERPRISE_MANIFEST')).get('version','none'))" 2>/dev/null || echo "none"
}

enterprise_mode() {
  [[ ! -f "$ENTERPRISE_MANIFEST" ]] && echo "community" && return
  local enabled
  enabled=$(python3 -c "import json; print(sum(1 for m in json.load(open('$ENTERPRISE_MANIFEST')).get('modules',{}).values() if m.get('enabled')))" 2>/dev/null) || enabled="0"
  [[ "$enabled" -gt 0 ]] && echo "enterprise" || echo "community"
}
