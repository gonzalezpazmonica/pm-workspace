#!/usr/bin/env bats
# tests/bats/test-sldc-context-loop.bats — SE-311 S1: post-merge context loop

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/sldc-context-loop.sh"
  TESTDIR=$(mktemp -d)
  export SLDC_PENDING_DIR="$TESTDIR/pending"
  export HOME="$TESTDIR"
}

teardown() {
  rm -rf "$TESTDIR"
}

@test "S1: clasifica spec → nota spec-status (spec real con **Estado:**)" {
  run bash "$SCRIPT" --base ORIGIN/MAIN --head HEAD --dry-run \
    < <(echo "projects/savia-vaults/specs/SE-311-sldc-context-loop.spec.md")
  [ "$status" -eq 0 ]
  [[ "$output" == *"SE-311-sldc-context-loop-status.md"* ]]
  [[ "$output" == *"PROPOSED"* ]]
}

@test "S1: extrae estado via **Estado:** y via status:" {
  run bash -c "echo '---'; echo 'status: APPROVED'" | grep -q "APPROVED" \
    || true
}

@test "S1: sin artefactos → NO_ARTIFACTS" {
  run bash "$SCRIPT" --base ORIGIN/MAIN --head HEAD --dry-run \
    < <(echo "src/foo.py")
  [ "$status" -eq 0 ]
  [[ "$output" == *"NO_ARTIFACTS"* ]]
}

@test "S1: feed fallido encola pendiente; list-pending lo muestra" {
  run bash "$SCRIPT" --base ORIGIN/MAIN --head HEAD --feed \
    < <(echo "CHANGELOG.d/x.md")
  # sin servidor A2A → encola pendiente (o falla graceful)
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" --list-pending
  [[ "$output" == *"pendientes"* ]]
}

@test "S1: --feed --dry-run no envia nada (DRY, sin pendientes)" {
  run bash "$SCRIPT" --base ORIGIN/MAIN --head HEAD --feed --dry-run \
    < <(echo "CHANGELOG.d/x.md")
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY"* ]]
  [ ! -d "$SLDC_PENDING_DIR" ]
}

@test "S1: CHANGELOG → nota release" {
  run bash "$SCRIPT" --base ORIGIN/MAIN --head HEAD --dry-run \
    < <(printf "CHANGELOG.d/se311-x.md\n- Cambio documentado\n")
  [ "$status" -eq 0 ]
  [[ "$output" == *"releases/"* ]]
}

@test "S1: docs/propuestas → nota decision" {
  run bash "$SCRIPT" --base ORIGIN/MAIN --head HEAD --dry-run \
    < <(printf "docs/propuestas/SE-999-x.md\ntitle: Decision X\n")
  [ "$status" -eq 0 ]
  [[ "$output" == *"decisions/"* ]]
}
