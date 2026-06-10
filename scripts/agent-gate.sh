#!/usr/bin/env bash
# agent-gate.sh — SE-216 Slice 2: inherited quality gates for agent runs
# Ref: docs/propuestas/SE-216-evo-patterns.md
set -uo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_usage() {
  cat >&2 <<'EOF'
Usage: agent-gate.sh <subcommand> [options]

Subcommands:
  add     --run-id X --name N --phase pre|post --cmd "CMD" --on-fail block|warn|skip [--branch B]
  run     --run-id X --branch B --phase pre|post
  status  --run-id X

Global gates (no --branch) are inherited by every branch in the run.
State is persisted in .evo/{run_id}/gates.json.
EOF
  exit 1
}

_die() {
  echo "ERROR: $*" >&2
  exit 1
}

_evo_dir() {
  local run_id="$1"
  echo ".evo/${run_id}"
}

_gates_file() {
  local run_id="$1"
  echo "$(_evo_dir "$run_id")/gates.json"
}

_ensure_gates_file() {
  local run_id="$1"
  local dir
  dir="$(_evo_dir "$run_id")"
  mkdir -p "$dir"
  local file="$(_gates_file "$run_id")"
  if [[ ! -f "$file" ]]; then
    printf '{"run_id":"%s","gates":[]}\n' "$run_id" > "$file"
  fi
}

# Portable JSON helpers — no jq required, use python3 as the JSON engine
_py() { python3 -c "$@"; }

_json_add_gate() {
  local file="$1"
  local name="$2"
  local phase="$3"
  local cmd="$4"
  local on_fail="$5"
  local branch="$6"   # empty string = global
  local created
  created="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  _py "
import json, sys

with open('${file}') as fh:
    data = json.load(fh)

gate = {
    'name': '${name}',
    'phase': '${phase}',
    'cmd': '${cmd}',
    'on_fail': '${on_fail}',
    'branch': '${branch}' if '${branch}' != '' else None,
    'created': '${created}',
}
data['gates'].append(gate)

with open('${file}', 'w') as fh:
    json.dump(data, fh, indent=2)
"
}

_json_get_gates() {
  # Print JSON array of gates matching run_id + branch (includes globals) + phase
  local file="$1"
  local branch="$2"
  local phase="$3"

  _py "
import json, sys

with open('${file}') as fh:
    data = json.load(fh)

result = []
for g in data['gates']:
    if g.get('phase') != '${phase}':
        continue
    b = g.get('branch')
    # global gate (branch=None) or branch-specific gate matching this branch
    if b is None or b == '${branch}':
        result.append(g)

print(json.dumps(result))
"
}

_json_is_valid() {
  local file="$1"
  _py "import json; json.load(open('${file}'))" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Subcommand: add
# ---------------------------------------------------------------------------

cmd_add() {
  local run_id="" name="" phase="" cmd="" on_fail="block" branch=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id)   run_id="$2";   shift 2 ;;
      --name)     name="$2";     shift 2 ;;
      --phase)    phase="$2";    shift 2 ;;
      --cmd)      cmd="$2";      shift 2 ;;
      --on-fail)  on_fail="$2";  shift 2 ;;
      --branch)   branch="$2";   shift 2 ;;
      *) _die "Unknown option for add: $1" ;;
    esac
  done

  [[ -z "$run_id" ]]   && _die "--run-id is required"
  [[ -z "$name" ]]     && _die "--name is required"
  [[ -z "$phase" ]]    && _die "--phase is required"
  [[ -z "$cmd" ]]      && _die "--cmd is required"

  [[ "$phase" == "pre" || "$phase" == "post" ]] \
    || _die "--phase must be 'pre' or 'post'"
  [[ "$on_fail" == "block" || "$on_fail" == "warn" || "$on_fail" == "skip" ]] \
    || _die "--on-fail must be 'block', 'warn', or 'skip'"

  _ensure_gates_file "$run_id"

  local file
  file="$(_gates_file "$run_id")"

  # Escape single-quotes in cmd for safe embedding into python string
  local safe_cmd="${cmd//\'/\'\"\'\"\'}"

  _json_add_gate "$file" "$name" "$phase" "$safe_cmd" "$on_fail" "$branch"

  echo "Gate '${name}' added to run '${run_id}'" \
    "${branch:+(branch: ${branch})}" \
    "(phase=${phase}, on-fail=${on_fail})"
}

# ---------------------------------------------------------------------------
# Subcommand: run
# ---------------------------------------------------------------------------

cmd_run() {
  local run_id="" branch="" phase=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id)  run_id="$2";  shift 2 ;;
      --branch)  branch="$2";  shift 2 ;;
      --phase)   phase="$2";   shift 2 ;;
      *) _die "Unknown option for run: $1" ;;
    esac
  done

  [[ -z "$run_id" ]]  && _die "--run-id is required"
  [[ -z "$branch" ]]  && _die "--branch is required"
  [[ -z "$phase" ]]   && _die "--phase is required"

  [[ "$phase" == "pre" || "$phase" == "post" ]] \
    || _die "--phase must be 'pre' or 'post'"

  local file
  file="$(_gates_file "$run_id")"
  [[ -f "$file" ]] || _die "run_id '${run_id}' not found — no gates.json at ${file}"

  local gates_json
  gates_json="$(_json_get_gates "$file" "$branch" "$phase")"

  local count
  count="$(_py "import json,sys; print(len(json.loads(sys.argv[1])))" "$gates_json")"

  if [[ "$count" -eq 0 ]]; then
    echo "No ${phase} gates for run '${run_id}' branch '${branch}'"
    exit 0
  fi

  local all_passed=0  # 0 = true in bash exit-code semantics

  # Iterate gates
  local i=0
  while [[ $i -lt $count ]]; do
    local gate_json
    gate_json="$(_py "import json,sys; gs=json.loads(sys.argv[1]); print(json.dumps(gs[$i]))" "$gates_json")"

    local gname gphase gcmd gon_fail
    gname="$(  _py "import json,sys; print(json.loads(sys.argv[1])['name'])"    "$gate_json")"
    gphase="$( _py "import json,sys; print(json.loads(sys.argv[1])['phase'])"   "$gate_json")"
    gcmd="$(   _py "import json,sys; print(json.loads(sys.argv[1])['cmd'])"     "$gate_json")"
    gon_fail="$(_py "import json,sys; print(json.loads(sys.argv[1])['on_fail'])" "$gate_json")"

    # Execute the gate command
    local exit_code=0
    eval "$gcmd" >/dev/null 2>&1 || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      echo "GATE OK: ${gname}"
    else
      case "$gon_fail" in
        block)
          echo "GATE FAILED: ${gname}" >&2
          exit 1
          ;;
        warn)
          echo "WARNING: gate '${gname}' failed (exit ${exit_code}) — continuing" >&2
          ;;
        skip)
          # silent
          ;;
      esac
    fi

    i=$(( i + 1 ))
  done

  exit 0
}

# ---------------------------------------------------------------------------
# Subcommand: status
# ---------------------------------------------------------------------------

cmd_status() {
  local run_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id) run_id="$2"; shift 2 ;;
      *) _die "Unknown option for status: $1" ;;
    esac
  done

  [[ -z "$run_id" ]] && _die "--run-id is required"

  local file
  file="$(_gates_file "$run_id")"
  [[ -f "$file" ]] || _die "run_id '${run_id}' not found — no gates.json at ${file}"

  _py "
import json, sys

with open('${file}') as fh:
    data = json.load(fh)

gates = data.get('gates', [])
if not gates:
    print('No gates defined for run: ${run_id}')
    sys.exit(0)

# Header
print(f\"{'GATE':<30} {'PHASE':<6} {'ON-FAIL':<8} {'BRANCH':<30}\")
print('-' * 78)

for g in gates:
    name    = g.get('name', '')
    phase   = g.get('phase', '')
    on_fail = g.get('on_fail', '')
    branch  = g.get('branch') or '(global)'
    print(f\"{name:<30} {phase:<6} {on_fail:<8} {branch:<30}\")
"
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

[[ $# -lt 1 ]] && _usage

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
  add)    cmd_add    "$@" ;;
  run)    cmd_run    "$@" ;;
  status) cmd_status "$@" ;;
  *)
    echo "ERROR: Unknown subcommand '${SUBCOMMAND}'" >&2
    _usage
    ;;
esac
