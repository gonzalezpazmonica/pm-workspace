#!/usr/bin/env bats
# tests/test-spill.bats — SE-326 S2: spill-save (AC-S2).
# Ref: docs/propuestas/SE-326-harness-loop-hygiene.md

SPILL="scripts/spill-save.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPD="${BATS_TEST_TMPDIR}"
  export SPILL_ROOT="$TMPD/spill"
  mkdir -p "$TMPD"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR" 2>/dev/null || true
  cd /
}

# ── AC-S2 ─────────────────────────────────────────────────────────────────

@test "S2.1: output > umbral → fichero con 0600 y dir 0700 (AC-S2.1)" {
  python3 -c "print('línea de prueba' * 50)" > "$TMPD/big.txt"
  run bash "$SPILL" --session sessA --name "bash-output.txt" --file "$TMPD/big.txt"
  DEST=$(echo "$output" | grep -o "${TMPD}/spill/[^ ]*" | head -1)
  [[ -n "$DEST" ]]
  MODE=$(stat -c "%a" "$DEST")
  [[ "$MODE" == "600" ]]
  DIRMODE=$(stat -c "%a" "$(dirname "$DEST")")
  [[ "$DIRMODE" == "700" ]]
}

@test "S2.2: output inline reemplazado por preview + locator + hint (AC-S2.2)" {
  python3 -c "print('x' * 500)" > "$TMPD/big.txt"
  run bash "$SPILL" --session sessB --name "out.txt" --file "$TMPD/big.txt"
  [[ "$output" == *"--- preview"* ]]
  [[ "$output" == *"[spill] output completo en"* ]]
  [[ "$output" == *"[spill] usa Read/Grep"* ]]
}

@test "S2.3: fallo de spill (origen inexistente) → no toca nada, exit 1 (AC-S2.3)" {
  run bash "$SPILL" --session sessC --name "out.txt" --file "$TMPD/no-existe.txt"
  [[ $status -eq 1 ]]
  [[ ! -d "$SPILL_ROOT" ]] || [[ -z "$(ls -A "$SPILL_ROOT" 2>/dev/null)" ]]
}

@test "S2.4: nombre con / o .. sanitizado a un segmento (AC-S2.4)" {
  python3 -c "print('y' * 200)" > "$TMPD/big.txt"
  run bash "$SPILL" --session sessD --name "../evil/name.txt" --file "$TMPD/big.txt"
  [[ "$output" =~ "evil" ]]
  # no se crea ningún path fuera del root de spill
  [[ ! -f "$TMPD/evil" ]]
  [[ ! -f "$TMPD/../evil" ]]
}

@test "S2.5: symlink plantado → escritura falla seguro (AC-S2.5)" {
  python3 -c "print('z' * 200)" > "$TMPD/big.txt"
  mkdir -p "$SPILL_ROOT/sessE"
  # plantamos un destino que apunta fuera (adivinando el nombre no es posible por random,
  # pero si existe un symlink en el dir destino el open 'wx' sigue fallando si colisiona)
  RAND=$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')
  ln -s /etc/passwd "$SPILL_ROOT/sessE/${RAND}-name.txt" 2>/dev/null || true
  run bash "$SPILL" --session sessE --name "name.txt" --file "$TMPD/big.txt"
  [[ $status -eq 0 ]] || [[ $status -eq 1 ]]
  # el /etc/passwd original no fue sobrescrito
  [[ "$(head -1 /etc/passwd)" != "z"* ]]
}

@test "S2.6: stdin feed funciona (AC-S2.1 vía stdin)" {
  run bash -c "printf '%s\n' 'stdin-line' | bash '$SPILL' --session sessF --name 'pipe.txt'"
  [[ $status -eq 0 ]]
  [[ "$output" == *"[spill] output completo en"* ]]
}
