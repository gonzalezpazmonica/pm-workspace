#!/usr/bin/env bats
# Tests for SE-030-T — graphrag quality gate
# Ref: docs/rules/domain/graphrag-quality-gates.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/graphrag-quality-gate.sh"
  export DOC="$REPO_ROOT/docs/rules/domain/graphrag-quality-gates.md"
  TMPDIR_QG="$(mktemp -d)"
  export TMPDIR_QG

  # Perfect metrics (all PASS at phase 3)
  cat > "$TMPDIR_QG/pass.json" <<'F'
{
  "ndcg_at_10": 0.80, "recall_at_20": 0.90, "mrr": 0.65, "cross_repo_precision": 0.72,
  "context_coherence": 0.91, "relevance": 0.85, "completeness": 0.88,
  "groundedness": 0.92, "hallucination": 0.08, "attribution_accuracy": 0.96,
  "factual_accuracy": 0.91, "coherence_gen": 0.87
}
F

  # Bad metrics: fails multiple
  cat > "$TMPDIR_QG/fail.json" <<'F'
{
  "ndcg_at_10": 0.50, "recall_at_20": 0.90, "mrr": 0.65, "cross_repo_precision": 0.72,
  "context_coherence": 0.91, "relevance": 0.85, "completeness": 0.88,
  "groundedness": 0.70, "hallucination": 0.25, "attribution_accuracy": 0.90,
  "factual_accuracy": 0.91, "coherence_gen": 0.87
}
F

  # Missing metrics
  cat > "$TMPDIR_QG/incomplete.json" <<'F'
{
  "ndcg_at_10": 0.80, "recall_at_20": 0.90
}
F

  # Malformed JSON
  echo "not a json" > "$TMPDIR_QG/malformed.json"
}

teardown() {
  rm -rf "$TMPDIR_QG" 2>/dev/null || true
}

# ── Safety ───────────────────────────────────────────────────────────────────

@test "safety: script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "safety: script has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: script references SE-030" {
  grep -q "SE-030" "$SCRIPT"
}

@test "safety: doc exists and is non-empty" {
  [ -f "$DOC" ]
  [ -s "$DOC" ]
}

# ── Positive: all pass ───────────────────────────────────────────────────────

@test "positive: all metrics pass at phase 3 → exit 0" {
  run bash "$SCRIPT" --metrics "$TMPDIR_QG/pass.json" --phase 3
  [ "$status" -eq 0 ]
}

@test "positive: JSON output parseable with 12 metrics" {
  run bash "$SCRIPT" --metrics "$TMPDIR_QG/pass.json" --phase 3 --json
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert len(d['metrics']) == 12
assert d['fails'] == 0
"
}

@test "positive: --help returns exit 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "positive: phase 1 passes with good metrics (no warns)" {
  run bash "$SCRIPT" --metrics "$TMPDIR_QG/pass.json" --phase 1
  [ "$status" -eq 0 ]
}

@test "positive: doc references all 12 metrics" {
  grep -q "NDCG@10" "$DOC"
  grep -q "Recall@20" "$DOC"
  grep -q "MRR" "$DOC"
  grep -q "Cross-Repo Precision" "$DOC"
  grep -q "Context Coherence" "$DOC"
  grep -q "Relevance" "$DOC"
  grep -q "Completeness" "$DOC"
  grep -q "Groundedness" "$DOC"
  grep -q "Hallucination" "$DOC"
  grep -q "Attribution" "$DOC"
  grep -q "Factual" "$DOC"
}

# ── Negative / fail cases ───────────────────────────────────────────────────

@test "negative: bad metrics at phase 3 → exit 1" {
  run bash "$SCRIPT" --metrics "$TMPDIR_QG/fail.json" --phase 3
  [ "$status" -eq 1 ]
  echo "$output" | grep -qE "FAIL"
}

@test "negative: bad generation metrics at phase 2 → exit 1" {
  run bash "$SCRIPT" --metrics "$TMPDIR_QG/fail.json" --phase 2
  [ "$status" -eq 1 ]
}

@test "negative: bad retrieval metrics at phase 1 → WARN (exit 1 flags attention)" {
  run bash "$SCRIPT" --metrics "$TMPDIR_QG/fail.json" --phase 1
  # Phase 1 warns on retrieval issues; overall non-zero exit for attention
  [ "$status" -eq 1 ]
}

@test "negative: incomplete metrics file → exit 1 (MISSING)" {
  run bash "$SCRIPT" --metrics "$TMPDIR_QG/incomplete.json" --phase 3
  [ "$status" -eq 1 ]
  echo "$output" | grep -qE "MISSING"
}

@test "negative: malformed JSON → exit 2" {
  run bash "$SCRIPT" --metrics "$TMPDIR_QG/malformed.json" --phase 3
  [ "$status" -eq 2 ]
}

@test "negative: missing --metrics rejected with exit 2" {
  run bash "$SCRIPT" --phase 3
  [ "$status" -eq 2 ]
}

@test "negative: nonexistent metrics file rejected with exit 2" {
  run bash "$SCRIPT" --metrics "/nonexistent/xyz.json"
  [ "$status" -eq 2 ]
}

@test "negative: unknown flag rejected" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: boundary value exactly at threshold PASSes (0.75 for NDCG@10)" {
  cat > "$TMPDIR_QG/boundary.json" <<'F'
{
  "ndcg_at_10": 0.75, "recall_at_20": 0.85, "mrr": 0.6, "cross_repo_precision": 0.7,
  "context_coherence": 0.9, "relevance": 0.8, "completeness": 0.85,
  "groundedness": 0.9, "hallucination": 0.1, "attribution_accuracy": 0.95,
  "factual_accuracy": 0.9, "coherence_gen": 0.85
}
F
  run bash "$SCRIPT" --metrics "$TMPDIR_QG/boundary.json" --phase 3 --json
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['fails'] == 0, f'fails was {d[\"fails\"]}'
"
}

@test "edge: hallucination >0.1 → FAIL (le direction)" {
  cat > "$TMPDIR_QG/high-hall.json" <<'F'
{
  "ndcg_at_10": 0.80, "recall_at_20": 0.90, "mrr": 0.65, "cross_repo_precision": 0.72,
  "context_coherence": 0.91, "relevance": 0.85, "completeness": 0.88,
  "groundedness": 0.92, "hallucination": 0.15, "attribution_accuracy": 0.96,
  "factual_accuracy": 0.91, "coherence_gen": 0.87
}
F
  run bash "$SCRIPT" --metrics "$TMPDIR_QG/high-hall.json" --phase 2 --json
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
halls = [m for m in d['metrics'] if m['metric']=='hallucination']
assert halls[0]['status'] == 'FAIL'
"
}

@test "edge: empty JSON object → 12 missing" {
  echo "{}" > "$TMPDIR_QG/empty.json"
  run bash "$SCRIPT" --metrics "$TMPDIR_QG/empty.json" --phase 3 --json
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['missing'] == 12
"
}

@test "edge: default phase is 1 when not specified" {
  run bash "$SCRIPT" --metrics "$TMPDIR_QG/pass.json" --json
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['phase'] == 1
"
}

# ── Isolation ────────────────────────────────────────────────────────────────

@test "isolation: does not modify input metrics file" {
  h=$(sha256sum "$TMPDIR_QG/pass.json" | awk '{print $1}')
  bash "$SCRIPT" --metrics "$TMPDIR_QG/pass.json" --phase 3 >/dev/null 2>&1
  h2=$(sha256sum "$TMPDIR_QG/pass.json" | awk '{print $1}')
  [ "$h" = "$h2" ]
}

@test "isolation: exit codes are 0, 1, or 2" {
  run bash "$SCRIPT" --metrics "$TMPDIR_QG/pass.json" --phase 3
  [[ "$status" == "0" || "$status" == "1" || "$status" == "2" ]]
}
