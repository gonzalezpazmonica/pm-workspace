#!/usr/bin/env bats
# test-se235-dual-pool.bats
#
# Tests SE-235: Formalización Dual Pool — Proposal State vs Result State
# Ref: docs/propuestas/SE-235-dual-pool-proposal-result.md

NIDO="/home/monica/.savia/nidos/se235-240-proto-architecture"

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

# ── Test 9: autonomous-safety.md tiene sección Dual Pool ─────────────────────
@test "autonomous-safety.md tiene sección '## Dual Pool'" {
  grep -q "## Dual Pool" "${NIDO}/docs/rules/domain/autonomous-safety.md"
}

# ── Test 10: SE-235 spec define "Estado Proposal" y "Estado Result" ──────────
@test "SE-235 spec define 'Estado Proposal' y 'Estado Result'" {
  grep -q "Estado Proposal" "${NIDO}/docs/propuestas/SE-235-dual-pool-proposal-result.md"
  grep -q "Estado Result" "${NIDO}/docs/propuestas/SE-235-dual-pool-proposal-result.md"
}
