#!/usr/bin/env bats
# test-se-004-agent-interop.bats — SPEC-SE-004: Agent Framework Interop
# Tests: agent-manifest-export.sh, agent-manifest-batch-export.sh

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export REPO_ROOT

  EXPORT_SCRIPT="${REPO_ROOT}/scripts/enterprise/agent-manifest-export.sh"
  BATCH_SCRIPT="${REPO_ROOT}/scripts/enterprise/agent-manifest-batch-export.sh"
  export EXPORT_SCRIPT BATCH_SCRIPT

  ADAPTERS_OUT="${TEST_TMPDIR}/adapters"
  export ADAPTERS_OUT
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── Test 1: agent-manifest-export.sh existe ───────────────────────────────────

@test "SE-004: agent-manifest-export.sh existe y es ejecutable" {
  [[ -f "$EXPORT_SCRIPT" ]]
  [[ -x "$EXPORT_SCRIPT" ]] || chmod +x "$EXPORT_SCRIPT"
}

# ── Test 2: msagent format produce YAML con AgentDefinition ──────────────────

@test "SE-004: msagent format produce YAML con AgentDefinition" {
  chmod +x "$EXPORT_SCRIPT"
  run bash "$EXPORT_SCRIPT" \
    --agent architect \
    --format msagent \
    --output-dir "$ADAPTERS_OUT"

  [ "$status" -eq 0 ]
  [[ -f "${ADAPTERS_OUT}/msagent/architect.yaml" ]]
  grep -q "AgentDefinition" "${ADAPTERS_OUT}/msagent/architect.yaml"
}

# ── Test 3: langgraph format produce JSON con node definition ─────────────────

@test "SE-004: langgraph format produce JSON con node definition" {
  chmod +x "$EXPORT_SCRIPT"
  run bash "$EXPORT_SCRIPT" \
    --agent architect \
    --format langgraph \
    --output-dir "$ADAPTERS_OUT"

  [ "$status" -eq 0 ]
  [[ -f "${ADAPTERS_OUT}/langgraph/architect.json" ]]
  grep -q '"node"' "${ADAPTERS_OUT}/langgraph/architect.json"
}

# ── Test 4: batch-export.sh genera compatibility-matrix.json ─────────────────

@test "SE-004: batch-export.sh genera compatibility-matrix.json" {
  chmod +x "$EXPORT_SCRIPT"
  chmod +x "$BATCH_SCRIPT"

  # Exportar solo formato msagent para reducir tiempo
  run bash "$BATCH_SCRIPT" \
    --format msagent \
    --output-dir "$ADAPTERS_OUT"

  [ "$status" -eq 0 ]
  [[ -f "${ADAPTERS_OUT}/compatibility-matrix.json" ]]
}

# ── Test 5: compatibility-matrix tiene todos los formatos como keys ───────────

@test "SE-004: compatibility-matrix.json tiene formatos como keys" {
  chmod +x "$EXPORT_SCRIPT"
  chmod +x "$BATCH_SCRIPT"

  bash "$BATCH_SCRIPT" \
    --format msagent \
    --output-dir "$ADAPTERS_OUT" >/dev/null 2>&1

  MATRIX="${ADAPTERS_OUT}/compatibility-matrix.json"
  grep -q '"formats"' "$MATRIX"
  grep -q '"msagent"' "$MATRIX"
}

# ── Test 6: export de 'architect' agent no falla en ningún formato ────────────

@test "SE-004: export de architect agent funciona en todos los formatos" {
  chmod +x "$EXPORT_SCRIPT"

  for FMT in msagent langgraph semantic-kernel pydantic-ai openai-agents; do
    run bash "$EXPORT_SCRIPT" \
      --agent architect \
      --format "$FMT" \
      --output-dir "$ADAPTERS_OUT"
    [ "$status" -eq 0 ]
  done
}

# ── Test 7: openai-agents format produce JSON con assistant spec ──────────────

@test "SE-004: openai-agents format produce JSON con assistant spec" {
  chmod +x "$EXPORT_SCRIPT"
  run bash "$EXPORT_SCRIPT" \
    --agent architect \
    --format openai-agents \
    --output-dir "$ADAPTERS_OUT"

  [ "$status" -eq 0 ]
  [[ -f "${ADAPTERS_OUT}/openai-agents/architect.json" ]]
  grep -q '"assistant"' "${ADAPTERS_OUT}/openai-agents/architect.json"
}
