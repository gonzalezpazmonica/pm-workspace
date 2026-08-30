#!/usr/bin/env bats
# tests/test-se-350-coherence-court.bats — SE-350: Coherence Court
# Ref: docs/specs/SE-350-coherence-court.spec.md
# Safety: set -uo pipefail applied per-test in setup().
#
# Coverage notes:
#   Exercises the public command surface of scripts/coherence-court.sh:
#     check, premises (init/add/list/show/clear), skeleton, score, gate, hash
#   Verifies the transversal contract: coherence is RELATIVE (needs premises),
#   gate exit codes mirror court-score-aggregator (0/2/1), and CRIT-001 (no net).

CC="${BATS_TEST_DIRNAME}/../scripts/coherence-court.sh"
SCHEMA="${BATS_TEST_DIRNAME}/../.claude/schemas/coherence-crc.schema.json"
RULES="${BATS_TEST_DIRNAME}/../rules/coherence.rules.yaml"
AGENTS_DIR="${BATS_TEST_DIRNAME}/../.opencode/agents"
RULES_DOC="${BATS_TEST_DIRNAME}/../docs/rules/domain/coherence-court.md"

setup() {
  set -uo pipefail
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export COHERENCE_PREMISES_DIR="$TMP_DIR/data"
  mkdir -p "$TMP_DIR/data"
  echo "stage output dummy" > "$TMP_DIR/stage.txt"
  FLOW="test-flow"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

# helper: register 3 premises (one of each kind)
seed_premises() {
  bash "$CC" premises "$FLOW" init
  bash "$CC" premises "$FLOW" add constraint "Max 400 LOC" --stage stage-1 >/dev/null
  bash "$CC" premises "$FLOW" add fact "El modulo X existe" --stage stage-1 >/dev/null
  bash "$CC" premises "$FLOW" add objective "No romper API" --stage stage-1 >/dev/null
}

# ── Structural ────────────────────────────────────────────────────────────

@test "coherence-court.sh exists and has no syntax errors" {
  [[ -f "$CC" ]]
  bash -n "$CC"
}

@test "coherence-court.sh is executable" {
  [[ -x "$CC" ]]
}

@test "coherence-court.sh uses set -uo pipefail" {
  head -3 "$CC" | grep -q "set -uo pipefail"
}

@test "coherence-crc schema exists and is valid JSON" {
  [[ -f "$SCHEMA" ]]
  python3 -c "import json; json.load(open('$SCHEMA'))"
}

@test "schema defines all 4 coherence judges" {
  for judge in coherence-factual coherence-scope coherence-objectives coherence-premise-drift; do
    grep -q "\"$judge\"" "$SCHEMA"
  done
}

@test "schema defines finding severity enum" {
  grep -q '"critical"' "$SCHEMA"
  grep -q '"high"' "$SCHEMA"
  grep -q '"medium"' "$SCHEMA"
  grep -q '"low"' "$SCHEMA"
}

@test "schema requires SHA-256 pattern for file hashes" {
  grep -q 'a-f0-9.*64' "$SCHEMA"
}

@test "rules/coherence.rules.yaml exists with thresholds" {
  [[ -f "$RULES" ]]
  grep -q "pass_threshold: 90" "$RULES"
  grep -q "conditional_threshold: 70" "$RULES"
}

@test "all 5 coherence agents exist and are <=150 lines" {
  for agent in coherence-court-orchestrator coherence-factual-judge coherence-scope-judge coherence-objectives-judge coherence-premise-drift-judge; do
    [[ -f "$AGENTS_DIR/$agent.md" ]]
    local lines
    lines=$(wc -l < "$AGENTS_DIR/$agent.md")
    [[ "$lines" -le 150 ]]
  done
}

@test "coherence-court rule doc exists" {
  [[ -f "$RULES_DOC" ]]
  grep -q "SE-350" "$RULES_DOC"
}

# ── check (flujo multi-etapa gate) ────────────────────────────────────────

@test "check without premises fails (single-stage flow)" {
  bash "$CC" premises "$FLOW" init
  run bash "$CC" check --flow "$FLOW" --stage-output "$TMP_DIR/stage.txt"
  [[ "$status" -ne 0 ]]
  echo "$output" | grep -qi "single-stage\|no prior stage"
}

@test "check requires --flow" {
  run bash "$CC" check
  [[ "$status" -ne 0 ]]
  echo "$output" | grep -qi "requires --flow"
}

@test "check requires --stage-output" {
  bash "$CC" premises "$FLOW" init
  run bash "$CC" check --flow "$FLOW"
  [[ "$status" -ne 0 ]]
  echo "$output" | grep -qi "requires --stage-output"
}

@test "check fails on missing stage output file" {
  bash "$CC" premises "$FLOW" init
  bash "$CC" premises "$FLOW" add fact "X" >/dev/null
  run bash "$CC" check --flow "$FLOW" --stage-output "$TMP_DIR/nope.txt"
  [[ "$status" -ne 0 ]]
  echo "$output" | grep -qi "stage_output not found"
}

@test "check passes with premises + stage output" {
  seed_premises
  run bash "$CC" check --flow "$FLOW" --stage-output "$TMP_DIR/stage.txt"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -qi "PASS"
}

# ── premises ──────────────────────────────────────────────────────────────

@test "premises init creates registry file" {
  bash "$CC" premises "$FLOW" init
  [[ -f "$TMP_DIR/data/coherence-premises-$FLOW.jsonl" ]]
}

@test "premises add writes a v1 record with timestamp" {
  bash "$CC" premises "$FLOW" init
  local pid
  pid=$(bash "$CC" premises "$FLOW" add constraint "Max 400 LOC" --stage stage-1)
  [[ -n "$pid" ]]
  grep -q '"schema_version": "1"' "$TMP_DIR/data/coherence-premises-$FLOW.jsonl"
  grep -q '"premise_id": "'"$pid"'"' "$TMP_DIR/data/coherence-premises-$FLOW.jsonl"
  grep -q '"kind": "constraint"' "$TMP_DIR/data/coherence-premises-$FLOW.jsonl"
  grep -q '"added_at"' "$TMP_DIR/data/coherence-premises-$FLOW.jsonl"
}

@test "premises add rejects invalid kind" {
  bash "$CC" premises "$FLOW" init
  run bash "$CC" premises "$FLOW" add bogus-kind "something"
  [[ "$status" -ne 0 ]]
  echo "$output" | grep -qi "invalid kind"
}

@test "premises add requires content" {
  bash "$CC" premises "$FLOW" init
  run bash "$CC" premises "$FLOW" add fact
  [[ "$status" -ne 0 ]]
  echo "$output" | grep -qi "requires <content>"
}

@test "premises list shows all premises" {
  seed_premises
  local out
  out=$(bash "$CC" premises "$FLOW" list)
  echo "$out" | grep -q "constraint"
  echo "$out" | grep -q "fact"
  echo "$out" | grep -q "objective"
}

@test "premises list --json is parseable" {
  seed_premises
  bash "$CC" premises "$FLOW" list --json | python3 -c "import sys,json; rows=json.load(sys.stdin); assert len(rows)==3, rows"
}

@test "premises show returns a single premise" {
  seed_premises
  local pid
  pid=$(grep -oP '"premise_id": "\K[^"]+' "$TMP_DIR/data/coherence-premises-$FLOW.jsonl" | head -1)
  bash "$CC" premises "$FLOW" show "$pid" | grep -q "\"premise_id\": \"$pid\""
}

@test "premises show on unknown id fails" {
  seed_premises
  run bash "$CC" premises "$FLOW" show does-not-exist
  [[ "$status" -ne 0 ]]
}

@test "premises clear empties the registry" {
  seed_premises
  bash "$CC" premises "$FLOW" clear
  run bash "$CC" premises "$FLOW" list --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "import sys,json; assert json.load(sys.stdin)==[], sys.stdin.read()"
}

# ── skeleton ──────────────────────────────────────────────────────────────

@test "skeleton generates .coherence.crc with 4 judges" {
  seed_premises
  bash "$CC" skeleton "$FLOW" "$TMP_DIR/stage.txt" > "$TMP_DIR/out.crc"
  grep -q "coherence-factual" "$TMP_DIR/out.crc"
  grep -q "coherence-scope" "$TMP_DIR/out.crc"
  grep -q "coherence-objectives" "$TMP_DIR/out.crc"
  grep -q "coherence-premise-drift" "$TMP_DIR/out.crc"
  grep -q "score: 0" "$TMP_DIR/out.crc"
  grep -q "premises_count: 3" "$TMP_DIR/out.crc"
}

@test "skeleton includes sha256 of stage output" {
  seed_premises
  local expected
  expected=$(bash "$CC" hash "$TMP_DIR/stage.txt")
  bash "$CC" skeleton "$FLOW" "$TMP_DIR/stage.txt" | grep -q "$expected"
}

@test "skeleton requires flow and stage_output" {
  run bash "$CC" skeleton
  [[ "$status" -ne 0 ]]
  run bash "$CC" skeleton "$FLOW"
  [[ "$status" -ne 0 ]]
}

# ── score ─────────────────────────────────────────────────────────────────

@test "score computes 100 - (C*25 + H*10 + M*3 + L*1)" {
  run bash "$CC" score 1 2 3 4
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "score=42"
}

@test "score floors at 0" {
  run bash "$CC" score 5 5 5 5
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "score=0"
}

@test "score 0 0 0 0 = 100 pass" {
  run bash "$CC" score 0 0 0 0
  echo "$output" | grep -q "score=100"
  echo "$output" | grep -q "verdict=pass"
}

# ── gate ──────────────────────────────────────────────────────────────────

@test "gate 95 passes (exit 0)" {
  run bash "$CC" gate 95
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "PASS"
}

@test "gate 80 is conditional (exit 2)" {
  run bash "$CC" gate 80
  [[ "$status" -eq 2 ]]
  echo "$output" | grep -q "CONDITIONAL"
}

@test "gate 50 fails (exit 1) — human gate" {
  run bash "$CC" gate 50
  [[ "$status" -eq 1 ]]
  echo "$output" | grep -qi "puerta humana"
}

@test "gate respects --threshold override" {
  run bash "$CC" gate 85 --threshold 90
  [[ "$status" -eq 2 ]]
  run bash "$CC" gate 85 --threshold 80
  [[ "$status" -eq 0 ]]
}

@test "gate rejects non-numeric score" {
  run bash "$CC" gate abc
  [[ "$status" -ne 0 ]]
}

@test "gate respects COHERENCE_SCORE_PASS env" {
  run env COHERENCE_SCORE_PASS=80 bash "$CC" gate 85
  [[ "$status" -eq 0 ]]
  run env COHERENCE_SCORE_PASS=95 bash "$CC" gate 85
  [[ "$status" -eq 2 ]]
  echo "$output" | grep -q "CONDITIONAL"
}

# ── hash ──────────────────────────────────────────────────────────────────

@test "hash emits 64 hex chars" {
  run bash "$CC" hash "$TMP_DIR/stage.txt"
  [[ "$status" -eq 0 ]]
  [[ "${#output}" -eq 64 ]]
  echo "$output" | grep -qE '^[a-f0-9]{64}$'
}

@test "hash fails on missing file" {
  run bash "$CC" hash "$TMP_DIR/missing.txt"
  [[ "$status" -ne 0 ]]
}

# ── CRIT-001 (no red) ─────────────────────────────────────────────────────

@test "no network calls in script" {
  grep -vE '^\s*#' "$CC" | grep -qE 'curl|wget|http://|https://' && return 1
  return 0
}
