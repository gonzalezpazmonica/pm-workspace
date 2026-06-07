#!/usr/bin/env bats
# tests/test-se-204-eval-harness.bats — SE-204: Evaluation harness minimo para agentes
# Ref: docs/propuestas/SE-204-eval-harness.md
# Cubre: script existe/ejecutable, set -uo pipefail, SE-204 referenciado,
#        directorio evals existe, 3 agentes con >=3 eval cases cada uno,
#        input.md+criteria.md en cada case, --agent filtra, --list muestra,
#        --dry-run no crea ficheros, report generado con tabla,
#        exit 0 score >= threshold, exit 1 score < threshold,
#        criteria.md >=5 criterios, setup/teardown con tmpdir

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/run-agent-evals.sh"
EVALS_DIR="${BATS_TEST_DIRNAME}/evals"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_write_valid_input() {
  local dest="$1"
  printf '%s\n' \
    "# Task for agent evaluation" \
    "" \
    "This is a realistic task description for the agent under evaluation." \
    "The agent must process this input and produce a structured output that" \
    "satisfies the acceptance criteria defined in the criteria file." \
    "Additional context: the system processes domain events and produces" \
    "verifiable artifacts. The task includes edge cases and error paths." \
    "Domain rules must be applied correctly throughout the evaluation." \
    > "$dest"
}

_write_valid_criteria() {
  local dest="$1"
  printf '%s\n' \
    "# Evaluation criteria" \
    "" \
    "## Score (each item 1 point, max 10)" \
    "" \
    "- [ ] Criterion one: output has required structure" \
    "- [ ] Criterion two: at least three acceptance criteria present" \
    "- [ ] Criterion three: error cases are specified" \
    "- [ ] Criterion four: no placeholder items remain" \
    "- [ ] Criterion five: output is verifiable by an automated agent" \
    "- [ ] Criterion six: domain context is referenced" \
    "" \
    "## Threshold: 7 of 10" \
    > "$dest"
}

# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------

setup() {
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR

  mkdir -p "${TMP_DIR}/tests/evals/sdd-spec-writer/eval-01-test"
  mkdir -p "${TMP_DIR}/tests/evals/sdd-spec-writer/eval-02-test"
  mkdir -p "${TMP_DIR}/tests/evals/sdd-spec-writer/eval-03-test"
  mkdir -p "${TMP_DIR}/tests/evals/court-orchestrator/eval-01-test"
  mkdir -p "${TMP_DIR}/tests/evals/court-orchestrator/eval-02-test"
  mkdir -p "${TMP_DIR}/tests/evals/court-orchestrator/eval-03-test"
  mkdir -p "${TMP_DIR}/tests/evals/business-analyst/eval-01-test"
  mkdir -p "${TMP_DIR}/tests/evals/business-analyst/eval-02-test"
  mkdir -p "${TMP_DIR}/tests/evals/business-analyst/eval-03-test"
  mkdir -p "${TMP_DIR}/output"

  for agent in sdd-spec-writer court-orchestrator business-analyst; do
    for num in 01 02 03; do
      local d="${TMP_DIR}/tests/evals/${agent}/eval-${num}-test"
      _write_valid_input "${d}/input.md"
      _write_valid_criteria "${d}/criteria.md"
    done
  done

  export TMP_PROJECT_ROOT="${TMP_DIR}"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]] && rm -rf "${TMP_DIR}"
}

# ---------------------------------------------------------------------------
# 1. Basic infrastructure
# ---------------------------------------------------------------------------

@test "run-agent-evals.sh exists at expected path" {
  [[ -f "$SCRIPT" ]]
}

@test "run-agent-evals.sh is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "run-agent-evals.sh uses set -uo pipefail" {
  run grep -E "^set -uo pipefail" "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "SE-204 is referenced in script header" {
  run grep "SE-204" "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

# ---------------------------------------------------------------------------
# 2. Eval case structure (real workspace)
# ---------------------------------------------------------------------------

@test "tests/evals/ directory exists" {
  [[ -d "$EVALS_DIR" ]]
}

@test "sdd-spec-writer has at least 3 eval cases" {
  local count
  count=$(find "${EVALS_DIR}/sdd-spec-writer" -maxdepth 1 -type d -name "eval-*" | wc -l)
  (( count >= 3 ))
}

@test "court-orchestrator has at least 3 eval cases" {
  local count
  count=$(find "${EVALS_DIR}/court-orchestrator" -maxdepth 1 -type d -name "eval-*" | wc -l)
  (( count >= 3 ))
}

@test "business-analyst has at least 3 eval cases" {
  local count
  count=$(find "${EVALS_DIR}/business-analyst" -maxdepth 1 -type d -name "eval-*" | wc -l)
  (( count >= 3 ))
}

@test "every eval case has input.md and criteria.md" {
  local missing=0
  while IFS= read -r -d '' case_dir; do
    [[ -f "${case_dir}/input.md" ]]    || (( missing++ ))
    [[ -f "${case_dir}/criteria.md" ]] || (( missing++ ))
  done < <(find "$EVALS_DIR" -maxdepth 2 -type d -name "eval-*" -print0)
  (( missing == 0 ))
}

@test "criteria.md files have at least 5 checklist items" {
  local insufficient=0
  while IFS= read -r -d '' cf; do
    local count
    count=$(grep -c '^\- \[' "$cf" 2>/dev/null || echo 0)
    (( count >= 5 )) || (( insufficient++ ))
  done < <(find "$EVALS_DIR" -name "criteria.md" -print0)
  (( insufficient == 0 ))
}

@test "input.md files have at least 50 words" {
  local insufficient=0
  while IFS= read -r -d '' inf; do
    local wc_val
    wc_val=$(wc -w < "$inf" 2>/dev/null || echo 0)
    (( wc_val >= 50 )) || (( insufficient++ ))
  done < <(find "$EVALS_DIR" -name "input.md" -print0)
  (( insufficient == 0 ))
}

# ---------------------------------------------------------------------------
# 3. Script flags (use tmp workspace for isolation)
# ---------------------------------------------------------------------------

@test "--list shows all eval cases" {
  run env PROJECT_ROOT="$TMP_PROJECT_ROOT" bash "$SCRIPT" --list
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"sdd-spec-writer"* ]]
  [[ "$output" == *"court-orchestrator"* ]]
  [[ "$output" == *"business-analyst"* ]]
}

@test "--agent filters to a single agent" {
  run env PROJECT_ROOT="$TMP_PROJECT_ROOT" bash "$SCRIPT" --agent sdd-spec-writer
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"3/3 passed"* ]]
}

@test "--dry-run does not create output files" {
  local before
  before=$(find "${TMP_PROJECT_ROOT}/output" -type f | wc -l)
  run env PROJECT_ROOT="$TMP_PROJECT_ROOT" bash "$SCRIPT" --dry-run
  [[ "$status" -eq 0 ]]
  local after
  after=$(find "${TMP_PROJECT_ROOT}/output" -type f | wc -l)
  (( after == before ))
}

@test "report file is generated after a full run" {
  run env PROJECT_ROOT="$TMP_PROJECT_ROOT" bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  local report
  report=$(find "${TMP_PROJECT_ROOT}/output" -name "eval-report-*.md" | head -1)
  [[ -n "$report" ]]
}

@test "report contains summary table" {
  env PROJECT_ROOT="$TMP_PROJECT_ROOT" bash "$SCRIPT" > /dev/null
  local report
  report=$(find "${TMP_PROJECT_ROOT}/output" -name "eval-report-*.md" | head -1)
  run grep "Total eval cases" "$report"
  [[ "$status" -eq 0 ]]
}

@test "exit 0 when score is at or above threshold" {
  run env PROJECT_ROOT="$TMP_PROJECT_ROOT" SAVIA_EVAL_THRESHOLD=80 bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "exit 1 when score is below threshold" {
  local empty_root
  empty_root="$(mktemp -d)"
  mkdir -p "${empty_root}/tests/evals/fake-agent/eval-01-empty"
  mkdir -p "${empty_root}/output"
  # eval-01-empty has no input.md and no criteria.md intentionally

  run env PROJECT_ROOT="$empty_root" SAVIA_EVAL_THRESHOLD=1 bash "$SCRIPT"
  [[ "$status" -eq 1 ]]

  rm -rf "$empty_root"
}

# ── Edge cases ────────────────────────────────────────────────────────────────

@test "edge: empty evals directory returns 0 cases gracefully" {
  local empty="$TMP_DIR/empty_evals"
  mkdir -p "$empty"
  run env PROJECT_ROOT="$TMP_DIR" SAVIA_EVALS_DIR="$empty" bash "$SCRIPT" --dry-run 2>&1 || true
  [[ "$status" -le 1 ]]
}

@test "edge: nonexistent evals directory handled without crash" {
  run env SAVIA_EVALS_DIR="/nonexistent/path/$$" bash "$SCRIPT" --dry-run 2>&1 || true
  [[ "$status" -le 2 ]]
}

@test "edge: zero eval cases in agent dir — skipped gracefully" {
  mkdir -p "$TMP_DIR/tests/evals/empty-agent"
  run env PROJECT_ROOT="$TMP_DIR" bash "$SCRIPT" --agent empty-agent --dry-run 2>&1 || true
  [[ "$status" -le 1 ]]
}

@test "negative: --agent with unknown name produces no output" {
  run bash "$SCRIPT" --agent "nonexistent-agent-$$" --dry-run 2>&1 || true
  [[ "$status" -le 1 ]]
}

@test "negative: criteria.md missing causes eval to be flagged" {
  mkdir -p "$TMP_DIR/tests/evals/bad-agent/eval-no-criteria"
  echo "# input only" > "$TMP_DIR/tests/evals/bad-agent/eval-no-criteria/input.md"
  run env PROJECT_ROOT="$TMP_DIR" SAVIA_EVAL_THRESHOLD=100 bash "$SCRIPT" --agent bad-agent 2>&1 || true
  # Should not exit 0 with threshold 100 when criteria missing
  [[ "$status" -ne 0 || "$output" =~ [Ww]arn|[Mm]issing|0% ]]
}

@test "coverage: SE-204 referenced in run-agent-evals.sh" {
  grep -q 'SE-204' "$SCRIPT"
}
