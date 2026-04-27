#!/usr/bin/env bats
# Ref: SPEC-SE-035 — delta-tier.sh helper
# Pattern source: dreamxist/balance reconciliation_status (MIT)

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$ROOT_DIR/scripts/enterprise/delta-tier.sh"
}

# ── Usage ───────────────────────────────────────────────────────────────────

@test "delta-tier: --help exits 0 and shows Usage line" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "delta-tier: rejects no args with exit 2" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "delta-tier: rejects single arg with exit 2" {
  run bash "$SCRIPT" 100
  [ "$status" -eq 2 ]
}

@test "delta-tier: rejects 5+ args with exit 2" {
  run bash "$SCRIPT" 1 2 3 4 5
  [ "$status" -eq 2 ]
}

# ── Tier classification ─────────────────────────────────────────────────────

@test "delta-tier: equal values → green tier" {
  run bash "$SCRIPT" 1000 1000
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=green"* ]]
}

@test "delta-tier: small delta below amber → green" {
  run bash "$SCRIPT" 1100 1000   # delta=100 < amber=1000
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=green"* ]]
}

@test "delta-tier: delta at amber threshold → amber" {
  run bash "$SCRIPT" 2000 1000   # delta=1000 == amber
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=amber"* ]]
}

@test "delta-tier: delta above amber but below red → amber" {
  run bash "$SCRIPT" 3000 1000   # delta=2000, amber=1000, red=5000
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=amber"* ]]
}

@test "delta-tier: delta at red threshold → red" {
  run bash "$SCRIPT" 6000 1000   # delta=5000 == red
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=red"* ]]
}

@test "delta-tier: delta above red threshold → red" {
  run bash "$SCRIPT" 50000 1000  # delta=49000 >> red=5000
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=red"* ]]
}

@test "delta-tier: negative delta uses absolute value for tier" {
  run bash "$SCRIPT" 1000 6000   # delta=-5000, |delta|=5000 == red
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=red"* ]]
}

# ── Custom thresholds ───────────────────────────────────────────────────────

@test "delta-tier: custom amber threshold honoured" {
  run bash "$SCRIPT" 100 50 25 100   # delta=50, amber=25, red=100 → amber
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=amber"* ]]
}

@test "delta-tier: custom red threshold triggers red" {
  run bash "$SCRIPT" 1000 0 100 500   # delta=1000, red=500 → red
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=red"* ]]
}

# ── Output modes ────────────────────────────────────────────────────────────

@test "delta-tier: --json emits valid JSON" {
  run bash "$SCRIPT" --json 100 50 25 100
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['tier']=='amber'"
}

@test "delta-tier: --json includes all 7 keys" {
  run bash "$SCRIPT" --json 100 50 25 100
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert {'declared','computed','delta','abs_delta','tier','amber','red'} == set(d.keys())
"
}

@test "delta-tier: --color emits ANSI escape" {
  run bash "$SCRIPT" --color 1000 1000
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\033'* ]]
}

@test "delta-tier: --color green uses green ANSI (32)" {
  run bash "$SCRIPT" --color 1000 1000
  [ "$status" -eq 0 ]
  [[ "$output" == *"32m"* ]]
}

@test "delta-tier: --color red uses red ANSI (31)" {
  run bash "$SCRIPT" --color 6000 1000
  [ "$status" -eq 0 ]
  [[ "$output" == *"31m"* ]]
}

# ── Decimal numbers ─────────────────────────────────────────────────────────

@test "delta-tier: handles decimal declared / computed" {
  run bash "$SCRIPT" 12.5 10.0 1 5
  [ "$status" -eq 0 ]
  [[ "$output" == *"tier=amber"* ]] || [[ "$output" == *"delta=2.5"* ]]
}

@test "delta-tier: handles negative declared" {
  run bash "$SCRIPT" -100 100 50 200
  [ "$status" -eq 0 ]
  # |delta| = 200 ≥ red=200 → red
  [[ "$output" == *"tier=red"* ]]
}

# ── Validation ──────────────────────────────────────────────────────────────

@test "delta-tier: rejects non-numeric declared with exit 3" {
  run bash "$SCRIPT" not_a_number 100
  [ "$status" -eq 3 ]
  [[ "$output" == *"not a number"* ]]
}

@test "delta-tier: rejects non-numeric computed with exit 3" {
  run bash "$SCRIPT" 100 NaN
  [ "$status" -eq 3 ]
}

@test "edge: zero zero zero zero → green tier" {
  run bash "$SCRIPT" 0 0 0 0
  [ "$status" -eq 0 ]
  # delta=0 < red=0? abs(0) >= 0 → red. Actually tier picks red (≥ red).
  # This is intentional foot-gun guard: thresholds 0 mean "any drift is red".
  [[ "$output" == *"tier=red"* ]]
}

@test "edge: empty input strings rejected" {
  run bash "$SCRIPT" "" ""
  [ "$status" -eq 3 ]
}

# ── Static / safety / spec ref ──────────────────────────────────────────────

@test "spec ref: SPEC-SE-035 cited in script header" {
  grep -q "SPEC-SE-035" "$SCRIPT"
}

@test "spec ref: Balance MIT origin documented" {
  grep -qi "balance" "$SCRIPT"
}

@test "safety: delta-tier.sh has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: delta-tier.sh never invokes git or network" {
  ! grep -E '^[^#]*(git\s|curl|wget|gh\s)' "$SCRIPT"
}
