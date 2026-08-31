#!/usr/bin/env bats
# test-se358-plan-md.bats — BATS tests for SE-358 plan.md verificado
# Ref: SE-358 — plan versionado + sync hook plan↔diff

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  VALIDATE="$REPO_ROOT/scripts/plan-validate.py"
  DIFFCHECK="$REPO_ROOT/scripts/plan-diff-check.sh"
  export REPO_ROOT VALIDATE DIFFCHECK

  # plan de ejemplo en tmp
  export PLAN_FILE="$(mktemp -d)/plan.md"
  cat > "$PLAN_FILE" << 'EOF'
# Plan: sample (from SPEC-000)

## Files that change
src/a.py (new)
src/b.py (modified)
tests/test_b.py (new)

## Order of work
1. Añadir b.py
2. Conectar a.py

## Risks
La API rate-limita; cachear.

## Proof
test_b.py cubre 3 estados.
EOF
}

teardown() {
  if [[ -n "${PLAN_FILE:-}" && -d "$(dirname "$PLAN_FILE")" ]]; then
    rm -rf "$(dirname "$PLAN_FILE")"
  fi
}

# ── T1: validador ─────────────────────────────────────────────────────────────

@test "plan válido → OK" {
  run python3 "$VALIDATE" --plan "$PLAN_FILE"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"OK"* ]]
}

@test "plan válido --files lista archivos" {
  run python3 "$VALIDATE" --plan "$PLAN_FILE" --files
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"src/a.py"* ]]
  [[ "$output" == *"src/b.py"* ]]
}

@test "plan malformado → WARN (no bloquea)" {
  local bad="$(dirname "$PLAN_FILE")/bad.md"
  printf '# Plan\n\n## Solo\n' > "$bad"
  run python3 "$VALIDATE" --plan "$bad"
  [[ "$status" -eq 0 ]]  # fail-soft
  [[ "$output" == *"WARN"* ]]
}

@test "plan malformado --strict → exit != 0" {
  local bad="$(dirname "$PLAN_FILE")/bad2.md"
  printf '# Plan\n\n## Solo\n' > "$bad"
  run python3 "$VALIDATE" --plan "$bad" --strict
  [[ "$status" -ne 0 ]]
}

@test "plan inexistente → error" {
  run python3 "$VALIDATE" --plan "/no/existe/plan.md"
  [[ "$status" -ne 0 ]]
}

# ── T2: diff check ────────────────────────────────────────────────────────────

@test "diff dentro del plan → pass" {
  run bash "$DIFFCHECK" --plan "$PLAN_FILE" --files "src/a.py src/b.py"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"WARN [SE-358]"* ]]
}

@test "diff con archivo fuera del plan → WARN (mode warn, exit 0)" {
  run bash "$DIFFCHECK" --plan "$PLAN_FILE" --files "src/a.py src/outside.py"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"WARN [SE-358]"* ]]
}

@test "diff fuera del plan mode block → exit 2" {
  run bash "$DIFFCHECK" --plan "$PLAN_FILE" --files "src/a.py src/outside.py" --mode block
  [[ "$status" -eq 2 ]]
}

@test "artefactos de proceso no son divergencia" {
  run bash "$DIFFCHECK" --plan "$PLAN_FILE" --files "src/a.py docs/specs/SE-358.spec.md CHANGELOG.d/x.md"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"WARN [SE-358]"* ]]
}

@test "plan inexistente → fail-soft (exit 0)" {
  run bash "$DIFFCHECK" --plan "/no/existe/plan.md" --files "src/a.py"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"fail-soft"* ]]
}

@test "falta --plan o --files → error" {
  run bash "$DIFFCHECK" --plan "$PLAN_FILE"
  [[ "$status" -ne 0 ]]
}
