#!/usr/bin/env bash
# agent-escalation-gate.sh — SE-272 S3: Declared thresholds per request type
# Ref: docs/propuestas/SE-272-servicio-gestionado.md
#
# Declared thresholds: ambiguity, impact, cost, irreversible → escalate to human.
# Agent platform cannot self-authorize actions outside scope.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)}"
DATA_DIR="${DATA_DIR:-$REPO_ROOT/data}"
mkdir -p "$DATA_DIR"
ESC_LOG="${ESC_LOG:-$DATA_DIR/agent-escalation-events.jsonl}"

_usage() {
  cat >&2 <<'EOF'
Usage: agent-escalation-gate.sh <subcommand> [options]

Subcommands:
  check    --rt TYPE --ctx JSON
           Check if request exceeds thresholds. Exit 0=proceed, 1=escalate.
  list
           List all escalation thresholds.
  escalate --reason REASON [--rid ID] [--details JSON]
           Record an escalation event.

Exit codes: 0=proceed, 1=escalate, 2=usage error
EOF
  exit 2
}

_die() {
  echo "ERROR: $*" >&2
  exit 2
}

_py() { python3 -c "$@"; }
_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

_get_thresholds() {
  local rt="$1"

  case "$rt" in
    r) echo '{"max_amb":0.7,"max_imp":2,"max_cost":500,"irrev":false,"desc":"Read — low risk, esc on high amb or med imp"}' ;;
    n) echo '{"max_amb":0.5,"max_imp":1,"max_cost":100,"irrev":false,"desc":"Notify — near-zero risk, esc on any amb"}' ;;
    w) echo '{"max_amb":0.3,"max_imp":2,"max_cost":2000,"irrev":false,"desc":"Write — esc on moderate amb or imp > 2"}' ;;
    d) echo '{"max_amb":0.2,"max_imp":1,"max_cost":0,"irrev":false,"desc":"Delete — esc unless zero amb and zero cost"}' ;;
    c) echo '{"max_amb":0.2,"max_imp":2,"max_cost":1000,"irrev":false,"desc":"Config — esc on any amb"}' ;;
    p) echo '{"max_amb":0.1,"max_imp":0,"max_cost":0,"irrev":false,"desc":"Deploy — ALWAYS esc to human"}' ;;
    *) echo '{"max_amb":0.3,"max_imp":1,"max_cost":500,"irrev":false,"desc":"Unknown — conservative"}' ;;
  esac
}

_log_esc() {
  local rt="$1"
  local reason="$2"
  local details="$3"
  local ts
  ts="$(_now)"

  _py "
import json
rec = {'ts': '${ts}', 'rt': '${rt}', 'reason': '${reason}', 'details': ${details}}
with open('${ESC_LOG}', 'a') as fh:
    fh.write(json.dumps(rec) + '\n')
" 2>/dev/null || true
}

cmd_check() {
  local rt="" ctx="{}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --rt)  rt="$2";  shift 2 ;;
      --ctx) ctx="$2"; shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$rt" ]] && _die "--rt is required"

  local th_json
  th_json="$(_get_thresholds "$rt")"

  local result
  result="$(_py "
import json, sys
th = json.loads('${th_json}')
c = json.loads('${ctx}')
v = []
a = c.get('amb', 0.0)
i = c.get('imp', 0)
ko = c.get('cost', 0)
ir = c.get('irrev', False)
if a > th['max_amb']:
    v.append(f\"amb={a} > max={th['max_amb']}\")
if i > th['max_imp']:
    v.append(f\"imp={i} > max={th['max_imp']}\")
if ko > th['max_cost']:
    v.append(f\"cost={ko} > max={th['max_cost']}\")
if ir and not th.get('irrev', False):
    v.append('irrev_not_allowed')
if v:
    print('ESC:' + '; '.join(v))
else:
    print('OK')
")"

  if [[ "$result" == OK* ]]; then
    echo "OK: rt=${rt} within thresholds"
    exit 0
  else
    _log_esc "$rt" "$result" "$ctx"
    echo "${result}" >&2
    exit 1
  fi
}

cmd_list() {
  while [[ $# -gt 0 ]]; do
    shift
  done

  for rt in r n w d c p; do
    echo "===== ${rt} ====="
    echo "$(_get_thresholds "$rt")" | _py "
import json, sys
t = json.loads(sys.stdin.read())
print(f\"  desc: {t.get('desc', 'none')}\")
print(f\"  max_amb: {t['max_amb']}\")
print(f\"  max_imp: {t['max_imp']}\")
print(f\"  max_cost: {t['max_cost']}\")
print(f\"  irrev: {t['irrev']}\")
"
  done
}

cmd_escalate() {
  local reason="" rid="" details="{}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reason)  reason="$2";  shift 2 ;;
      --rid)     rid="$2";     shift 2 ;;
      --details) details="$2"; shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$reason" ]] && _die "--reason is required"

  local ts
  ts="$(_now)"

  _py "
import json
rec = {'ts': '${ts}', 'rid': '${rid}', 'reason': '${reason}', 'details': ${details}}
with open('${ESC_LOG}', 'a') as fh:
    fh.write(json.dumps(rec) + '\n')
" 2>/dev/null || true

  echo "ESCALATED: reason='${reason}' rid='${rid:-N/A}' at ${ts}" >&2
  exit 1
}

[[ $# -lt 1 ]] && _usage

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
  check)     cmd_check     "$@" ;;
  list)      cmd_list      "$@" ;;
  escalate)  cmd_escalate  "$@" ;;
  *)         _usage ;;
esac
