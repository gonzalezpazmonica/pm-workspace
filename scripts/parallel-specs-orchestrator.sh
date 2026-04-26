#!/usr/bin/env bash
# parallel-specs-orchestrator.sh — SE-074 Slice 1 — orchestrates parallel spec execution
#
# Spawns N parallel worker sessions (claude/opencode/custom command), each in
# an isolated worktree, with bounded concurrency, port allocation, tmp dir
# sandboxing, runtime timeout, and adaptive halting integration.
#
# Architecture:
#   1. Read queue (file or argv) of spec IDs to execute
#   2. For each spec: create worktree, allocate port range, allocate tmp dir
#   3. Compute retry budget via spec-budget.sh based on spec effort field
#   4. Launch worker command (configurable via SPEC_WORKER_CMD)
#   5. Bounded concurrency: at most MAX_PARALLEL_SPECS in-flight
#   6. Per-worker timeout via MAX_RUNTIME_MINUTES
#   7. Per-worker session log to output/parallel-runs/<spec_id>/session.log
#
# Usage:
#   bash scripts/parallel-specs-orchestrator.sh SE-073 SE-076 SE-078
#   bash scripts/parallel-specs-orchestrator.sh --queue .parallel-queue.txt
#   bash scripts/parallel-specs-orchestrator.sh --dry-run SE-073
#
# Env (all optional):
#   MAX_PARALLEL_SPECS       default 3, hard cap 5 (rejects higher)
#   MAX_RUNTIME_MINUTES      default 60, per-worker kill timeout
#   SPEC_WORKER_CMD          default "claude -w {worktree} --spec {spec_id}"
#                            placeholders: {worktree}, {spec_id}, {budget}, {ports}
#   SPECS_DIR                default docs/propuestas
#   PORT_RANGE_START         default 8080
#   PORT_RANGE_SIZE          default 10 per worktree
#   PARALLEL_RUNS_DIR        default output/parallel-runs
#
# Exit codes:
#   0 — all workers completed (zero failures or graceful per-worker fails)
#   1 — orchestrator-level error (config invalid, no specs found)
#   2 — usage error
#
# Reference: SE-074 (docs/propuestas/SE-074-parallel-spec-execution.md)
# Reference: docs/rules/domain/parallel-spec-execution.md
# Reference: docs/rules/domain/autonomous-safety.md (gates inviolables)

set -uo pipefail

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SPECS_DIR="${SPECS_DIR:-${ROOT}/docs/propuestas}"
MAX_PARALLEL_SPECS="${MAX_PARALLEL_SPECS:-3}"
MAX_RUNTIME_MINUTES="${MAX_RUNTIME_MINUTES:-60}"
if [[ -z "${SPEC_WORKER_CMD:-}" ]]; then
  SPEC_WORKER_CMD='claude -w {worktree} --spec {spec_id}'
fi
PORT_RANGE_START="${PORT_RANGE_START:-8080}"
PORT_RANGE_SIZE="${PORT_RANGE_SIZE:-10}"
PARALLEL_RUNS_DIR="${PARALLEL_RUNS_DIR:-${ROOT}/output/parallel-runs}"
WORKTREES_DIR="${WORKTREES_DIR:-${ROOT}/.claude/worktrees}"
DRY_RUN=0

# Hard cap enforcement (autonomous-safety: bounded concurrency rule)
if [[ "${MAX_PARALLEL_SPECS}" -gt 5 ]]; then
  echo "ERROR: MAX_PARALLEL_SPECS=${MAX_PARALLEL_SPECS} exceeds hard cap 5 (per docs/rules/domain/autonomous-safety.md bounded concurrency)" >&2
  exit 1
fi

usage() {
  cat <<USG
Usage: parallel-specs-orchestrator.sh [options] <spec_id> [spec_id...]
       parallel-specs-orchestrator.sh --queue <file>

Options:
  --queue <file>   Read spec IDs from file (one per line, # for comments)
  --dry-run        Print plan without spawning workers
  --help           Show this help

Env (key):
  MAX_PARALLEL_SPECS    default ${MAX_PARALLEL_SPECS} (hard cap 5)
  MAX_RUNTIME_MINUTES   default ${MAX_RUNTIME_MINUTES}
  SPEC_WORKER_CMD       default "${SPEC_WORKER_CMD}"
USG
}

SPEC_LIST=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --queue)
      [[ -z "${2:-}" || ! -f "$2" ]] && { echo "ERROR: queue file missing or not found: ${2:-}" >&2; exit 2; }
      while IFS= read -r line; do
        line="${line%%#*}"  # strip inline comments
        # Greedy whitespace trim (leading + trailing) — non-greedy ${...## } only ate one space
        if [[ "${line}" =~ ^[[:space:]]*(.*[^[:space:]])[[:space:]]*$ ]]; then
          line="${BASH_REMATCH[1]}"
        else
          line=""  # line was empty or whitespace-only after comment strip
        fi
        [[ -n "$line" ]] && SPEC_LIST+=("$line")
      done < "$2"
      shift 2
      ;;
    --*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) SPEC_LIST+=("$1"); shift ;;
  esac
done

if [[ ${#SPEC_LIST[@]} -eq 0 ]]; then
  echo "ERROR: no specs to execute" >&2
  usage >&2
  exit 2
fi

# Locate spec file from ID
locate_spec() {
  local spec_id="$1"
  local matches=()
  while IFS= read -r f; do matches+=("$f"); done < <(find "${SPECS_DIR}" -maxdepth 1 -type f -name "${spec_id}*.md" 2>/dev/null)
  [[ ${#matches[@]} -eq 0 ]] && return 1
  printf '%s\n' "${matches[0]}"
}

# Read field from frontmatter
read_field() {
  local file="$1" field="$2"
  awk -v field="^${field}:" '/^---$/{c++; next} c==1 && $0~field {sub(field, ""); gsub(/^[[:space:]]*"?|"?[[:space:]]*$/, ""); print; exit} c==2{exit}' "${file}"
}

# Allocate port range deterministic from worktree name
allocate_ports() {
  local name="$1"
  local hash; hash=$(echo -n "${name}" | cksum | awk '{print $1}')
  local offset=$(( (hash % 100) * PORT_RANGE_SIZE ))
  local start=$((PORT_RANGE_START + offset))
  echo "${start}-$((start + PORT_RANGE_SIZE - 1))"
}

# Build resolved command per spec (placeholder substitution)
resolve_cmd() {
  local cmd="$1" worktree="$2" spec_id="$3" budget="$4" ports="$5"
  cmd="${cmd//\{worktree\}/${worktree}}"
  cmd="${cmd//\{spec_id\}/${spec_id}}"
  cmd="${cmd//\{budget\}/${budget}}"
  cmd="${cmd//\{ports\}/${ports}}"
  echo "${cmd}"
}

mkdir -p "${PARALLEL_RUNS_DIR}" "${WORKTREES_DIR}"

# Validate all specs first (fail-fast before spawning)
declare -A SPEC_FILES SPEC_EFFORTS SPEC_BUDGETS
for spec_id in "${SPEC_LIST[@]}"; do
  spec_file=$(locate_spec "${spec_id}") || { echo "ERROR: spec not found: ${spec_id}" >&2; exit 1; }
  SPEC_FILES["${spec_id}"]="${spec_file}"
  effort=$(read_field "${spec_file}" "effort")
  # Extract first letter (S/M/L) from effort string like "M 8h" or "L 14h"
  # Accept lowercase too, then normalize to upper — spec-budget.sh accepts either
  # but downstream display + budget cache key rely on a canonical case.
  effort_tier=$(echo "${effort}" | grep -oE '^[SMLsml]' | tr 'sml' 'SML')
  [[ -z "${effort_tier}" ]] && effort_tier="M"
  SPEC_EFFORTS["${spec_id}"]="${effort_tier}"
  budget=$(bash "${ROOT}/scripts/spec-budget.sh" "${effort_tier}" "${spec_id}")
  SPEC_BUDGETS["${spec_id}"]="${budget}"
done

# Plan summary
echo "parallel-specs-orchestrator: plan"
echo "  specs queued       : ${#SPEC_LIST[@]}"
echo "  max parallel       : ${MAX_PARALLEL_SPECS}"
echo "  max runtime/worker : ${MAX_RUNTIME_MINUTES}m"
echo "  worker cmd template: ${SPEC_WORKER_CMD}"
echo ""
echo "  Plan per spec:"
for spec_id in "${SPEC_LIST[@]}"; do
  worktree_name="spec-${spec_id}-$(date +%Y%m%d%H%M%S)"
  ports=$(allocate_ports "${worktree_name}")
  printf "    %-12s  effort=%s budget=%s ports=%s\n" \
    "${spec_id}" "${SPEC_EFFORTS[${spec_id}]}" "${SPEC_BUDGETS[${spec_id}]}" "${ports}"
done

if [[ "${DRY_RUN}" == "1" ]]; then
  echo ""
  echo "DRY-RUN: no workers spawned."
  exit 0
fi

# Spawn workers with bounded concurrency
echo ""
echo "  Spawning workers..."

declare -a WORKER_PIDS=()
declare -A WORKER_SPEC WORKER_LOG WORKER_TMP
declare -A WORKER_DONE

# Concurrency control via job slots
SLOT_COUNT=0
FAILURES=0

spawn_worker() {
  local spec_id="$1"
  local timestamp; timestamp=$(date -u +%Y%m%d-%H%M%S)
  local worktree_name="spec-${spec_id}-${timestamp}"
  local worktree="${WORKTREES_DIR}/${worktree_name}"
  local ports; ports=$(allocate_ports "${worktree_name}")
  local budget="${SPEC_BUDGETS[${spec_id}]}"
  local effort="${SPEC_EFFORTS[${spec_id}]}"
  local tmp_dir="/tmp/savia-${worktree_name}"
  local log_dir="${PARALLEL_RUNS_DIR}/${spec_id}"
  local log_file="${log_dir}/session.log"

  mkdir -p "${log_dir}" "${tmp_dir}"

  local resolved; resolved=$(resolve_cmd "${SPEC_WORKER_CMD}" "${worktree}" "${spec_id}" "${budget}" "${ports}")

  # Worker subshell: isolation envvars + timeout + logging
  (
    export TMPDIR="${tmp_dir}"
    export SPEC_WORKER_PORTS="${ports}"
    export SPEC_WORKER_BUDGET="${budget}"
    export SPEC_WORKER_ID="${spec_id}"
    export SPEC_WORKER_WORKTREE="${worktree}"
    {
      echo "=== parallel-specs worker start ==="
      echo "spec_id   : ${spec_id}"
      echo "effort    : ${effort}"
      echo "budget    : ${budget}"
      echo "worktree  : ${worktree}"
      echo "ports     : ${ports}"
      echo "tmp_dir   : ${tmp_dir}"
      echo "cmd       : ${resolved}"
      echo "timestamp : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo ""
    } > "${log_file}"

    # Per-worker timeout + capture exit
    timeout "${MAX_RUNTIME_MINUTES}m" bash -c "${resolved}" >> "${log_file}" 2>&1
    local exit_code=$?
    {
      echo ""
      echo "=== worker exit ==="
      echo "exit_code : ${exit_code}"
      echo "timestamp : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } >> "${log_file}"
    exit "${exit_code}"
  ) &

  local pid=$!
  WORKER_PIDS+=("${pid}")
  WORKER_SPEC["${pid}"]="${spec_id}"
  WORKER_LOG["${pid}"]="${log_file}"
  WORKER_TMP["${pid}"]="${tmp_dir}"

  echo "    spawned ${spec_id} pid=${pid} ports=${ports} budget=${budget}"
}

wait_one_slot() {
  local finished_pid=""
  while true; do
    for pid in "${WORKER_PIDS[@]}"; do
      [[ -n "${WORKER_DONE[${pid}]:-}" ]] && continue
      if ! kill -0 "${pid}" 2>/dev/null; then
        finished_pid="${pid}"
        break 2
      fi
    done
    sleep 1
  done
  wait "${finished_pid}" 2>/dev/null
  local rc=$?
  WORKER_DONE["${finished_pid}"]=1
  SLOT_COUNT=$((SLOT_COUNT - 1))
  if [[ "${rc}" -ne 0 ]]; then
    FAILURES=$((FAILURES + 1))
    echo "    worker ${WORKER_SPEC[${finished_pid}]} (pid ${finished_pid}) FAILED rc=${rc} log=${WORKER_LOG[${finished_pid}]}" >&2
  else
    echo "    worker ${WORKER_SPEC[${finished_pid}]} (pid ${finished_pid}) OK"
  fi
  # Cleanup tmp dir
  [[ -d "${WORKER_TMP[${finished_pid}]}" ]] && rm -rf "${WORKER_TMP[${finished_pid}]}"
}

for spec_id in "${SPEC_LIST[@]}"; do
  while [[ "${SLOT_COUNT}" -ge "${MAX_PARALLEL_SPECS}" ]]; do
    wait_one_slot
  done
  spawn_worker "${spec_id}"
  SLOT_COUNT=$((SLOT_COUNT + 1))
done

# Drain remaining
while [[ "${SLOT_COUNT}" -gt 0 ]]; do
  wait_one_slot
done

echo ""
echo "parallel-specs-orchestrator: complete"
echo "  workers total  : ${#WORKER_PIDS[@]}"
echo "  failures       : ${FAILURES}"
echo "  logs in        : ${PARALLEL_RUNS_DIR}/<spec_id>/session.log"

# Even if some workers failed, exit 0 (graceful per-worker failure per AC-05).
# Caller can inspect logs/failure count.
exit 0
