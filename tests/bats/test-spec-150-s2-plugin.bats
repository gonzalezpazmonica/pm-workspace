#!/usr/bin/env bats
# tests/bats/test-spec-150-s2-plugin.bats
# SPEC-150 Slice 2 — sycophancy guard plugin (TS port of sycophancy-strip.sh)
# >= 4 tests
#
# Context: Slice 1 probe measured FP rate = 0.00 (0%). ROI threshold for
# full migration (Slices 3-6) was not met. Only Slice 2 (sycophancy) was
# executed as the highest semantic-value candidate.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

GUARD_FILE="$REPO_ROOT/.opencode/plugins/guards/sycophancy-guard.ts"
FOUNDATION_FILE="$REPO_ROOT/.opencode/plugins/savia-foundation.ts"
BASH_HOOK="$REPO_ROOT/.opencode/hooks/sycophancy-strip.sh"
MIGRATION_DOC="$REPO_ROOT/docs/rules/domain/hook-multihandler-migration.md"

# ── Test 1: plugin file exists ────────────────────────────────────────────────
@test "SPEC-150-S2 AC-01: sycophancy-guard.ts plugin file exists" {
  [[ -f "$GUARD_FILE" ]]
}

# ── Test 2: plugin contains adulation patterns ────────────────────────────────
@test "SPEC-150-S2 AC-02: sycophancy-guard.ts contains obvious adulation patterns" {
  # Verify key patterns are present in the TypeScript guard
  grep -q "OBVIOUS_PATTERNS" "$GUARD_FILE"
  grep -q "buena" "$GUARD_FILE"
  grep -q "absolutamente" "$GUARD_FILE"
  grep -q "great" "$GUARD_FILE"
  grep -q "detectSycophancy" "$GUARD_FILE"
}

# ── Test 3: bash hook sycophancy-strip.sh still exists (not broken) ───────────
@test "SPEC-150-S2 AC-03: bash hook sycophancy-strip.sh still exists and is executable" {
  [[ -f "$BASH_HOOK" ]]
  [[ -x "$BASH_HOOK" ]]
  # Verify it still references SPEC-192 (structural integrity check)
  grep -q "SPEC-192" "$BASH_HOOK"
}

# ── Test 4: migration doc records S3-S6 descoped (FP=0, ROI low) ─────────────
@test "SPEC-150-S2 AC-04: hook-multihandler-migration.md records Slice 2 decision (FP=0, S3-S6 descoped)" {
  [[ -f "$MIGRATION_DOC" ]]
  grep -q "FP=0\|FP rate\|0.00\|descart" "$MIGRATION_DOC"
  # Must also reference Slice 2 as executed
  grep -q -i "slice.2\|Slice 2\|sycophancy" "$MIGRATION_DOC"
}

# ── Test 5: foundation plugin wires sycophancyGuard in AFTER_GUARDS ───────────
@test "SPEC-150-S2 AC-05: savia-foundation.ts registers sycophancyGuard in AFTER_GUARDS" {
  grep -q "sycophancyGuard" "$FOUNDATION_FILE"
  grep -q "sycophancy-guard" "$FOUNDATION_FILE"
  # Confirm it appears in the AFTER_GUARDS array (not just as an import)
  python3 - "$FOUNDATION_FILE" <<'EOF'
import sys, re
content = open(sys.argv[1]).read()
# Extract the AFTER_GUARDS array block
m = re.search(r'const AFTER_GUARDS\s*=\s*\[(.*?)\]\s*as const', content, re.DOTALL)
assert m, "AFTER_GUARDS array block not found"
after_block = m.group(1)
assert "sycophancyGuard" in after_block, f"sycophancyGuard not in AFTER_GUARDS block: {after_block[:300]}"
EOF
}

# ── Test 6: TS guard exports detectSycophancy and sycophancyGuard ─────────────
@test "SPEC-150-S2 AC-06: sycophancy-guard.ts exports both detectSycophancy and sycophancyGuard" {
  grep -q "export function detectSycophancy" "$GUARD_FILE"
  grep -q "export async function sycophancyGuard" "$GUARD_FILE"
}
