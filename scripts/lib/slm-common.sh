#!/usr/bin/env bash
# slm-common.sh — Shared helpers for SLM subcommands (SE-049 Slice 1).
#
# Source this library from `scripts/slm.sh` and individual subcommands
# (once Slice 2 migrates them). Provides consistent error handling,
# path discovery, and help formatting across the SLM toolchain.
#
# Usage (from another script):
#   LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
#   # shellcheck source=/dev/null
#   source "$LIB_DIR/slm-common.sh"
#
# Safety: no side effects on source. Functions only.

# Guard against double-source
[[ -n "${_SLM_COMMON_LOADED:-}" ]] && return 0
_SLM_COMMON_LOADED=1

# ── Error handling ────────────────────────────────────────

slm_die() {
  local msg="$1"
  local code="${2:-2}"
  echo "ERROR: $msg" >&2
  exit "$code"
}

slm_warn() {
  echo "WARN: $1" >&2
}

# ── Path discovery ────────────────────────────────────────

# Resolve project root from script location (handles sourcing via scripts/slm.sh)
slm_project_root() {
  local script_dir="${1:-$(pwd)}"
  # Walk up until we find .claude/ or hit filesystem root
  local d="$script_dir"
  while [[ "$d" != "/" ]]; do
    [[ -d "$d/.claude" ]] && { echo "$d"; return 0; }
    d="$(dirname "$d")"
  done
  slm_die "cannot find project root (no .claude/ up the tree)" 2
}

# Project-specific SLM data dir (honors CLAUDE_PROJECT_DIR)
slm_data_dir() {
  local project="${1:-default}"
  local base="${HOME}/.savia/slm-data"
  echo "$base/$project"
}

# ── Registry / routing ────────────────────────────────────

# Canonical subcommand registry. Maps short names to existing scripts.
# Used by scripts/slm.sh dispatcher. Slice 2 will migrate logic INTO
# slm.sh using this registry as the single source of truth.
declare -gA SLM_REGISTRY=(
  [collect]="slm-data-collect.sh"
  [prep]="slm-data-prep.sh"
  [dataset-prep]="slm-dataset-prep.sh"
  [validate]="slm-dataset-validate.sh"
  [synth]="slm-synth.sh"
  [synth-recipe]="slm-synth-recipe.sh"
  [train-config]="slm-train-config.sh"
  [train]="slm-train.sh"
  [eval-harness-setup]="slm-eval-harness-setup.sh"
  [eval-compare]="slm-eval-compare.sh"
  [export-gguf]="slm-export-gguf.sh"
  [modelfile-gen]="slm-modelfile-gen.sh"
  [deploy]="slm-deploy.sh"
  [registry]="slm-registry.sh"
  [project-init]="slm-project-init.sh"
  [pipeline-validate]="slm-pipeline-validate.sh"
)

slm_list_subcommands() {
  local k
  for k in "${!SLM_REGISTRY[@]}"; do
    echo "$k"
  done | sort
}

slm_resolve_subcommand() {
  local sub="$1"
  [[ -z "$sub" ]] && return 1
  local target="${SLM_REGISTRY[$sub]:-}"
  [[ -z "$target" ]] && return 1
  echo "$target"
}

# ── Format helpers ────────────────────────────────────────

slm_print_registry_table() {
  printf "  %-20s  %s\n" "SUBCOMMAND" "TARGET SCRIPT"
  printf "  %-20s  %s\n" "----------" "-------------"
  local k
  while IFS= read -r k; do
    printf "  %-20s  %s\n" "$k" "${SLM_REGISTRY[$k]}"
  done < <(slm_list_subcommands)
}
