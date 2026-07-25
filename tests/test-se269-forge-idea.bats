#!/usr/bin/env bats
# BATS tests for scripts/forge-idea.sh (SE-269 S1)
# Ref: docs/specs/SE-269-bmad-patterns.spec.md

SCRIPT="scripts/forge-idea.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

# ── Structure / safety ────────────────────────────────────────────────────

@test "SE269-S1: script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "SE269-S1: script has valid bash syntax" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── Input validation ──────────────────────────────────────────────────────

@test "SE269-S1: --idea is required" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "SE269-S1: --idea with empty string fails" {
  run bash "$SCRIPT" --idea ""
  [ "$status" -eq 1 ]
}

@test "SE269-S1: accepts --idea with valid text" {
  run bash "$SCRIPT" --idea "Crear un sistema de notificaciones"
  [ "$status" -eq 0 ]
}

# ── AC-1.3: linea_roja check ──────────────────────────────────────────────

@test "SE269-S1 AC-1.3: idea violating CRIT-023 produces MUERTA" {
  run bash "$SCRIPT" --idea "Propongo un bypass de seguridad fail.open sin verificacion ni control"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"veredicto": "MUERTA"'* ]]
}

@test "SE269-S1 AC-1.3: clean idea survives linea_roja check" {
  run bash "$SCRIPT" --idea "Mejorar la documentacion del proyecto"
  [ "$status" -eq 0 ]
  [[ "$output" != *'"veredicto": "MUERTA"'* ]]
}

# ── Output structure ──────────────────────────────────────────────────────

@test "SE269-S1: output contains required fields" {
  run bash "$SCRIPT" --idea "test idea"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"veredicto"'* ]]
  [[ "$output" == *'"motivo"'* ]]
  [[ "$output" == *'"destilado"'* ]]
  [[ "$output" == *'"turnos"'* ]]
  [[ "$output" == *'"session_id"'* ]]
  [[ "$output" == *'"timestamp"'* ]]
  [[ "$output" == *'"kg_contrast"'* ]]
  [[ "$output" == *'"preguntas_abiertas"'* ]]
  [[ "$output" == *'"decisiones"'* ]]
  [[ "$output" == *'"max_turns"'* ]]
}

@test "SE269-S1: output is valid JSON" {
  run bash "$SCRIPT" --idea "test valid json"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool >/dev/null 2>&1
  [ "$?" -eq 0 ]
}

@test "SE269-S1: verdict is ENDURECIDA for clean ideas" {
  run bash "$SCRIPT" --idea "Una idea valida y no conflictiva"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"veredicto": "ENDURECIDA"'* ]]
}

# ── Adversarial mode ──────────────────────────────────────────────────────

@test "SE269-S1: --adversarial flag is accepted" {
  run bash "$SCRIPT" --idea "test" --adversarial
  [ "$status" -eq 0 ]
}

@test "SE269-S1: adversarial mode reflected in output" {
  run bash "$SCRIPT" --idea "test" --adversarial
  [ "$status" -eq 0 ]
  [[ "$output" == *'"adversarial": true'* ]]
}

@test "SE269-S1: default mode is not adversarial" {
  run bash "$SCRIPT" --idea "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"adversarial": false'* ]]
}

# ── AC-1.6: max turns ─────────────────────────────────────────────────────

@test "SE269-S1 AC-1.6: max_turns is in output" {
  run bash "$SCRIPT" --idea "test" --max-turns 15
  [ "$status" -eq 0 ]
  [[ "$output" == *'"max_turns": 15'* ]]
}

@test "SE269-S1 AC-1.6: default max_turns is 20" {
  run bash "$SCRIPT" --idea "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"max_turns": 20'* ]]
}

# ── Residue file ──────────────────────────────────────────────────────────

@test "SE269-S1 AC-1.5: residue file is created" {
  local tmp_dir; tmp_dir="$(mktemp -d)"
  local residue_file="$tmp_dir/forge-residue.jsonl"
  mkdir -p "$(dirname "$residue_file")"
  run env RESIDUE_FILE="$residue_file" bash "$SCRIPT" --idea "test residue write"
  [ "$status" -eq 0 ]
  [[ -f "$residue_file" ]]
  rm -rf "$tmp_dir"
}

# ── Destilado ─────────────────────────────────────────────────────────────

@test "SE269-S1 AC-1.4: destilado contains the idea content" {
  run bash "$SCRIPT" --idea "Crear un dashboard de metricas"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Crear un dashboard de metricas"* ]]
}

# ── Session ID ────────────────────────────────────────────────────────────

@test "SE269-S1: each run produces unique session_id" {
  run bash "$SCRIPT" --idea "test1"
  local sid1; sid1=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['session_id'])" 2>/dev/null)
  run bash "$SCRIPT" --idea "test2"
  local sid2; sid2=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['session_id'])" 2>/dev/null)
  [[ "$sid1" != "$sid2" ]]
}

# ── Decisiones ────────────────────────────────────────────────────────────

@test "SE269-S1: decisiones array is populated" {
  run bash "$SCRIPT" --idea "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"decisiones"'* ]]
  local count; count=$(echo "$output" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['decisiones']))" 2>/dev/null)
  [[ "$count" -ge 1 ]]
}

# ── kg_contrast field ─────────────────────────────────────────────────────

@test "SE269-S1: kg_contrast field is present" {
  run bash "$SCRIPT" --idea "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"kg_contrast"'* ]]
}
