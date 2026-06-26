#!/usr/bin/env bats
# test-spec-188-phases34.bats — SPEC-188 Phases 3+4 MVP
#
# Validates causal-confidence-scorer.py and diagnostic-metrics-tracker.py
# Ref: docs/propuestas/SPEC-188-root-cause-investigation-architecture.md

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    CAUSAL_SCORER="$REPO_ROOT/scripts/causal-confidence-scorer.py"
    DIAG_TRACKER="$REPO_ROOT/scripts/diagnostic-metrics-tracker.py"
    TMPDIR_TEST="$(mktemp -d)"
    TEST_LOG="$TMPDIR_TEST/test-diagnostic-metrics.jsonl"
    export PYTHONPATH="$REPO_ROOT"
}

teardown() {
    rm -rf "${TMPDIR_TEST:-}" 2>/dev/null || true
}

# ── Test 1: causal-confidence-scorer.py exists ───────────────────────────────

@test "SPEC-188 P3: causal-confidence-scorer.py exists" {
    [ -f "$CAUSAL_SCORER" ]
}

# ── Test 2: diagnostic-metrics-tracker.py exists ────────────────────────────

@test "SPEC-188 P4: diagnostic-metrics-tracker.py exists" {
    [ -f "$DIAG_TRACKER" ]
}

# ── Test 3: --report produces output with accuracy_rate ──────────────────────

@test "SPEC-188 P4: --report produces JSON with accuracy_rate" {
    # Record two entries: 1 correct, 1 incorrect
    python3 "$DIAG_TRACKER" --log "$TEST_LOG" \
        --record --investigation-id "T1" --time-to-identify 30 \
        --confidence 0.80 --correct true > /dev/null
    python3 "$DIAG_TRACKER" --log "$TEST_LOG" \
        --record --investigation-id "T2" --time-to-identify 20 \
        --confidence 0.60 --correct false > /dev/null

    run python3 "$DIAG_TRACKER" --log "$TEST_LOG" --report
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'accuracy_rate' in d, f'Missing accuracy_rate. Keys: {list(d.keys())}'
assert 0.0 <= d['accuracy_rate'] <= 1.0, f'accuracy_rate out of range: {d[\"accuracy_rate\"]}'
"
}

# ── Test 4: causal scorer JSON output is parseable ───────────────────────────

@test "SPEC-188 P3: causal-confidence-scorer JSON output is parseable" {
    run python3 "$CAUSAL_SCORER" \
        --cause "Test root cause" \
        --evidence '["Evidence one", "Evidence two"]' \
        --alternatives '[]'
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
required = {'cause', 'confidence_score', 'supporting_evidence', 'contradicting_evidence', 'alternative_causes', 'verdict'}
missing = required - set(d.keys())
assert not missing, f'Missing fields: {missing}'
assert 0.0 <= d['confidence_score'] <= 1.0
assert d['verdict'] in {'high', 'medium', 'low', 'insufficient'}
"
}

# ── Test 5: diagnostic-metrics.jsonl is created if not exists ────────────────

@test "SPEC-188 P4: diagnostic-metrics.jsonl created on first --record" {
    local new_log="$TMPDIR_TEST/new-subdir/metrics.jsonl"
    [ ! -f "$new_log" ]
    python3 "$DIAG_TRACKER" --log "$new_log" \
        --record --investigation-id "NEWLOG" \
        --time-to-identify 10 --confidence 0.5 --correct false > /dev/null
    [ -f "$new_log" ]
}

# ── Test 6: 0 evidence returns insufficient ──────────────────────────────────

@test "SPEC-188 P3: 0 evidence returns verdict=insufficient" {
    run python3 "$CAUSAL_SCORER" \
        --cause "Some cause" \
        --evidence '[]' \
        --alternatives '[]'
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['verdict'] == 'insufficient', f'Expected insufficient, got {d[\"verdict\"]}'
assert d['confidence_score'] == 0.0
"
}

# ── Test 7: 3+ evidence coherent returns high verdict ────────────────────────

@test "SPEC-188 P3: 3+ coherent evidence returns verdict=high" {
    run python3 "$CAUSAL_SCORER" \
        --cause "Root cause identified" \
        --evidence '["Metrics confirm the pattern", "Logs show consistent errors", "Reproduced in staging"]' \
        --alternatives '[]'
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['verdict'] == 'high', f'Expected high, got {d[\"verdict\"]} score={d[\"confidence_score\"]}'
assert d['confidence_score'] >= 0.70
"
}

# ── Test 8: --list returns entries ───────────────────────────────────────────

@test "SPEC-188 P4: --list returns recorded entries" {
    for i in 1 2 3; do
        python3 "$DIAG_TRACKER" --log "$TEST_LOG" \
            --record --investigation-id "LST-$i" \
            --time-to-identify 15 --confidence 0.7 --correct true > /dev/null
    done
    run python3 "$DIAG_TRACKER" --log "$TEST_LOG" --list --n 2
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
entries = json.load(sys.stdin)
assert len(entries) == 2, f'Expected 2 entries, got {len(entries)}'
"
}
