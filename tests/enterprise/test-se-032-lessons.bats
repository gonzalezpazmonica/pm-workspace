#!/usr/bin/env bats
# test-se-032-lessons.bats — SE-032 Cross-Project Lessons Pipeline
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-032-cross-project-lessons.md

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export REPO_ROOT

  LESSONS_COLLECTOR="${REPO_ROOT}/scripts/enterprise/lessons-collector.sh"
  LESSONS_PROMOTE="${REPO_ROOT}/scripts/enterprise/lessons-promote.sh"
  export LESSONS_COLLECTOR LESSONS_PROMOTE

  OUTPUT_DIR="${TEST_TMPDIR}/enterprise"
  mkdir -p "$OUTPUT_DIR"
  export OUTPUT_DIR

  # Create minimal learned rules for test
  LEARNED_DIR="${TEST_TMPDIR}/docs/rules/learned"
  mkdir -p "$LEARNED_DIR"
  cat > "${LEARNED_DIR}/timeout-handling.md" <<'EOF'
---
date: 2026-04-12
---
Always configure timeouts on HTTP clients to prevent cascading failures.
EOF
  export LEARNED_DIR
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── Test 1: lessons-collector.sh exists and produces JSON ────────────────────

@test "lessons-collector.sh exists and is executable" {
  [[ -f "$LESSONS_COLLECTOR" ]]
  [[ -x "$LESSONS_COLLECTOR" ]]
}

# ── Test 2: collector produces output with themes field ──────────────────────

@test "lessons-collector.sh produces JSON with themes field" {
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' '$LESSONS_COLLECTOR' --output-dir '$OUTPUT_DIR'"
  [ "$status" -eq 0 ]

  OUT_FILE="$(ls "${OUTPUT_DIR}"/cross-project-lessons-*.json 2>/dev/null | tail -1)"
  [[ -f "$OUT_FILE" ]]
  grep -q '"themes"' "$OUT_FILE"
}

# ── Test 3: anonymization — project names not in output ──────────────────────

@test "lessons-collector.sh anonymizes project names" {
  # Create a fake tenant with a project whose name must not appear in output
  mkdir -p "${TEST_TMPDIR}/tenants/acme-corp/projects/SECRET_PROJECT_NAME"
  cat > "${TEST_TMPDIR}/tenants/acme-corp/projects/SECRET_PROJECT_NAME/evaluation.md" <<'EOF'
# Evaluation

## lessons_learned

- Always document API contracts before implementation
EOF

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' '$LESSONS_COLLECTOR' --tenant 'acme-corp' --output-dir '$OUTPUT_DIR'"
  [ "$status" -eq 0 ]

  OUT_FILE="$(ls "${OUTPUT_DIR}"/cross-project-lessons-*.json 2>/dev/null | tail -1)"
  [[ -f "$OUT_FILE" ]]

  # Raw project name must NOT appear in the output
  run grep -c "SECRET_PROJECT_NAME" "$OUT_FILE"
  [ "$output" -eq 0 ]
}

# ── Test 4: lessons-promote.sh with --dry-run does not create file ────────────

@test "lessons-promote.sh with --dry-run does not create any file" {
  # Create the lessons file in the path the script expects: REPO_ROOT/output/enterprise/
  FAKE_LESSONS_DIR="${TEST_TMPDIR}/output/enterprise"
  mkdir -p "$FAKE_LESSONS_DIR"
  cat > "${FAKE_LESSONS_DIR}/cross-project-lessons-$(date +%Y-%m-%d).json" <<'EOF'
{
  "generated_at": "2026-06-24T00:00:00Z",
  "themes": [
    {
      "theme": "test-lesson-abc",
      "lesson_count": 3,
      "representative_lesson": "Always use connection pooling for database access.",
      "projects": ["aaa11111","bbb22222"]
    }
  ]
}
EOF

  TARGET="${TEST_TMPDIR}/rules/learned"
  mkdir -p "$TARGET"

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' '$LESSONS_PROMOTE' --lesson-id 'test-lesson-abc' --target '$TARGET' --dry-run"
  [ "$status" -eq 0 ]

  # File must NOT have been created
  [[ ! -f "${TARGET}/test-lesson-abc.md" ]]
  # But output must mention what it would create
  echo "$output" | grep -qi "dry.run\|would create"
}

# ── Test 5: lessons-promote.sh exists and is executable ──────────────────────

@test "lessons-promote.sh exists and is executable" {
  [[ -f "$LESSONS_PROMOTE" ]]
  [[ -x "$LESSONS_PROMOTE" ]]
}

# ── Test 6: lessons-collector.sh with no data produces graceful empty output ──

@test "lessons-collector.sh with no learned rules produces valid JSON" {
  EMPTY_DIR="${TEST_TMPDIR}/empty-enterprise"
  mkdir -p "$EMPTY_DIR"

  run bash -c "REPO_ROOT='${TEST_TMPDIR}/nonexistent' '$LESSONS_COLLECTOR' --output-dir '$EMPTY_DIR'"
  [ "$status" -eq 0 ]

  OUT_FILE="$(ls "${EMPTY_DIR}"/cross-project-lessons-*.json 2>/dev/null | tail -1)"
  [[ -f "$OUT_FILE" ]]
  # Must be valid JSON structure
  grep -q '"themes"' "$OUT_FILE"
}
