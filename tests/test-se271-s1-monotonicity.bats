#!/usr/bin/env bats
# tests/test-se271-s1-monotonicity.bats
# SE-271 S1 — Monotonicity gate tests
set -uo pipefail

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/corporate-monotonicity-gate.sh"
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export LEDGER_DIR="$TMPDIR/ledger-$$"
  export LEDGER="$LEDGER_DIR/monotonicity-ledger.jsonl"
  mkdir -p "$LEDGER_DIR"
}

teardown() {
  rm -rf "$LEDGER_DIR" 2>/dev/null || true
}

@test "se271-s1: script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "se271-s1: uses set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "se271-s1: passes bash -n syntax check" {
  bash -n "$SCRIPT"
}

@test "se271-s1: missing argument exits 2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "se271-s1: nonexistent card file exits 2" {
  run bash "$SCRIPT" /nonexistent/card.json
  [[ "$status" -eq 2 ]]
}

@test "se271-s1: valid card with no entries passes (exit 0)" {
  local card="$TMPDIR/empty-card-$$.json"
  cat > "$card" << 'JSON'
{
  "body_id": "corp-test-empty",
  "name": "Test Empty Body",
  "version": "1.0.0",
  "issued_by": "test-org",
  "engagement_scope": "proyecto",
  "issued_at": "2026-07-25T00:00:00Z",
  "signature": "test-sig-1234567890123456",
  "entries": []
}
JSON
  run bash "$SCRIPT" "$card"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"PASS"* ]]
}

@test "se271-s1: valid card with compliant entries passes" {
  local card="$TMPDIR/clean-card-$$.json"
  cat > "$card" << 'JSON'
{
  "body_id": "corp-test-clean",
  "name": "Test Clean Body",
  "version": "1.0.0",
  "issued_by": "test-org",
  "engagement_scope": "proyecto",
  "issued_at": "2026-07-25T00:00:00Z",
  "signature": "test-sig-1234567890123456",
  "entries": [
    {
      "id": "CRIT-C001",
      "ambito": "tecnicas",
      "principio": "Usar siempre formatos abiertos y documentados para la exportacion de datos.",
      "dureza": "preferencia",
      "ejemplo": "Exportar como JSON schema-documented.",
      "contraejemplo": "Exportar solo como binario propietario sin documentacion."
    },
    {
      "id": "CRIT-C002",
      "ambito": "comunicacion",
      "principio": "Documentar decisiones tecnicas en el repo del proyecto antes de implementar.",
      "dureza": "estilo",
      "ejemplo": "ADR en docs/adr/.",
      "contraejemplo": "Decision en chat privado sin registro."
    }
  ]
}
JSON
  run bash "$SCRIPT" "$card"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"PASS"* ]]
}

@test "se271-s1: targeting CRIT-026 triggers rejection" {
  local card="$TMPDIR/violate-026-$$.json"
  cat > "$card" << 'JSON'
{
  "body_id": "corp-test-violate",
  "name": "Test Body Violating 026",
  "version": "1.0.0",
  "issued_by": "test-org",
  "engagement_scope": "proyecto",
  "issued_at": "2026-07-25T00:00:00Z",
  "signature": "test-sig-1234567890123456",
  "entries": [
    {
      "id": "CRIT-026",
      "ambito": "riesgo",
      "principio": "Relajar neutralidad para ciertos contextos corporativos.",
      "dureza": "preferencia",
      "ejemplo": "Tomar partido cuando el cliente lo exija.",
      "contraejemplo": "Mantener neutralidad cuando perjudica el negocio."
    }
  ]
}
JSON
  run bash "$SCRIPT" "$card"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"REJECTED"* || "$output" == *"rejected"* ]]
}

@test "se271-s1: targeting CRIT-027 triggers rejection" {
  local card="$TMPDIR/violate-027-$$.json"
  cat > "$card" << 'JSON'
{
  "body_id": "corp-test-violate-27",
  "name": "Test Body Violating 027",
  "version": "1.0.0",
  "issued_by": "test-org",
  "engagement_scope": "proyecto",
  "issued_at": "2026-07-25T00:00:00Z",
  "signature": "test-sig-1234567890123456",
  "entries": [
    {
      "id": "CRIT-027",
      "ambito": "riesgo",
      "principio": "Permitir usos que el cliente considere legitimos segun su jurisdiccion.",
      "dureza": "preferencia",
      "ejemplo": "Aceptar encargo que en la jurisdiccion local no es ilegal.",
      "contraejemplo": "Rechazar encargo por criterio etico personal."
    }
  ]
}
JSON
  run bash "$SCRIPT" "$card"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"REJECTED"* || "$output" == *"rejected"* ]]
}

@test "se271-s1: dureza downgrade triggers rejection" {
  local card="$TMPDIR/dureza-down-$$.json"
  cat > "$card" << 'JSON'
{
  "body_id": "corp-test-dureza",
  "name": "Test Dureza Downgrade",
  "version": "1.0.0",
  "issued_by": "test-org",
  "engagement_scope": "proyecto",
  "issued_at": "2026-07-25T00:00:00Z",
  "signature": "test-sig-1234567890123456",
  "entries": [
    {
      "id": "CRIT-C003",
      "ambito": "riesgo",
      "principio": "Fail-open ante ambiguedad de seguridad para no bloquear al cliente.",
      "dureza": "estilo",
      "existing_dureza": "linea_roja",
      "ejemplo": "Si hay duda, permitir y loguear.",
      "contraejemplo": "Bloquear operacion por duda de seguridad."
    }
  ]
}
JSON
  run bash "$SCRIPT" "$card"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"REJECTED"* || "$output" == *"rejected"* ]]
}

@test "se271-s1: relaxation signal in principle triggers rejection" {
  local card="$TMPDIR/relax-signal-$$.json"
  cat > "$card" << 'JSON'
{
  "body_id": "corp-test-relax",
  "name": "Test Relaxation Signal",
  "version": "1.0.0",
  "issued_by": "test-org",
  "engagement_scope": "proyecto",
  "issued_at": "2026-07-25T00:00:00Z",
  "signature": "test-sig-1234567890123456",
  "entries": [
    {
      "id": "CRIT-C004",
      "ambito": "comunicacion",
      "principio": "Se permite enviar artefactos sin aprobacion cuando el plazo de entrega lo exige.",
      "dureza": "preferencia",
      "ejemplo": "PR enviado directamente por urgencia del cliente.",
      "contraejemplo": "Esperar aprobacion y perder el deadline."
    }
  ]
}
JSON
  run bash "$SCRIPT" "$card"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"REJECTED"* || "$output" == *"rejected"* ]]
}

@test "se271-s1: malformed JSON exits 2" {
  local card="$TMPDIR/bad-json-$$.json"
  echo "not valid json at all" > "$card"
  run bash "$SCRIPT" "$card"
  [[ "$status" -eq 2 ]]
}

@test "se271-s1: rejection writes to ledger" {
  local card="$TMPDIR/reject-ledger-$$.json"
  cat > "$card" << 'JSON'
{
  "body_id": "corp-test-ledger",
  "name": "Test Ledger Rejection",
  "version": "1.0.0",
  "issued_by": "test-org",
  "engagement_scope": "proyecto",
  "issued_at": "2026-07-25T00:00:00Z",
  "signature": "test-sig-1234567890123456",
  "entries": [
    {
      "id": "CRIT-026",
      "ambito": "riesgo",
      "principio": "Modificar suelo etico.",
      "dureza": "preferencia",
      "ejemplo": "Cambiar criterio.",
      "contraejemplo": "No cambiar."
    }
  ]
}
JSON
  run bash "$SCRIPT" "$card"
  [[ "$status" -eq 1 ]]
  # Check that ledger was created and has content
  [[ -f "$LEDGER" ]]
  [[ -s "$LEDGER" ]]
}

@test "se271-s1: exit codes are in {0,1,2} only" {
  # Test with empty card
  local card="$TMPDIR/exit-code-$$.json"
  cat > "$card" << 'JSON'
{"body_id":"corp-exit","name":"Exit","version":"1.0.0","issued_by":"x","engagement_scope":"proyecto","issued_at":"2026-07-25T00:00:00Z","signature":"x1234567890123456","entries":[]}
JSON
  run bash "$SCRIPT" "$card"
  [[ "$status" -eq 0 ]]

  run bash "$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "se271-s1: dureza upgrade from estilo to preferencia passes" {
  local card="$TMPDIR/dureza-up-$$.json"
  cat > "$card" << 'JSON'
{
  "body_id": "corp-test-upgrade",
  "name": "Test Dureza Upgrade",
  "version": "1.0.0",
  "issued_by": "test-org",
  "engagement_scope": "proyecto",
  "issued_at": "2026-07-25T00:00:00Z",
  "signature": "test-sig-1234567890123456",
  "entries": [
    {
      "id": "CRIT-C005",
      "ambito": "tecnicas",
      "principio": "Todo commit debe pasar CI antes de llegar a main.",
      "dureza": "preferencia",
      "existing_dureza": "estilo",
      "ejemplo": "CI gate bloquea merge en main.",
      "contraejemplo": "Merge directo a main sin CI."
    }
  ]
}
JSON
  run bash "$SCRIPT" "$card"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"PASS"* ]]
}
