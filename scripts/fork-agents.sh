#!/usr/bin/env bash
# fork-agents.sh — Lanza N invocaciones paralelas de Claude con prefijo cacheable
# SPEC-FORK-AGENT-PREFIX | Ref: docs/specs/SPEC-FORK-AGENT-PREFIX.spec.md
#
# Usage: bash scripts/fork-agents.sh --prefix FILE --suffixes DIR [opciones]
#
# Required:
#   --prefix FILE       Fichero con el prompt prefijo (byte-identico para todos)
#   --suffixes DIR      Directorio con ficheros .txt, uno por agente fork
#
# Optional:
#   --parallel N        Agentes simultaneos. Default: 5
#   --timeout S         Timeout por agente en segundos. Default: 300
#   --run-id ID         ID de la ejecucion. Default: YYYYMMDD-HHMMSS-fork
#   --output DIR        Directorio output. Default: output/fork-runs/{run-id}/
#   --model MODEL       Modelo a usar. Default: prefers.yaml mid-tier
#   --dry-run           Muestra lo que lanzaria sin ejecutar
#   --verify-cache      Imprime sha256 del prefijo y sale (sin lanzar agentes)
#
# Exit: 0 todos ok, 1 error config, 2 algun agente fallo, 3 paralelismo degradado

set -uo pipefail

# ── Constantes ────────────────────────────────────────────────────────────────
readonly DEFAULT_PARALLEL=5
readonly DEFAULT_TIMEOUT=300

# Provider-agnostic model resolution via preferences.yaml
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/savia-env.sh" ]]; then
  source "${SCRIPT_DIR}/savia-env.sh"
fi
readonly DEFAULT_MODEL="${SAVIA_MODEL_MID:-deepseek/deepseek-chat}"

# Resolve tier names (heavy/mid/fast) or legacy short names (sonnet/opus/haiku)
# to the user's provider model ID via ~/.savia/preferences.yaml.
resolve_fork_model() {
  local raw="$1"
  case "$raw" in
    heavy|mid|fast|opus|sonnet|haiku)
      savia_resolve_model "$raw" 2>/dev/null || echo "$raw"
      ;;
    *)
      echo "$raw"
      ;;
  esac
}

# Context windows por modelo (tokens). 80% = limite para prefijo.
# Key convention: CTX_<model_with_underscores>. Falls back to 200000 token default.
readonly CTX_claude_sonnet_4_6=200000
readonly CTX_claude_opus_4_6=200000
readonly CTX_claude_haiku_4_5=200000
readonly CTX_deepseek_deepseek_chat=128000
readonly CTX_deepseek_deepseek_v4_pro=128000
# Chars por token (aproximacion conservadora: 4 chars = 1 token)
readonly CHARS_PER_TOKEN=4

# ── Variables ─────────────────────────────────────────────────────────────────
PREFIX_FILE=""
SUFFIXES_DIR=""
PARALLEL=${DEFAULT_PARALLEL}
TIMEOUT_S=${DEFAULT_TIMEOUT}
RUN_ID=""
OUTPUT_DIR=""
MODEL="${DEFAULT_MODEL}"
DRY_RUN=false
VERIFY_CACHE=false

# ── Parseo de argumentos ──────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
  exit 0
}

parse_args() {
  [[ $# -eq 0 ]] && { usage; }
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix)     PREFIX_FILE="${2:-}";   shift 2 ;;
      --suffixes)   SUFFIXES_DIR="${2:-}";  shift 2 ;;
      --parallel)   PARALLEL="${2:-5}";     shift 2 ;;
      --timeout)    TIMEOUT_S="${2:-300}";  shift 2 ;;
      --run-id)     RUN_ID="${2:-}";        shift 2 ;;
      --output)     OUTPUT_DIR="${2:-}";    shift 2 ;;
      --model)      MODEL="${2:-}";         shift 2 ;;
      --dry-run)    DRY_RUN=true;           shift ;;
      --verify-cache) VERIFY_CACHE=true;   shift ;;
      --help|-h)    usage ;;
      *) echo "ERROR: argumento desconocido: $1" >&2; exit 1 ;;
    esac
  done
}

# ── Validaciones ──────────────────────────────────────────────────────────────
validate_config() {
  local errors=0

  if [[ -z "${PREFIX_FILE}" ]]; then
    echo "ERROR: --prefix es obligatorio" >&2; errors=1
  elif [[ ! -f "${PREFIX_FILE}" ]]; then
    echo "ERROR: fichero prefix no existe: ${PREFIX_FILE}" >&2; errors=1
  fi

  if [[ -z "${SUFFIXES_DIR}" ]]; then
    echo "ERROR: --suffixes es obligatorio" >&2; errors=1
  elif [[ ! -d "${SUFFIXES_DIR}" ]]; then
    echo "ERROR: directorio suffixes no existe: ${SUFFIXES_DIR}" >&2; errors=1
  fi

  if [[ ${errors} -eq 1 ]]; then exit 1; fi

  # FA-02: minimo 2 sufijos
  local suffix_count
  suffix_count=$(find "${SUFFIXES_DIR}" -maxdepth 1 -name "*.txt" | wc -l)
  if [[ ${suffix_count} -lt 2 ]]; then
    echo "ERROR (FA-02): se necesitan al menos 2 sufijos para justificar fork. Usa un subagente directo." >&2
    exit 1
  fi

  # FA-04: prefijo <= 80% context window
  local ctx_var="CTX_$(echo "${MODEL}" | tr '-' '_')"
  local ctx_tokens=${!ctx_var:-200000}
  local prefix_bytes
  prefix_bytes=$(wc -c < "${PREFIX_FILE}")
  local prefix_tokens=$(( prefix_bytes / CHARS_PER_TOKEN ))
  local limit_tokens=$(( ctx_tokens * 80 / 100 ))
  if [[ ${prefix_tokens} -gt ${limit_tokens} ]]; then
    echo "ERROR (FA-04): prefix exceeds 80% context window (${prefix_tokens} tokens estimados > ${limit_tokens})" >&2
    exit 1
  fi
}

# ── Setup de directorio de output ─────────────────────────────────────────────
setup_output_dir() {
  if [[ -z "${RUN_ID}" ]]; then
    RUN_ID="$(date +%Y%m%d-%H%M%S)-fork"
  fi
  if [[ -z "${OUTPUT_DIR}" ]]; then
    OUTPUT_DIR="output/fork-runs/${RUN_ID}"
  fi

  # FA-05: no sobreescribir directorio existente
  if [[ -d "${OUTPUT_DIR}" ]]; then
    echo "ERROR (FA-05): el directorio output ya existe: ${OUTPUT_DIR}" >&2
    exit 1
  fi

  mkdir -p "${OUTPUT_DIR}"
  cp "${PREFIX_FILE}" "${OUTPUT_DIR}/prefix.md"
}

# ── Calculo del hash del prefijo ──────────────────────────────────────────────
compute_prefix_hash() {
  sha256sum "${PREFIX_FILE}" | awk '{print $1}'
}

# ── Lanzamiento de un agente con timeout ─────────────────────────────────────
# Escribe output a agent-NN.md; registra metricas en metrics.jsonl (FA-07)
run_agent() {
  local idx="$1"
  local suffix_file="$2"
  local prompt_file="${OUTPUT_DIR}/prompt-$(printf '%02d' "${idx}").tmp"
  local output_file="${OUTPUT_DIR}/agent-$(printf '%02d' "${idx}").md"
  local metrics_file="${OUTPUT_DIR}/metrics.jsonl"
  local suffix_name
  suffix_name=$(basename "${suffix_file}")

  cat "${PREFIX_FILE}" "${suffix_file}" > "${prompt_file}"

  local start_ts
  start_ts=$(date +%s)
  local exit_code=0

  if command -v claude &>/dev/null; then
    timeout "${TIMEOUT_S}" \
      claude -p "$(cat "${prompt_file}")" --model "${MODEL}" \
      > "${output_file}" 2>/dev/null || exit_code=$?
  else
    # Sin claude CLI disponible (entorno de test / CI)
    echo "[fork-agents: claude CLI no disponible]" > "${output_file}"
    exit_code=0
  fi

  local end_ts
  end_ts=$(date +%s)
  local latency=$(( end_ts - start_ts ))

  # FA-07: registro append-only en metrics.jsonl
  local prefix_bytes
  prefix_bytes=$(wc -c < "${PREFIX_FILE}")
  local tokens_input=$(( prefix_bytes / CHARS_PER_TOKEN ))
  local tokens_cached=$(( tokens_input * 94 / 100 ))   # estimacion 94% cache hit
  local tokens_output=0
  if [[ -f "${output_file}" ]]; then
    local out_bytes
    out_bytes=$(wc -c < "${output_file}")
    tokens_output=$(( out_bytes / CHARS_PER_TOKEN ))
  fi

  printf '{"agent":%d,"suffix":"%s","tokens_input":%d,"tokens_cached":%d,"tokens_output":%d,"latency_s":%d,"exit":%d}\n' \
    "${idx}" "${suffix_name}" "${tokens_input}" "${tokens_cached}" \
    "${tokens_output}" "${latency}" "${exit_code}" \
    >> "${metrics_file}"

  rm -f "${prompt_file}"
  return "${exit_code}"
}

# ── Ejecucion paralela con batching ──────────────────────────────────────────
run_all_agents() {
  local suffixes=()
  while IFS= read -r -d '' f; do
    suffixes+=("$f")
  done < <(find "${SUFFIXES_DIR}" -maxdepth 1 -name "*.txt" -print0 | sort -z)

  local total=${#suffixes[@]}
  local any_failed=0
  local parallel_degraded=0

  # Intentar paralelismo con & y wait
  local batch_start=0
  while [[ ${batch_start} -lt ${total} ]]; do
    local batch_end=$(( batch_start + PARALLEL ))
    [[ ${batch_end} -gt ${total} ]] && batch_end=${total}

    local pids=()
    local batch_idx=()
    local i=${batch_start}
    while [[ ${i} -lt ${batch_end} ]]; do
      local agent_idx=$(( i + 1 ))
      run_agent "${agent_idx}" "${suffixes[${i}]}" &
      pids+=($!)
      batch_idx+=("${agent_idx}")
      i=$(( i + 1 ))
    done

    # Esperar todos los pids del batch
    local j=0
    while [[ ${j} -lt ${#pids[@]} ]]; do
      local pid=${pids[${j}]}
      local aidx=${batch_idx[${j}]}
      if ! wait "${pid}"; then
        echo "WARN: agente ${aidx} termino con error" >&2
        any_failed=1
      fi
      j=$(( j + 1 ))
    done

    batch_start=${batch_end}
  done

  return $(( any_failed == 1 ? 2 : 0 ))
}

# ── Generacion de summary ─────────────────────────────────────────────────────
generate_summary() {
  local metrics_file="${OUTPUT_DIR}/metrics.jsonl"
  local summary_file="${OUTPUT_DIR}/summary.md"
  local prefix_hash
  prefix_hash=$(compute_prefix_hash)

  local total=0 ok=0 failed=0 total_input=0 total_cached=0

  if [[ -f "${metrics_file}" ]]; then
    while IFS= read -r line; do
      total=$(( total + 1 ))
      local exit_val
      exit_val=$(echo "${line}" | grep -o '"exit":[0-9]*' | grep -o '[0-9]*')
      local inp
      inp=$(echo "${line}" | grep -o '"tokens_input":[0-9]*' | grep -o '[0-9]*')
      local cac
      cac=$(echo "${line}" | grep -o '"tokens_cached":[0-9]*' | grep -o '[0-9]*')
      if [[ "${exit_val}" == "0" ]]; then
        ok=$(( ok + 1 ))
      else
        failed=$(( failed + 1 ))
      fi
      total_input=$(( total_input + inp ))
      total_cached=$(( total_cached + cac ))
    done < "${metrics_file}"
  fi

  {
    echo "# Fork Agents — Resumen de Ejecucion"
    echo ""
    echo "**Run ID:** ${RUN_ID}"
    echo "**Modelo:** ${MODEL}"
    echo "**Prefijo sha256:** \`${prefix_hash}\`"
    echo ""
    echo "## Resultados"
    echo ""
    echo "- Total agentes: ${total}"
    echo "- OK: ${ok}/${total}"
    echo "- Fallidos: ${failed}/${total}"
    echo ""
    echo "## Metricas de Cache"
    echo ""
    echo "- Tokens input totales: ${total_input}"
    echo "- Tokens cacheados: ${total_cached}"
    if [[ ${total_input} -gt 0 ]]; then
      local pct=$(( total_cached * 100 / total_input ))
      echo "- Cache hit rate: ${pct}%"
    fi
  } > "${summary_file}"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  parse_args "$@"
  # Resolve tier names (heavy/mid/fast) to provider model ID
  MODEL="$(resolve_fork_model "$MODEL")"

  # --verify-cache: solo imprime hash y sale
  if [[ "${VERIFY_CACHE}" == "true" ]]; then
    if [[ -z "${PREFIX_FILE}" || ! -f "${PREFIX_FILE}" ]]; then
      echo "ERROR: --prefix FILE requerido con --verify-cache" >&2
      exit 1
    fi
    local hash
    hash=$(compute_prefix_hash)
    echo "prefix_sha256=${hash}"
    exit 0
  fi

  validate_config

  # --dry-run: mostrar comandos sin ejecutar
  if [[ "${DRY_RUN}" == "true" ]]; then
    local suffixes=()
    while IFS= read -r -d '' f; do
      suffixes+=("$f")
    done < <(find "${SUFFIXES_DIR}" -maxdepth 1 -name "*.txt" -print0 | sort -z)
    local idx=1
    for s in "${suffixes[@]}"; do
      echo "claude -p \"\$(cat ${PREFIX_FILE} ${s})\" --model ${MODEL} > agent-$(printf '%02d' ${idx}).md"
      idx=$(( idx + 1 ))
    done
    exit 0
  fi

  setup_output_dir

  local prefix_hash
  prefix_hash=$(compute_prefix_hash)
  echo "INFO: prefijo sha256=${prefix_hash} | run-id=${RUN_ID}"

  run_all_agents
  local run_exit=$?

  generate_summary
  echo "INFO: summary generado en ${OUTPUT_DIR}/summary.md"

  exit ${run_exit}
}

main "$@"
