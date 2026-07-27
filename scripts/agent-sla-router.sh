#!/usr/bin/env bash
# agent-sla-router.sh — SE-272 S3: Differentiated SLA by origin type
# Ref: docs/propuestas/SE-272-servicio-gestionado.md
#
# Differentiated SLA by origin type:
#   agent  → seconds/minutes with auto-resolution
#   human  → classic (hours)
# Single SLA for both is wrong contract engineering.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)}"
DATA_DIR="${DATA_DIR:-$REPO_ROOT/data}"
mkdir -p "$DATA_DIR"
SLA_LOG="${SLA_LOG:-$DATA_DIR/agent-sla-decisions.jsonl}"

_usage() {
  cat >&2 <<'EOF'
Usage: agent-sla-router.sh <subcommand> [options]

Subcommands:
  route    --origin human|agent [--rt TYPE]
           Route request to SLA tier. Prints SLA config.
  deadline --origin human|agent --received-at ISO8601 [--rt TYPE]
           Calc deadline for request given its origin and receive time.
  config   [--origin human|agent]
           Print SLA config. Without --origin, prints all.

Exit codes: 0 = ok, 1 = SLA violation, 2 = usage error
EOF
  exit 2
}

_die() {
  echo "ERROR: $*" >&2
  exit 2
}

_py() { python3 -c "$@"; }
_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

_get_sla_config() {
  local ori="$1"
  local rt="${2:-default}"

  case "$ori" in
    agent)
      case "$rt" in
        q) echo '{"tier":"agent-q","max_rsp_s":30,"max_res_s":300,"auto":true,"esc":"op","desc":"Agent q — 30s rsp, 5min res"}' ;;
        n) echo '{"tier":"agent-n","max_rsp_s":5,"max_res_s":60,"auto":true,"esc":"log","desc":"Agent n — 5s rsp, 1min res"}' ;;
        a) echo '{"tier":"agent-a","max_rsp_s":10,"max_res_s":120,"auto":false,"esc":"human","desc":"Agent a — 10s rsp, 2min res, human esc"}' ;;
        *) echo '{"tier":"agent-d","max_rsp_s":60,"max_res_s":600,"auto":true,"esc":"op","desc":"Agent d — 60s rsp, 10min res"}' ;;
      esac
      ;;
    human)
      case "$rt" in
        u) echo '{"tier":"human-u","max_rsp_h":2,"max_res_h":8,"auto":false,"esc":"op","desc":"Human urg — 2h rsp, 8h res"}' ;;
        s) echo '{"tier":"human-s","max_rsp_h":8,"max_res_h":24,"auto":false,"esc":"op","desc":"Human std — 8h rsp, 24h res"}' ;;
        b) echo '{"tier":"human-b","max_rsp_h":24,"max_res_h":72,"auto":false,"esc":"op","desc":"Human bg — 24h rsp, 72h res"}' ;;
        *) echo '{"tier":"human-d","max_rsp_h":4,"max_res_h":12,"auto":false,"esc":"op","desc":"Human d — 4h rsp, 12h res"}' ;;
      esac
      ;;
    *)
      _die "Unknown origin: ${ori}"
      ;;
  esac
}

_log_sla() {
  local ori="$1"
  local rt="$2"
  local ti="$3"
  local ts
  ts="$(_now)"
  _py "import json; rec={'ts':'${ts}','ori':'${ori}','rt':'${rt}','ti':'${ti}'}; open('${SLA_LOG}','a').write(json.dumps(rec)+'\n')" 2>/dev/null || true
}

cmd_route() {
  local ori="" rt="default"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --origin) ori="$2"; shift 2 ;;
      --rt)     rt="$2";  shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$ori" ]] && _die "--origin is required"

  local slaj
  slaj="$(_get_sla_config "$ori" "$rt")"

  local ti
  ti="$(_py "import json,sys; print(json.loads(sys.argv[1])['tier'])" "$slaj")"

  _log_sla "$ori" "$rt" "$ti"

  echo "$slaj" | _py "
import json, sys
sla = json.loads(sys.stdin.read())
print(f\"SLA_TIER: {sla['tier']}\")
for k, v in sorted(sla.items()):
    if k != 'tier':
        print(f\"{k.upper()}: {v}\")
"
}

cmd_deadline() {
  local ori="" rt="default" recv=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --origin)      ori="$2";  shift 2 ;;
      --rt)          rt="$2";   shift 2 ;;
      --received-at) recv="$2"; shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$ori" ]]  && _die "--origin is required"
  [[ -z "$recv" ]] && _die "--received-at is required"

  local slaj
  slaj="$(_get_sla_config "$ori" "$rt")"

  local output
  output="$(_py "
import json, sys
from datetime import datetime, timedelta, timezone

s = json.loads('${slaj}')
r = datetime.fromisoformat('${recv}'.replace('Z', '+00:00'))
if 'max_res_h' in s:
    rh = s['max_res_h']; dl = r + timedelta(hours=rh)
    rph = s.get('max_rsp_h', rh); rd = r + timedelta(hours=rph)
else:
    rs = s['max_res_s']; dl = r + timedelta(seconds=rs)
    rps = s.get('max_rsp_s', rs); rd = r + timedelta(seconds=rps)
n = datetime.now(timezone.utc)
de = n > dl; re = n > rd
print(f\"RECV_AT: ${recv}\")
print(f\"TIER: {s['tier']}\")
print(f\"RESP_DL: {rd.isoformat().replace('+00:00', 'Z')}\")
print(f\"RES_DL: {dl.isoformat().replace('+00:00', 'Z')}\")
print(f\"RESP_EXC: {str(re).lower()}\")
print(f\"RES_EXC: {str(de).lower()}\")
")"

  echo "$output"

  local ec=0
  if [[ "$output" == *"RESP_EXC: true"* ]] || [[ "$output" == *"RES_EXC: true"* ]]; then
    ec=1
  fi
  exit $ec
}

cmd_config() {
  local ori=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --origin) ori="$2"; shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  if [[ -n "$ori" ]]; then
    for rt in q n a default; do
      echo "--- ${ori}/${rt} ---"
      cmd_route --origin "$ori" --rt "$rt" 2>/dev/null || true
    done
  else
    for ori in agent human; do
      echo "=== ${ori^^} SLA ==="
      for rt in q n a default; do
        echo "--- ${ori}/${rt} ---"
        cmd_route --origin "$ori" --rt "$rt" 2>/dev/null || true
      done
      echo ""
    done
  fi
}

[[ $# -lt 1 ]] && _usage

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
  route)     cmd_route     "$@" ;;
  deadline)  cmd_deadline  "$@" ;;
  config)    cmd_config    "$@" ;;
  *)         _usage ;;
esac
