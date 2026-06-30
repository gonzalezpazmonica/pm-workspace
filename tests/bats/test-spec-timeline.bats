#!/usr/bin/env bats
# tests/bats/test-spec-timeline.bats — SPEC-182
#
# Integration tests for the bitemporal timeline tooling.
# Requires: bats-core, python3
#
# Run: bats tests/bats/test-spec-timeline.bats
#
# Ref: SPEC-182 (docs/propuestas/SPEC-182-bitemporal-timeline-frontmatter.md)

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    APPEND_SCRIPT="$REPO_ROOT/scripts/spec-timeline-append.py"
    QUERY_SCRIPT="$REPO_ROOT/scripts/spec-timeline-query.py"
    LIFECYCLE_SCRIPT="$REPO_ROOT/scripts/spec-lifecycle.sh"
    PROPUESTAS="$REPO_ROOT/docs/propuestas"

    # Temp dir for test fixtures
    TEST_TMP="$(mktemp -d)"

    # Minimal spec fixture
    cat > "$TEST_TMP/SPEC-TEST.md" <<'EOF'
---
spec_id: SPEC-TEST
title: Test spec for timeline
status: PROPOSED
---

# Body of the test spec
EOF
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ── T1: spec-timeline-append.py exists and is executable ────────────────────

@test "spec-timeline-append.py exists" {
    [ -f "$APPEND_SCRIPT" ]
}

# ── T2: --dry-run does not modify the file ───────────────────────────────────

@test "spec-timeline-append --dry-run does not modify file" {
    local before
    before="$(cat "$TEST_TMP/SPEC-TEST.md")"

    run python3 "$APPEND_SCRIPT" \
        --file "$TEST_TMP/SPEC-TEST.md" \
        --from "2026-06-24" \
        --learned "2026-06-24" \
        --value "APPROVED" \
        --source "bats:t2" \
        --dry-run

    [ "$status" -eq 0 ]

    local after
    after="$(cat "$TEST_TMP/SPEC-TEST.md")"
    [ "$before" = "$after" ]
}

# ── T3: spec-timeline-append writes timeline when run without --dry-run ──────

@test "spec-timeline-append writes timeline entry" {
    run python3 "$APPEND_SCRIPT" \
        --file "$TEST_TMP/SPEC-TEST.md" \
        --from "2026-06-24" \
        --learned "2026-06-24" \
        --value "APPROVED" \
        --source "bats:t3"

    [ "$status" -eq 0 ]

    grep -q 'timeline:' "$TEST_TMP/SPEC-TEST.md"
    grep -q '"APPROVED"' "$TEST_TMP/SPEC-TEST.md"
}

# ── T4: spec-timeline-query.py exists and produces output ───────────────────

@test "spec-timeline-query.py exists and produces output for back-filled spec" {
    [ -f "$QUERY_SCRIPT" ]

    local spec_file="$PROPUESTAS/SPEC-192-anti-adulation-illusory-truth.md"
    [ -f "$spec_file" ] || skip "SPEC-192 not found"

    run python3 "$QUERY_SCRIPT" --file "$spec_file" --format table
    [ "$status" -eq 0 ]
    # Should contain at least one row with IMPLEMENTED
    echo "$output" | grep -q "IMPLEMENTED"
}

# ── T5: spec-lifecycle.sh has --no-timeline flag documented ──────────────────

@test "spec-lifecycle.sh --help documents --no-timeline flag" {
    run bash "$LIFECYCLE_SCRIPT" --help
    # help text must mention --no-timeline
    echo "$output" | grep -q '\-\-no-timeline'
}

# ── T6: spec-lifecycle.sh auto-appends timeline on real transition ───────────

@test "spec-lifecycle.sh auto-appends timeline entry after status transition" {
    local spec="$TEST_TMP/SPEC-LIFECYCLE.md"
    cat > "$spec" <<'EOF'
---
spec_id: SPEC-LIFECYCLE
title: Lifecycle test spec
status: PROPOSED
---

# Body
EOF

    # Override log file to avoid polluting real LOG.md
    LOG_FILE_OVERRIDE="$TEST_TMP/LOG.md" \
    run bash "$LIFECYCLE_SCRIPT" \
        --spec "$spec" \
        --status APPROVED \
        --note "bats test"

    [ "$status" -eq 0 ]

    # Timeline entry should have been appended
    grep -q 'timeline:' "$spec"
    grep -q '"APPROVED"' "$spec"
}

# ── T7: spec-timeline-query --format json returns valid JSON ─────────────────

@test "spec-timeline-query --format json returns valid JSON" {
    # First add an entry
    python3 "$APPEND_SCRIPT" \
        --file "$TEST_TMP/SPEC-TEST.md" \
        --from "2026-06-24" \
        --learned "2026-06-24" \
        --value "PROPOSED" \
        --source "bats:t7"

    run python3 "$QUERY_SCRIPT" --file "$TEST_TMP/SPEC-TEST.md" --format json
    [ "$status" -eq 0 ]

    # Validate JSON using python3
    echo "$output" | python3 -c "import sys, json; json.load(sys.stdin)"
}

# ── T8: spec-lifecycle.sh --no-timeline skips timeline append ────────────────

@test "spec-lifecycle.sh --no-timeline does not append timeline" {
    local spec="$TEST_TMP/SPEC-NOTIMELINE.md"
    cat > "$spec" <<'EOF'
---
spec_id: SPEC-NOTIMELINE
title: No timeline spec
status: PROPOSED
---

# Body
EOF

    LOG_FILE_OVERRIDE="$TEST_TMP/LOG.md" \
    run bash "$LIFECYCLE_SCRIPT" \
        --spec "$spec" \
        --status APPROVED \
        --no-timeline

    [ "$status" -eq 0 ]

    # timeline: key must NOT appear
    run grep -c 'timeline:' "$spec"
    [ "$output" = "0" ]
}
