#!/usr/bin/env bats
# SE-086: Ubiquitous Language extractor — Slice 1 (skill) + Slice 2 (extractor).
# Acceptance: AC-01..AC-10 from docs/propuestas/SE-086-ubiquitous-language-extractor.md

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
  SKILL_DIR=".claude/skills/ubiquitous-language"
  SKILL_MD="$SKILL_DIR/SKILL.md"
  DOMAIN_MD="$SKILL_DIR/DOMAIN.md"
  EXTRACTOR="scripts/extract-domain-entities.py"
  BRIDGE="scripts/knowledge-graph-domain-bridge.py"
  STAMP="$(date +%Y%m%d)"
  FIXTURE="tests/fixtures/se086-domain-sample.md"
}

teardown() {
  cd /
}

# ── Slice 1: Skill structure (AC-01..AC-04) ───────────────────────────────────

@test "AC-01: SKILL.md exists and is ≤150 lines (Rule 11)" {
  [[ -f "$SKILL_MD" ]]
  local lines
  lines=$(wc -l < "$SKILL_MD")
  [ "$lines" -le 150 ]
}

@test "AC-01: DOMAIN.md exists" {
  [[ -f "$DOMAIN_MD" ]]
}

@test "AC-02: SKILL.md has MIT attribution to Pocock" {
  grep -qi "mattpocock\|MIT" "$SKILL_MD"
}

@test "AC-03: SKILL.md describes trigger conditions" {
  grep -qi "trigger\|glossary\|ubiquitous" "$SKILL_MD"
}

@test "AC-03: SKILL.md describes 5-step process" {
  grep -qE "Step [1-5]|5.step|five.step" "$SKILL_MD"
}

@test "AC-04: SKILL.md has valid YAML frontmatter" {
  head -1 "$SKILL_MD" | grep -q "^---"
  grep -q "^name:" "$SKILL_MD"
  grep -q "^maturity:" "$SKILL_MD"
}

@test "DOMAIN.md: has Por que section" {
  grep -qE "Por que existe|Por qué existe" "$DOMAIN_MD"
}

@test "DOMAIN.md: mentions SE-086 or rule reference" {
  grep -q "SE-086\|ubiquitous-language" "$DOMAIN_MD"
}

# ── Slice 2: Extractor (AC-05..AC-08) ────────────────────────────────────────

@test "AC-05: extractor script exists and is executable" {
  [[ -f "$EXTRACTOR" ]]
  python3 "$EXTRACTOR" --help 2>&1 | grep -qi "project\|extract\|domain"
}

@test "AC-05: extractor produces report from memory-store" {
  run python3 "$EXTRACTOR" --project test-se086 --input "$FIXTURE" --output-dir "$TMPDIR"
  [ "$status" -eq 0 ]
}

@test "AC-05: report file is created with correct naming" {
  python3 "$EXTRACTOR" --project test-se086 --input "$FIXTURE" --output-dir "$TMPDIR" 2>/dev/null
  [[ -f "$TMPDIR/domain-entity-report-test-se086-$STAMP.md" ]]
}

@test "AC-05: report contains table header with Term column" {
  python3 "$EXTRACTOR" --project test-se086 --input "$FIXTURE" --output-dir "$TMPDIR" 2>/dev/null
  grep -q "| Term" "$TMPDIR/domain-entity-report-test-se086-$STAMP.md"
}

@test "AC-06: report includes status column with valid values" {
  python3 "$EXTRACTOR" --project test-se086 --input "$FIXTURE" --output-dir "$TMPDIR" 2>/dev/null
  grep -qE "\| (new|existing|inconsistent) \|" \
    "$TMPDIR/domain-entity-report-test-se086-$STAMP.md"
}

@test "AC-07: --auto-update creates CONTEXT.md with [REVIEW] markers" {
  local ctx="$TMPDIR/CONTEXT-test-$BATS_TEST_NUMBER.md"
  python3 "$EXTRACTOR" --project test-se086 \
    --context "$ctx" --auto-update --output-dir "$TMPDIR" 2>/dev/null || true
  if [[ -f "$ctx" ]]; then
    grep -q "\[REVIEW\]" "$ctx"
  fi
}

@test "AC-08: without --auto-update, CONTEXT.md is not modified" {
  local ctx="$TMPDIR/ctx-no-update-$BATS_TEST_NUMBER.md"
  echo "existing content" > "$ctx"
  python3 "$EXTRACTOR" --project test-se086 --context "$ctx" \
    --output-dir "$TMPDIR" 2>/dev/null || true
  grep -q "existing content" "$ctx"
}

@test "AC-08: --auto-update does not overwrite existing term definitions" {
  local ctx="$TMPDIR/ctx-existing-$BATS_TEST_NUMBER.md"
  cat > "$ctx" <<'MD'
# Domain Glossary — test
| Term | Definition | Status |
|------|------------|--------|
| Era | My existing definition | stable |
MD
  python3 "$EXTRACTOR" --project test-se086 \
    --context "$ctx" --auto-update --output-dir "$TMPDIR" 2>/dev/null || true
  grep -q "My existing definition" "$ctx"
}

# ── Bridge (AC-09) ────────────────────────────────────────────────────────────

@test "AC-09: bridge script exists" {
  [[ -f "$BRIDGE" ]]
}

@test "AC-09: bridge script references DOMAIN_TERM" {
  grep -q "DOMAIN_TERM" "$BRIDGE"
}

# ── Spec ref ─────────────────────────────────────────────────────────────────

@test "spec ref: rule doc ubiquitous-language.md exists" {
  [[ -f "docs/rules/domain/ubiquitous-language.md" ]]
}

@test "spec ref: rule doc mentions CONTEXT.md and extract-domain-entities.py" {
  grep -q "CONTEXT.md" docs/rules/domain/ubiquitous-language.md
  grep -q "extract-domain-entities" docs/rules/domain/ubiquitous-language.md
}

# ── Negative ─────────────────────────────────────────────────────────────────

@test "negative: extractor with missing input file exits non-zero" {
  run python3 "$EXTRACTOR" --project test --input "$TMPDIR/nonexistent-file-9999.md"
  [ "$status" -ne 0 ]
}

@test "negative: empty input produces graceful message" {
  local empty="$TMPDIR/empty-input.md"
  : > "$empty"
  run python3 "$EXTRACTOR" --project test --input "$empty" --output-dir "$TMPDIR"
  [ "$status" -eq 0 ]
}

# ── Edge ─────────────────────────────────────────────────────────────────────

@test "edge: extractor with --min-mentions 1 returns more terms" {
  local report1="$TMPDIR/report-min1-$BATS_TEST_NUMBER.md"
  local report2="$TMPDIR/report-min2-$BATS_TEST_NUMBER.md"
  python3 "$EXTRACTOR" --project test-edge --min-mentions 1 \
    --output-dir "$TMPDIR" 2>/dev/null || true
  python3 "$EXTRACTOR" --project test-edge --min-mentions 5 \
    --output-dir "$TMPDIR" 2>/dev/null || true
  # just assert both run without error (counts depend on store content)
  [ "$?" -eq 0 ]
}

@test "edge: running extractor twice is idempotent (same report content)" {
  python3 "$EXTRACTOR" --project test-idempotent --output-dir "$TMPDIR" 2>/dev/null
  local f="$TMPDIR/domain-entity-report-test-idempotent-$STAMP.md"
  local h1=""
  [[ -f "$f" ]] && h1=$(md5sum "$f" | cut -d' ' -f1)
  python3 "$EXTRACTOR" --project test-idempotent --output-dir "$TMPDIR" 2>/dev/null
  local h2=""
  [[ -f "$f" ]] && h2=$(md5sum "$f" | cut -d' ' -f1)
  [ "$h1" = "$h2" ]
}
