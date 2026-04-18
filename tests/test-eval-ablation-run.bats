#!/usr/bin/env bats
# Tests for SE-030-A — ablation seam runner
# Ref: docs/propuestas/SE-030-graphrag-quality-gates.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/eval-ablation-run.sh"
  TMPDIR_AB="$(mktemp -d)"
  export TMPDIR_AB

  cat > "$TMPDIR_AB/full.json" <<'F'
{"ndcg_at_10":0.85,"recall_at_20":0.90,"mrr":0.70,"cross_repo_precision":0.75,
 "context_coherence":0.92,"relevance":0.88,"completeness":0.87,
 "groundedness":0.93,"hallucination":0.06,"attribution_accuracy":0.96,
 "factual_accuracy":0.92,"coherence_gen":0.88}
F

  # Large degradation (layer valuable)
  cat > "$TMPDIR_AB/ablated-large.json" <<'F'
{"ndcg_at_10":0.71,"recall_at_20":0.85,"mrr":0.60,"cross_repo_precision":0.55,
 "context_coherence":0.80,"relevance":0.75,"completeness":0.78,
 "groundedness":0.82,"hallucination":0.14,"attribution_accuracy":0.88,
 "factual_accuracy":0.84,"coherence_gen":0.82}
F

  # Small degradation (layer questionable)
  cat > "$TMPDIR_AB/ablated-small.json" <<'F'
{"ndcg_at_10":0.84,"recall_at_20":0.89,"mrr":0.69,"cross_repo_precision":0.74,
 "context_coherence":0.91,"relevance":0.87,"completeness":0.86,
 "groundedness":0.92,"hallucination":0.07,"attribution_accuracy":0.95,
 "factual_accuracy":0.91,"coherence_gen":0.87}
F
}

teardown() {
  rm -rf "$TMPDIR_AB" 2>/dev/null || true
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

# ── Positive: valuable layer ─────────────────────────────────────────────────

@test "positive: large degradation → VALUABLE, exit 0" {
  run bash "$SCRIPT" --full-metrics "$TMPDIR_AB/full.json" \
    --ablated-metrics "$TMPDIR_AB/ablated-large.json" --ablated-layer graph
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "VALUABLE"
}

@test "positive: JSON output parseable with deltas" {
  run bash "$SCRIPT" --full-metrics "$TMPDIR_AB/full.json" \
    --ablated-metrics "$TMPDIR_AB/ablated-large.json" --ablated-layer graph --json
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert 'deltas' in d
assert d['status'] == 'VALUABLE'
assert d['avg_delta'] > 0.05
"
}

@test "positive: --help returns exit 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "positive: all 4 ablated-layer enum values accepted" {
  for layer in retrieval reasoning generation graph; do
    run bash "$SCRIPT" --full-metrics "$TMPDIR_AB/full.json" \
      --ablated-metrics "$TMPDIR_AB/ablated-large.json" --ablated-layer "$layer" --json
    [ "$status" -eq 0 ]
  done
}

@test "positive: hallucination inversely tracked (ablated>full is bad)" {
  run bash "$SCRIPT" --full-metrics "$TMPDIR_AB/full.json" \
    --ablated-metrics "$TMPDIR_AB/ablated-large.json" --ablated-layer graph --json
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
hall = [x for x in d['deltas'] if x['metric']=='hallucination'][0]
assert hall.get('inverse') is True
assert hall['delta'] > 0
"
}

# ── Negative: small degradation ─────────────────────────────────────────────

@test "negative: small degradation → QUESTIONABLE, exit 1" {
  run bash "$SCRIPT" --full-metrics "$TMPDIR_AB/full.json" \
    --ablated-metrics "$TMPDIR_AB/ablated-small.json" --ablated-layer graph
  [ "$status" -eq 1 ]
  echo "$output" | grep -qE "QUESTIONABLE"
}

@test "negative: invalid --ablated-layer rejected with exit 2" {
  run bash "$SCRIPT" --full-metrics "$TMPDIR_AB/full.json" \
    --ablated-metrics "$TMPDIR_AB/ablated-large.json" --ablated-layer "bogus"
  [ "$status" -eq 2 ]
}

@test "negative: missing --full-metrics rejected" {
  run bash "$SCRIPT" --ablated-metrics "$TMPDIR_AB/ablated-large.json" --ablated-layer graph
  [ "$status" -eq 2 ]
}

@test "negative: missing --ablated-metrics rejected" {
  run bash "$SCRIPT" --full-metrics "$TMPDIR_AB/full.json" --ablated-layer graph
  [ "$status" -eq 2 ]
}

@test "negative: nonexistent full file rejected" {
  run bash "$SCRIPT" --full-metrics "/nonexistent.json" \
    --ablated-metrics "$TMPDIR_AB/ablated-large.json" --ablated-layer graph
  [ "$status" -eq 2 ]
}

@test "negative: unknown flag rejected" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: --min-delta override (lower → accept smaller delta)" {
  run bash "$SCRIPT" --full-metrics "$TMPDIR_AB/full.json" \
    --ablated-metrics "$TMPDIR_AB/ablated-small.json" --ablated-layer graph --min-delta 0.001 --json
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['status']=='VALUABLE'"
}

@test "edge: empty JSON files → zero deltas" {
  echo "{}" > "$TMPDIR_AB/empty.json"
  run bash "$SCRIPT" --full-metrics "$TMPDIR_AB/empty.json" \
    --ablated-metrics "$TMPDIR_AB/empty.json" --ablated-layer graph --json
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['avg_delta'] == 0.0"
}

@test "edge: identical metrics → QUESTIONABLE (no degradation)" {
  run bash "$SCRIPT" --full-metrics "$TMPDIR_AB/full.json" \
    --ablated-metrics "$TMPDIR_AB/full.json" --ablated-layer graph
  [ "$status" -eq 1 ]
}

@test "edge: default min-delta is 0.05" {
  grep -q 'MIN_DELTA="0.05"' "$SCRIPT"
}

# ── Isolation ────────────────────────────────────────────────────────────────

@test "isolation: does not modify metrics files" {
  h=$(sha256sum "$TMPDIR_AB/full.json" | awk '{print $1}')
  bash "$SCRIPT" --full-metrics "$TMPDIR_AB/full.json" \
    --ablated-metrics "$TMPDIR_AB/ablated-large.json" --ablated-layer graph --json >/dev/null 2>&1
  h2=$(sha256sum "$TMPDIR_AB/full.json" | awk '{print $1}')
  [ "$h" = "$h2" ]
}

@test "isolation: exit codes are 0, 1, or 2" {
  run bash "$SCRIPT" --full-metrics "$TMPDIR_AB/full.json" \
    --ablated-metrics "$TMPDIR_AB/ablated-large.json" --ablated-layer graph
  [[ "$status" == "0" || "$status" == "1" || "$status" == "2" ]]
}
