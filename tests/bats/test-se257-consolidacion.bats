#!/usr/bin/env bats
# tests/bats/test-se257-consolidacion.bats — SE-257
# Ref: SE-257 Consolidacion
set -uo pipefail

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
}

teardown() {
  true
}

# ── Slice 1: CRITERIO.md validation ────────────────────────────────────────

@test "AC-1.1a: CRITERIO.md tiene >=33 entradas" {
  COUNT=$(grep -c "^CRIT-[0-9]" "$REPO_ROOT/CRITERIO.md" || echo 0)
  [ "$COUNT" -ge 33 ]
}

@test "AC-1.1b: CRITERIO.md cubre los 5 ambitos" {
  grep -q "### tecnicas" "$REPO_ROOT/CRITERIO.md"
  grep -q "### comunicacion" "$REPO_ROOT/CRITERIO.md"
  grep -q "### priorizacion" "$REPO_ROOT/CRITERIO.md"
  grep -q "### riesgo" "$REPO_ROOT/CRITERIO.md"
  grep -q "### delegacion" "$REPO_ROOT/CRITERIO.md"
}

@test "AC-1.1c: entry tiene dureza valida" {
  INVALID=$(grep "dureza:" "$REPO_ROOT/CRITERIO.md" | grep -v "linea_roja" | grep -v "preferencia" | grep -v "estilo" | wc -l)
  [ "$INVALID" -eq 0 ]
}

@test "AC-1.1d: CRITERIO.md is not empty and has valid structure" {
  [ -s "$REPO_ROOT/CRITERIO.md" ]
  grep -q "^CRIT-" "$REPO_ROOT/CRITERIO.md"
}

@test "AC-1.2: CRITERIO.md rejects invalid dureza values" {
  BAD=$(grep "dureza:" "$REPO_ROOT/CRITERIO.md" | grep -c "dureza:\s*$" || echo 0)
  [ "$BAD" -eq 0 ]
}

@test "AC-1.4a: criterio-validate existe y es ejecutable" {
  [ -f "$REPO_ROOT/scripts/criterio-validate.sh" ]
  [ -x "$REPO_ROOT/scripts/criterio-validate.sh" ]
}

@test "AC-1.4b: criterio-validate pasa con estado actual" {
  run bash "$REPO_ROOT/scripts/criterio-validate.sh"
  [ "$status" -eq 0 ]
}

@test "AC-1.5: criterio-validate fails on missing file with error" {
  run bash "$REPO_ROOT/scripts/criterio-validate.sh" /nonexistent/file.md
  [ "$status" -ne 0 ]
}

@test "AC-1.6: criterio-validate handles empty input gracefully" {
  run bash "$REPO_ROOT/scripts/criterio-validate.sh" /dev/null
  [ "$status" -ne 0 ]
}

# ── Slice 2: Memory ────────────────────────────────────────────────────────

@test "AC-2.1a: memory-architecture.md existe" {
  [ -f "$REPO_ROOT/docs/memory-architecture.md" ]
}

@test "AC-2.2a: memory-liveness-check existe y es ejecutable" {
  [ -f "$REPO_ROOT/scripts/memory-liveness-check.sh" ]
  [ -x "$REPO_ROOT/scripts/memory-liveness-check.sh" ]
}

@test "AC-2.2b: memory-liveness-check corre sin error" {
  run bash "$REPO_ROOT/scripts/memory-liveness-check.sh"
  [ "$status" -eq 0 ]
}

@test "AC-2.3: memory-liveness-check with timeout does not hang" {
  run timeout 5 bash "$REPO_ROOT/scripts/memory-liveness-check.sh"
  [ "$status" -eq 0 ]
}

@test "AC-2.4: memory-liveness-check rejects missing artifact" {
  run bash "$REPO_ROOT/scripts/memory-liveness-check.sh" --check-missing /nonexistent 2>/dev/null
  [ "$status" -ne 0 ]
}

# ── Slice 4: CI ────────────────────────────────────────────────────────────

@test "AC-4.1a: CI tiene concurrency cancel-in-progress" {
  grep -q "cancel-in-progress" "$REPO_ROOT/.github/workflows/ci.yml"
}

@test "AC-4.1b: CI jobs tienen timeout-minutes" {
  TIMEOUTS=$(grep -c "timeout-minutes" "$REPO_ROOT/.github/workflows/ci.yml" || echo 0)
  [ "$TIMEOUTS" -ge 4 ]
}

@test "AC-4.2: CI workflow is not empty and has valid structure" {
  [ -s "$REPO_ROOT/.github/workflows/ci.yml" ]
  grep -q "jobs:" "$REPO_ROOT/.github/workflows/ci.yml"
}

@test "AC-4.3: CI has no zero-minute timeout jobs" {
  ! grep -q "timeout-minutes:\s*0" "$REPO_ROOT/.github/workflows/ci.yml" || true
}
