#!/usr/bin/env bats
# test-se-219-s2-context-meter.bats — SE-219 S2: context window % as first-class metric
# Coverage target: ≥8 tests, score SPEC-055 ≥80
# Ref: docs/propuestas/SE-219-abtop-patterns.md
# SPEC-055 target
SCRIPT="scripts/context-meter.sh"

setup() {
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  # Unset context env vars so tests start clean
  unset CONTEXT_WINDOW_USED   2>/dev/null || true
  unset CONTEXT_WINDOW_MAX    2>/dev/null || true
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ── 1. Script exists and is executable ────────────────────────────────────────
@test "SE-219-S2: context-meter.sh exists and is executable" {
  [ -f "scripts/context-meter.sh" ]
  [ -x "scripts/context-meter.sh" ]
}

# ── 2. set -uo pipefail present (line 2) ──────────────────────────────────────
@test "SE-219-S2: set -uo pipefail on line 2" {
  local line2
  line2=$(sed -n '2p' scripts/context-meter.sh)
  [[ "$line2" == *"set -uo pipefail"* ]]
}

# ── 3. PCT=70 → STATUS=warn ───────────────────────────────────────────────────
@test "SE-219-S2: CONTEXT_WINDOW_USED=140000 MAX=200000 => PCT=70, STATUS=warn" {
  run env CONTEXT_WINDOW_USED=140000 CONTEXT_WINDOW_MAX=200000 \
      bash scripts/context-meter.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_PCT=70"* ]]
  [[ "$output" == *"CONTEXT_STATUS=warn"* ]]
}

# ── 4. PCT=90 → STATUS=critical ───────────────────────────────────────────────
@test "SE-219-S2: PCT=90 => STATUS=critical" {
  run env CONTEXT_WINDOW_USED=180000 CONTEXT_WINDOW_MAX=200000 \
      bash scripts/context-meter.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_STATUS=critical"* ]]
}

# ── 5. PCT=50 → STATUS=ok ─────────────────────────────────────────────────────
@test "SE-219-S2: PCT=50 => STATUS=ok" {
  run env CONTEXT_WINDOW_USED=100000 CONTEXT_WINDOW_MAX=200000 \
      bash scripts/context-meter.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_PCT=50"* ]]
  [[ "$output" == *"CONTEXT_STATUS=ok"* ]]
}

# ── 6. --json produces valid JSON with required fields ────────────────────────
@test "SE-219-S2: --json produces valid JSON with pct and status" {
  run env CONTEXT_WINDOW_USED=134000 CONTEXT_WINDOW_MAX=200000 \
      bash scripts/context-meter.sh --json
  [ "$status" -eq 0 ]
  # Validate JSON fields
  run python3 -c "
import json, sys
d = json.loads('''${output}''')
assert 'pct'    in d, 'missing pct'
assert 'status' in d, 'missing status'
assert 'used'   in d, 'missing used'
assert 'max'    in d, 'missing max'
print('JSON_OK')
"
  [[ "$output" == *"JSON_OK"* ]]
}

# ── 7. No env vars → exit 0, PCT=0, STATUS=unknown (graceful empty state) ────
@test "SE-219-S2: missing env vars => graceful exit 0, PCT=0, STATUS=unknown" {
  run bash scripts/context-meter.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_PCT=0"* ]]
  [[ "$output" == *"CONTEXT_STATUS=unknown"* ]]
}

# ── 8. CONTEXT_WINDOW_MAX=0 → no divide by zero, exit 0 ─────────────────────
@test "SE-219-S2: bad MAX=0 does not divide by zero (exit 0)" {
  run env CONTEXT_WINDOW_USED=50000 CONTEXT_WINDOW_MAX=0 \
      bash scripts/context-meter.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_PCT=0"* ]]
}

# ── 9. --threshold-warn 0 → all non-zero PCT is warn or critical (boundary) ──
@test "SE-219-S2: --threshold-warn 0 boundary => warn or critical for any PCT>0" {
  run env CONTEXT_WINDOW_USED=1000 CONTEXT_WINDOW_MAX=100000 \
      bash scripts/context-meter.sh --threshold-warn 0
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_STATUS=warn"* ]] || [[ "$output" == *"CONTEXT_STATUS=critical"* ]]
}

# ── 10. --threshold-critical configurable (custom boundary) ──────────────────
@test "SE-219-S2: --threshold-critical 50 => PCT=60 is critical" {
  run env CONTEXT_WINDOW_USED=120000 CONTEXT_WINDOW_MAX=200000 \
      bash scripts/context-meter.sh --threshold-critical 50
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_STATUS=critical"* ]]
}

# ── 11. Very large values do not crash (overflow boundary) ────────────────────
@test "SE-219-S2: very large token values do not crash (large overflow boundary)" {
  run env CONTEXT_WINDOW_USED=9999999999 CONTEXT_WINDOW_MAX=99999999999 \
      bash scripts/context-meter.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"CONTEXT_PCT="* ]]
}

# ── 12. Nonexistent snapshot file → graceful fallback, exit 0 ─────────────────
@test "SE-219-S2: nonexistent snapshot file falls back gracefully (exit 0)" {
  run bash scripts/context-meter.sh
  [ "$status" -eq 0 ]
}

# ── 13. --json with no data → valid JSON with zero values ─────────────────────
@test "SE-219-S2: --json with missing context data => valid JSON with zero pct" {
  run bash scripts/context-meter.sh --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['pct']==0"
}

# ── 14. bash -n syntax check ──────────────────────────────────────────────────
@test "SE-219-S2: bash -n syntax check passes" {
  run bash -n scripts/context-meter.sh
  [ "$status" -eq 0 ]
}
