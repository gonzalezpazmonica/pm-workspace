#!/usr/bin/env bats
# Tests for SE-230 Auto-Loop Gate
# Ref: docs/rules/domain/auto-loop-gate.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/auto-loop-gate.sh"
  unset SAVIA_LOOP_CONTEXT 2>/dev/null || true
}

teardown() {
  unset SAVIA_LOOP_CONTEXT 2>/dev/null || true
}

# ── Structural ───────────────────────────────────────────────────────────────

@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "script has safety flags set" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

# ── PROPOSE_LOOP: tdd-vertical-slices via spec+test ──────────────────────────

@test "spec+test -> PROPOSE_LOOP tdd-vertical-slices" {
  run bash "$SCRIPT" --request "implementa la spec SE-200 con tests y dod"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['decision']=='PROPOSE_LOOP', d['decision']
assert d['loop_skill']=='tdd-vertical-slices', d['loop_skill']
"
}

@test "spec+acceptance -> PROPOSE_LOOP tdd-vertical-slices max 8 iterations" {
  run bash "$SCRIPT" --request "implementa spec con acceptance criteria definidos"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['decision']=='PROPOSE_LOOP'
assert d['loop_skill']=='tdd-vertical-slices'
assert d['max_iterations']==8, d['max_iterations']
"
}

# ── PROPOSE_LOOP: tdd-vertical-slices via bug+reproduce ──────────────────────

@test "bug+reproduce -> PROPOSE_LOOP tdd-vertical-slices max 5" {
  run bash "$SCRIPT" --request "hay un bug que debo reproduce con test"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['decision']=='PROPOSE_LOOP', d['decision']
assert d['loop_skill']=='tdd-vertical-slices'
assert d['max_iterations']==5, d['max_iterations']
"
}

@test "bug+falla -> PROPOSE_LOOP tdd-vertical-slices" {
  run bash "$SCRIPT" --request "corrige el bug que falla en el login"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['decision']=='PROPOSE_LOOP'
assert d['loop_skill']=='tdd-vertical-slices'
"
}

# ── PROPOSE_LOOP: code-improvement-loop via refactor+coverage ────────────────

@test "refactor+coverage -> PROPOSE_LOOP code-improvement-loop" {
  run bash "$SCRIPT" --request "refactor el modulo auth mejorando coverage"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['decision']=='PROPOSE_LOOP', d['decision']
assert d['loop_skill']=='code-improvement-loop', d['loop_skill']
assert d['max_iterations']==6
"
}

# ── PROPOSE_LOOP: court-orchestrator via code review ─────────────────────────

@test "code review -> PROPOSE_LOOP court-orchestrator" {
  run bash "$SCRIPT" --request "necesito un code review de este PR"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['decision']=='PROPOSE_LOOP', d['decision']
assert d['loop_skill']=='court-orchestrator', d['loop_skill']
assert d['max_iterations']==3
"
}

@test "pr review -> PROPOSE_LOOP court-orchestrator" {
  run bash "$SCRIPT" --request "haz un pr review del cambio"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['decision']=='PROPOSE_LOOP'
assert d['loop_skill']=='court-orchestrator'
"
}

# ── SINGLE_SHOT: conversational ──────────────────────────────────────────────

@test "conversational request -> SINGLE_SHOT" {
  run bash "$SCRIPT" --request "hola como estas, que tal el sprint"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['decision']=='SINGLE_SHOT', d['decision']
"
}

@test "docs request -> SINGLE_SHOT" {
  run bash "$SCRIPT" --request "actualiza el README con los nuevos endpoints"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['decision']=='SINGLE_SHOT', d['decision']
"
}

# ── CLARIFY_NEEDED: refactor without criterion ───────────────────────────────

@test "refactor alone -> CLARIFY_NEEDED" {
  run bash "$SCRIPT" --request "refactor el servicio de pagos"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['decision']=='CLARIFY_NEEDED', d['decision']
"
}

# ── Recursion guard ───────────────────────────────────────────────────────────

@test "SAVIA_LOOP_CONTEXT set -> always SINGLE_SHOT" {
  export SAVIA_LOOP_CONTEXT="active"
  run bash "$SCRIPT" --request "implementa la spec SE-200 con tests y dod"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys,json; d=json.load(sys.stdin)
assert d['decision']=='SINGLE_SHOT', d['decision']
assert 'recursion' in d['rationale'].lower() or 'recursion' in d.get('rationale','').lower()
"
}

# ── JSON validity ─────────────────────────────────────────────────────────────

@test "output is valid JSON for spec+dod request" {
  run bash "$SCRIPT" --request "spec con criterio de aceptacion y dod"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)"
}

@test "output is valid JSON for SINGLE_SHOT" {
  run bash "$SCRIPT" --request "que tiempo hace"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)"
}

@test "decision field is one of three valid values" {
  run bash "$SCRIPT" --request "cualquier peticion arbitraria sin patron"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['decision'] in ('PROPOSE_LOOP','SINGLE_SHOT','CLARIFY_NEEDED'), d['decision']
"
}

@test "max_iterations is positive int when PROPOSE_LOOP" {
  run bash "$SCRIPT" --request "spec con test de aceptacion"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys,json
d=json.load(sys.stdin)
if d['decision']=='PROPOSE_LOOP':
  assert isinstance(d['max_iterations'],int) and d['max_iterations']>0, d['max_iterations']
"
}

@test "proposal_text contains loop_skill name when PROPOSE_LOOP" {
  run bash "$SCRIPT" --request "spec con tests y criterio de aceptacion"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys,json
d=json.load(sys.stdin)
if d['decision']=='PROPOSE_LOOP':
  assert d['loop_skill'] in (d.get('proposal_text') or ''), 'skill not in proposal_text'
"
}

@test "rationale is non-empty string in PROPOSE_LOOP" {
  run bash "$SCRIPT" --request "hay un bug que reproduce la falla"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys,json
d=json.load(sys.stdin)
assert d['decision']=='PROPOSE_LOOP'
assert isinstance(d['rationale'],str) and len(d['rationale'])>0
"
}
