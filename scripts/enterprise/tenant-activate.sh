#!/usr/bin/env bash
# tenant-activate.sh — Activate multi-tenant mode in the workspace
# SPEC: SPEC-SE-002 Multi-Tenant & RBAC
#
# Usage:
#   scripts/enterprise/tenant-activate.sh
#
# Actions:
#   - Sets manifest.json modules.multi-tenant.enabled = true
#   - Creates tenants/ directory if absent
#   - Registers tenant-resolver and tenant-isolation-gate hooks in .claude/settings.json
#
# Output JSON: {activated: bool, tenants_dir_created: bool, hooks_registered: bool}

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
MANIFEST="$PROJECT_DIR/.claude/enterprise/manifest.json"
SETTINGS="$PROJECT_DIR/.claude/settings.json"
TENANTS_DIR="$PROJECT_DIR/tenants"
RESOLVER_HOOK="$PROJECT_DIR/.claude/enterprise/hooks/tenant-resolver.sh"
GATE_HOOK="$PROJECT_DIR/.claude/enterprise/hooks/tenant-isolation-gate.sh"

if [[ ! -f "$MANIFEST" ]]; then
  echo '{"error":"manifest.json not found — is Savia Enterprise installed?"}' >&2
  exit 1
fi

TENANTS_DIR_CREATED=false
HOOKS_REGISTERED=false

# 1. Create tenants/ if absent
if [[ ! -d "$TENANTS_DIR" ]]; then
  mkdir -p "$TENANTS_DIR"
  TENANTS_DIR_CREATED=true
fi

# 2. Enable multi-tenant in manifest.json
python3 - "$MANIFEST" << 'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    d = json.load(f)
d.setdefault('modules', {}).setdefault('multi-tenant', {})['enabled'] = True
with open(path, 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
print("ok")
PYEOF

# 3. Register hooks in .claude/settings.json
if [[ -f "$RESOLVER_HOOK" && -f "$GATE_HOOK" && -f "$SETTINGS" ]]; then
  python3 - "$SETTINGS" "$RESOLVER_HOOK" "$GATE_HOOK" << 'PYEOF'
import json, sys, os

settings_path, resolver, gate = sys.argv[1], sys.argv[2], sys.argv[3]

with open(settings_path) as f:
    s = json.load(f)

hooks = s.setdefault('hooks', {})
pre = hooks.setdefault('PreToolUse', [])

def hook_registered(hooks_list, matcher, script):
    for h in hooks_list:
        if isinstance(h, dict) and h.get('command') == script:
            return True
    return False

changed = False

# tenant-resolver: runs standalone, register as PostToolUse on all (informational)
# Actually register both as PreToolUse entries for Edit|Write|Read
for script, matcher in [
    (resolver, "Edit|Write|Read|Bash"),
    (gate, "Edit|Write|Read"),
]:
    if not hook_registered(pre, matcher, script):
        pre.append({
            "matcher": matcher,
            "hooks": [{"type": "command", "command": script}]
        })
        changed = True

if changed:
    with open(settings_path, 'w') as f:
        json.dump(s, f, indent=2)
        f.write('\n')
    print("registered")
else:
    print("already-registered")
PYEOF
  HOOKS_REGISTERED=true
fi

# 4. Output
python3 -c "
import json, sys
print(json.dumps({
  'activated': True,
  'tenants_dir_created': sys.argv[1] == 'true',
  'hooks_registered': sys.argv[2] == 'true',
  'manifest': '.claude/enterprise/manifest.json',
  'module': 'multi-tenant'
}, indent=2))
" "$TENANTS_DIR_CREATED" "$HOOKS_REGISTERED"
