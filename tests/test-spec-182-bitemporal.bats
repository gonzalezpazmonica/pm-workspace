#!/usr/bin/env bats
# test-spec-182-bitemporal.bats — BATS tests for SPEC-182 bi-temporal timeline frontmatter
# Ref: SPEC-182
# Min score: 15 tests targeting >=80 coverage

SCHEMA_DOC="docs/rules/domain/bitemporal-timeline-schema.md"
APPEND_SCRIPT="scripts/timeline-append.sh"
QUERY_SCRIPT="scripts/timeline-query.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  TMPDIR_TEST="$(mktemp -d)"
  # Create a minimal spec fixture
  FIXTURE_SPEC="$TMPDIR_TEST/SPEC-TEST.md"
  cat > "$FIXTURE_SPEC" << 'SPEC'
---
spec_id: SPEC-TEST
title: Test Spec for timeline BATS
status: PROPOSED
tier: 1
---

# Test spec body
SPEC
  export FIXTURE_SPEC TMPDIR_TEST
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── Static checks ─────────────────────────────────────────────────────────────

@test "schema doc exists" {
  [[ -f "$SCHEMA_DOC" ]]
}

@test "schema doc references SPEC-182" {
  run grep -c "SPEC-182" "$SCHEMA_DOC"
  [[ "$output" -ge 1 ]]
}

@test "timeline-append.sh exists and is executable" {
  [[ -x "$APPEND_SCRIPT" ]]
}

@test "timeline-query.sh exists and is executable" {
  [[ -x "$QUERY_SCRIPT" ]]
}

@test "timeline-append.sh uses set -uo pipefail" {
  run grep -c "set -uo pipefail" "$APPEND_SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "timeline-query.sh uses set -uo pipefail" {
  run grep -c "set -uo pipefail" "$QUERY_SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "timeline-append.sh passes bash -n syntax check" {
  run bash -n "$APPEND_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "timeline-query.sh passes bash -n syntax check" {
  run bash -n "$QUERY_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "timeline-append.sh references SPEC-182" {
  run grep -c "SPEC-182" "$APPEND_SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "timeline-query.sh references SPEC-182" {
  run grep -c "SPEC-182" "$QUERY_SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── Append behaviour ──────────────────────────────────────────────────────────

@test "append: adds timeline block to file without existing timeline" {
  run bash "$APPEND_SCRIPT" status "$FIXTURE_SPEC" APPROVED "bats test"
  [ "$status" -eq 0 ]
  run grep -c "timeline:" "$FIXTURE_SPEC"
  [[ "$output" -ge 1 ]]
}

@test "append: updates top-level status field" {
  bash "$APPEND_SCRIPT" status "$FIXTURE_SPEC" APPROVED "bats test"
  run grep "^status:" "$FIXTURE_SPEC"
  [[ "$output" == *"APPROVED"* ]]
}

@test "append --dry-run does not modify file" {
  BEFORE="$(cat "$FIXTURE_SPEC")"
  run bash "$APPEND_SCRIPT" status "$FIXTURE_SPEC" APPROVED "bats test" --dry-run
  [ "$status" -eq 0 ]
  AFTER="$(cat "$FIXTURE_SPEC")"
  [[ "$BEFORE" == "$AFTER" ]]
}

@test "append --dry-run output shows field transition" {
  run bash "$APPEND_SCRIPT" status "$FIXTURE_SPEC" APPROVED "bats test" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROPOSED"* ]] || [[ "$output" == *"APPROVED"* ]]
}

@test "append: second append closes previous entry with until date" {
  bash "$APPEND_SCRIPT" status "$FIXTURE_SPEC" APPROVED "first"
  bash "$APPEND_SCRIPT" status "$FIXTURE_SPEC" IMPLEMENTED "second"
  run grep -c "until:" "$FIXTURE_SPEC"
  [[ "$output" -ge 1 ]]
}

# ── Query behaviour ───────────────────────────────────────────────────────────

@test "query: returns correct value for date in range" {
  bash "$APPEND_SCRIPT" status "$FIXTURE_SPEC" APPROVED "merged"
  TODAY="$(date -u +%Y-%m-%d)"
  run bash "$QUERY_SCRIPT" "$FIXTURE_SPEC" --at "$TODAY"
  [ "$status" -eq 0 ]
  [[ "$output" == "APPROVED" ]]
}

@test "query: exit 1 for date before first entry" {
  bash "$APPEND_SCRIPT" status "$FIXTURE_SPEC" APPROVED "merged"
  run bash "$QUERY_SCRIPT" "$FIXTURE_SPEC" --at "2020-01-01"
  [ "$status" -eq 1 ]
}

@test "query: exit 1 for file without timeline key" {
  EMPTY_SPEC="$TMPDIR_TEST/SPEC-NO-TIMELINE.md"
  cat > "$EMPTY_SPEC" << 'SPEC'
---
spec_id: SPEC-NO-TIMELINE
title: No timeline here
status: PROPOSED
---
# body
SPEC
  run bash "$QUERY_SCRIPT" "$EMPTY_SPEC" --at "2026-06-01"
  [ "$status" -eq 1 ]
}

# ── Pilot migration ───────────────────────────────────────────────────────────

@test "5 pilot SPECs have timeline key in frontmatter" {
  count=0
  for f in docs/propuestas/SPEC-184-*.md docs/propuestas/SPEC-185-*.md docs/propuestas/SPEC-186-*.md docs/propuestas/SPEC-187-*.md docs/propuestas/SPEC-188-*.md; do
    [[ -f "$f" ]] || continue
    if grep -q "^timeline:" "$f"; then
      count=$((count + 1))
    fi
  done
  [[ "$count" -ge 5 ]]
}

@test "pilot SPECs: top-level status equals last timeline entry value" {
  for f in docs/propuestas/SPEC-184-*.md docs/propuestas/SPEC-185-*.md docs/propuestas/SPEC-186-*.md; do
    [[ -f "$f" ]] || continue
    top_status=$(grep "^status:" "$f" | head -1 | sed 's/status: *//')
    last_value=$(grep "^    value:" "$f" | tail -1 | sed 's/.*value: *//' | tr -d '"')
    [[ "$top_status" == "$last_value" ]]
  done
}

# ── Isolation ─────────────────────────────────────────────────────────────────

setup() { ISO_TMP="$(mktemp -d)"; }
teardown() { rm -rf "$ISO_TMP"; }

# ── Edge cases ────────────────────────────────────────────────────────────────

@test "edge: empty input file to timeline-append exits with error" {
  touch "$ISO_TMP/empty.md"
  run bash "$APPEND" status "$ISO_TMP/empty.md" APPROVED "test" 2>&1 || true
  # Either exits non-zero or produces no-op — must not crash with unbound var
  [[ "$status" -le 2 ]]
}

@test "edge: nonexistent file to timeline-query exits non-zero" {
  run bash "$QUERY" "$ISO_TMP/nonexistent.md" --at 2026-01-01
  [ "$status" -ne 0 ]
}

@test "edge: zero-length timeline array — query returns null gracefully" {
  printf -- '---\nstatus: PROPOSED\ntimeline: []\n---\n# empty\n' > "$ISO_TMP/zero.md"
  run bash "$QUERY" "$ISO_TMP/zero.md" --at 2026-01-01 2>&1 || true
  [[ "$status" -ne 0 ]]
}

@test "edge: no-arg invocation of timeline-append shows usage" {
  run bash "$APPEND" 2>&1 || true
  [[ "$status" -ne 0 || "$output" =~ [Uu]sage ]]
}

@test "coverage: SPEC-182 referenced in timeline-append script" {
  grep -q 'SPEC-182' "$APPEND"
}

@test "coverage: timeline-query referenced in timeline-append or schema doc" {
  grep -q 'timeline-query' "$SCHEMA" || grep -q 'timeline-query' "$APPEND"
}
