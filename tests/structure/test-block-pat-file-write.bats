#!/usr/bin/env bats
# Ref: SPEC-SE-036 Slice 3 — block-pat-file-write.sh (PAT/token/secret path guard)
#
# Verifica que el hook bloquea paths de credenciales pero NO produce falsos
# positivos sobre substrings (lección SE-347: `*pat*` bloqueaba dispatch/compat).

setup() {
  HOOK=".opencode/hooks/block-pat-file-write.sh"
}

@test "block-pat: permite scripts de trabajo normales (parallel-dispatch, compat)" {
  run bash "$HOOK" --path scripts/parallel-dispatch.sh
  [ "$status" -eq 0 ]
  run bash "$HOOK" --path scripts/compat-loader.sh
  [ "$status" -eq 0 ]
  run bash "$HOOK" --path scripts/patched-version.sh
  [ "$status" -eq 0 ]
}

@test "block-pat: bloquea paths con token PAT/credential" {
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

@test "block-pat: permite tests/ y docs/ (excepciones)" {
  run bash "$HOOK" --path tests/structure/test-github-pat.txt
  [ "$status" -eq 0 ]
  run bash "$HOOK" --path docs/rules/domain/github-pat.md
  [ "$status" -eq 0 ]
}

@test "block-pat: hook usa coincidencia de token, no substring" {
  grep -q 'pat|pat.\*|\*-pat|\*-pat.\*|\*_pat|\*_pat.\*' "$HOOK"
  ! grep -qE '^\s+\*pat\*\)' "$HOOK"
}
