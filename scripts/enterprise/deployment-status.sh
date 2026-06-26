#!/usr/bin/env bash
# deployment-status.sh — Show current deployment mode for a tenant
set -uo pipefail
# SPEC: SPEC-SE-005 Sovereign Deployment
#
# Usage:
#   scripts/enterprise/deployment-status.sh [--tenant SLUG]
#
# Reads: tenants/{slug}/deployment.yaml  OR  deployment.yaml (global)
# Output JSON: {mode, llm_provider, egress_allowed, sovereign_ready: bool}

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# ---------- arg parsing ----------
TENANT_SLUG="${SAVIA_TENANT:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant) TENANT_SLUG="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: deployment-status.sh [--tenant SLUG]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Find deployment config
DEPLOY_YAML=""
if [[ -n "$TENANT_SLUG" ]]; then
  TENANT_YAML="$PROJECT_DIR/tenants/$TENANT_SLUG/deployment.yaml"
  [[ -f "$TENANT_YAML" ]] && DEPLOY_YAML="$TENANT_YAML"
fi

# Fallback to global deployment.yaml
if [[ -z "$DEPLOY_YAML" ]]; then
  GLOBAL_YAML="$PROJECT_DIR/deployment.yaml"
  [[ -f "$GLOBAL_YAML" ]] && DEPLOY_YAML="$GLOBAL_YAML"
fi

if [[ -z "$DEPLOY_YAML" ]]; then
  # No deployment config found — report cloud defaults
  python3 -c "
import json, sys
print(json.dumps({
  'mode': 'cloud',
  'llm_provider': 'anthropic',
  'llm_host': 'https://api.anthropic.com',
  'egress_allowed': True,
  'sovereign_ready': False,
  'tenant': sys.argv[1] if sys.argv[1] else None,
  'config_source': 'default-no-deployment-yaml'
}, indent=2))
" "${TENANT_SLUG:-}"
  exit 0
fi

python3 - "$DEPLOY_YAML" "${TENANT_SLUG:-}" << 'PYEOF'
import json, sys, os

deploy_path = sys.argv[1]
tenant = sys.argv[2] if len(sys.argv) > 2 else ''

try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False

if not HAS_YAML:
    # Fallback: grep-based parsing
    mode = 'cloud'
    llm_host = 'https://api.anthropic.com'
    egress_allowed = True
    try:
        with open(deploy_path) as f:
            for line in f:
                line = line.strip()
                if line.startswith('mode:'):
                    mode = line.split(':', 1)[1].strip().strip('"\'')
                elif line.startswith('  host:') or line.startswith('host:'):
                    llm_host = line.split(':', 1)[1].strip().strip('"\'')
                elif 'egress_allowed' in line:
                    egress_allowed = 'true' in line.lower()
    except Exception:
        pass
    print(json.dumps({
        'mode': mode, 'llm_provider': 'unknown-no-pyyaml',
        'llm_host': llm_host, 'egress_allowed': egress_allowed,
        'sovereign_ready': mode in ('sovereign', 'air-gap'),
        'tenant': tenant or None,
        'config_source': deploy_path
    }, indent=2))
    sys.exit(0)

try:
    with open(deploy_path) as f:
        d = yaml.safe_load(f) or {}
except Exception as e:
    print(json.dumps({'error': f'Failed to parse {deploy_path}: {e}',
        'mode': 'cloud', 'llm_provider': 'unknown', 'llm_host': '',
        'egress_allowed': True, 'sovereign_ready': False}))
    sys.exit(1)

mode = d.get('mode', 'cloud')
llm = d.get('llm', {})
network = d.get('network', {})

print(json.dumps({
    'mode': mode,
    'llm_provider': llm.get('provider', 'anthropic'),
    'llm_host': llm.get('host', 'https://api.anthropic.com'),
    'egress_allowed': network.get('egress_allowed', True),
    'allowed_hosts': network.get('allowed_hosts', []),
    'sovereign_ready': mode in ('sovereign', 'air-gap'),
    'tenant': d.get('tenant', tenant) or None,
    'config_source': deploy_path
}, indent=2))
PYEOF
