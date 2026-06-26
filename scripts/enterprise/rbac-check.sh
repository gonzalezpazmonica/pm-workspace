#!/usr/bin/env bash
# rbac-check.sh — Verify if a user has permission to run a command in a tenant
set -uo pipefail
# SPEC: SE-002 Extension Points / SPEC-SE-002 Multi-Tenant
#
# Usage:
#   scripts/enterprise/rbac-check.sh --user SLUG --command CMD --tenant SLUG
#
# Output JSON: {allowed: bool, role: str, command: str, reason: str, tenant: str}
#
# Exit codes:
#   0 — allowed
#   1 — denied or error

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# ---------- arg parsing ----------
USER_SLUG=""
COMMAND_ARG=""
TENANT_SLUG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)    USER_SLUG="$2";    shift 2 ;;
    --command) COMMAND_ARG="$2";  shift 2 ;;
    --tenant)  TENANT_SLUG="$2";  shift 2 ;;
    --help|-h)
      echo "Usage: rbac-check.sh --user SLUG --command CMD --tenant SLUG"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

emit() {
  # emit JSON result and exit with code $1
  local exit_code="$1"
  shift
  python3 -c "import json,sys; print(json.dumps(dict(zip(sys.argv[1::2],
    [v if v not in ('true','false') else v=='true' for v in sys.argv[2::2]]),
    **{'allowed': $([[ $exit_code -eq 0 ]] && echo 'True' || echo 'False')})
    ))" "$@" 2>/dev/null || \
  python3 -c "
import json, sys
args = sys.argv[1:]
d = {}
for i in range(0, len(args), 2):
    k, v = args[i], args[i+1]
    if v in ('true', 'false'):
        d[k] = (v == 'true')
    else:
        d[k] = v
d['allowed'] = $([[ $exit_code -eq 0 ]] && echo 'True' || echo 'False')
print(json.dumps(d, indent=2))
" "$@"
  exit "$exit_code"
}

if [[ -z "$USER_SLUG" || -z "$COMMAND_ARG" || -z "$TENANT_SLUG" ]]; then
  python3 -c "import json; print(json.dumps({'allowed': False, 'error': 'missing required arguments: --user, --command, --tenant', 'role': '', 'command': '', 'reason': 'invalid-args', 'tenant': ''}))"
  exit 1
fi

RBAC_FILE="$PROJECT_DIR/tenants/$TENANT_SLUG/rbac.yaml"

if [[ ! -f "$RBAC_FILE" ]]; then
  python3 -c "
import json, sys
print(json.dumps({'allowed': False, 'role': '', 'command': sys.argv[1],
  'reason': 'tenant-not-found', 'tenant': sys.argv[2],
  'error': f'rbac.yaml not found at tenants/{sys.argv[2]}/rbac.yaml'}))
" "$COMMAND_ARG" "$TENANT_SLUG"
  exit 1
fi

# ---------- check via Python (PyYAML) ----------
python3 << PYEOF
import json, sys, os

try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False

rbac_file = "$RBAC_FILE"
user_slug = "$USER_SLUG"
command = "$COMMAND_ARG"
tenant = "$TENANT_SLUG"

def fnmatch_pattern(pattern, command):
    """Simple glob matching: * matches any sequence."""
    import fnmatch
    return fnmatch.fnmatch(command, pattern)

def role_allows(roles, role_name, command, visited=None):
    """Recursively check if a role allows a command (with inheritance)."""
    if visited is None:
        visited = set()
    if role_name in visited:
        return False
    visited.add(role_name)

    role = roles.get(role_name, {})
    commands = role.get('commands', [])
    for pat in commands:
        if fnmatch_pattern(pat, command):
            return True

    inherited = role.get('inherits')
    if inherited:
        if isinstance(inherited, str):
            inherited = [inherited]
        for parent in inherited:
            if role_allows(roles, parent, command, visited):
                return True
    return False

if not HAS_YAML:
    # Fallback: try simple grep
    try:
        with open(rbac_file) as f:
            content = f.read()
        # If file mentions the command literally, allow
        if command in content:
            print(json.dumps({'allowed': True, 'role': 'unknown', 'command': command,
                'reason': 'yaml-unavailable-fallback', 'tenant': tenant}))
            sys.exit(0)
    except Exception:
        pass
    print(json.dumps({'allowed': False, 'role': '', 'command': command,
        'reason': 'pyyaml-unavailable', 'tenant': tenant,
        'error': 'PyYAML not installed — cannot parse rbac.yaml'}))
    sys.exit(1)

try:
    with open(rbac_file) as f:
        rbac = yaml.safe_load(f)
except Exception as e:
    print(json.dumps({'allowed': False, 'role': '', 'command': command,
        'reason': 'rbac-parse-error', 'tenant': tenant, 'error': str(e)}))
    sys.exit(1)

roles = rbac.get('roles', {})
users = rbac.get('users', {})

# Look up user role
user_info = users.get(user_slug, {})
user_role = user_info.get('role', '')

if not user_role:
    print(json.dumps({'allowed': False, 'role': '', 'command': command,
        'reason': 'user-not-found', 'tenant': tenant,
        'error': f"User '{user_slug}' not found in rbac.yaml"}))
    sys.exit(1)

allowed = role_allows(roles, user_role, command)
reason = 'role-allowed' if allowed else 'role-denied'

print(json.dumps({'allowed': allowed, 'role': user_role, 'command': command,
    'reason': reason, 'tenant': tenant}))
sys.exit(0 if allowed else 1)
PYEOF
