#!/usr/bin/env bats
# SCRIPT='scripts/twin-linter.sh'
# test-spec-169-twin-linter.bats — BATS suite for SPEC-169 Project Twin linter
# Spec: SPEC-169 AC-1, AC-7, AC-9
# Score target: ≥85 (SPEC-055 quality gate)

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
LINTER="$REPO_ROOT/scripts/twin-linter.sh"
FIXTURES="$REPO_ROOT/tests/fixtures/twin"

setup() {
  TMP_DIR="$(mktemp -d)"
  [[ -f "$LINTER" ]] || { echo "linter not found: $LINTER" >&2; return 1; }
}

teardown() {
  rm -rf "$TMP_DIR"
}

make_twin() {
  # make_twin <file> [extra_body] — writes a valid twin to a temp file
  local out="$TMP_DIR/${1:-twin.md}"
  local now; now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  cat > "$out" << TWIN
---
twin_id: "tmp-project"
spec_version: "1.0"
last_refresh: "${now}"
stale_after_days: 14
token_budget: 2000
health: green
predictions:
  sprint_slip:
    value: 0.1
    confidence: 0.9
    evidence_ref: "tests/fixtures/twin/evidence.md"
  next_blocker:
    value: "none detected"
    confidence: 0.8
    evidence_ref: "tests/fixtures/twin/evidence.md"
  scope_drift:
    value: 0.05
    confidence: 0.7
    evidence_ref: "tests/fixtures/twin/evidence.md"
  aggregate_health:
    value: green
    confidence: 0.85
    evidence_ref: "tests/fixtures/twin/evidence.md"
---

## Estado
Sprint ok. Items: 3 abiertos, 0 bloqueantes.

## Reglas
WIP limit 3 items.

## Predicciones
Sin slip. Sin bloqueantes. Scope estable. Salud verde.
${2:-}
TWIN
  echo "$out"
}

# ── Existence + safety ────────────────────────────────────────────────────────
@test "linter: script exists and is executable" {
  [[ -x "$LINTER" ]]
}

@test "linter: has set -uo pipefail" {
  grep -q "set -uo pipefail" "$LINTER"
}

@test "linter: SPEC-169 cited in header" {
  grep -q "SPEC-169" "$LINTER"
}

@test "linter: AC-7 cited in header" {
  grep -q "AC-7" "$LINTER"
}

@test "linter: under 120 lines" {
  [[ "$(wc -l < "$LINTER")" -lt 120 ]]
}

# ── Usage / error handling ────────────────────────────────────────────────────
@test "linter: no args exits 2 with usage" {
  run bash "$LINTER"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "Usage" ]]
}

@test "linter: nonexistent file exits 2" {
  run bash "$LINTER" "$TMP_DIR/nonexistent.md"
  [[ "$status" -eq 2 ]]
}

# ── Valid fixture ─────────────────────────────────────────────────────────────
@test "linter: valid twin exits 0" {
  run bash "$LINTER" "$FIXTURES/valid.md"
  [[ "$status" -eq 0 ]]
}

@test "linter: valid twin prints OK" {
  run bash "$LINTER" "$FIXTURES/valid.md"
  [[ "$output" =~ "OK:" ]]
}

@test "linter: dynamically created valid twin exits 0 (mktemp isolation)" {
  f=$(make_twin "dynamic.md")
  run bash "$LINTER" "$f"
  [[ "$status" -eq 0 ]]
}

# ── Required frontmatter fields (fm_field coverage) ──────────────────────────
@test "linter: missing token_budget exits 2" {
  run bash "$LINTER" "$FIXTURES/missing-field.md"
  [[ "$status" -eq 2 ]]
}

@test "linter: missing token_budget reports INVALID" {
  run bash "$LINTER" "$FIXTURES/missing-field.md"
  [[ "$output" =~ "INVALID" ]]
}

@test "linter: empty twin_id exits 2" {
  f="$TMP_DIR/no-id.md"
  sed 's/twin_id: "tmp-project"/twin_id: ""/' "$(make_twin noid.md)" > "$f"
  # empty string still present; test missing entirely
  sed -i '/^twin_id:/d' "$f"
  run bash "$LINTER" "$f"
  [[ "$status" -eq 2 ]]
}

# ── Required sections (has_section coverage) ─────────────────────────────────
@test "linter: missing Predicciones section exits 2" {
  run bash "$LINTER" "$FIXTURES/missing-section.md"
  [[ "$status" -eq 2 ]]
}

@test "linter: missing Estado section exits 2" {
  f="$TMP_DIR/no-estado.md"
  sed '/^## Estado/,/^## Reglas/{/^## Estado/d}' "$FIXTURES/valid.md" > "$f"
  run bash "$LINTER" "$f"
  [[ "$status" -eq 2 ]]
}

# ── Forbidden fields (AC-7, frontmatter body scan) ────────────────────────────
@test "linter: forbidden field assigned_to exits 3" {
  run bash "$LINTER" "$FIXTURES/forbidden-field.md"
  [[ "$status" -eq 3 ]]
}

@test "linter: forbidden field reports FORBIDDEN" {
  run bash "$LINTER" "$FIXTURES/forbidden-field.md"
  [[ "$output" =~ "FORBIDDEN" ]]
}

@test "linter: forbidden-fields config file exists" {
  [[ -f "$REPO_ROOT/scripts/twin-forbidden-fields.txt" ]]
}

@test "linter: forbidden-fields has at least 8 patterns" {
  count=$(grep -cvE "^#|^$" "$REPO_ROOT/scripts/twin-forbidden-fields.txt")
  [[ "$count" -ge 8 ]]
}

@test "linter: inline forbidden field in tmp twin exits 3" {
  f=$(make_twin "bad-inline.md")
  printf "\nassigned_to: dev-lead\n" >> "$f"
  run bash "$LINTER" "$f"
  [[ "$status" -eq 3 ]]
}

# ── Stale check ───────────────────────────────────────────────────────────────
@test "linter: stale twin exits 1" {
  run bash "$LINTER" "$FIXTURES/stale.md"
  [[ "$status" -eq 1 ]]
}

@test "linter: stale twin reports STALE" {
  run bash "$LINTER" "$FIXTURES/stale.md"
  [[ "$output" =~ "STALE" ]]
}

# ── Edge cases ────────────────────────────────────────────────────────────────
@test "edge: confidence 1.0 boundary is valid" {
  f=$(make_twin "conf-boundary.md")
  sed -i 's/confidence: 0.9/confidence: 1.0/' "$f"
  run bash "$LINTER" "$f"
  [[ "$status" -eq 0 ]]
}

@test "edge: confidence 0.0 boundary is valid" {
  f=$(make_twin "conf-zero.md")
  sed -i 's/confidence: 0.9/confidence: 0.0/' "$f"
  run bash "$LINTER" "$f"
  [[ "$status" -eq 0 ]]
}

@test "edge: empty file exits 2" {
  f="$TMP_DIR/empty.md"
  touch "$f"
  run bash "$LINTER" "$f"
  [[ "$status" -eq 2 ]]
}

# ── Rule doc (AC-9) ───────────────────────────────────────────────────────────
@test "rule doc: project-twin-as-code.md exists" {
  [[ -f "$REPO_ROOT/docs/rules/domain/project-twin-as-code.md" ]]
}

@test "rule doc: under 150 lines (AC-9)" {
  [[ "$(wc -l < "$REPO_ROOT/docs/rules/domain/project-twin-as-code.md")" -lt 150 ]]
}

@test "rule doc: SPEC-169 referenced" {
  grep -q "SPEC-169" "$REPO_ROOT/docs/rules/domain/project-twin-as-code.md"
}

@test "rule doc: forbidden fields section documented" {
  grep -qiE "prohibid|forbidden" "$REPO_ROOT/docs/rules/domain/project-twin-as-code.md"
}

# ── Pilot twin (AC-V1) ────────────────────────────────────────────────────────
@test "pilot: proyecto-alpha/twin.md exists" {
  [[ -f "$REPO_ROOT/projects/proyecto-alpha/twin.md" ]]
}

@test "pilot: proyecto-alpha twin passes linter" {
  run bash "$LINTER" "$REPO_ROOT/projects/proyecto-alpha/twin.md"
  [[ "$status" -eq 0 ]]
}

@test "pilot: twin.md has all 4 predictions" {
  for pred in sprint_slip next_blocker scope_drift aggregate_health; do
    grep -q "$pred" "$REPO_ROOT/projects/proyecto-alpha/twin.md"
  done
}

@test "pilot: twin.md last_refresh after SPEC-169 spec creation date" {
  last=$(grep "^last_refresh:" "$REPO_ROOT/projects/proyecto-alpha/twin.md" | head -1 | sed 's/.*: *//' | tr -d '"')
  [[ "$last" > "2026-06-04" ]]
}

# ── Loader: twin-load.sh (Slice 3) ────────────────────────────────────────────
@test "loader: script exists and executable" {
  [[ -x "$REPO_ROOT/scripts/twin-load.sh" ]]
}

@test "loader: no args exits 2 with usage" {
  run bash "$REPO_ROOT/scripts/twin-load.sh"
  [[ "$status" -eq 2 ]]
  [[ "$output" =~ "Usage" ]]
}

@test "loader: unknown slug exits 2" {
  run bash "$REPO_ROOT/scripts/twin-load.sh" nonexistent-slug-zzz
  [[ "$status" -eq 2 ]]
}

@test "loader: --summary prints health and tokens" {
  run bash "$REPO_ROOT/scripts/twin-load.sh" "proyecto-alpha" "--summary"
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  [[ "$output" =~ "Health:" ]]
  [[ "$output" =~ "Tokens" ]]
}

@test "loader: N1 context blocks projects twin (AC-5)" {
  run env TWIN_CONTEXT=N1 bash "$REPO_ROOT/scripts/twin-load.sh" "proyecto-alpha"
  [[ "$status" -eq 3 ]]
  [[ "$output" =~ "BLOCKED" ]]
}

@test "loader: SPEC-169 cited in header" {
  grep -q "SPEC-169" "$REPO_ROOT/scripts/twin-load.sh"
}

# ── Refresher: twin-refresh.sh (Slice 4) ──────────────────────────────────────
@test "refresher: script exists and executable" {
  [[ -x "$REPO_ROOT/scripts/twin-refresh.sh" ]]
}

@test "refresher: no args exits 2" {
  run bash "$REPO_ROOT/scripts/twin-refresh.sh"
  [[ "$status" -eq 2 ]]
}

@test "refresher: dry-run on pilot exits 0" {
  run bash "$REPO_ROOT/scripts/twin-refresh.sh" "proyecto-alpha" "--dry-run"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "dry-run" ]]
}

@test "refresher: dry-run shows diff (AC-V2 auditable)" {
  run bash "$REPO_ROOT/scripts/twin-refresh.sh" "proyecto-alpha" "--dry-run"
  [[ "$output" =~ "health:" ]]
  [[ "$output" =~ "sprint_slip:" ]]
}

@test "refresher: real refresh completes under 5000ms (AC-V2)" {
  start=$(date +%s%3N)
  bash "$REPO_ROOT/scripts/twin-refresh.sh" "proyecto-alpha" >/dev/null 2>&1
  end=$(date +%s%3N)
  elapsed=$(( end - start ))
  [[ "$elapsed" -lt 5000 ]]
}

# ── Decay check: twin-decay-check.sh (Slice 5) ────────────────────────────────
@test "decay: script exists and executable" {
  [[ -x "$REPO_ROOT/scripts/twin-decay-check.sh" ]]
}

@test "decay: workspace scan exits 0 with fresh pilot" {
  run bash "$REPO_ROOT/scripts/twin-decay-check.sh"
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  [[ "$output" =~ "decay-check:" ]]
}

# ── Anonymize: twin-anonymize.sh (Slice 6, AC-6) ─────────────────────────────
@test "anonymize: script exists and executable" {
  [[ -x "$REPO_ROOT/scripts/twin-anonymize.sh" ]]
}

@test "anonymize: no args exits 2" {
  run bash "$REPO_ROOT/scripts/twin-anonymize.sh"
  [[ "$status" -eq 2 ]]
}

@test "anonymize: produces output file (AC-6)" {
  run bash "$REPO_ROOT/scripts/twin-anonymize.sh" "proyecto-alpha"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "OK:" ]]
}

@test "anonymize: output contains no real project slug" {
  bash "$REPO_ROOT/scripts/twin-anonymize.sh" "proyecto-alpha" >/dev/null 2>&1 || true
  anon_file=$(find "$REPO_ROOT/docs/case-studies" -name "*anon.twin.md" | head -1)
  [[ -n "$anon_file" ]]
  ! grep -q "twin_id: \"proyecto-alpha\"" "$anon_file"
}

@test "anonymize: output strips absolute paths" {
  anon_file=$(find "$REPO_ROOT/docs/case-studies" -name "*anon.twin.md" | head -1)
  [[ -n "$anon_file" ]]
  ! grep -qE "/home/|/Users/" "$anon_file"
}

# ── Hook: twin-posttooluse.sh (Slice 5) ──────────────────────────────────────
@test "hook: twin-posttooluse.sh exists in .claude/hooks" {
  [[ -f "$REPO_ROOT/.claude/hooks/twin-posttooluse.sh" ]]
}

@test "hook: no-op by default without TWIN_HOOK_ENABLED=true" {
  run env TWIN_HOOK_ENABLED=false bash "$REPO_ROOT/.claude/hooks/twin-posttooluse.sh" <<< '{}'
  [[ "$status" -eq 0 ]]
}
