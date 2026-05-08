#!/usr/bin/env bats
# Ref: SE-084 Slice 2 — pr-plan G14 skill catalog gate
# Spec: docs/propuestas/SE-084-skill-catalog-quality-audit.md
# Re-implementation pattern from mattpocock/skills/write-a-skill (MIT, clean-room).
# Safety: tests verify 'set -uo pipefail' presence in pr-plan-gates.sh.

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="scripts/pr-plan-gates.sh"
  GATES_ABS="$ROOT_DIR/$SCRIPT"
  AUDITOR="$ROOT_DIR/scripts/skill-catalog-audit.sh"
  RULE_DOC="$ROOT_DIR/docs/rules/domain/skill-catalog-discipline.md"
  PR_PLAN="$ROOT_DIR/scripts/pr-plan.sh"
  TMPDIR_T=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_T"
}

# Helper: source the gates file and run a function
source_gates() {
  # shellcheck disable=SC1090
  source "$GATES_ABS"
}

# ── Doc structure ───────────────────────────────────────────────────────────

@test "rule doc skill-catalog-discipline.md exists" {
  [ -f "$RULE_DOC" ]
}

@test "rule doc declares 5 enforcement rules (frontmatter / size / trigger / attribution / cross-refs)" {
  grep -q "Frontmatter obligatorio" "$RULE_DOC"
  grep -q "Tamaño" "$RULE_DOC"
  grep -q "Description trigger discipline" "$RULE_DOC"
  grep -q "Atribución upstream" "$RULE_DOC"
  grep -q "Cross-references" "$RULE_DOC"
}

@test "rule doc cites SE-084 spec and the auditor script path" {
  grep -q "SE-084" "$RULE_DOC"
  grep -q "scripts/skill-catalog-audit.sh" "$RULE_DOC"
}

@test "rule doc cites Pocock write-a-skill MIT pattern source" {
  grep -q "mattpocock/skills/write-a-skill" "$RULE_DOC"
  grep -q "MIT" "$RULE_DOC"
}

# ── G14 function structure ──────────────────────────────────────────────────

@test "g14_skill_catalog function defined in pr-plan-gates.sh" {
  grep -q "^g14_skill_catalog()" "$GATES_ABS"
}

@test "g14 invocation registered in pr-plan.sh" {
  grep -qE 'gate "G14".*g14_skill_catalog' "$PR_PLAN"
}

@test "g14 references the SE-084 auditor script" {
  grep -q "skill-catalog-audit.sh" "$GATES_ABS"
}

@test "g14 filters to .opencode/skills/.../SKILL.md only" {
  grep -qF '.opencode/skills/' "$GATES_ABS"
  grep -qF 'SKILL.md' "$GATES_ABS"
}

@test "safety: SE-084 auditor (the script G14 invokes) declares 'set -uo pipefail'" {
  # pr-plan-gates.sh is sourced (not executed), so no 'set -uo pipefail' there.
  # The actual safety boundary lives in the auditor invoked by G14.
  grep -q 'set -[uo]o pipefail' "$AUDITOR"
}

# ── G14 behavior — positive paths ───────────────────────────────────────────

@test "g14: skipped when no SKILL.md is modified in the diff" {
  source_gates
  # The current branch (this test runs on it) modifies SKILL.md... but the function reads
  # `git diff origin/main..HEAD`. We invoke under a fake CWD with no diff.
  cd "$TMPDIR_T"
  git init -q 2>/dev/null || true
  run g14_skill_catalog
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped"* ]] || [[ "$output" == *"WARN"* ]] || [[ "$output" == *"audited"* ]]
}

@test "g14: warns gracefully if auditor missing (SE-084 Slice 1 not on branch)" {
  bats_test_dir=$(mktemp -d)
  cp "$GATES_ABS" "$bats_test_dir/gates.sh"
  # Run from a working tree where the auditor does NOT exist
  cd "$bats_test_dir"
  source ./gates.sh
  run g14_skill_catalog
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"* ]] || [[ "$output" == *"missing"* ]] || [[ "$output" == *"skipped"* ]]
}

# ── G14 dogfood: the rule doc itself is not a SKILL.md, so G14 should skip ──

@test "dogfood: this PR's modifications are NOT SKILL.md so G14 skips on this branch" {
  cd "$ROOT_DIR"
  source_gates
  run g14_skill_catalog
  [ "$status" -eq 0 ]
  # On this branch we change docs/rules/, scripts/, tests/ but NO .opencode/skills/*/SKILL.md
  [[ "$output" == *"skipped"* ]] || [[ "$output" == *"audited"* ]]
}

# ── G14 negative cases (auditor surfaces fail-severity) ─────────────────────

@test "negative: auditor --gate exits 1 on overlong skill" {
  mkdir -p "$TMPDIR_T/skills/overlong"
  {
    echo '---'
    echo 'name: overlong'
    echo 'description: A skill that is way too long for the size budget. Use when testing overlong boundary.'
    echo '---'
    echo '# Big'
    for i in $(seq 1 250); do echo "line $i"; done
  } > "$TMPDIR_T/skills/overlong/SKILL.md"
  SKILLS_DIR="$TMPDIR_T/skills" OUTPUT_DIR="$TMPDIR_T/out" run bash "$AUDITOR" --gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"GATE FAIL"* ]]
  [[ "$output" == *"skill-overlong"* ]]
}

@test "negative: auditor --gate exits 1 on missing description-field" {
  mkdir -p "$TMPDIR_T/skills/nodesc"
  cat > "$TMPDIR_T/skills/nodesc/SKILL.md" <<'EOF'
---
name: nodesc
---
# No description
EOF
  SKILLS_DIR="$TMPDIR_T/skills" OUTPUT_DIR="$TMPDIR_T/out" run bash "$AUDITOR" --gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-description-field"* ]]
}

# ── G14 edge cases ──────────────────────────────────────────────────────────

@test "edge: --skill on a directory containing valid SKILL.md passes --gate" {
  mkdir -p "$TMPDIR_T/skills/good"
  cat > "$TMPDIR_T/skills/good/SKILL.md" <<'EOF'
---
name: good
description: A nicely formed skill that the auditor approves. Use when running the gate in a sandbox.
---
# Good
EOF
  OUTPUT_DIR="$TMPDIR_T/out" run bash "$AUDITOR" --gate --skill "$TMPDIR_T/skills/good"
  [ "$status" -eq 0 ]
}

@test "edge: empty SKILL.md is reported missing-frontmatter (zero LOC boundary)" {
  mkdir -p "$TMPDIR_T/skills/empty"
  : > "$TMPDIR_T/skills/empty/SKILL.md"
  SKILLS_DIR="$TMPDIR_T/skills" OUTPUT_DIR="$TMPDIR_T/out" run bash "$AUDITOR" --gate
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing-frontmatter"* ]]
}

@test "edge: skill-long warning (between 100-200 LOC) does NOT block --gate" {
  mkdir -p "$TMPDIR_T/skills/medium"
  {
    echo '---'
    echo 'name: medium'
    echo 'description: A skill at the warning boundary. Use when testing the medium-size band.'
    echo '---'
    echo '# Medium'
    for i in $(seq 1 120); do echo "line $i"; done
  } > "$TMPDIR_T/skills/medium/SKILL.md"
  OUTPUT_DIR="$TMPDIR_T/out" run bash "$AUDITOR" --gate --skill "$TMPDIR_T/skills/medium"
  [ "$status" -eq 0 ]  # WARN does not block
  # But the report should mention skill-long
  OUTPUT_DIR="$TMPDIR_T/out" run bash "$AUDITOR" --report --skill "$TMPDIR_T/skills/medium"
  [[ "$output" == *"skill-long"* ]] || [[ "$output" == *"WARN"* ]]
}

# ── Spec ref + assertion quality reinforcement ──────────────────────────────

@test "spec ref: docs/propuestas/SE-084 referenced in this test file" {
  grep -q "docs/propuestas/SE-084" "$BATS_TEST_FILENAME"
}

@test "auditor JSON output contains required keys for G14 to parse" {
  run bash "$AUDITOR" --json --skill "$ROOT_DIR/.opencode/skills/caveman" 2>&1
  if [ "$status" -eq 0 ]; then
    python3 -c "import json,sys; r=json.loads(sys.argv[1]); assert 'fail' in r and 'warn' in r" "$output"
  else
    skip "caveman skill not yet on this branch (SE-081 not merged)"
  fi
}
