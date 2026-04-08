#!/usr/bin/env bats
# Tests for competitive-design.sh — Parallel design generation with 3 philosophies
# Ref: docs/propuestas/SPEC-095-competitive-architects.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/competitive-design.sh"
  TMPDIR_CD=$(mktemp -d)

  # Create mock spec
  cat > "$TMPDIR_CD/test.spec.md" <<'EOF'
---
spec_id: TEST-001
title: Test Spec for Competitive Design
---
# TEST-001: Create User API

## Contract
POST /api/users → 201 Created

## Business Rules
- Email must be unique
- Password minimum 8 chars

## Test Scenarios
- Valid user creation → 201
- Duplicate email → 409
EOF

  # Create mock designs.json for evaluate/compare
  cat > "$TMPDIR_CD/designs.json" <<'EOF'
{
  "spec": "test-spec",
  "spec_path": "test.spec.md",
  "philosophies": ["minimal", "clean", "pragmatic"],
  "designs": {
    "minimal": {"philosophy": "minimal", "status": "done", "content": "..."},
    "clean": {"philosophy": "clean", "status": "done", "content": "..."},
    "pragmatic": {"philosophy": "pragmatic", "status": "done", "content": "..."}
  }
}
EOF

  # Create mock evaluation with scores
  cat > "$TMPDIR_CD/evaluated.json" <<'EOF'
{
  "spec": "test-spec",
  "criteria": ["implementation_complexity", "spec_alignment", "maintainability_6m", "regression_risk"],
  "evaluations": {
    "minimal": {"philosophy": "minimal", "scores": {"implementation_complexity": 8, "spec_alignment": 7, "maintainability_6m": 6, "regression_risk": 9}, "total": 30},
    "clean": {"philosophy": "clean", "scores": {"implementation_complexity": 5, "spec_alignment": 9, "maintainability_6m": 9, "regression_risk": 5}, "total": 28},
    "pragmatic": {"philosophy": "pragmatic", "scores": {"implementation_complexity": 7, "spec_alignment": 8, "maintainability_6m": 8, "regression_risk": 7}, "total": 30}
  }
}
EOF
}

teardown() {
  rm -rf "$TMPDIR_CD"
}

# ── 1. Script existence and structure ────────────────────────────────────────

@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "script has safety flags (set -uo pipefail)" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "script shows usage without arguments" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

# ── 2. Philosophies ──────────────────────────────────────────────────────────

@test "philosophies lists all 3 design approaches" {
  run bash "$SCRIPT" philosophies
  [ "$status" -eq 0 ]
  [[ "$output" == *"minimal"* ]]
  [[ "$output" == *"clean"* ]]
  [[ "$output" == *"pragmatic"* ]]
}

@test "philosophies contain distinct priorities" {
  run bash "$SCRIPT" philosophies
  [ "$status" -eq 0 ]
  [[ "$output" == *"MINIMUM CHANGES"* ]]
  [[ "$output" == *"IDEAL CLEAN ARCHITECTURE"* ]]
  [[ "$output" == *"PRAGMATIC BALANCE"* ]]
}

# ── 3. Generate ──────────────────────────────────────────────────────────────

@test "generate produces valid JSON" {
  run bash "$SCRIPT" generate "$TMPDIR_CD/test.spec.md"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

@test "generate includes all 3 philosophies" {
  run bash "$SCRIPT" generate "$TMPDIR_CD/test.spec.md"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['philosophies']))")
  [ "$count" -eq 3 ]
}

@test "generate includes spec name" {
  run bash "$SCRIPT" generate "$TMPDIR_CD/test.spec.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"test"* ]]
}

@test "generate fails on missing spec" {
  run bash "$SCRIPT" generate "$TMPDIR_CD/nonexistent.md"
  [ "$status" -eq 1 ]
}

# ── 4. Evaluate ──────────────────────────────────────────────────────────────

@test "evaluate produces valid JSON with 4 criteria" {
  run bash "$SCRIPT" evaluate "$TMPDIR_CD/designs.json"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['criteria']))")
  [ "$count" -eq 4 ]
}

@test "evaluate includes all 3 philosophies in evaluations" {
  run bash "$SCRIPT" evaluate "$TMPDIR_CD/designs.json"
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | python3 -c "import json,sys; print(len(json.load(sys.stdin)['evaluations']))")
  [ "$count" -eq 3 ]
}

# ── 5. Compare ───────────────────────────────────────────────────────────────

@test "compare generates markdown table" {
  run bash "$SCRIPT" compare "$TMPDIR_CD/evaluated.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| Criterion"* ]]
  [[ "$output" == *"Minimal"* ]]
  [[ "$output" == *"Clean"* ]]
  [[ "$output" == *"Pragmatic"* ]]
}

@test "compare includes recommendation" {
  run bash "$SCRIPT" compare "$TMPDIR_CD/evaluated.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Recommendation"* ]]
}

@test "compare shows total scores" {
  run bash "$SCRIPT" compare "$TMPDIR_CD/evaluated.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"**Total**"* ]]
}

# ── 6. Edge cases ────────────────────────────────────────────────────────────

@test "evaluate fails on missing file" {
  run bash "$SCRIPT" evaluate "$TMPDIR_CD/nonexistent.json"
  [ "$status" -eq 1 ]
}

@test "unknown command shows error" {
  run bash "$SCRIPT" foobar
  [ "$status" -eq 1 ]
}
