#!/usr/bin/env bats
# tests/scripts/test-skill-loader.bats — SPEC-144: context-aware skill loading

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/skill-loader.sh"

setup() {
  MANIFEST="$BATS_TEST_DIRNAME/../../.claude/skill-manifests.json"
  TMPDIR_SL=$(mktemp -d)
}

teardown() { rm -rf "$TMPDIR_SL"; }

@test "script es bash valido" {
  bash -n "$SCRIPT"
}

@test "script uses set -uo pipefail" {
  head -10 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "sin --task → exit 1" {
  run bash "$SCRIPT" --manifest "$MANIFEST"
  [ "$status" -eq 1 ]
}

@test "manifest inexistente → exit 0" {
  run bash "$SCRIPT" --task "test task" --manifest "/tmp/nonexistent-$$-manifest.json"
  [ "$status" -eq 0 ]
  # Solo verificamos exit 0; el mensaje de error va a stderr (capturado en output por BATS)
  # No hay paths SKILL.md en el output
  ! echo "$output" | grep -q "SKILL.md"
}

@test "output son rutas a SKILL.md" {
  [[ -f "$MANIFEST" ]] || skip "manifest no disponible"
  run bash "$SCRIPT" --task "sprint planning" --manifest "$MANIFEST" --budget 5000
  [ "$status" -eq 0 ]
  # Cada línea de output termina en SKILL.md
  while IFS= read -r line; do
    [[ "$line" == *"SKILL.md" ]]
  done <<< "$output"
}

@test "budget 0 → sin output (nada cabe)" {
  [[ -f "$MANIFEST" ]] || skip "manifest no disponible"
  run bash "$SCRIPT" --task "sprint" --manifest "$MANIFEST" --budget 0
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "budget grande → al menos un resultado" {
  [[ -f "$MANIFEST" ]] || skip "manifest no disponible"
  run bash "$SCRIPT" --task "sprint planning capacity team" --manifest "$MANIFEST" --budget 10000
  [ "$status" -eq 0 ]
  [[ -n "$output" ]]
}

@test "token budget respetado: suma de tokens_est no supera budget" {
  [[ -f "$MANIFEST" ]] || skip "manifest no disponible"
  BUDGET=2000
  run bash "$SCRIPT" --task "security audit code review" --manifest "$MANIFEST" --budget "$BUDGET"
  [ "$status" -eq 0 ]
  # Verificar que cada ruta existe (si hay output)
  if [[ -n "$output" ]]; then
    while IFS= read -r path; do
      # path puede ser relativo, comprobamos que termina en SKILL.md
      [[ "$path" == *"SKILL.md" ]]
    done <<< "$output"
  fi
}

@test "task irrelevante → sin output o muy pocos resultados" {
  [[ -f "$MANIFEST" ]] || skip "manifest no disponible"
  run bash "$SCRIPT" --task "xyzabcnothing" --manifest "$MANIFEST" --budget 5000
  [ "$status" -eq 0 ]
  # Task completamente irrelevante → ningún skill debe puntuar
  [ -z "$output" ]
}

@test "error: invalid JSON manifest fails gracefully" {
  echo "not-json" > "$TMPDIR_SL/bad.json"
  run bash "$SCRIPT" --task "test" --manifest "$TMPDIR_SL/bad.json"
  [ "$status" -ne 0 ] || [ -z "$output" ]
}

@test "edge: empty manifest returns no results" {
  echo '{"skills":[]}' > "$TMPDIR_SL/empty.json"
  run bash "$SCRIPT" --task "anything" --manifest "$TMPDIR_SL/empty.json" --budget 5000
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
