#!/usr/bin/env bats
# test-se235-dual-pool.bats
#
# Tests SE-235: Formalización Dual Pool — Proposal State vs Result State
# Ref: docs/propuestas/SE-235-dual-pool-proposal-result.md

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
NIDO="$REPO_ROOT"
PLUGIN="${NIDO}/.opencode/plugins/guards/block-proposal-as-source.ts"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-$(mktemp -d)}"
  WORK="$(mktemp -d "$TMPDIR/dualpool.XXXXXX")"
}

teardown() { cd /; }

# ── Test 1: SE-235 spec existe ────────────────────────────────────────────────
@test "SE-235 spec existe en docs/propuestas/" {
  [ -f "${NIDO}/docs/propuestas/SE-235-dual-pool-proposal-result.md" ]
}

# ── Test 2: autonomous-safety.md menciona "proposal" ────────────────────────
@test "autonomous-safety.md menciona 'proposal'" {
  grep -qi "proposal" "${NIDO}/docs/rules/domain/autonomous-safety.md"
}

# ── Test 3: autonomous-safety.md menciona "result state" ─────────────────────
@test "autonomous-safety.md menciona 'result state'" {
  grep -qi "result state" "${NIDO}/docs/rules/domain/autonomous-safety.md"
}

# ── Test 4: block-proposal-as-source.ts existe en plugins/guards/ ────────────
@test "block-proposal-as-source.ts existe en .opencode/plugins/guards/" {
  [ -f "${NIDO}/.opencode/plugins/guards/block-proposal-as-source.ts" ]
}

# ── Test 5: El plugin tiene tests asociados ───────────────────────────────────
@test "block-proposal-as-source.ts tiene fichero de tests (.test.ts)" {
  [ -f "${NIDO}/.opencode/plugins/guards/block-proposal-as-source.test.ts" ]
}

# ── Test 6: El plugin exporta la función guard ────────────────────────────────
@test "block-proposal-as-source.ts exporta función guard" {
  grep -q "export function guard" "${NIDO}/.opencode/plugins/guards/block-proposal-as-source.ts"
}

# ── Test 7: El plugin detecta paths en .savia/nidos/ como proposal ────────────
@test "el plugin identifica paths en .savia/nidos/ como proposal state" {
  grep -q "\.savia/nidos/" "${NIDO}/.opencode/plugins/guards/block-proposal-as-source.ts"
}

# ── Test 8: El plugin detecta prefijo agent/* ─────────────────────────────────
@test "el plugin identifica ramas agent/* como proposal state" {
  grep -q "agent/" "${NIDO}/.opencode/plugins/guards/block-proposal-as-source.ts"
}

# ── Test 9: autonomous-safety define Dual Pool (núcleo eager + anexo, SPEC-181) ─
@test "autonomous-safety.md define Dual Pool; el anexo conserva la sección" {
  core="${NIDO}/docs/rules/domain/autonomous-safety.md"
  grep -q "Dual Pool.*SE-235" "$core"
  grep -q "proposal = rama .agent/\*." "$core"
  grep -q "result state = en main con PR aprobado" "$core"
  grep -q "## Dual Pool" "${NIDO}/docs/rules/domain/autonomous-safety-reference.md"
}

# ── Test 10: SE-235 spec define "Estado Proposal" y "Estado Result" ──────────
@test "SE-235 spec define 'Estado Proposal' y 'Estado Result'" {
  grep -q "Estado Proposal" "${NIDO}/docs/propuestas/SE-235-dual-pool-proposal-result.md"
  grep -q "Estado Result" "${NIDO}/docs/propuestas/SE-235-dual-pool-proposal-result.md"
}

# ── Safety / edge / negative (SPEC-181 split keeps the definition findable) ──

@test "safety: the Dual Pool line in the eager core is non-empty and cites SE-235" {
  run grep -m1 "Dual Pool" "${NIDO}/docs/rules/domain/autonomous-safety.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SE-235"* ]]
  [[ "$output" == *"proposal"* ]]
}

@test "edge: empty rule copy has no Dual Pool definition (grep detects absence)" {
  : > "$WORK/autonomous-safety.md"
  run grep -q "Dual Pool" "$WORK/autonomous-safety.md"
  [ "$status" -ne 0 ]
}

@test "negative: nonexistent annex path is reported as missing" {
  run grep -q "## Dual Pool" "$WORK/no-such-reference.md"
  [ "$status" -eq 2 ]
}

@test "boundary: plugin guards both proposal sources (nidos paths and agent/* branches)" {
  run grep -c -E "nidos|agent/" "$PLUGIN"
  [ "$status" -eq 0 ]
  [ "$output" -ge 2 ]
}
