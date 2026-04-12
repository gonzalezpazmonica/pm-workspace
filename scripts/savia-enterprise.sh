#!/usr/bin/env bash
set -uo pipefail
# savia-enterprise.sh — Enterprise module lifecycle manager
# SPEC: SE-010 Migration Path & Backward Compat
#
# Subcommands: status, modules, enable, disable, uninstall, migrate-data
# All changes are opt-in and reversible.

MANIFEST="${CLAUDE_PROJECT_DIR:-.}/.claude/enterprise/manifest.json"
ENTERPRISE_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/enterprise"

die() { echo "ERROR: $*" >&2; exit 2; }

_require_manifest() {
  [[ -f "$MANIFEST" ]] || die "No manifest.json found at $MANIFEST. Is Savia Enterprise installed?"
}

_read_module() {
  local module="$1"
  python3 -c "
import json,sys
d=json.load(open('$MANIFEST'))
m=d.get('modules',{}).get('$module')
if not m: print('NOT_FOUND'); sys.exit(1)
print('enabled' if m.get('enabled') else 'disabled')
" 2>/dev/null || echo "NOT_FOUND"
}

_set_module() {
  local module="$1" state="$2"
  python3 -c "
import json
with open('$MANIFEST') as f: d=json.load(f)
if '$module' not in d.get('modules',{}):
    print('ERROR: Module $module not found in manifest'); exit(1)
d['modules']['$module']['enabled'] = $state
with open('$MANIFEST','w') as f: json.dump(d,f,indent=2)
print('OK')
" 2>/dev/null || die "Failed to update manifest"
}

cmd_status() {
  _require_manifest
  local version
  version=$(python3 -c "import json; print(json.load(open('$MANIFEST')).get('version','?'))" 2>/dev/null) || version="?"
  local total enabled
  total=$(python3 -c "import json; print(len(json.load(open('$MANIFEST')).get('modules',{})))" 2>/dev/null) || total="?"
  enabled=$(python3 -c "import json; print(sum(1 for m in json.load(open('$MANIFEST')).get('modules',{}).values() if m.get('enabled')))" 2>/dev/null) || enabled="?"

  echo "Savia Enterprise — Status"
  echo "  Manifest version: $version"
  echo "  Modules: $enabled/$total enabled"
  echo "  Enterprise dir: $ENTERPRISE_DIR"
  if [[ "$enabled" == "0" ]]; then
    echo "  Mode: Community (all modules disabled)"
  else
    echo "  Mode: Enterprise ($enabled active modules)"
  fi
}

cmd_modules() {
  _require_manifest
  echo "Savia Enterprise — Modules"
  echo ""
  python3 -c "
import json
d=json.load(open('$MANIFEST'))
for name, info in sorted(d.get('modules',{}).items()):
    status = 'ON ' if info.get('enabled') else 'OFF'
    spec = info.get('spec','?')
    desc = info.get('description','')
    print(f'  [{status}] {name:30s} ({spec}) — {desc}')
" 2>/dev/null || die "Failed to parse manifest"
}

cmd_enable() {
  local module="${1:-}"
  [[ -z "$module" ]] && die "Usage: savia-enterprise.sh enable <module>"
  _require_manifest

  local current
  current=$(_read_module "$module")
  [[ "$current" == "NOT_FOUND" ]] && die "Module '$module' not found. Run: savia-enterprise.sh modules"
  [[ "$current" == "enabled" ]] && echo "Module '$module' is already enabled." && return

  echo "Enabling module: $module"
  local result
  result=$(_set_module "$module" "True")
  [[ "$result" == "OK" ]] && echo "ENABLED: $module" || die "Failed to enable $module"
}

cmd_disable() {
  local module="${1:-}"
  [[ -z "$module" ]] && die "Usage: savia-enterprise.sh disable <module>"
  _require_manifest

  local current
  current=$(_read_module "$module")
  [[ "$current" == "NOT_FOUND" ]] && die "Module '$module' not found."
  [[ "$current" == "disabled" ]] && echo "Module '$module' is already disabled." && return

  echo "Disabling module: $module"
  local result
  result=$(_set_module "$module" "False")
  [[ "$result" == "OK" ]] && echo "DISABLED: $module — Core behavior restored for this module." || die "Failed to disable $module"
}

cmd_uninstall() {
  _require_manifest
  echo "Savia Enterprise — Uninstall"
  echo ""
  echo "This will disable ALL Enterprise modules and return to Community mode."
  echo "Your data in projects/ and tenants/ will NOT be deleted."
  echo ""
  read -rp "Confirm uninstall? [y/N] " confirm
  [[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "Cancelled." && return

  python3 -c "
import json
with open('$MANIFEST') as f: d=json.load(f)
count=0
for m in d.get('modules',{}).values():
    if m.get('enabled'):
        m['enabled']=False
        count+=1
with open('$MANIFEST','w') as f: json.dump(d,f,indent=2)
print(f'Disabled {count} modules. Savia is now in Community mode.')
" 2>/dev/null || die "Failed to uninstall"
}

cmd_migrate_data() {
  local module="${1:-}"
  [[ -z "$module" ]] && die "Usage: savia-enterprise.sh migrate-data <module>"
  _require_manifest

  case "$module" in
    multi-tenant)
      echo "Multi-tenant migration wizard"
      echo "This will move projects/ to tenants/default/projects/"
      echo "Symlinks for backward compatibility will be created."
      read -rp "Confirm? [y/N] " confirm
      [[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "Cancelled." && return
      echo "Migration not yet implemented. Coming in SE-002 full implementation."
      ;;
    *)
      echo "Module '$module' does not require data migration."
      ;;
  esac
}

case "${1:-}" in
  status)       cmd_status ;;
  modules)      cmd_modules ;;
  enable)       shift; cmd_enable "$@" ;;
  disable)      shift; cmd_disable "$@" ;;
  uninstall)    cmd_uninstall ;;
  migrate-data) shift; cmd_migrate_data "$@" ;;
  --help|-h)    echo "Usage: savia-enterprise.sh {status|modules|enable|disable|uninstall|migrate-data}" ;;
  *)            echo "Usage: savia-enterprise.sh {status|modules|enable|disable|uninstall|migrate-data}" ;;
esac
