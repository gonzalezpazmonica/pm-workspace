#!/usr/bin/env bats
# Ref: SPEC-SE-036 Slice 3 — block-pat-file-write.sh (PAT/token/secret path guard)
#
# Verifica que el hook bloquea paths de credenciales pero NO produce falsos
# positivos sobre substrings (lección SE-347: `*pat*` bloqueaba dispatch/compat).

setup() {
  HOOK=".opencode/hooks/block-pat-file-write.sh"
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
}

teardown() { cd /; }

@test "pat-hook: permite scripts de trabajo normales (parallel-dispatch, compat)" {
  run bash "$HOOK" --path scripts/parallel-dispatch.sh
  [ "$status" -eq 0 ]
  run bash "$HOOK" --path scripts/compat-loader.sh
  [ "$status" -eq 0 ]
  run bash "$HOOK" --path scripts/patched-version.sh
  [ "$status" -eq 0 ]
}

@test "pat-hook: bloquea paths con token PAT/credential" {
  run bash "$HOOK" --path scripts/github-pat.txt
  [ "$status" -eq 2 ]
  run bash "$HOOK" --path scripts/azure-devops-pat
  [ "$status" -eq 2 ]
  run bash "$HOOK" --path scripts/my_pat.txt
  [ "$status" -eq 2 ]
  run bash "$HOOK" --path scripts/secret.txt
  [ "$status" -eq 2 ]
  run bash "$HOOK" --path scripts/api-token.json
  [ "$status" -eq 2 ]
}

@test "pat-hook: permite tests/ y docs/ (excepciones)" {
  run bash "$HOOK" --path tests/structure/test-github-pat.txt
  [ "$status" -eq 0 ]
  run bash "$HOOK" --path docs/rules/domain/github-pat.md
  [ "$status" -eq 0 ]
}

@test "pat-hook: hook usa coincidencia de token, no substring" {
  # Behavioural (was a grep of the old case pattern, broken by the #1153 regex).
  for p in scripts/my-pat-file.txt scripts/secrets_pat scripts/pat.txt config/devops-pat; do
    run bash "$HOOK" --path "$p"
    [ "$status" -eq 2 ] || { echo "not blocked: $p"; return 1; }
  done
  for p in scripts/compat.sh scripts/patched.sh scripts/parallel-dispatch.sh scripts/spatial.md; do
    run bash "$HOOK" --path "$p"
    [ "$status" -eq 0 ] || { echo "false positive: $p"; return 1; }
  done
}

@test "pat-hook: hook declara set -uo pipefail" {
  head -5 "$HOOK" | grep -q 'set -uo pipefail'
}

@test "pat-hook: fichero normal permitido (README.md)" {
  run bash "$HOOK" --path README.md
  [ "$status" -eq 0 ]
}

@test "pat-hook: mayúsculas también bloquean (MY-PAT.txt)" {
  run bash "$HOOK" --path scripts/MY-PAT.txt
  [ "$status" -eq 2 ]
}

@test "pat-hook: entrada JSON por stdin (tool_input.file_path) bloquea" {
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"scripts/pat.txt\"}}' | bash '$HOOK'"
  [ "$status" -eq 2 ]
}

@test "pat-hook: empty JSON input (sin path) no bloquea" {
  run bash -c "echo '{}' | bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "pat-hook: ruta gitignored permitida (no puede filtrarse)" {
  run bash "$HOOK" --path output/pat.txt
  [ "$status" -eq 0 ]
}

@test "pat-hook: SAVIA_PAT_BLOCK=off desactiva el hook (boundary)" {
  SAVIA_PAT_BLOCK=off run bash "$HOOK" --path scripts/pat.txt
  [ "$status" -eq 0 ]
}

@test "pat-hook: el mensaje de rechazo cita la ruta y la Rule #1" {
  run bash "$HOOK" --path scripts/pat.txt
  [ "$status" -eq 2 ]
  [[ "$output" == *"Path  : scripts/pat.txt"* ]]
  [[ "$output" == *"Rule #1"* ]]
}

@test "pat-hook: empty --path no bloquea (nada que comprobar)" {
  run bash "$HOOK" --path ""
  [ "$status" -eq 0 ]
}

@test "pat-hook: nonexistent directory still evaluated by file name" {
  run bash "$HOOK" --path no/such/dir/deep/pat.txt
  [ "$status" -eq 2 ]
}
