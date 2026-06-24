#!/usr/bin/env bash
# rollback-module.sh — Revert activation of an Enterprise module
# SPEC: SPEC-SE-010 Migration Path & Backward Compat
#
# Usage:
#   scripts/enterprise/rollback-module.sh --module MODULE
#
# Actions:
#   - Sets manifest.json: module.enabled = false
#   - Removes hooks that were added by the module (if identifiable)
#
# Output JSON: {module, rolled_back: bool, hooks_removed: N}

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
MANIFEST="$PROJECT_DIR/.claude/enterprise/manifest.json"
SETTINGS="$PROJECT_DIR/.claude/settings.json"

# ---------- arg parsing ----------
MODULE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --module) MODULE="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: rollback-module.sh --module MODULE"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$MODULE" ]]; then
  echo '{"error":"--module is required"}' >&2
  exit 1
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo '{"error":"manifest.json not found"}' >&2
  exit 1
fi

# Module → hooks mapping (hooks that are added when a module is activated)
declare -A MODULE_HOOKS
MODULE_HOOKS["multi-tenant"]="$PROJECT_DIR/.claude/enterprise/hooks/tenant-resolver.sh $PROJECT_DIR/.claude/enterprise/hooks/tenant-isolation-gate.sh"
MODULE_HOOKS["sovereign-deployment"]="$PROJECT_DIR/.claude/enterprise/hooks/network-egress-guard.sh"

python3 - "$MANIFEST" "$SETTINGS" "$MODULE" "${MODULE_HOOKS[$MODULE]:-}" << 'PYEOF'
import json, sys, os

manifest_path = sys.argv[1]
settings_path = sys.argv[2]
module = sys.argv[3]
hooks_str = sys.argv[4] if len(sys.argv) > 4 else ''
hooks_to_remove = [h for h in hooks_str.split() if h]

# 1. Disable in manifest
with open(manifest_path) as f:
    d = json.load(f)

modules = d.get('modules', {})
if module not in modules:
    print(json.dumps({'error': f"Module '{module}' not found in manifest",
        'available': list(modules.keys())}))
    sys.exit(1)

was_enabled = modules[module].get('enabled', False)
modules[module]['enabled'] = False
d['modules'] = modules

with open(manifest_path, 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')

# 2. Remove hooks from settings.json
hooks_removed = 0
if hooks_to_remove and os.path.isfile(settings_path):
    with open(settings_path) as f:
        s = json.load(f)

    changed = False
    for section_name in ('PreToolUse', 'PostToolUse'):
        section = s.get('hooks', {}).get(section_name, [])
        new_section = []
        for entry in section:
            if not isinstance(entry, dict):
                new_section.append(entry)
                continue
            new_hooks = [
                h for h in entry.get('hooks', [])
                if not (isinstance(h, dict) and h.get('command', '') in hooks_to_remove)
            ]
            removed_count = len(entry.get('hooks', [])) - len(new_hooks)
            hooks_removed += removed_count
            if removed_count > 0:
                changed = True
            if new_hooks:
                entry_copy = dict(entry)
                entry_copy['hooks'] = new_hooks
                new_section.append(entry_copy)
            # else: drop the entire entry (no hooks left)
        if changed:
            s.setdefault('hooks', {})[section_name] = new_section

    if changed:
        with open(settings_path, 'w') as f:
            json.dump(s, f, indent=2)
            f.write('\n')

print(json.dumps({
    'module': module,
    'rolled_back': True,
    'was_enabled': was_enabled,
    'hooks_removed': hooks_removed,
    'manifest': manifest_path
}, indent=2))
PYEOF
