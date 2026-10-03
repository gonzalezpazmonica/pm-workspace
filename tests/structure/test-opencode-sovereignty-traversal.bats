#!/usr/bin/env bats
# Ref: SPEC-OC-01 — Savia Shield en OpenCode (guard TS de soberanía de datos)
#
# Un destino público no puede pasar por privado con «..» en la ruta: el guard resuelve la ruta
# como el sistema (posix.normalize) antes de decidir si escanea. Estructura en reposo y, si hay
# bun, el comportamiento real con una credencial sintética (tests de __tests__).

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  GATE="$ROOT_DIR/.opencode/plugins/guards/data-sovereignty-gate.ts"
  PATTERNS="$ROOT_DIR/.opencode/plugins/lib/sovereignty-patterns.ts"
  BUN_TEST="$ROOT_DIR/.opencode/plugins/__tests__/data-sovereignty-traversal.test.ts"
  HOOK="$ROOT_DIR/.opencode/hooks/data-sovereignty-gate.sh"
  BUN_BIN="$(command -v bun || echo "$HOME/.bun/bin/bun")"
  TMP_DIR="$(mktemp -d)"
  cd "$TMP_DIR"
}

teardown() {
  cd "$ROOT_DIR"
  [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ] && rmdir "$TMP_DIR" 2>/dev/null || true
}

# Ejecuta el guard real con bun sobre una ruta y un contenido; imprime BLOQUEA o PERMITE.
run_gate() {
  "$BUN_BIN" -e "
    const { dataSovereigntyGate } = await import('$GATE');
    const k = (...p) => p.join('');
    const secret = 'conexion: ' + k('Ser', 'ver=db.interna;') + k('User ', 'Id=sa;') + k('Pass', 'word=') + 'Sint3tic0!;';
    const content = process.argv[2] === 'empty' ? '' : secret;
    try { await dataSovereigntyGate({ tool: 'write' }, { args: { filePath: process.argv[1], content } }); console.log('PERMITE') }
    catch { console.log('BLOQUEA') }
  " "$1" "${2:-secret}" 2>/dev/null
}

@test "guard: el fichero existe y declara el guard de soberanía" {
  [ -f "$GATE" ]
  grep -q 'export async function dataSovereigntyGate' "$GATE"
}

@test "positivo: la ruta se normaliza con posix.normalize" {
  grep -qF 'import { posix } from "node:path";' "$GATE"
  grep -qF 'posix.normalize(' "$GATE"
}

@test "negativo: ya no se colapsa «/../» sin resolverlo" {
  run grep -F '.replace(/\/\.\.\//g, "/")' "$GATE"
  [ "$status" -ne 0 ]
}

@test "borde: docs/ relativo cuenta como destino público (N1)" {
  grep -qF '(?:^|\/)docs\/' "$PATTERNS"
}

@test "seguridad: el hook bash gemelo mantiene set -uo pipefail" {
  head -8 "$HOOK" | grep -q 'set -uo pipefail'
}

@test "borde: ruta vacía, el guard no decide nada (empty)" {
  if [ ! -x "$BUN_BIN" ]; then skip "bun no disponible"; fi
  run run_gate "" secret
  [ "$output" = "PERMITE" ]
}

@test "borde: fichero nonexistent bajo docs/ con rodeo se sigue escaneando" {
  if [ ! -x "$BUN_BIN" ]; then skip "bun no disponible"; fi
  run run_gate "/repo/projects/../docs/no-existe-aun.md"
  [ "$output" = "BLOQUEA" ]
}

@test "borde: contenido empty hacia docs/ no bloquea (nada que escanear)" {
  if [ ! -x "$BUN_BIN" ]; then skip "bun no disponible"; fi
  run run_gate "/repo/docs/x.md" empty
  [ "$output" = "PERMITE" ]
}

@test "seguridad: el guard decide sin escribir ficheros" {
  run grep -E 'writeFile|appendFile' "$GATE"
  [ "$status" -ne 0 ]
}

@test "comportamiento: con bun, los casos de rodeo se bloquean (si no hay bun, se omite)" {
  [ -f "$BUN_TEST" ]
  if [ ! -x "$BUN_BIN" ]; then skip "bun no disponible"; fi
  run "$BUN_BIN" test "$BUN_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"3 pass"* ]]
  [[ "$output" == *"0 fail"* ]]
}
