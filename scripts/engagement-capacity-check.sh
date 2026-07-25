#!/usr/bin/env bash
# engagement-capacity-check.sh — SE-271 S4: Capacity enforcement per engagement
set -uo pipefail
#
# Usage:
#   scripts/engagement-capacity-check.sh --engagement FILE --tool TOOL --domain DOMAIN --action ACTION
#   scripts/engagement-capacity-check.sh --no-engagement --tool TOOL --domain DOMAIN --action ACTION
#
# Exit codes:
#   0 — allowed
#   1 — denied (not in scope)
#   2 — usage error
#   3 — engagement file parse error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

ENG_FILE=""
NO_ENG=false
TOOL=""
DOMAIN=""
ACTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --engagement) ENG_FILE="$2"; shift 2 ;;
    --no-engagement) NO_ENG=true; shift ;;
    --tool) TOOL="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --action) ACTION="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: engagement-capacity-check.sh [--engagement FILE | --no-engagement] --tool TOOL --domain DOMAIN --action ACTION"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$TOOL" && -z "$DOMAIN" && -z "$ACTION" ]]; then
  echo '{"allowed":false,"reason":"at-least-one-of-tool-domain-action-required"}' >&2
  exit 2
fi

if [[ "$NO_ENG" == "true" ]]; then
  echo '{"allowed":true,"reason":"no-engagement-unrestricted","mode":"unrestricted"}'
  exit 0
fi

if [[ -z "$ENG_FILE" ]]; then
  echo '{"allowed":true,"reason":"no-engagement-unrestricted","mode":"unrestricted"}'
  exit 0
fi

if [[ ! -f "$ENG_FILE" ]]; then
  echo "{\"allowed\":false,\"reason\":\"eng-file-not-found\",\"file\":\"$ENG_FILE\"}" >&2
  exit 3
fi

export ENG_FILE_ENV="$ENG_FILE"
export ENG_TOOL="$TOOL"
export ENG_DOMAIN="$DOMAIN"
export ENG_ACTION="$ACTION"

python3 << 'PYEOF'
import json, sys, os

eng_file = os.environ.get('ENG_FILE_ENV', '')
eng_tool = os.environ.get('ENG_TOOL', '')
eng_domain = os.environ.get('ENG_DOMAIN', '')
eng_action = os.environ.get('ENG_ACTION', '')

try:
    import yaml
except ImportError:
    print(json.dumps({"allowed": False, "reason": "pyyaml-not-available"}))
    sys.exit(3)

try:
    with open(eng_file) as f:
        doc = yaml.safe_load(f)
except Exception as e:
    print(json.dumps({"allowed": False, "reason": "parse-error", "error": str(e)}))
    sys.exit(3)

if not isinstance(doc, dict) or 'engagement' not in doc:
    print(json.dumps({"allowed": False, "reason": "invalid-schema"}))
    sys.exit(3)

e = doc['engagement']

sts = e.get('status', '')
if sts != 'active':
    print(json.dumps({"allowed": False, "reason": "not-active", "status": sts}))
    sys.exit(1)

scp = e.get('scope', {})
if not isinstance(scp, dict):
    print(json.dumps({"allowed": False, "reason": "invalid-scope"}))
    sys.exit(3)

ad = scp.get('domains', [])
at = scp.get('tools', [])
aa = scp.get('actions', [])

if not ad and not at and not aa:
    print(json.dumps({"allowed": False, "reason": "empty-scope-deny-by-default"}))
    sys.exit(1)

chk_dom = bool(eng_domain)
chk_tool = bool(eng_tool)
chk_act = bool(eng_action)

dom_ok = not chk_dom or eng_domain in ad
tool_ok = not chk_tool or eng_tool in at
act_ok = not chk_act or eng_action in aa

granted = []
denied = []

if chk_dom:
    (granted if dom_ok else denied).append("domain:" + eng_domain)
if chk_tool:
    (granted if tool_ok else denied).append("tool:" + eng_tool)
if chk_act:
    (granted if act_ok else denied).append("action:" + eng_action)

all_ok = dom_ok and tool_ok and act_ok

result = {
    "allowed": all_ok,
    "engagement_id": e.get("id", "?"),
    "client": e.get("client", "?"),
    "granted": granted,
    "denied": denied,
    "scope": {"domains": ad, "tools": at, "actions": aa}
}
result["reason"] = "denied:" + ",".join(denied) if denied else "in-scope"

print(json.dumps(result, indent=2))
sys.exit(0 if all_ok else 1)
PYEOF
