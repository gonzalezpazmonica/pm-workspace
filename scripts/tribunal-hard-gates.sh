#!/usr/bin/env bash
# tribunal-hard-gates.sh — SE-227 Slice 1
#
# Deterministic pre-LLM hard gates for Savia tribunals.
# Runs O(1) bash checks that can reject an input BEFORE calling any LLM judge,
# reducing cost and filtering structurally invalid inputs.
#
# Usage:
#   tribunal-hard-gates.sh --tribunal recommendation|truth|court \
#                           --input-file <json_or_text> \
#                           [--format-check] [--source-check] [--length-check] \
#                           [--nonce <string>]
#
# Output (always JSON to stdout):
#   {"passed": true,  "gates_run": 3, "failures": []}
#   {"passed": false, "gates_run": 2, "gate": "format_check",
#    "reason": "missing required sections", "failures": [...]}
#
# Exit codes:
#   0  All gates passed
#   1  At least one gate failed (HARD_GATE_FAIL)
#   2  Usage / missing args
#
# SE-227 — docs/propuestas/SE-227-mech-gov-hard-gates-tribunales.md
# Related: SPEC-192, recommendation-tribunal-orchestrator

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Defaults ─────────────────────────────────────────────────────────────────
TRIBUNAL=""
INPUT_FILE=""
NONCE=""
FLAG_FORMAT_CHECK=0
FLAG_SOURCE_CHECK=0
FLAG_LENGTH_CHECK=0
SELF_TEST=0

MIN_LENGTH=50
MAX_LENGTH=50000

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") --tribunal recommendation|truth|court \\
                         --input-file <path> \\
                         [--format-check] [--source-check] [--length-check] \\
                         [--nonce <string>] [--self-test]

Gates (all deterministic, zero LLM):
  format_check     Draft is non-empty and >$MIN_LENGTH chars
  length_range     $MIN_LENGTH < input < $MAX_LENGTH chars
  no_empty_output  Input file exists and is readable
  spec_syntax      If spec path referenced, it must exist in repo
  e3_nonce_check   If --nonce passed, nonce must appear in input file

Output: JSON  {"passed": bool, "gates_run": N, "failures": [...]}
EOF
  exit 2
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tribunal)       TRIBUNAL="${2:-}";    shift 2 ;;
    --input-file)     INPUT_FILE="${2:-}";  shift 2 ;;
    --nonce)          NONCE="${2:-}";       shift 2 ;;
    --format-check)   FLAG_FORMAT_CHECK=1;  shift   ;;
    --source-check)   FLAG_SOURCE_CHECK=1;  shift   ;;
    --length-check)   FLAG_LENGTH_CHECK=1;  shift   ;;
    --self-test)      SELF_TEST=1;          shift   ;;
    -h|--help)        usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

# ── Self-test mode ────────────────────────────────────────────────────────────
if [[ $SELF_TEST -eq 1 ]]; then
  PASS=0; FAIL=0
  _assert() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
      echo "  PASS: $desc"
      ((PASS++)) || true
    else
      echo "  FAIL: $desc (expected='$expected' got='$actual')"
      ((FAIL++)) || true
    fi
  }

  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT

  # Test 1: no_empty_output — nonexistent file
  OUT="$(bash "$0" --tribunal recommendation --input-file "$TMP_DIR/nonexistent.txt" 2>/dev/null)"
  _assert "no_empty_output fails for missing file" "false" "$(echo "$OUT" | python3 -c 'import sys,json; print(str(json.load(sys.stdin)["passed"]).lower())')"

  # Test 2: format_check — empty content
  EMPTY_FILE="$TMP_DIR/empty.txt"
  touch "$EMPTY_FILE"
  OUT="$(bash "$0" --tribunal recommendation --input-file "$EMPTY_FILE" --format-check 2>/dev/null)"
  _assert "format_check fails for empty file" "false" "$(echo "$OUT" | python3 -c 'import sys,json; print(str(json.load(sys.stdin)["passed"]).lower())')"

  # Test 3: format_check — valid content
  VALID_FILE="$TMP_DIR/valid.txt"
  printf '%0.s x' {1..30} > "$VALID_FILE"  # 60 chars
  OUT="$(bash "$0" --tribunal recommendation --input-file "$VALID_FILE" --format-check 2>/dev/null)"
  _assert "format_check passes for valid content" "true" "$(echo "$OUT" | python3 -c 'import sys,json; print(str(json.load(sys.stdin)["passed"]).lower())')"

  # Test 4: nonce check — nonce present
  NONCE_FILE="$TMP_DIR/nonce_present.txt"
  TEST_NONCE="abc123def456"
  printf '%0.s x' {1..30} > "$NONCE_FILE"
  echo "$TEST_NONCE" >> "$NONCE_FILE"
  OUT="$(bash "$0" --tribunal recommendation --input-file "$NONCE_FILE" --nonce "$TEST_NONCE" 2>/dev/null)"
  _assert "e3_nonce_check passes when nonce present" "true" "$(echo "$OUT" | python3 -c 'import sys,json; print(str(json.load(sys.stdin)["passed"]).lower())')"

  # Test 5: nonce check — nonce absent
  NO_NONCE_FILE="$TMP_DIR/no_nonce.txt"
  printf '%0.s x' {1..30} > "$NO_NONCE_FILE"
  OUT="$(bash "$0" --tribunal recommendation --input-file "$NO_NONCE_FILE" --nonce "MISSING_NONCE_xyz789" 2>/dev/null)"
  _assert "e3_nonce_check fails when nonce absent" "false" "$(echo "$OUT" | python3 -c 'import sys,json; print(str(json.load(sys.stdin)["passed"]).lower())')"

  echo ""
  echo "Self-test: $PASS passed, $FAIL failed"
  [[ $FAIL -eq 0 ]] && exit 0 || exit 1
fi

# ── Validation ────────────────────────────────────────────────────────────────
if [[ -z "$TRIBUNAL" ]]; then
  echo '{"passed":false,"gates_run":0,"gate":"usage","reason":"--tribunal is required","failures":["missing --tribunal"]}' 
  exit 2
fi

case "$TRIBUNAL" in
  recommendation|truth|court) ;;
  *) echo '{"passed":false,"gates_run":0,"gate":"usage","reason":"unknown tribunal type","failures":["invalid --tribunal value"]}'; exit 2 ;;
esac

# ── Gate helpers ──────────────────────────────────────────────────────────────
GATES_RUN=0
FAILURES=()
FIRST_FAILURE=""
FIRST_REASON=""

_fail() {
  local gate="$1" reason="$2"
  FAILURES+=("$gate: $reason")
  if [[ -z "$FIRST_FAILURE" ]]; then
    FIRST_FAILURE="$gate"
    FIRST_REASON="$reason"
  fi
}

_emit_json() {
  local passed="$1"
  # Build failures JSON array
  local failures_json="["
  local sep=""
  for f in "${FAILURES[@]:-}"; do
    failures_json+="${sep}$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$f")"
    sep=","
  done
  failures_json+="]"

  if [[ "$passed" == "true" ]]; then
    printf '{"passed":true,"gates_run":%d,"failures":[]}\n' "$GATES_RUN"
  else
    printf '{"passed":false,"gates_run":%d,"gate":%s,"reason":%s,"failures":%s}\n' \
      "$GATES_RUN" \
      "$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$FIRST_FAILURE")" \
      "$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$FIRST_REASON")" \
      "$failures_json"
  fi
}

# ── Gate 1: no_empty_output ───────────────────────────────────────────────────
# Input file must exist and be readable. Runs ALWAYS (not behind a flag).
((GATES_RUN++)) || true
if [[ -z "$INPUT_FILE" ]]; then
  _fail "no_empty_output" "no --input-file specified"
elif [[ ! -e "$INPUT_FILE" ]]; then
  _fail "no_empty_output" "input file does not exist: $INPUT_FILE"
elif [[ ! -r "$INPUT_FILE" ]]; then
  _fail "no_empty_output" "input file is not readable: $INPUT_FILE"
fi

# Short-circuit: if file not readable, remaining gates can't run
if [[ ${#FAILURES[@]} -gt 0 ]]; then
  _emit_json "false"
  exit 1
fi

# ── Gate 2: format_check (if --format-check or --tribunal recommendation) ────
# Runs when explicitly requested or implied by tribunal type.
RUN_FORMAT=0
[[ $FLAG_FORMAT_CHECK -eq 1 ]] && RUN_FORMAT=1
[[ "$TRIBUNAL" == "recommendation" ]] && RUN_FORMAT=1

if [[ $RUN_FORMAT -eq 1 ]]; then
  ((GATES_RUN++)) || true
  CONTENT_LENGTH="$(wc -c < "$INPUT_FILE" | tr -d ' ')"
  if [[ "$CONTENT_LENGTH" -lt "$MIN_LENGTH" ]]; then
    _fail "format_check" "input too short (${CONTENT_LENGTH} chars, minimum ${MIN_LENGTH})"
  fi
fi

# ── Gate 3: length_range ──────────────────────────────────────────────────────
# Runs when --length-check or for truth/court tribunals (more strict).
RUN_LENGTH=0
[[ $FLAG_LENGTH_CHECK -eq 1 ]] && RUN_LENGTH=1
[[ "$TRIBUNAL" == "truth" || "$TRIBUNAL" == "court" ]] && RUN_LENGTH=1

if [[ $RUN_LENGTH -eq 1 ]]; then
  ((GATES_RUN++)) || true
  CONTENT_LENGTH="$(wc -c < "$INPUT_FILE" | tr -d ' ')"
  if [[ "$CONTENT_LENGTH" -lt "$MIN_LENGTH" ]]; then
    _fail "length_range" "input too short (${CONTENT_LENGTH} chars, minimum ${MIN_LENGTH})"
  elif [[ "$CONTENT_LENGTH" -gt "$MAX_LENGTH" ]]; then
    _fail "length_range" "input too long (${CONTENT_LENGTH} chars, maximum ${MAX_LENGTH})"
  fi
fi

# ── Gate 4: spec_syntax ───────────────────────────────────────────────────────
# If the input references a spec path (docs/propuestas/... or scripts/...),
# verify that the path exists in the repo. Zero-LLM: pure grep + stat.
((GATES_RUN++)) || true
SPEC_REFS=()
while IFS= read -r line; do
  SPEC_REFS+=("$line")
done < <(grep -oE '(docs/propuestas/[A-Za-z0-9_./-]+\.md|scripts/[A-Za-z0-9_.-]+\.sh)' "$INPUT_FILE" 2>/dev/null || true)

for spec_path in "${SPEC_REFS[@]:-}"; do
  if [[ -n "$spec_path" ]]; then
    FULL_PATH="$ROOT/$spec_path"
    if [[ ! -e "$FULL_PATH" ]]; then
      _fail "spec_syntax" "referenced spec path does not exist: $spec_path"
      break  # Report first missing reference only
    fi
  fi
done

# ── Gate 5: source_check (if --source-check or truth tribunal) ───────────────
# For truth tribunal: verify at least one @ref citation exists.
RUN_SOURCE=0
[[ $FLAG_SOURCE_CHECK -eq 1 ]] && RUN_SOURCE=1
[[ "$TRIBUNAL" == "truth" ]] && RUN_SOURCE=1

if [[ $RUN_SOURCE -eq 1 ]]; then
  ((GATES_RUN++)) || true
  # Check for @ref, @source, or (source:...) patterns
  if ! grep -qE '(@ref|@source|\(source:|https?://)' "$INPUT_FILE" 2>/dev/null; then
    _fail "source_check" "no source citations found (@ref, @source, or URL)"
  fi
fi

# ── Gate 6: e3_nonce_check ────────────────────────────────────────────────────
# If orchestrator passed a nonce, verify it appears in the judge output.
if [[ -n "$NONCE" ]]; then
  ((GATES_RUN++)) || true
  if ! grep -qF "$NONCE" "$INPUT_FILE" 2>/dev/null; then
    _fail "e3_nonce_check" "E3 nonce not found in judge output — possible pre-cooking detected"
  fi
fi

# ── Emit result ───────────────────────────────────────────────────────────────
if [[ ${#FAILURES[@]} -eq 0 ]]; then
  _emit_json "true"
  exit 0
else
  _emit_json "false"
  exit 1
fi
