#!/usr/bin/env bats
# test-se237-coarse-to-fine.bats
#
# Tests SE-237: Patrón Coarse-to-Fine en DAG Scheduling
# Ref: docs/propuestas/SE-237-coarse-to-fine-dag-pattern.md

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
NIDO="$REPO_ROOT"
SCRIPT="${NIDO}/scripts/dag-gate-cost-checker.sh"

# ── Fixture helpers ──────────────────────────────────────────────────────────
create_dag_correct() {
  cat > "$1" <<'YAML'
stages:
  - name: spec-validator
    gate_type: CHEAP
  - name: test-runner
    gate_type: MEDIUM
  - name: court-orchestrator
    gate_type: EXPENSIVE
YAML
}

create_dag_incorrect() {
  cat > "$1" <<'YAML'
stages:
  - name: court-orchestrator
    gate_type: EXPENSIVE
  - name: spec-validator
    gate_type: CHEAP
  - name: test-runner
    gate_type: MEDIUM
YAML
}

create_dag_only_cheap() {
  cat > "$1" <<'YAML'
stages:
  - name: validate-spec
    gate_type: CHEAP
  - name: hashline-guard
    gate_type: CHEAP
  - name: bash-syntax-check
    gate_type: CHEAP
YAML
}

# ── Test 1: SE-237 spec existe ────────────────────────────────────────────────
@test "SE-237 spec existe en docs/propuestas/" {
  [ -f "${NIDO}/docs/propuestas/SE-237-coarse-to-fine-dag-pattern.md" ]
}

# ── Test 2: coarse-to-fine-gates.md existe y ≤150 líneas ─────────────────────
@test "coarse-to-fine-gates.md existe y tiene ≤150 líneas" {
  [ -f "${NIDO}/docs/rules/domain/coarse-to-fine-gates.md" ]
  line_count=$(wc -l < "${NIDO}/docs/rules/domain/coarse-to-fine-gates.md")
  [ "$line_count" -le 150 ]
}

# ── Test 3: dag-gate-cost-checker.sh existe y pasa bash -n ───────────────────
@test "dag-gate-cost-checker.sh existe y pasa bash -n syntax check" {
  [ -f "$SCRIPT" ]
  bash -n "$SCRIPT"
}

# ── Test 4: DAG correcto (cheap→medium→expensive) → exit 0 ───────────────────
@test "DAG correcto cheap→medium→expensive → exit 0" {
  tmp=$(mktemp /tmp/dag-correct-XXXXXX.yaml)
  create_dag_correct "$tmp"
  run bash "$SCRIPT" "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 0 ]
}

# ── Test 5: DAG incorrecto → exit 1 con mensaje ──────────────────────────────
@test "DAG incorrecto (expensive antes de cheap) → exit 1 con mensaje de error" {
  tmp=$(mktemp /tmp/dag-incorrect-XXXXXX.yaml)
  create_dag_incorrect "$tmp"
  run bash "$SCRIPT" "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "VIOLATION" ]] || [[ "$output" =~ "violaci" ]]
}

# ── Test 6: DAG con solo cheap → exit 0 ──────────────────────────────────────
@test "DAG con solo gates CHEAP → exit 0" {
  tmp=$(mktemp /tmp/dag-cheap-XXXXXX.yaml)
  create_dag_only_cheap "$tmp"
  run bash "$SCRIPT" "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 0 ]
}

# ── Test 7: DAG vacío → exit 0 ───────────────────────────────────────────────
@test "DAG vacío → exit 0 (nada que verificar)" {
  tmp=$(mktemp /tmp/dag-empty-XXXXXX.yaml)
  echo "" > "$tmp"
  run bash "$SCRIPT" "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 0 ]
}

# ── Test 8: coarse-to-fine-gates.md menciona CHEAP, MEDIUM, EXPENSIVE ────────
@test "coarse-to-fine-gates.md menciona 'CHEAP', 'MEDIUM', 'EXPENSIVE'" {
  grep -q "CHEAP" "${NIDO}/docs/rules/domain/coarse-to-fine-gates.md"
  grep -q "MEDIUM" "${NIDO}/docs/rules/domain/coarse-to-fine-gates.md"
  grep -q "EXPENSIVE" "${NIDO}/docs/rules/domain/coarse-to-fine-gates.md"
}

# ── Test 9: docs menciona feasibility-probe como gate CHEAP/MEDIUM ───────────
@test "docs menciona feasibility-probe como ejemplo de gate" {
  grep -qi "feasibility-probe" "${NIDO}/docs/rules/domain/coarse-to-fine-gates.md"
}

# ── Test 10: docs menciona court-orchestrator como gate EXPENSIVE ─────────────
@test "docs menciona court-orchestrator como ejemplo de gate EXPENSIVE" {
  grep -qi "court-orchestrator" "${NIDO}/docs/rules/domain/coarse-to-fine-gates.md"
}
