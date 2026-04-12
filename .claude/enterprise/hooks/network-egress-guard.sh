#!/usr/bin/env bash
set -uo pipefail
# network-egress-guard.sh — Block outbound network calls in sovereign/air-gap mode
# SPEC: SE-005 Sovereign Deployment
# Layer: Enterprise (PreToolUse: Bash)
#
# When tenant deployment mode is "sovereign" or "air-gap", blocks any
# Bash command that makes outbound network calls (curl, wget, gh api,
# npm install, pip install, etc.) unless the host is in the allowed list.
#
# No-op when: module disabled, mode is "cloud" or "hybrid", no tenant active.

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/../../../scripts/lib"
if [[ -f "$LIB_DIR/enterprise-helpers.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/enterprise-helpers.sh"
  enterprise_enabled "sovereign-deployment" || exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TENANT_SLUG="${SAVIA_TENANT:-}"

# Find deployment config for active tenant
DEPLOY_CONFIG=""
if [[ -n "$TENANT_SLUG" ]]; then
  DEPLOY_CONFIG="$PROJECT_DIR/tenants/$TENANT_SLUG/deployment.yaml"
fi
[[ ! -f "${DEPLOY_CONFIG:-}" ]] && exit 0

# Read mode — requires PyYAML; degrade to cloud if unavailable
MODE=""
if command -v python3 >/dev/null 2>&1; then
  MODE=$(python3 -c "
import sys
try:
    import yaml
    d = yaml.safe_load(open(sys.argv[1]))
    print(d.get('mode', 'cloud'))
except ImportError:
    print('cloud')
except Exception as e:
    print('cloud', file=sys.stderr)
    print(f'WARN: deployment.yaml parse error: {e}', file=sys.stderr)
    print('cloud')
" "$DEPLOY_CONFIG" 2>/dev/null)
else
  echo "WARN: python3 not available — cannot enforce sovereign mode" >&2
  exit 0
fi

[[ "$MODE" != "sovereign" && "$MODE" != "air-gap" ]] && exit 0

# Read hook input from stdin
INPUT=""
if [[ ! -t 0 ]]; then
  if command -v timeout >/dev/null 2>&1; then
    INPUT=$(timeout 3 cat) || { echo "WARN: stdin read timeout" >&2; exit 0; }
  else
    INPUT=$(cat)
  fi
fi
[[ -z "$INPUT" ]] && exit 0

COMMAND=$(printf '%s' "$INPUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('command', ''))
" 2>/dev/null)

if [[ -z "${COMMAND:-}" ]]; then
  echo "WARN: could not extract command from hook input" >&2
  exit 0
fi

# Network-calling patterns to block
NETWORK_PATTERNS=(
  'curl ' 'wget ' 'gh api' 'gh pr create' 'gh pr merge'
  'npm install' 'pip install' 'pip3 install'
  'apt install' 'apt-get install' 'docker pull'
  'git clone' 'git fetch' 'git push' 'git pull'
)

# Read allowed hosts
ALLOWED_HOSTS=""
if command -v python3 >/dev/null 2>&1; then
  ALLOWED_HOSTS=$(python3 -c "
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
hosts = d.get('network', {}).get('allowed_hosts', [])
print(' '.join(str(h) for h in hosts))
" "$DEPLOY_CONFIG" 2>/dev/null)
fi

for pattern in "${NETWORK_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qF "$pattern"; then
    blocked=true
    for host in $ALLOWED_HOSTS; do
      if echo "$COMMAND" | grep -qF "$host"; then
        blocked=false
        break
      fi
    done
    if $blocked; then
      echo "BLOCKED: sovereign mode prohibits outbound network calls" >&2
      echo "  Command: $(echo "$COMMAND" | head -c 100)" >&2
      echo "  Mode: $MODE | Tenant: $TENANT_SLUG" >&2
      echo "  To allow: add host to tenants/$TENANT_SLUG/deployment.yaml → network.allowed_hosts" >&2
      exit 2
    fi
  fi
done

exit 0
