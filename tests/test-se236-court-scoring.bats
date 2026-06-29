#!/usr/bin/env bats
# test-se236-court-scoring.bats
#
# Tests SE-236: Scoring Numérico en Code Review Court
# Ref: docs/propuestas/SE-236-court-numeric-scoring.md

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
NIDO="$REPO_ROOT"
SCRIPT="${NIDO}/scripts/court-score-aggregator.sh"

# ── Test 1: SE-236 spec existe ────────────────────────────────────────────────
@test "SE-236 spec existe en docs/propuestas/" {
  [ -f "${NIDO}/docs/propuestas/SE-236-court-numeric-scoring.md" ]
}

# ── Test 2: court-score-aggregator.sh existe y es ejecutable ─────────────────
@test "court-score-aggregator.sh existe y es ejecutable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# ── Test 3: Con todos scores 0.0 → veredicto PASS ────────────────────────────
@test "con todos los scores 0.0 → veredicto PASS" {
  input='{"judge":"security-judge","score":0.0,"weight":2.0,"blocking":false}
{"judge":"correctness-judge","score":0.0,"weight":1.5,"blocking":false}'
  
  output=$(echo "$input" | bash "$SCRIPT")
  echo "$output" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); assert d['verdict']=='PASS', f'Expected PASS, got {d[\"verdict\"]}'"
}

# ── Test 4: Con un score 0.9 en judge blocking → veredicto FAIL ──────────────
@test "con score 0.9 en judge blocking=true → veredicto FAIL" {
  input='{"judge":"security-judge","score":0.9,"weight":2.0,"blocking":true,"blocking_threshold":0.3}'
  
  # El script devuelve exit 1 en FAIL, capturamos con || true
  output=$(echo "$input" | bash "$SCRIPT" || true)
  echo "$output" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); assert d['verdict']=='FAIL', f'Expected FAIL, got {d[\"verdict\"]}'"
}

# ── Test 5: energy total < threshold → PASS ──────────────────────────────────
@test "energy total < 0.2 → veredicto PASS" {
  input='{"judge":"correctness-judge","score":0.1,"weight":1.0,"blocking":false}
{"judge":"architecture-judge","score":0.05,"weight":1.0,"blocking":false}'
  
  output=$(echo "$input" | COURT_ENERGY_THRESHOLD=0.2 bash "$SCRIPT")
  echo "$output" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); assert d['verdict']=='PASS', f'Expected PASS, got {d[\"verdict\"]}'"
}

# ── Test 6: energy total >= threshold → FAIL o CONDITIONAL ───────────────────
@test "energy total >= 0.5 → veredicto FAIL" {
  input='{"judge":"security-judge","score":0.8,"weight":1.0,"blocking":false}
{"judge":"correctness-judge","score":0.6,"weight":1.0,"blocking":false}'
  
  output=$(echo "$input" | COURT_ENERGY_THRESHOLD=0.2 bash "$SCRIPT" || true)
  echo "$output" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); assert d['verdict'] in ['FAIL','CONDITIONAL'], f'Expected FAIL or CONDITIONAL, got {d[\"verdict\"]}'"
}

# ── Test 7: Reporta bottleneck_judge correctamente ───────────────────────────
@test "reporta bottleneck_judge como el juez con mayor score ponderado" {
  input='{"judge":"security-judge","score":0.8,"weight":2.0,"blocking":false}
{"judge":"cognitive-judge","score":0.1,"weight":0.5,"blocking":false}'
  
  output=$(echo "$input" | bash "$SCRIPT" || true)
  echo "$output" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); assert d['bottleneck_judge']=='security-judge', f'Expected security-judge, got {d[\"bottleneck_judge\"]}'"
}

# ── Test 8: JSONL vacío → PASS por defecto ────────────────────────────────────
@test "JSONL vacío → veredicto PASS por defecto" {
  output=$(echo "" | bash "$SCRIPT")
  echo "$output" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); assert d['verdict']=='PASS', f'Expected PASS, got {d[\"verdict\"]}'"
}

# ── Test 9: COURT_ENERGY_THRESHOLD es configurable ───────────────────────────
@test "COURT_ENERGY_THRESHOLD configurable via env var" {
  input='{"judge":"judge1","score":0.15,"weight":1.0,"blocking":false}'
  
  # Con threshold 0.1, score 0.15 debería ser CONDITIONAL o FAIL
  output=$(echo "$input" | COURT_ENERGY_THRESHOLD=0.1 bash "$SCRIPT" || true)
  echo "$output" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); assert d['verdict'] != 'PASS', f'Expected non-PASS with threshold 0.1 and score 0.15'"
}

# ── Test 10: script pasa bash -n syntax check ────────────────────────────────
@test "court-score-aggregator.sh pasa bash -n syntax check" {
  bash -n "$SCRIPT"
}

# ── Test 11: docs/rules/domain/ tiene md que menciona scoring numérico ────────
@test "docs/rules/domain/ tiene fichero md que menciona scoring numérico" {
  grep -rl "scoring" "${NIDO}/docs/rules/domain/" | grep -q "\.md$"
}

# ── Test 12: output incluye total_energy, bottleneck_judge, convergence_score ─
@test "output incluye total_energy, bottleneck_judge y convergence_score" {
  input='{"judge":"security-judge","score":0.1,"weight":2.0,"blocking":false}'
  output=$(echo "$input" | bash "$SCRIPT")
  
  echo "$output" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
assert 'total_energy' in d, 'missing total_energy'
assert 'bottleneck_judge' in d, 'missing bottleneck_judge'
assert 'convergence_score' in d, 'missing convergence_score'
"
}
