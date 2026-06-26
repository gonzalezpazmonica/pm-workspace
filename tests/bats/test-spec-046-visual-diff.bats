#!/usr/bin/env bats
# tests/bats/test-spec-046-visual-diff.bats — SPEC-046: Visual Diff QA at Merge Time

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/scripts/visual-diff-merge-check.sh"
TMP_DIR=""

setup() {
    TMP_DIR="$(mktemp -d)"
    mkdir -p "$TMP_DIR/baseline" "$TMP_DIR/candidate" "$TMP_DIR/output"
    # Create tiny fake PNG files (1x1 pixel, identical)
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82' \
        > "$TMP_DIR/baseline/home--desktop.png"
    cp "$TMP_DIR/baseline/home--desktop.png" "$TMP_DIR/candidate/home--desktop.png"
}

teardown() {
    rm -rf "$TMP_DIR"
}

# ── test 1: missing --pr-id → exit 3 ─────────────────────────────────────────
@test "SPEC-046: missing --pr-id exits with code 3" {
    run bash "$SCRIPT" \
        --baseline-dir "$TMP_DIR/baseline" \
        --candidate-dir "$TMP_DIR/candidate"
    [ "$status" -eq 3 ]
}

# ── test 2: missing baseline dir → exit 3 ────────────────────────────────────
@test "SPEC-046: missing baseline-dir exits with code 3" {
    run bash "$SCRIPT" --pr-id "PR-TEST" \
        --baseline-dir "/nonexistent/path" \
        --candidate-dir "$TMP_DIR/candidate"
    [ "$status" -eq 3 ]
}

# ── test 3: identical screenshots → PASS (exit 0) ────────────────────────────
@test "SPEC-046: identical screenshots → PASS exit 0" {
    run bash "$SCRIPT" \
        --pr-id "PR-IDENTICAL" \
        --baseline-dir "$TMP_DIR/baseline" \
        --candidate-dir "$TMP_DIR/candidate" \
        --output-base "$TMP_DIR/output" \
        --dry-run
    [ "$status" -eq 0 ]
}

# ── test 4: report.json is created ───────────────────────────────────────────
@test "SPEC-046: report.json created after run" {
    run bash "$SCRIPT" \
        --pr-id "PR-REPORT" \
        --baseline-dir "$TMP_DIR/baseline" \
        --candidate-dir "$TMP_DIR/candidate" \
        --output-base "$TMP_DIR/output" \
        --dry-run
    [ -f "$TMP_DIR/output/PR-REPORT/report.json" ]
}

# ── test 5: report.json contains required fields ─────────────────────────────
@test "SPEC-046: report.json has pr_id, status, score fields" {
    bash "$SCRIPT" \
        --pr-id "PR-FIELDS" \
        --baseline-dir "$TMP_DIR/baseline" \
        --candidate-dir "$TMP_DIR/candidate" \
        --output-base "$TMP_DIR/output" \
        --dry-run >/dev/null 2>&1 || true

    REPORT="$TMP_DIR/output/PR-FIELDS/report.json"
    [ -f "$REPORT" ]
    grep -q '"pr_id"' "$REPORT"
    grep -q '"status"' "$REPORT"
    grep -q '"score"' "$REPORT"
}

# ── test 6: no screenshots → SKIP (exit 0, status=SKIP) ──────────────────────
@test "SPEC-046: no matched screenshots → SKIP status in report" {
    mkdir -p "$TMP_DIR/empty-baseline" "$TMP_DIR/empty-candidate"
    bash "$SCRIPT" \
        --pr-id "PR-EMPTY" \
        --baseline-dir "$TMP_DIR/empty-baseline" \
        --candidate-dir "$TMP_DIR/empty-candidate" \
        --output-base "$TMP_DIR/output" \
        --dry-run >/dev/null 2>&1 || true

    REPORT="$TMP_DIR/output/PR-EMPTY/report.json"
    [ -f "$REPORT" ]
    grep -q '"SKIP"' "$REPORT"
}

# ── test 7: report.md is created ─────────────────────────────────────────────
@test "SPEC-046: report.md is created alongside report.json" {
    bash "$SCRIPT" \
        --pr-id "PR-MD" \
        --baseline-dir "$TMP_DIR/baseline" \
        --candidate-dir "$TMP_DIR/candidate" \
        --output-base "$TMP_DIR/output" \
        --dry-run >/dev/null 2>&1 || true

    [ -f "$TMP_DIR/output/PR-MD/report.md" ]
}
