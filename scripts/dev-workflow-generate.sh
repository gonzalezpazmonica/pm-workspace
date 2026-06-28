#!/usr/bin/env bash
# dev-workflow-generate.sh — SE-232 Workflow-as-Output para dev-orchestrator
# Genera un workflow YAML adaptado a una spec SDD concreta.
#
# Usage:
#   bash scripts/dev-workflow-generate.sh --spec <path_to_spec.md> [--output <path>]
#
# Output: YAML a stdout (o fichero si --output se indica)

set -euo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────────
SPEC_PATH=""
OUTPUT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec)
      SPEC_PATH="$2"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="$2"
      shift 2
      ;;
    *)
      echo "ERROR: unknown argument '$1'" >&2
      echo "Usage: $0 --spec <path> [--output <path>]" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$SPEC_PATH" ]]; then
  echo "ERROR: --spec is required" >&2
  exit 1
fi

if [[ ! -f "$SPEC_PATH" ]]; then
  echo "ERROR: spec file not found: $SPEC_PATH" >&2
  exit 1
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
spec_content=$(cat "$SPEC_PATH")
spec_lower=$(echo "$spec_content" | tr '[:upper:]' '[:lower:]')

# Extract frontmatter field (first occurrence)
frontmatter_field() {
  local field="$1"
  echo "$spec_content" | grep -m1 "^${field}:" | sed 's/^[^:]*:[[:space:]]*//' | tr -d '"' || true
}

generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

spec_id=$(frontmatter_field "spec_id")
title=$(frontmatter_field "title")
language_fm=$(frontmatter_field "language")

# ── Language detection ────────────────────────────────────────────────────────
detect_language() {
  # Frontmatter field takes priority
  if [[ -n "$language_fm" ]]; then
    echo "$language_fm" | tr '[:upper:]' '[:lower:]'
    return
  fi
  # File extension hints in spec body
  if echo "$spec_lower" | grep -qE '\.py[^a-z]|python'; then
    echo "python"; return
  fi
  if echo "$spec_lower" | grep -qE '\.ts[^a-z]|typescript|angular|react'; then
    echo "typescript"; return
  fi
  if echo "$spec_lower" | grep -qE '\.go[^a-z]|golang'; then
    echo "go"; return
  fi
  if echo "$spec_lower" | grep -qE '\.java[^a-z]|spring'; then
    echo "java"; return
  fi
  if echo "$spec_lower" | grep -qE '\.rb[^a-z]|ruby|rails'; then
    echo "ruby"; return
  fi
  if echo "$spec_lower" | grep -qE '\.rs[^a-z]|rust|tokio|axum'; then
    echo "rust"; return
  fi
  if echo "$spec_lower" | grep -qE '\.php[^a-z]|laravel'; then
    echo "php"; return
  fi
  # Default
  echo "dotnet"
}

language=$(detect_language)

case "$language" in
  python)     impl_agent="python-developer" ;;
  typescript) impl_agent="typescript-developer" ;;
  go)         impl_agent="go-developer" ;;
  java)       impl_agent="java-developer" ;;
  ruby)       impl_agent="ruby-developer" ;;
  rust)       impl_agent="rust-developer" ;;
  php)        impl_agent="php-developer" ;;
  *)          impl_agent="dotnet-developer" ;;
esac

# ── Feature flags ─────────────────────────────────────────────────────────────
# Security step: security-sensitive keywords (negation-aware: "no security" does not trigger)
has_security=false
if echo "$spec_lower" | grep -qE '\bsecurity\b|\bauth\b|\bauthentication\b|\bauthorization\b|\bpii\b|\bcredential\b|\bjwt\b|\boauth\b|\bencrypt\b'; then
  if ! echo "$spec_lower" | grep -qE '\b(no|non|without|not)[[:space:]-]+security\b'; then
    has_security=true
  fi
fi

# Test step: spec has ACs in [ ] checkbox format or explicit test section
has_tests=false
if echo "$spec_content" | grep -qE '^\s*-\s*\[ \]|\btest\b|\btests\b|\btesting\b|\bunit test\b|\bac-[0-9]|\bacceptance criteria\b'; then
  has_tests=true
fi

# Parallel hint: spec explicitly mentions parallel sections or independent parts
has_parallel=false
if echo "$spec_lower" | grep -qE '\bparallel\b|\bindependent\b|\bconcurrent\b'; then
  has_parallel=true
fi

# ── Build step list ───────────────────────────────────────────────────────────
# Steps accumulate in arrays; we'll render YAML at the end.
# Each step: id|agent|subtask|access_list|blocking|parallel_with

declare -a step_ids=()
declare -a step_agents=()
declare -a step_subtasks=()
declare -a step_access=()
declare -a step_blocking=()
declare -a step_parallel=()

next_id=1

add_step() {
  local agent="$1"
  local subtask="$2"
  local access="$3"   # space-separated ids, or ""
  local blocking="$4" # true|false
  local parallel="$5" # space-separated ids, or ""

  step_ids+=("$next_id")
  step_agents+=("$agent")
  step_subtasks+=("$subtask")
  step_access+=("$access")
  step_blocking+=("$blocking")
  step_parallel+=("$parallel")

  (( next_id++ ))
}

# Step 1: security pre-scan (if needed)
sec_id=""
if [[ "$has_security" == "true" ]]; then
  add_step "security-guardian" \
    "Pre-scan spec: detectar superficies de ataque, PII y requisitos de auth" \
    "" "true" ""
  sec_id="1"
fi

# Step: architect validation
arch_access="${sec_id}"
add_step "architect" \
  "Validar arquitectura y dependencias del diseño propuesto en la spec" \
  "$arch_access" "false" ""
arch_id="${step_ids[-1]}"

# Step(s): implementation + (optional) tests
# Determine access for impl: architect (and security if present)
if [[ -n "$sec_id" ]]; then
  impl_access="${sec_id} ${arch_id}"
else
  impl_access="${arch_id}"
fi

if [[ "$has_tests" == "true" ]]; then
  # impl and test-engineer can run in parallel when has_parallel or by default
  if [[ "$has_parallel" == "true" ]]; then
    # We need to know the upcoming test step id before adding impl step
    impl_step_id="$next_id"
    test_step_id=$(( next_id + 1 ))
    add_step "$impl_agent" \
      "Implementar la feature según los requisitos de la spec" \
      "$impl_access" "false" "$test_step_id"
    add_step "test-engineer" \
      "Escribir tests unitarios e integración para los criterios de aceptación" \
      "$impl_access" "false" "$impl_step_id"
  else
    add_step "test-engineer" \
      "Escribir tests unitarios e integración para los criterios de aceptación" \
      "$impl_access" "false" ""
    test_id="${step_ids[-1]}"
    add_step "$impl_agent" \
      "Implementar la feature según los requisitos de la spec" \
      "$impl_access $test_id" "false" ""
  fi
  impl_id="${step_ids[-1]}"
  # Integration step
  prev_test_id="${step_ids[-2]}"
  add_step "$impl_agent" \
    "Integrar tests con la implementación y corregir fallos detectados" \
    "${impl_id} ${prev_test_id}" "false" ""
  integrate_id="${step_ids[-1]}"
else
  add_step "$impl_agent" \
    "Implementar la feature según los requisitos de la spec" \
    "$impl_access" "false" ""
  integrate_id="${step_ids[-1]}"
fi

# Check step count before adding court — max 8
# court-orchestrator is always the last step
current_count=${#step_ids[@]}
if [[ $current_count -ge 8 ]]; then
  # Trim to 7 to leave room for court
  while [[ ${#step_ids[@]} -gt 7 ]]; do
    last_idx=$(( ${#step_ids[@]} - 1 ))
    unset 'step_ids[last_idx]'
    unset 'step_agents[last_idx]'
    unset 'step_subtasks[last_idx]'
    unset 'step_access[last_idx]'
    unset 'step_blocking[last_idx]'
    unset 'step_parallel[last_idx]'
  done
fi

# Last step: court-orchestrator — access_list = all previous step ids
all_prev_ids="${step_ids[*]}"
add_step "court-orchestrator" \
  "Code review final: correctness, security, spec compliance, cognitive clarity" \
  "$all_prev_ids" "false" ""

# ── YAML rendering ────────────────────────────────────────────────────────────
render_id_list() {
  local raw="$1"
  # Trim and deduplicate, emit as YAML inline list
  local unique
  unique=$(echo "$raw" | tr ' ' '\n' | grep -v '^$' | sort -un | tr '\n' ' ' | sed 's/ $//')
  if [[ -z "$unique" ]]; then
    echo "[]"
  else
    local out="["
    local first=true
    for id in $unique; do
      if [[ "$first" == "true" ]]; then
        out="${out}${id}"
        first=false
      else
        out="${out}, ${id}"
      fi
    done
    out="${out}]"
    echo "$out"
  fi
}

build_yaml() {
  echo "workflow:"
  echo "  spec_ref: \"${SPEC_PATH}\""
  echo "  generated_at: \"${generated_at}\""
  if [[ -n "$spec_id" ]]; then
    echo "  spec_id: \"${spec_id}\""
  fi
  if [[ -n "$title" ]]; then
    echo "  title: \"${title}\""
  fi
  echo "  steps:"

  for i in "${!step_ids[@]}"; do
    local id="${step_ids[$i]}"
    local agent="${step_agents[$i]}"
    local subtask="${step_subtasks[$i]}"
    local access="${step_access[$i]}"
    local blocking="${step_blocking[$i]}"
    local parallel="${step_parallel[$i]}"

    echo "    - id: ${id}"
    echo "      agent: ${agent}"
    echo "      subtask: \"${subtask}\""
    echo "      access_list: $(render_id_list "$access")"
    if [[ "$blocking" == "true" ]]; then
      echo "      blocking: true"
    fi
    local plist
    plist=$(render_id_list "$parallel")
    if [[ "$plist" != "[]" ]]; then
      echo "      parallel_with: ${plist}"
    fi
  done
}

yaml_output=$(build_yaml)

# ── Emit ──────────────────────────────────────────────────────────────────────
if [[ -n "$OUTPUT_PATH" ]]; then
  echo "$yaml_output" > "$OUTPUT_PATH"
  echo "Workflow written to: $OUTPUT_PATH" >&2
else
  echo "$yaml_output"
fi
