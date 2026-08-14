#!/usr/bin/env bats
# tests/test-token-meter.bats — SE-326 S3: token-meter (AC-S3).
# Ref: docs/propuestas/SE-326-harness-loop-hygiene.md

METER="scripts/token-meter.py"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPD="${BATS_TEST_TMPDIR}"
  mkdir -p "$TMPD"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR" 2>/dev/null || true
  cd /
}

# ── AC-S3 ─────────────────────────────────────────────────────────────────

@test "S3.1: emite snapshot JSON con total/surface/nodes (AC-S3.1)" {
  run python3 "$METER" --session t1 --surface '[{"role":"user","text":"hola mundo"}]'
  [[ "$output" =~ '"total_tokens"' ]]
  [[ "$output" =~ '"surface_tokens"' ]]
  [[ "$output" =~ '"nodes"' ]]
  python3 -c "import json,sys; d=json.loads('''$output'''); assert 'total_tokens' in d and 'nodes' in d"
}

@test "S3.2: surface_tokens == suma de nodos (AC-S3.2)" {
  out=$(python3 "$METER" --session t2 --surface '[{"role":"user","text":"aaaa"}]')
  python3 -c "
import json,sys
d=json.loads('''$out''')
assert d['surface_tokens'] == sum(n['tokens'] for n in d['nodes']), d
"
}

@test "S3.3: medición no muta ficheros de sesión (AC-S3.3)" {
  export CLAUDE_PROJECT_DIR="$TMPD"
  mkdir -p "$TMPD/output"
  python3 "$METER" --session t3 --surface '[{"role":"user","text":"x"}]' --out "$TMPD/snap.json"
  # no toca agent-traces.jsonl ni crea estado de sesión
  [[ ! -f "$TMPD/output/agent-traces.jsonl" ]]
}

@test "S3.4: baseline usage se reutiliza (AC-S3.1 baseline)" {
  run python3 "$METER" --session t4 --surface '[{"role":"user","text":"aaaa"}]' --usage 1000
  [[ "$output" =~ '"kind": "usage"' ]]
  [[ "$output" =~ '"total_tokens": 1000' ]]
}

@test "S3.5: sin usage → baseline estimated (AC-S3.1)" {
  run python3 "$METER" --session t5 --surface '[{"role":"user","text":"aaaa"}]'
  [[ "$output" =~ '"kind": "estimated"' ]]
}

@test "S3.6: tool_result pesa más que user text (heurística x3)" {
  user=$(python3 "$METER" --session t6 --surface '[{"role":"user","text":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]' | python3 -c "import json,sys;print(json.load(sys.stdin)['surface_tokens'])")
  tool=$(python3 "$METER" --session t6 --surface '[{"role":"tool_result","text":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]' | python3 -c "import json,sys;print(json.load(sys.stdin)['surface_tokens'])")
  [[ "$tool" -gt "$user" ]]
}
