#!/usr/bin/env bash
# rbac-bulk-assign.sh — Bulk-assign roles from a CSV file
# SPEC: SPEC-SE-002 Multi-Tenant & RBAC
#
# Usage:
#   scripts/enterprise/rbac-bulk-assign.sh --csv FILE
#
# CSV format (no header):
#   user_slug,tenant_slug,role
#
# Updates tenants/{tenant}/rbac.yaml for each row.
# Output JSON: {assigned: N, errors: [...]}

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# ---------- arg parsing ----------
CSV_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --csv)   CSV_FILE="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: rbac-bulk-assign.sh --csv FILE"
      echo "CSV columns: user_slug,tenant_slug,role"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$CSV_FILE" ]]; then
  echo '{"error":"--csv is required"}' >&2
  exit 1
fi

if [[ ! -f "$CSV_FILE" ]]; then
  python3 -c "import json,sys; print(json.dumps({'error': f'CSV file not found: {sys.argv[1]}', 'assigned': 0, 'errors': []}))" "$CSV_FILE"
  exit 1
fi

python3 - "$PROJECT_DIR" "$CSV_FILE" << 'PYEOF'
import json, sys, os

project_dir = sys.argv[1]
csv_path = sys.argv[2]

try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False

assigned = 0
errors = []

def load_rbac(path):
    if not HAS_YAML:
        return None
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return yaml.safe_load(f) or {}

def save_rbac(path, data):
    if not HAS_YAML:
        return False
    # atomic write via temp file
    import tempfile
    tmp = path + '.tmp'
    with open(tmp, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
    os.replace(tmp, path)
    return True

def parse_csv_line(line):
    line = line.strip()
    if not line or line.startswith('#'):
        return None
    parts = [p.strip().strip('"') for p in line.split(',')]
    if len(parts) < 3:
        return None
    return parts[0], parts[1], parts[2]

with open(csv_path) as f:
    lines = f.readlines()

# Skip header if first line looks like a header
start = 0
if lines and lines[0].strip().lower().startswith('user'):
    start = 1

for lineno, line in enumerate(lines[start:], start=start + 1):
    parsed = parse_csv_line(line)
    if parsed is None:
        continue

    user_slug, tenant_slug, role = parsed
    rbac_path = os.path.join(project_dir, 'tenants', tenant_slug, 'rbac.yaml')

    if not os.path.exists(rbac_path):
        errors.append({
            'line': lineno,
            'user': user_slug,
            'tenant': tenant_slug,
            'role': role,
            'error': f'rbac.yaml not found for tenant {tenant_slug}'
        })
        continue

    rbac = load_rbac(rbac_path)
    if rbac is None:
        errors.append({
            'line': lineno,
            'user': user_slug,
            'tenant': tenant_slug,
            'role': role,
            'error': 'PyYAML not available — cannot update rbac.yaml'
        })
        continue

    # Validate role exists
    roles = rbac.get('roles', {})
    if role not in roles:
        errors.append({
            'line': lineno,
            'user': user_slug,
            'tenant': tenant_slug,
            'role': role,
            'error': f"role '{role}' not defined in rbac.yaml for tenant '{tenant_slug}'"
        })
        continue

    users = rbac.setdefault('users', {})
    users[user_slug] = {'role': role}
    rbac['users'] = users

    if save_rbac(rbac_path, rbac):
        assigned += 1
    else:
        errors.append({
            'line': lineno,
            'user': user_slug,
            'tenant': tenant_slug,
            'role': role,
            'error': 'failed to save rbac.yaml'
        })

print(json.dumps({'assigned': assigned, 'errors': errors}, indent=2))
PYEOF
