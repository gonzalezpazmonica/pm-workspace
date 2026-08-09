#!/usr/bin/env bats
# BATS tests for audit-chain scripts (SE-275 S1 / SE-313 S6).
# Ref: docs/propuestas/SE-275-trust-gated-audit-trail.md

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/ws"
  mkdir -p "$CLAUDE_PROJECT_DIR"
  rm -rf "$CLAUDE_PROJECT_DIR/output/audit" 2>/dev/null || true
}

teardown() {
  cd /
}

@test "audit-chain-append.sh existe y es ejecutable" {
  [[ -f scripts/audit-chain-append.sh ]]
  [[ -x scripts/audit-chain-append.sh ]]
}

@test "audit-chain-verify.sh existe y es ejecutable" {
  [[ -f scripts/audit-chain-verify.sh ]]
  [[ -x scripts/audit-chain-verify.sh ]]
}

@test "append crea cadena con prev_hash encadenado" {
  bash scripts/audit-chain-append.sh court-20260809-001 correctness-judge verdict verdict=pass >/dev/null
  bash scripts/audit-chain-append.sh court-20260809-001 cognitive-judge verdict verdict=pass >/dev/null
  F="$CLAUDE_PROJECT_DIR/output/audit/court-20260809-001.jsonl"
  [[ -f "$F" ]]
  SEQ1=$(head -1 "$F" | jq -r '.seq')
  SEQ2=$(tail -1 "$F" | jq -r '.seq')
  [[ "$SEQ1" == "1" ]]
  [[ "$SEQ2" == "2" ]]
  # prev_hash de la entrada 2 = entry_hash de la entrada 1
  PH2=$(tail -1 "$F" | jq -r '.prev_hash')
  EH1=$(head -1 "$F" | jq -r '.entry_hash')
  [[ "$PH2" == "$EH1" ]]
}

@test "verify pasa con cadena íntegra" {
  bash scripts/audit-chain-append.sh truth-20260809-001 factuality-judge verdict verdict=pass >/dev/null
  bash scripts/audit-chain-append.sh truth-20260809-001 coherence-judge verdict verdict=pass >/dev/null
  run bash scripts/audit-chain-verify.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"íntegra"* ]]
}

@test "verify detecta corrupción (entry modificado)" {
  bash scripts/audit-chain-append.sh court-20260809-002 judge-a verdict verdict=pass >/dev/null
  bash scripts/audit-chain-append.sh court-20260809-002 judge-b verdict verdict=pass >/dev/null
  F="$CLAUDE_PROJECT_DIR/output/audit/court-20260809-002.jsonl"
  python3 -c "
import json
lines=open('$F').read().splitlines()
d=json.loads(lines[1]); d['verdict']='tampered'
lines[1]=json.dumps(d)
open('$F','w').write('\n'.join(lines)+'\n')
"
  run bash scripts/audit-chain-verify.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"CORRUPT"* ]]
}

@test "verify detecta seq salto (entrada eliminada)" {
  bash scripts/audit-chain-append.sh court-20260809-003 judge-a verdict verdict=pass >/dev/null
  bash scripts/audit-chain-append.sh court-20260809-003 judge-b verdict verdict=pass >/dev/null
  bash scripts/audit-chain-append.sh court-20260809-003 judge-c verdict verdict=pass >/dev/null
  F="$CLAUDE_PROJECT_DIR/output/audit/court-20260809-003.jsonl"
  # Eliminar la entrada del medio (seq 2)
  sed -i '2d' "$F"
  run bash scripts/audit-chain-verify.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"seq"* ]]
}

@test "prune no falla sin cadenas" {
  run bash scripts/audit-chain-prune.sh
  [ "$status" -eq 0 ]
}

@test "append con usage inválido falla" {
  run bash scripts/audit-chain-append.sh
  [ "$status" -eq 2 ]
}
