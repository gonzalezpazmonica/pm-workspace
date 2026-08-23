#!/usr/bin/env bats
# L13 F3 — l13-meta-pruebas (harness determinista pruebas M1-M4)
# Linea: labs/roadmaps/l13-savia-metacognition.md (F3) / protocolo L13

HARNESS="scripts/l13-meta-pruebas.sh"

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
  FIXDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$FIXDIR"
}

@test "existe, bash -n, sin vendor cloud names, PURE_BASH" {
  [[ -x "$HARNESS" ]]
  bash -n "$HARNESS"
  run grep -niE "api\.openai\.com|api\.anthropic\.com|api\.deepseek\.com|api\.google\.com|api\.mistral\.ai" "$HARNESS"
  [[ "$status" -ne 0 ]]
}

@test "usage sin --pruebas invalido; exit 2" {
  run bash "$HARNESS" --pruebas
  [[ "$status" -eq 2 ]]
}

@test "dependencia ausente → exit 3" {
  # Copiamos el harness a un dir vacío sin las dependencias L13; al ejecutarse
  # desde ahí, la comprobación de dependencias debe abortar con exit 3.
  mkdir -p "$FIXDIR/empty"
  cp "$HARNESS" "$FIXDIR/empty/harness.sh"
  chmod +x "$FIXDIR/empty/harness.sh"
  run bash "$FIXDIR/empty/harness.sh" --pruebas M1
  [[ "$status" -eq 3 ]]
  [[ "$output" == *"falta scripts/meta-monitor.sh"* ]]
}

@test "M1: el tratamiento ajusta el gap de calibración (baseline cruda > ajustada)" {
  run bash "$HARNESS" --pruebas M1 --fixtures "$FIXDIR"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"M1"* ]]
  [[ "$output" == *"PASS"* ]]
  # gap baseline = 15 (confianza cruda 95 vs real 80); el ajuste debe reducirlo
  [[ "$output" == *"baseline=15"* ]]
}

@test "M2: divergence modula la confianza (transiciones monotónicas)" {
  run bash "$HARNESS" --pruebas M2 --fixtures "$FIXDIR"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"M2"* ]]
  [[ "$output" == *"PASS"* ]]
}

@test "M3: autorregulación — POSTPONE evita emitir propuesta errónea" {
  run bash "$HARNESS" --pruebas M3 --fixtures "$FIXDIR"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"M3"* ]]
  [[ "$output" == *"PASS"* ]]
  [[ "$output" == *"POSTPONE"* ]]
}

@test "M4: recalibración — gap decrece entre bloques (curva recalibra)" {
  run bash "$HARNESS" --pruebas M4 --fixtures "$FIXDIR"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"M4"* ]]
  [[ "$output" == *"PASS"* ]]
  [[ "$output" == *"gap bloque2"* ]]
}

@test "suite completa M1-M4: verdict CONFIRMA con >=2 PASS (criterio preregistrado)" {
  run bash "$HARNESS" --fixtures "$FIXDIR"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"CONFIRMA"* ]]
}

@test "CRIT-031 invariante: el harness no modifica CRITERIO.md ni CONSTITUCION.md" {
  local crit_before constit_before crit_after constit_after
  crit_before=$(sha256sum CRITERIO.md 2>/dev/null | cut -d' ' -f1)
  constit_before=$(sha256sum .claude/CONSTITUCION.md 2>/dev/null | cut -d' ' -f1)
  run bash "$HARNESS" --fixtures "$FIXDIR"
  crit_after=$(sha256sum CRITERIO.md 2>/dev/null | cut -d' ' -f1)
  constit_after=$(sha256sum .claude/CONSTITUCION.md 2>/dev/null | cut -d' ' -f1)
  [[ "$crit_before" == "$crit_after" ]]
  [[ "$constit_before" == "$constit_after" ]]
}

@test "reproducibilidad: dos runs idénticos → mismo veredicto y mismas métricas" {
  local r1 r2
  r1=$(bash "$HARNESS" --fixtures "$FIXDIR" 2>/dev/null | grep -E "^\[M[0-9]" | sort)
  r2=$(bash "$HARNESS" --fixtures "$FIXDIR" 2>/dev/null | grep -E "^\[M[0-9]" | sort)
  [[ "$r1" == "$r2" ]]
}