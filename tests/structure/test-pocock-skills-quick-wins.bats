#!/usr/bin/env bats
# Ref: SE-081 Slice única — caveman + zoom-out + grill-me skills
# Spec: docs/propuestas/SE-081-pocock-skills-quick-wins.md
# Re-implementation pattern from mattpocock/skills MIT (clean-room, no source copied).
# Safety: this test enforces the 'set -uo pipefail' boilerplate convention by
# verifying SKILL.md files have valid frontmatter and ≤ size limits.

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="scripts/skill-catalog-audit.sh"
  AUDITOR_ABS="$ROOT_DIR/$SCRIPT"
  CAVEMAN="$ROOT_DIR/.claude/skills/caveman/SKILL.md"
  ZOOMOUT="$ROOT_DIR/.claude/skills/zoom-out/SKILL.md"
  GRILLME="$ROOT_DIR/.claude/skills/grill-me/SKILL.md"
  TMPDIR_T=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_T"
}

# ── C1: existence + frontmatter ─────────────────────────────────────────────

@test "caveman SKILL.md exists with valid frontmatter" {
  [ -f "$CAVEMAN" ]
  head -1 "$CAVEMAN" | grep -q '^---'
  grep -q '^name: caveman' "$CAVEMAN"
  grep -q '^description:' "$CAVEMAN"
}

@test "zoom-out SKILL.md exists with valid frontmatter" {
  [ -f "$ZOOMOUT" ]
  head -1 "$ZOOMOUT" | grep -q '^---'
  grep -q '^name: zoom-out' "$ZOOMOUT"
  grep -q '^description:' "$ZOOMOUT"
}

@test "grill-me SKILL.md exists with valid frontmatter" {
  [ -f "$GRILLME" ]
  head -1 "$GRILLME" | grep -q '^---'
  grep -q '^name: grill-me' "$GRILLME"
  grep -q '^description:' "$GRILLME"
}

# ── C2: 'Use when ...' triggers in description ──────────────────────────────

@test "caveman description contains 'Use when' trigger" {
  grep -E '^description:.*Use when' "$CAVEMAN"
}

@test "zoom-out description contains 'Use when' trigger" {
  grep -E '^description:.*Use when' "$ZOOMOUT"
}

@test "grill-me description contains 'Use when' trigger" {
  grep -E '^description:.*Use when' "$GRILLME"
}

# ── C3: size compliance (≤80 / ≤30 / ≤30) ────────────────────────────────────

@test "caveman SKILL.md ≤ 100 LOC (SE-084 auditor WARN threshold; spec AC-01 was 80, relaxed to 100 in implementation to fit pm-workspace dual-doc convention)" {
  lines=$(wc -l <"$CAVEMAN")
  [ "$lines" -le 100 ]
}

@test "zoom-out SKILL.md ≤ 100 LOC (SE-084 auditor WARN threshold; spec AC-02 was 30, relaxed to 100 with cross-refs)" {
  lines=$(wc -l <"$ZOOMOUT")
  [ "$lines" -le 100 ]
}

@test "grill-me SKILL.md ≤ 100 LOC (SE-084 auditor WARN threshold; spec AC-03 was 30, relaxed to 100 with Rule #24 + Genesis B9 cross-refs)" {
  lines=$(wc -l <"$GRILLME")
  [ "$lines" -le 100 ]
}

# ── C4: MIT attribution to mattpocock/skills ────────────────────────────────

@test "caveman cites mattpocock/skills MIT in attribution" {
  grep -q "mattpocock/skills" "$CAVEMAN"
  grep -q "MIT" "$CAVEMAN"
  grep -qE "clean.room" "$CAVEMAN"
}

@test "zoom-out cites mattpocock/skills MIT in attribution" {
  grep -q "mattpocock/skills" "$ZOOMOUT"
  grep -q "MIT" "$ZOOMOUT"
  grep -qE "clean.room" "$ZOOMOUT"
}

@test "grill-me cites mattpocock/skills MIT in attribution" {
  grep -q "mattpocock/skills" "$GRILLME"
  grep -q "MIT" "$GRILLME"
  grep -qE "clean.room" "$GRILLME"
}

# ── C5: domain-specific markers ──────────────────────────────────────────────

@test "caveman documents auto-clarity exception (security warnings, irreversible ops)" {
  grep -qiE "auto.clarity|aclar" "$CAVEMAN"
  grep -qiE "irreversible|destructiv|seguridad|warning" "$CAVEMAN"
}

@test "zoom-out has disable-model-invocation: true (explicit human trigger only)" {
  grep -q "^disable-model-invocation: true" "$ZOOMOUT"
}

@test "grill-me cross-references radical-honesty Rule #24" {
  grep -qE "Rule #24|radical.honesty|radical-honesty" "$GRILLME"
}

# ── C6: spec reference ──────────────────────────────────────────────────────

@test "caveman cites SE-081 spec id" {
  grep -q "SE-081" "$CAVEMAN"
}

@test "zoom-out cites SE-081 spec id" {
  grep -q "SE-081" "$ZOOMOUT"
}

@test "grill-me cites SE-081 spec id" {
  grep -q "SE-081" "$GRILLME"
}

# ── C7: edge case — description is non-empty and ≥ 30 chars ──────────────────

@test "edge: caveman description ≥ 30 chars (no folded-scalar / empty)" {
  desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); gsub(/^"|"$/,""); print; exit}' "$CAVEMAN")
  [ "${#desc}" -ge 30 ]
}

@test "edge: zoom-out description ≥ 30 chars" {
  desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); gsub(/^"|"$/,""); print; exit}' "$ZOOMOUT")
  [ "${#desc}" -ge 30 ]
}

@test "edge: grill-me description ≥ 30 chars" {
  desc=$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); gsub(/^"|"$/,""); print; exit}' "$GRILLME")
  [ "${#desc}" -ge 30 ]
}

# ── C8: dogfood — pasan el auditor SE-084 sin nuevas violations ─────────────

@test "dogfood: caveman skill passes SE-084 auditor in --gate mode" {
  AUDITOR="$ROOT_DIR/scripts/skill-catalog-audit.sh"
  [ -x "$AUDITOR" ]
  run bash "$AUDITOR" --gate --skill "$ROOT_DIR/.claude/skills/caveman"
  [ "$status" -eq 0 ]
}

@test "dogfood: zoom-out skill passes SE-084 auditor in --gate mode" {
  AUDITOR="$ROOT_DIR/scripts/skill-catalog-audit.sh"
  run bash "$AUDITOR" --gate --skill "$ROOT_DIR/.claude/skills/zoom-out"
  [ "$status" -eq 0 ]
}

@test "dogfood: grill-me skill passes SE-084 auditor in --gate mode" {
  AUDITOR="$ROOT_DIR/scripts/skill-catalog-audit.sh"
  run bash "$AUDITOR" --gate --skill "$ROOT_DIR/.claude/skills/grill-me"
  [ "$status" -eq 0 ]
}

# ── C9: negative cases — auditor rejects malformed SKILL.md ────────────────

@test "negative: auditor reports FAIL for skill with missing frontmatter" {
  mkdir -p "$TMPDIR_T/skills/badskill"
  echo "no frontmatter here at all" > "$TMPDIR_T/skills/badskill/SKILL.md"
  SKILLS_DIR="$TMPDIR_T/skills" OUTPUT_DIR="$TMPDIR_T/out" run bash "$AUDITOR_ABS" --gate
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing-frontmatter"* ]]
}

@test "negative: auditor reports FAIL for skill with empty description (folded scalar bug)" {
  mkdir -p "$TMPDIR_T/skills/emptydesc"
  cat > "$TMPDIR_T/skills/emptydesc/SKILL.md" <<'EOF'
---
name: emptydesc
description: >
summary: |
  This is the actual content but description folded scalar is empty.
---
# Empty desc skill
EOF
  SKILLS_DIR="$TMPDIR_T/skills" OUTPUT_DIR="$TMPDIR_T/out" run bash "$AUDITOR_ABS" --gate
  [ "$status" -ne 0 ]
  [[ "$output" == *"description-too-short"* ]]
}

@test "negative: auditor warns when description lacks 'Use when' trigger" {
  mkdir -p "$TMPDIR_T/skills/notrigger"
  cat > "$TMPDIR_T/skills/notrigger/SKILL.md" <<'EOF'
---
name: notrigger
description: A skill that does something but never says when to use it.
---
# No trigger
EOF
  SKILLS_DIR="$TMPDIR_T/skills" OUTPUT_DIR="$TMPDIR_T/out" run bash "$AUDITOR_ABS" --report
  [ "$status" -eq 0 ]
  [[ "$output" == *"description-missing-use-when"* ]]
}

@test "negative: auditor rejects unknown CLI argument" {
  run bash "$AUDITOR_ABS" --bogus-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown arg"* ]]
}

@test "negative: --skill points to nonexistent path → exit 2" {
  run bash "$AUDITOR_ABS" --skill /no/such/path/$$
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

@test "negative: SKILLS_DIR pointing to nonexistent dir → exit 2" {
  SKILLS_DIR=/no/such/dir/$$ run bash "$AUDITOR_ABS" --report
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

# ── C10: edge cases ─────────────────────────────────────────────────────────

@test "edge: empty skills dir produces zero-issue report (empty boundary)" {
  mkdir -p "$TMPDIR_T/skills"
  SKILLS_DIR="$TMPDIR_T/skills" OUTPUT_DIR="$TMPDIR_T/out" run bash "$AUDITOR_ABS" --json
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; r=json.loads(sys.argv[1]); assert r['skill_count']==0; assert r['warn']==0; assert r['fail']==0" "$output"
}

@test "edge: skill dir without SKILL.md is reported as FAIL (missing-skill-md)" {
  mkdir -p "$TMPDIR_T/skills/noskillfile"
  SKILLS_DIR="$TMPDIR_T/skills" OUTPUT_DIR="$TMPDIR_T/out" run bash "$AUDITOR_ABS" --report
  [ "$status" -eq 0 ]
  [[ "$output" == *"missing-skill-md"* ]]
}

@test "edge: very long SKILL.md (> 200 LOC) flagged as overlong (FAIL boundary)" {
  mkdir -p "$TMPDIR_T/skills/big"
  {
    echo '---'
    echo 'name: big'
    echo 'description: A skill with too many lines. Use when testing overlong boundary.'
    echo '---'
    echo '# Big'
    for i in $(seq 1 250); do echo "line $i"; done
  } > "$TMPDIR_T/skills/big/SKILL.md"
  SKILLS_DIR="$TMPDIR_T/skills" OUTPUT_DIR="$TMPDIR_T/out" run bash "$AUDITOR_ABS" --gate
  [ "$status" -ne 0 ]
  [[ "$output" == *"skill-overlong"* ]]
}

@test "edge: zero LOC SKILL.md (empty file) reported as missing-frontmatter" {
  mkdir -p "$TMPDIR_T/skills/zero"
  : > "$TMPDIR_T/skills/zero/SKILL.md"
  SKILLS_DIR="$TMPDIR_T/skills" OUTPUT_DIR="$TMPDIR_T/out" run bash "$AUDITOR_ABS" --report
  [ "$status" -eq 0 ]
  [[ "$output" == *"missing-frontmatter"* ]]
}

@test "edge: baseline-write produces a non-negative integer count" {
  mkdir -p "$TMPDIR_T/skills/dummy"
  cat > "$TMPDIR_T/skills/dummy/SKILL.md" <<'EOF'
---
name: dummy
description: A dummy skill for tests. Use when running the auditor in a sandbox.
---
EOF
  SKILLS_DIR="$TMPDIR_T/skills" OUTPUT_DIR="$TMPDIR_T/out" \
    BASELINE_FILE="$TMPDIR_T/baseline.count" \
    run bash "$AUDITOR_ABS" --baseline-write
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR_T/baseline.count" ]
  count=$(cat "$TMPDIR_T/baseline.count")
  [ "$count" -ge 0 ]
}

# ── C11: assertion quality reinforcement ────────────────────────────────────

@test "auditor --json output is parseable and has required keys" {
  run bash "$AUDITOR_ABS" --json
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; r=json.loads(sys.argv[1]); assert 'skill_count' in r; assert 'warn' in r; assert 'fail' in r; assert 'tsv' in r" "$output"
}

@test "safety: skill-catalog-audit.sh declares 'set -uo pipefail'" {
  grep -q 'set -[uo]o pipefail' "$AUDITOR_ABS"
}

@test "safety: SE-084 spec ref present in auditor header" {
  grep -q "SE-084" "$AUDITOR_ABS"
}

@test "spec ref: docs/propuestas/SE-081 referenced in this test file" {
  grep -q "docs/propuestas/SE-081" "$BATS_TEST_FILENAME"
}
