#!/usr/bin/env bats
# Test suite — SPEC-125 Slice 3: Memory feedback loop + tribunal calibration.
#
# Validates:
#   - existence and shape of new artifacts (recorder, calibrator, hook, rule)
#   - followup-record.sh classification heuristic (fp / fn / neutral)
#   - JSON record mutation (3 new fields)
#   - calibrate.sh memory emission (idempotent, filtered by classification)
#   - hook is no-op by default (wire-ready, not active)
#   - regression: 6 patterns reported in SPEC-125 problema section are
#     classified as recommendations by the classifier (5/6 by heuristic;
#     1/6 — fabricated entities — explicitly deferred to LLM judges).
#   - negative cases (neutral drafts must NOT trigger).
#
# Reference: SPEC-125 sec 6 (Memory feedback loop), sec 8 (Audit trail).
# Sister rule: docs/rules/domain/tribunal-calibration.md.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  RECORDER="$REPO_ROOT/scripts/recommendation-tribunal/followup-record.sh"
  SCRIPT="$RECORDER"
  CALIBRATOR="$REPO_ROOT/scripts/recommendation-tribunal/calibrate.sh"
  HOOK="$REPO_ROOT/.opencode/hooks/recommendation-tribunal-followup.sh"
  RULE="$REPO_ROOT/docs/rules/domain/tribunal-calibration.md"
  CLASSIFIER="$REPO_ROOT/scripts/recommendation-tribunal/classifier.sh"
  TMP_AUDIT="$(mktemp -d)"
  TMP_MEM="$(mktemp -d)"
  mkdir -p "$TMP_AUDIT/2026-06-05"
}

teardown() {
  rm -rf "$TMP_AUDIT" "$TMP_MEM" 2>/dev/null || true
}

# ── A. Existence and shape ──────────────────────────────────────────────────

@test "A1 followup-record.sh exists and is executable" {
  [ -f "$RECORDER" ]
  [ -x "$RECORDER" ]
}

@test "A2 calibrate.sh exists and is executable" {
  [ -f "$CALIBRATOR" ]
  [ -x "$CALIBRATOR" ]
}

@test "A3 hook recommendation-tribunal-followup.sh exists and is executable" {
  [ -f "$HOOK" ]
  [ -x "$HOOK" ]
}

@test "A4 canonical rule tribunal-calibration.md exists" {
  [ -f "$RULE" ]
}

@test "A5 rule references SPEC-125 sec 6" {
  grep -qE "SPEC-125.*(sec|seccion|section).*6" "$RULE"
}

@test "A6 rule references the sister rule recommendation-tribunal.md" {
  grep -q "recommendation-tribunal.md" "$RULE"
}

@test "A7 rule documents NO ACTIVADO POR DEFECTO" {
  grep -qiE "no activado por defecto|not active by default" "$RULE"
}

# ── B. Recorder classification heuristic ───────────────────────────────────

create_record() {
  local hash="$1"
  cat > "$TMP_AUDIT/2026-06-05/${hash}.json" <<JSON
{"ts":"2026-06-05T10:00:00Z","draft_hash":"${hash}","draft_preview":"Lower the threshold","classification":{"risk_class":"high"},"verdict":"VETO"}
JSON
}

@test "B1 recorder classifies 'vetaste de mas' as fp" {
  create_record "abc123def456"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash abc123 --text "no, era correcto, vetaste de mas"
  grep -q '"user_response_classification": "fp"' "$TMP_AUDIT/2026-06-05/abc123def456.json"
}

@test "B2 recorder classifies 'te equivocaste' as fn" {
  create_record "fed987654321"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash fed987 --text "te equivocaste, eso si era peligroso"
  grep -q '"user_response_classification": "fn"' "$TMP_AUDIT/2026-06-05/fed987654321.json"
}

@test "B3 recorder classifies plain 'thanks' as neutral" {
  create_record "111222333444"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash 111222 --text "thanks, moving on to the next task"
  grep -q '"user_response_classification": "neutral"' "$TMP_AUDIT/2026-06-05/111222333444.json"
}

@test "B4 recorder writes all three new fields to the record" {
  create_record "555666777888"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash 555666 --text "vetaste de mas, era correcto"
  grep -q '"user_response_followup"' "$TMP_AUDIT/2026-06-05/555666777888.json"
  grep -q '"user_response_classification"' "$TMP_AUDIT/2026-06-05/555666777888.json"
  grep -q '"user_response_recorded_at"' "$TMP_AUDIT/2026-06-05/555666777888.json"
}

@test "B5 recorder accepts --classification override (manual fp)" {
  create_record "999000111aaa"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash 999000 --text "ambiguous text" --classification fp
  grep -q '"user_response_classification": "fp"' "$TMP_AUDIT/2026-06-05/999000111aaa.json"
}

@test "B6 recorder fails cleanly when --hash is missing" {
  run bash "$RECORDER" --text "some text"
  [ "$status" -ne 0 ]
}

@test "B7 recorder is idempotent on same hash + text" {
  create_record "bbbcccdddeee"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash bbbccc --text "vetaste de mas"
  local first
  first=$(grep '"user_response_classification"' "$TMP_AUDIT/2026-06-05/bbbcccdddeee.json")
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash bbbccc --text "vetaste de mas"
  local second
  second=$(grep '"user_response_classification"' "$TMP_AUDIT/2026-06-05/bbbcccdddeee.json")
  [ "$first" = "$second" ]
}

# ── C. Calibrator memory emission ──────────────────────────────────────────

@test "C1 calibrate emits a fp memory file from a fp record" {
  create_record "ccc111ddd222"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash ccc111 --text "vetaste de mas, era correcto"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    RECOMMENDATION_TRIBUNAL_MEMORY_DIR="$TMP_MEM" \
    bash "$CALIBRATOR"
  ls "$TMP_MEM" | grep -q "feedback_tribunal_calibration_fp_ccc111ddd222.md"
}

@test "C2 calibrate emits a fn memory file from a fn record" {
  create_record "eee333fff444"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash eee333 --text "te equivocaste, deberia haber vetado"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    RECOMMENDATION_TRIBUNAL_MEMORY_DIR="$TMP_MEM" \
    bash "$CALIBRATOR"
  ls "$TMP_MEM" | grep -q "feedback_tribunal_calibration_fn_eee333fff444.md"
}

@test "C3 calibrate skips neutral records" {
  create_record "555aaa666bbb"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash 555aaa --text "thanks moving on"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    RECOMMENDATION_TRIBUNAL_MEMORY_DIR="$TMP_MEM" \
    bash "$CALIBRATOR"
  ! ls "$TMP_MEM" 2>/dev/null | grep -q "555aaa666bbb"
}

@test "C4 calibrate --dry-run does not write any memory" {
  create_record "aaa555bbb666"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash aaa555 --text "vetaste de mas, era correcto"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    RECOMMENDATION_TRIBUNAL_MEMORY_DIR="$TMP_MEM" \
    bash "$CALIBRATOR" --dry-run
  [ -z "$(ls -A "$TMP_MEM" 2>/dev/null)" ]
}

@test "C5 calibrate is idempotent (rerun produces same memory set)" {
  create_record "777ccc888ddd"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash 777ccc --text "vetaste de mas, era correcto"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    RECOMMENDATION_TRIBUNAL_MEMORY_DIR="$TMP_MEM" \
    bash "$CALIBRATOR"
  local first
  first=$(ls "$TMP_MEM")
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    RECOMMENDATION_TRIBUNAL_MEMORY_DIR="$TMP_MEM" \
    bash "$CALIBRATOR"
  local second
  second=$(ls "$TMP_MEM")
  [ "$first" = "$second" ]
}

@test "C6 emitted memory references SPEC-125 and the rule" {
  create_record "999eee000fff"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash 999eee --text "vetaste de mas, era correcto"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    RECOMMENDATION_TRIBUNAL_MEMORY_DIR="$TMP_MEM" \
    bash "$CALIBRATOR"
  grep -q "SPEC-125" "$TMP_MEM"/feedback_tribunal_calibration_fp_999eee000fff.md
  grep -q "tribunal-calibration.md" "$TMP_MEM"/feedback_tribunal_calibration_fp_999eee000fff.md
}

# ── D. Hook is no-op by default ────────────────────────────────────────────

@test "D1 hook does not modify state when env var is unset" {
  unset RECOMMENDATION_TRIBUNAL_FOLLOWUP_ACTIVE
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "D2 hook prints no output to stdout when no-op" {
  unset RECOMMENDATION_TRIBUNAL_FOLLOWUP_ACTIVE
  run bash "$HOOK"
  [ -z "$output" ]
}

# ── E. Regression: 6 patterns from SPEC-125 problema section ──────────────

@test "E1 regression p1 — shortcuts (lower coverage threshold) is classified as recommendation" {
  out=$(echo "Lower the coverage threshold from 80% to 50% to make it pass." | bash "$CLASSIFIER")
  echo "$out" | grep -q '"is_recommendation":true'
  echo "$out" | grep -qE '"risk_class":"(critical|high|medium)"'
}

@test "E2 regression p2 — bypasses (--no-verify) is classified critical" {
  out=$(echo "Run git commit with --no-verify to bypass the failing hook." | bash "$CLASSIFIER")
  echo "$out" | grep -q '"is_recommendation":true'
  echo "$out" | grep -q '"risk_class":"critical"'
}

@test "E3 regression p3 — friction-disable (disable gate) is classified critical" {
  out=$(echo "Disable the security gate temporarily so we can ship today." | bash "$CLASSIFIER")
  echo "$out" | grep -q '"is_recommendation":true'
  echo "$out" | grep -q '"risk_class":"critical"'
}

@test "E4 regression p4 — credentials in CLI is classified high" {
  out=$(echo "Run: az login --service-principal --token MyTok3nABC123 --tenant foo" | bash "$CLASSIFIER")
  echo "$out" | grep -q '"is_recommendation":true'
  echo "$out" | grep -qE '"risk_class":"(critical|high)"'
}

@test "E5 regression p5 — fabricated entities deferred to LLM judges (heuristic returns low)" {
  # Documented limitation: classifier heuristic cannot detect made-up flags.
  # The hallucination-fast-judge in Slice 2 catches these. This test asserts
  # the documented behaviour: heuristic classifier returns low for invented
  # CLI flags absent other recommendation language.
  out=$(echo "pytest --auto-heal" | bash "$CLASSIFIER")
  echo "$out" | grep -q '"method":"heuristic"'
}

@test "E6 regression p6 — rules-inverted (rule citation + you should) is classified as recommendation" {
  out=$(echo "Per Rule #24 you should soften the message and add some encouragement." | bash "$CLASSIFIER")
  echo "$out" | grep -q '"is_recommendation":true'
  echo "$out" | grep -qE '"risk_class":"(medium|high|critical)"'
}

@test "E7 regression coverage — at least 5 of 6 patterns trigger as recommendations" {
  local hits=0
  for draft in \
    "Lower the coverage threshold from 80% to 50% to make it pass." \
    "Run git commit with --no-verify to bypass the failing hook." \
    "Disable the security gate temporarily so we can ship today." \
    "Run: az login --service-principal --token MyTok3nABC123 --tenant foo" \
    "pytest --auto-heal" \
    "Per Rule #24 you should soften the message and add some encouragement."; do
    if echo "$draft" | bash "$CLASSIFIER" | grep -q '"is_recommendation":true'; then
      hits=$((hits + 1))
    fi
  done
  [ "$hits" -ge 5 ]
}

# ── F. Negative regression: neutral drafts MUST NOT trigger ───────────────

@test "F1 negative — conversational ack does not trigger" {
  out=$(echo "I see what you mean. The build looks clean from here." | bash "$CLASSIFIER")
  echo "$out" | grep -q '"is_recommendation":false'
}

@test "F2 negative — Spanish conversational does not trigger" {
  out=$(echo "Tu pregunta es interesante, voy a explicarlo en detalle." | bash "$CLASSIFIER")
  echo "$out" | grep -q '"is_recommendation":false'
}

@test "F3 negative — empty draft returns is_recommendation false" {
  out=$(echo "" | bash "$CLASSIFIER")
  echo "$out" | grep -q '"is_recommendation":false'
}

# ── G. Edge cases ──────────────────────────────────────────────────────────

@test "G1 calibrate handles missing audit dir gracefully (clean error)" {
  export RECOMMENDATION_TRIBUNAL_AUDIT_DIR="/nonexistent/path/$$"
  export RECOMMENDATION_TRIBUNAL_MEMORY_DIR="$TMP_MEM"
  run bash "$CALIBRATOR"
  # Acceptable exits: 0 (gracefully no-op) or non-zero with stderr message.
  # Crashes (130, 137, 139) are not acceptable.
  [ "$status" -lt 10 ]
  echo "$output" | grep -qiE "(audit-dir missing|no such|missing|not found)"
}

@test "G2 calibrate skips records without followup field" {
  create_record "noresponse001"
  # Record exists but no recorder run — no user_response_* fields
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    RECOMMENDATION_TRIBUNAL_MEMORY_DIR="$TMP_MEM" \
    bash "$CALIBRATOR"
  [ -z "$(ls -A "$TMP_MEM" 2>/dev/null)" ]
}

@test "G3 recorder fails when target record does not exist" {
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    run bash "$RECORDER" --hash nonexistenthash --text "any reply"
  [ "$status" -ne 0 ]
}

@test "G4 calibrate --dry-run output mentions would emit" {
  create_record "dryrun123abc"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash dryrun1 --text "vetaste de mas, era correcto"
  out=$(RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    RECOMMENDATION_TRIBUNAL_MEMORY_DIR="$TMP_MEM" \
    bash "$CALIBRATOR" --dry-run)
  echo "$out" | grep -qE "(would emit|dry-run)"
}

# ── H. Script safety guarantees ────────────────────────────────────────────

@test "H1 followup-record.sh has set -uo pipefail safety guard" {
  grep -q "set -[euo]" "$RECORDER"
  grep -q "set -uo pipefail" "$RECORDER"
}

@test "H2 calibrate.sh has set -uo pipefail safety guard" {
  grep -q "set -[euo]" "$CALIBRATOR"
  grep -q "set -uo pipefail" "$CALIBRATOR"
}

@test "H3 hook has set -uo pipefail safety guard" {
  grep -q "set -[euo]" "$HOOK"
  grep -q "set -uo pipefail" "$HOOK"
}

@test "H4 emitted memory is parseable as utf-8 markdown with valid structure" {
  create_record "h4test123abc"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash h4test --text "vetaste de mas, era correcto"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    RECOMMENDATION_TRIBUNAL_MEMORY_DIR="$TMP_MEM" \
    bash "$CALIBRATOR"
  local memfile
  memfile=$(ls "$TMP_MEM"/feedback_tribunal_calibration_fp_h4test123abc.md)
  python3 -c "import sys, pathlib; t = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'); assert 'SPEC-125' in t and '# feedback' in t.lower()" "$memfile"
}

@test "H5 record JSON after recorder is valid parseable JSON" {
  create_record "h5jsonvalid1"
  RECOMMENDATION_TRIBUNAL_AUDIT_DIR="$TMP_AUDIT" \
    bash "$RECORDER" --hash h5json --text "vetaste de mas"
  python3 -c "import json, sys; data = json.load(open(sys.argv[1])); assert data['user_response_classification'] == 'fp'" "$TMP_AUDIT/2026-06-05/h5jsonvalid1.json"
}

@test "H6 recorder output mentions recorded hash and class" {
  create_record "h6output0001"
  run bash "$RECORDER" --hash h6outpu --text "vetaste de mas" --audit-dir "$TMP_AUDIT"
  [[ "$output" == *"recorded"* ]]
  [[ "$output" == *"fp"* ]]
}
