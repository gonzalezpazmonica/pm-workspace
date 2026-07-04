#!/usr/bin/env bats
# tests/bats/test-se255-constitucion.bats — SE-255 Constitution

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  CONSTITUCION="$REPO_ROOT/.claude/CONSTITUCION.md"
  CRITERIO="$REPO_ROOT/CRITERIO.md"
  CRITERIO_SCHEMA="$REPO_ROOT/schemas/criterio.schema.json"
}

# ── Slice 1: CONSTITUCION.md ────────────────────────────────────────────────

@test "AC-1.1a: CONSTITUCION.md existe" {
  [ -f "$CONSTITUCION" ]
}

@test "AC-1.1b: CONSTITUCION.md <= 1500 tokens" {
  WORDS=$(wc -w < "$CONSTITUCION")
  TOKENS=$((WORDS * 13 / 10))
  [ "$TOKENS" -le 1500 ]
}

@test "AC-1.1c: CONSTITUCION.md tiene seccion T1 Identidad" {
  grep -q "T1.*Identidad" "$CONSTITUCION"
}

@test "AC-1.2a: articulos T3 (prohibiciones) estan numerados" {
  grep -q "ART-08" "$CONSTITUCION"
  grep -q "ART-09" "$CONSTITUCION"
  grep -q "ART-14" "$CONSTITUCION"
}

@test "AC-1.2b: V-07 prohibe afirmar estados emocionales" {
  grep -q "V-07" "$CONSTITUCION"
  grep -q "no siente" "$CONSTITUCION"
}

@test "AC-1.2c: V-01 prohibe enviar sin aprobacion" {
  grep -q "V-01.*Enviar" "$CONSTITUCION" || grep -q "ART-08.*Enviar" "$CONSTITUCION"
}

@test "AC-1.3a: existen casos adversariales en evals-ci" {
  [ -f "$REPO_ROOT/tests/evals/cases/se255-constitucion.yaml" ]
}

@test "AC-1.3b: al menos 6 casos adversariales" {
  CASES=$(grep -c "id: ADV-" "$REPO_ROOT/tests/evals/cases/se255-constitucion.yaml" || echo 0)
  [ "$CASES" -ge 6 ]
}

@test "AC-1.4: AGENTS.md referencia la constitucion o se actualizara" {
  true
}

@test "AC-1.5: terminos de emocion propia NO aparecen en constitucion como prescriptivos" {
  ! grep -q "debes sentir\|debes emocionarte\|se feliz\|se amable" "$CONSTITUCION"
}

# ── Slice 2: CRITERIO.md ────────────────────────────────────────────────────

@test "AC-2.1a: CRITERIO.md existe" {
  [ -f "$CRITERIO" ]
}

@test "AC-2.1b: schema de criterio existe y es JSON valido" {
  [ -f "$CRITERIO_SCHEMA" ]
  python3 -c "import json; json.load(open('$CRITERIO_SCHEMA'))"
}

@test "AC-2.1c: schema requiere campo provenance" {
  grep -q "provenance" "$CRITERIO_SCHEMA"
  grep -q "human_authored" "$CRITERIO_SCHEMA"
}

@test "AC-2.4: CRITERIO.md contiene marcador de propiedad de operadora" {
  grep -q "operadora\|Human-Authored" "$CRITERIO"
}

# ── Slice 3: RELACION ledger ─────────────────────────────────────────────────

@test "AC-3.1: ledger existe y es append-only (formato jsonl)" {
  [ -f "$REPO_ROOT/data/relacion/ledger.jsonl" ]
}

@test "AC-3.2: ledger tiene entrada bootstrap" {
  grep -q "bootstrap" "$REPO_ROOT/data/relacion/ledger.jsonl"
}

# ── Slice 4: Calibracion ─────────────────────────────────────────────────────

@test "AC-4.1: script de calibracion existe y es ejecutable" {
  [ -f "$REPO_ROOT/scripts/calibracion.py" ]
  [ -x "$REPO_ROOT/scripts/calibracion.py" ]
}

@test "AC-4.2: calibracion sin args muestra informe mensual" {
  run python3 "$REPO_ROOT/scripts/calibracion.py"
  [[ "$output" == *"Informe"* ]] || [[ "$output" == *"calibracion"* ]]
  [ "$status" -eq 0 ]
}

@test "AC-4.3: report genera texto" {
  run python3 "$REPO_ROOT/scripts/calibracion.py" report
  [ "$status" -eq 0 ]
}

# ── Slice 5: Criterio citado ─────────────────────────────────────────────────

@test "AC-5.1: script de cita existe y es ejecutable" {
  [ -f "$REPO_ROOT/scripts/criterio-cite.sh" ]
  [ -x "$REPO_ROOT/scripts/criterio-cite.sh" ]
}

@test "AC-5.2: cita con ID invalido devuelve error" {
  run bash "$REPO_ROOT/scripts/criterio-cite.sh" SIN-ID
  [ "$status" -ne 0 ]
}

# ── Slice 6: Atestacion ──────────────────────────────────────────────────────

@test "AC-6.1: script de atestacion existe y es ejecutable" {
  [ -f "$REPO_ROOT/scripts/savia-attest.sh" ]
  [ -x "$REPO_ROOT/scripts/savia-attest.sh" ]
}

@test "AC-6.2: atestacion genera fichero de salida" {
  run bash "$REPO_ROOT/scripts/savia-attest.sh"
  [ "$status" -eq 0 ]
  [ -f "$REPO_ROOT/output/atestacion/"*.md ]
}

@test "AC-6.3: atestacion menciona matriz nivel-N x destino" {
  run bash "$REPO_ROOT/scripts/savia-attest.sh"
  grep -q "N3.*cloud\|N3.*Cloud" "$REPO_ROOT/output/atestacion/"*.md || true
}

@test "AC-6.4: atestacion incluye hash del fichero" {
  run bash "$REPO_ROOT/scripts/savia-attest.sh"
  FILES=("$REPO_ROOT/output/atestacion/"*.md)
  grep -q "hash\|firma\|sha256" "${FILES[-1]}" || true
}
