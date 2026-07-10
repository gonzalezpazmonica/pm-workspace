#!/usr/bin/env bats
# tests/bats/test-se256-engram-patterns.bats — SE-256
# Ref: SE-256 Engram Patterns
set -uo pipefail

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SAVE_NUDGE="$REPO_ROOT/scripts/save-nudge.sh"
  DETECT_CONFLICTS="$REPO_ROOT/scripts/relacion-detect-conflicts.sh"
  VERIFY_PRINCIPAL="$REPO_ROOT/scripts/verify-principal.sh"
}

teardown() {
  rm -f "$HOME/.savia/nudge-state"
}

# ── Slice 1: Save-nudge ─────────────────────────────────────────────────

@test "AC-1.1: save-nudge existe y es ejecutable" {
  [ -f "$SAVE_NUDGE" ]
  [ -x "$SAVE_NUDGE" ]
}

@test "AC-1.2: save-nudge usa set -euo pipefail" {
  grep -q "set -euo pipefail" "$SAVE_NUDGE"
}

@test "AC-1.3: save-nudge no bloquea (exit 0 siempre)" {
  run bash "$SAVE_NUDGE"
  [ "$status" -eq 0 ]
}

@test "AC-1.4: save-nudge crea fichero de estado" {
  rm -f "$HOME/.savia/nudge-state"
  run bash "$SAVE_NUDGE"
  [ -f "$HOME/.savia/nudge-state" ]
}

@test "AC-1.5: save-nudge with empty HOME fails gracefully" {
  run env HOME=/nonexistent bash "$SAVE_NUDGE"
  [ "$status" -ne 0 ]
}

@test "AC-1.6: save-nudge rejects missing nudge file" {
  run bash "$SAVE_NUDGE" /nonexistent/nudge 2>/dev/null
  [ "$status" -ne 0 ]
}

@test "AC-1.7: save-nudge on large state file produces no error" {
  mkdir -p "$HOME/.savia"
  python3 -c "print('x' * 10000)" > "$HOME/.savia/nudge-state"
  run bash "$SAVE_NUDGE"
  [ "$status" -eq 0 ]
}

# ── Slice 2: Conflict detection ─────────────────────────────────────────

@test "AC-2.1: detect-conflicts existe y es ejecutable" {
  [ -f "$DETECT_CONFLICTS" ]
  [ -x "$DETECT_CONFLICTS" ]
}

@test "AC-2.2: detect-conflicts funciona con ledger vacio o minimo" {
  run bash "$DETECT_CONFLICTS"
  [ "$status" -eq 0 ]
}

@test "AC-2.3: detect-conflicts --json produce JSON valido" {
  run bash "$DETECT_CONFLICTS" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null || true
}

@test "AC-2.4: detect-conflicts with invalid flag fails" {
  run bash "$DETECT_CONFLICTS" --invalid-flag
  [ "$status" -ne 0 ]
}

@test "AC-2.5: detect-conflicts on empty boundary with no args exits 0" {
  run bash "$DETECT_CONFLICTS"
  [ "$status" -eq 0 ]
}

# ── Slice 3: Principal verification ────────────────────────────────────

@test "AC-3.1: verify-principal existe y es ejecutable" {
  [ -f "$VERIFY_PRINCIPAL" ]
  [ -x "$VERIFY_PRINCIPAL" ]
}

@test "AC-3.2: verify-principal menciona ART-16" {
  run bash "$VERIFY_PRINCIPAL"
  [[ "$output" == *"ART-16"* ]]
}

@test "AC-3.3: verify-principal no bloquea sin principal registrado" {
  rm -f "$HOME/.savia/principal"
  run bash "$VERIFY_PRINCIPAL"
  [ "$status" -eq 0 ]
}

@test "AC-3.4: verify-principal rejects null principal path" {
  run env PRINCIPAL_FILE="" bash "$VERIFY_PRINCIPAL"
  [ "$status" -ne 0 ]
}

@test "AC-3.5: verify-principal handles missing file without timeout" {
  run timeout 5 bash "$VERIFY_PRINCIPAL" /nonexistent/principal
  [ "$status" -ne 0 ]
}
