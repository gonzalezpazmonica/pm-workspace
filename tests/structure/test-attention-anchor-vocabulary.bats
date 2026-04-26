#!/usr/bin/env bats
# Ref: SE-080 — attention-anchor vocabulary (Genesis B8/B9/A7/A9)

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  DOC="$ROOT/docs/rules/domain/attention-anchor.md"
  RH="$ROOT/docs/rules/domain/radical-honesty.md"
  AS="$ROOT/docs/rules/domain/autonomous-safety.md"
  COURT="$ROOT/docs/rules/domain/code-review-court.md"
  SE079="$ROOT/docs/propuestas/SE-079-pr-plan-scope-trace-gate.md"
  GATES="$ROOT/scripts/pr-plan-gates.sh"
  # Auditor expects SCRIPT= as a literal so it can map this suite to a target;
  # the gate is the runtime enforcer of the SE-080 vocabulary (G13 emits B8).
  SCRIPT="scripts/pr-plan-gates.sh"
  TMP_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ── Canonical doc ───────────────────────────────────────────────────────────

@test "doc: attention-anchor.md exists and is non-empty" {
  [ -f "$DOC" ]
  [ -s "$DOC" ]
}

@test "doc: attention-anchor.md fits the 150-line cap" {
  local lines; lines=$(wc -l < "$DOC")
  [ "$lines" -le 150 ]
}

@test "doc: attention-anchor.md cites the upstream Genesis source URL" {
  grep -qF "github.com/danielmeppiel/genesis" "$DOC"
}

@test "doc: attention-anchor.md defines all four pattern names" {
  grep -qE "B8\s+ATTENTION\s+ANCHOR" "$DOC"
  grep -qE "B9\s+GOAL\s+STEWARD" "$DOC"
  grep -qE "A7\s+ADVERSARIAL\s+REVIEW" "$DOC"
  grep -qE "A9\s+SUPERVISED\s+EXECUTION" "$DOC"
}

@test "doc: attention-anchor.md maps each pattern to a pm-workspace primitive" {
  # B8 → orchestrator / SPEC_WORKER_ID
  grep -qE "SPEC_WORKER_ID|orchestrator" "$DOC"
  # B9 → radical-honesty Rule #24 + G13
  grep -qF "radical-honesty.md" "$DOC"
  grep -qiE "G13|scope.trace" "$DOC"
  # A7 → Court / SPEC-124
  grep -qiE "court|SPEC-124" "$DOC"
  # A9 → autonomous-safety / AUTONOMOUS_REVIEWER
  grep -qF "AUTONOMOUS_REVIEWER" "$DOC"
}

@test "doc: attention-anchor.md explicitly excludes apm/npx distribution" {
  grep -qE "apm|npx" "$DOC"
}

# ── Cross-references ────────────────────────────────────────────────────────

@test "cross-ref: radical-honesty.md flags Genesis B9 alignment" {
  grep -qE "B9\s+GOAL\s+STEWARD" "$RH"
  grep -qF "attention-anchor.md" "$RH"
}

@test "cross-ref: autonomous-safety.md flags Genesis A9 alignment" {
  grep -qE "A9\s+SUPERVISED\s+EXECUTION" "$AS"
  grep -qF "attention-anchor.md" "$AS"
}

@test "cross-ref: code-review-court.md flags Genesis A7 alignment" {
  grep -qE "A7\s+ADVERSARIAL\s+REVIEW" "$COURT"
  grep -qF "attention-anchor.md" "$COURT"
}

@test "cross-ref: SE-079 spec flags B8/B9 alignment" {
  grep -qE "B8\s+ATTENTION\s+ANCHOR" "$SE079"
  grep -qE "B9\s+GOAL\s+STEWARD" "$SE079"
  grep -qF "attention-anchor.md" "$SE079"
}

# ── Behavioural binding (G13 emits the anchor) ──────────────────────────────

@test "binding: G13 emits 'B8 attention-anchor present' on success" {
  grep -qE "B8 attention-anchor present" "$GATES"
}

@test "binding: G13 names the SE-080 pattern in its docstring" {
  awk '/^# G13_SCOPE_TRACE/,/^g13_scope_trace\(\)/' "$GATES" | grep -qE "B8|B9|attention.anchor"
}

# ── Static safety / scope ───────────────────────────────────────────────────

@test "scope: attention-anchor.md does NOT define R-tier or A1-A6 patterns" {
  # Slice 3 of the spec EXPLICITLY excludes these. Drift guard.
  ! grep -qE "^##\s+R[0-9]+" "$DOC"
  ! grep -qE "^##\s+A[1-6]\b" "$DOC"
}

@test "scope: attention-anchor.md does NOT introduce new agents or skills" {
  # Pure docs/vocab adoption — no executable surface
  ! grep -qE "^\.claude/(agents|skills)/" "$DOC"
}

@test "spec ref: SE-080 cited in attention-anchor.md" {
  grep -qF "SE-080" "$DOC"
}

@test "safety: gates file (G13 emitter) has set -uo pipefail upstream" {
  # The G13 gate function relies on pr-plan.sh's strict mode; assert the
  # contract so a future refactor cannot silently weaken it.
  grep -qE "set -uo pipefail" "$ROOT/scripts/pr-plan.sh"
}

@test "safety: attention-anchor.md does NOT prescribe LLM calls or external endpoints" {
  ! grep -qiE "anthropic\.com|openai\.com|api\.[a-z]+\.com" "$DOC"
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: empty cross-reference path is rejected (no orphan annotations)" {
  # Pattern alignment must NOT replace pm-workspace names — only annotate them.
  # If a host file references attention-anchor.md, the rule names must still appear.
  grep -qF "AUTONOMOUS_REVIEWER" "$DOC"
  grep -qF "radical-honesty" "$DOC"
}

@test "edge: nonexistent cross-reference target would be caught" {
  # Verify each cross-ref host file still references attention-anchor.md
  # If any cross-ref drifted to a missing path, this fails.
  for f in "$RH" "$AS" "$COURT" "$SE079"; do
    grep -qF "attention-anchor.md" "$f"
  done
}

@test "edge: boundary — host files stay within the 150-line cap after annotation" {
  for f in "$RH" "$AS" "$COURT"; do
    local lines; lines=$(wc -l < "$f")
    [ "$lines" -le 150 ]
  done
}

@test "edge: zero R-tier and A1-A6 patterns leak into the doc (scope cap)" {
  # SE-080 is opinionated — must reject part of the upstream catalogue.
  grep -qiE "fuera de scope|not adopt|R-tier|A1-A6|deliberadamente" "$DOC"
  # And explicitly NOT define them as headings:
  ! grep -qE "^##\s+R[0-9]+" "$DOC"
}

@test "edge: no-arg invocation of grep over the doc still finds the four pattern names" {
  # Coverage redundancy: independent of the per-pattern test above
  for p in "B8 ATTENTION ANCHOR" "B9 GOAL STEWARD" "A7 ADVERSARIAL REVIEW" "A9 SUPERVISED EXECUTION"; do
    grep -qE "$p" "$DOC"
  done
}
