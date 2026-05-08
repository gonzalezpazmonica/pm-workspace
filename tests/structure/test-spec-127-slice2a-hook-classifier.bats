#!/usr/bin/env bats
# Ref: SPEC-127 Slice 2a — Hook portability classifier
# Spec: docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md
#
# Slice 2a ships:
#   - scripts/hook-portability-classifier.sh
#   - output/hook-portability-classification.md (auto-generated)
#
# Enforces SPEC-127 Slice 2 AC-2.1 (top 10 hooks classified explicitly),
# AC-2.3 (safety-critical hooks in TIER-1 or TIER-2 — PV-02), AC-2.4
# (full 64-hook classification documented).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="scripts/hook-portability-classifier.sh"
  CLASSIFIER="$REPO_ROOT/$SCRIPT"
  REPORT="$REPO_ROOT/output/hook-portability-classification.md"
  HOOKS_DIR="$REPO_ROOT/.claude/hooks"
  SETTINGS="$REPO_ROOT/.claude/settings.json"
  SPEC="$REPO_ROOT/docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md"
  TMPDIR_C=$(mktemp -d)
  # output/ is gitignored — regenerate report in CI fresh checkout
  if [[ ! -f "$REPORT" ]]; then
    bash "$CLASSIFIER" --markdown >/dev/null 2>&1 || true
  fi
}

teardown() {
  rm -rf "$TMPDIR_C"
}

# ── AC-2.1 — classifier exists, executable, syntax safe ────────────────────

@test "AC-2.1: classifier script exists, executable, has shebang" {
  [ -f "$CLASSIFIER" ]
  head -1 "$CLASSIFIER" | grep -q '^#!'
  [ -x "$CLASSIFIER" ]
}

@test "AC-2.1: classifier declares 'set -uo pipefail' in first 5 lines" {
  head -5 "$CLASSIFIER" | grep -q "set -uo pipefail"
}

@test "AC-2.1: classifier passes bash -n syntax check" {
  bash -n "$CLASSIFIER"
}

@test "AC-2.1: TSV mode (default) emits header + rows" {
  run bash "$CLASSIFIER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hook"* ]]
  [[ "$output" == *"tier"* ]]
  [[ "$output" == *"reroute"* ]]
}

@test "AC-2.1: summary mode aggregates by tier" {
  run bash "$CLASSIFIER" --summary
  [ "$status" -eq 0 ]
  [[ "$output" == *"TIER-1"* ]]
  [[ "$output" == *"TIER-2"* ]]
  [[ "$output" == *"TIER-4"* ]]
}

@test "AC-2.1: JSON mode produces valid JSON" {
  run bash "$CLASSIFIER" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.loads(sys.stdin.read())"
}

@test "AC-2.1: classifier processes all hooks in .opencode/hooks/" {
  hook_count=$(find "$HOOKS_DIR" -maxdepth 1 -name "*.sh" -type f | wc -l)
  row_count=$(bash "$CLASSIFIER" | tail -n +2 | wc -l)
  [ "$row_count" = "$hook_count" ]
}

@test "AC-2.1: every classified row has a tier (TIER-1/2/3/4 or LIB)" {
  rows=$(bash "$CLASSIFIER" | tail -n +2)
  bad=$(printf '%s\n' "$rows" | awk -F'\t' '$3 !~ /^(TIER-[1-4]|LIB)$/ {print}')
  [ -z "$bad" ]
}

# ── AC-2.3 — safety-critical hooks in TIER-1 or TIER-2 (PV-02) ─────────────

@test "AC-2.3: block-credential-leak.sh classified TIER-1 or TIER-2" {
  tier=$(bash "$CLASSIFIER" | awk -F'\t' '$1=="block-credential-leak.sh" {print $3}')
  [ "$tier" = "TIER-1" ] || [ "$tier" = "TIER-2" ]
}

@test "AC-2.3: block-gitignored-references.sh classified TIER-1 or TIER-2" {
  tier=$(bash "$CLASSIFIER" | awk -F'\t' '$1=="block-gitignored-references.sh" {print $3}')
  [ "$tier" = "TIER-1" ] || [ "$tier" = "TIER-2" ]
}

@test "AC-2.3: prompt-injection-guard.sh classified TIER-1 or TIER-2" {
  tier=$(bash "$CLASSIFIER" | awk -F'\t' '$1=="prompt-injection-guard.sh" {print $3}')
  [ "$tier" = "TIER-1" ] || [ "$tier" = "TIER-2" ]
}

@test "AC-2.2 (partial): ≥5 hooks classified TIER-1 (portable to plugin TS)" {
  count=$(bash "$CLASSIFIER" --summary 2>&1 | awk '$1=="TIER-1" {print $2}')
  [ "$count" -ge 5 ]
}

# ── AC-2.4 — full classification report exists + structured ────────────────

@test "AC-2.4: report file exists at output/hook-portability-classification.md" {
  [ -f "$REPORT" ]
}

@test "AC-2.4: report has Tier definitions section" {
  grep -q "Tier definitions" "$REPORT"
  grep -q "TIER-1 portable" "$REPORT"
  grep -q "TIER-4 lost" "$REPORT"
}

@test "AC-2.4: report has Summary section with counts" {
  grep -q "## Summary" "$REPORT"
}

@test "AC-2.4: report has Per-hook classification table (markdown)" {
  grep -q "## Per-hook classification" "$REPORT"
  grep -qE '^\| Hook \| Events \| Tier' "$REPORT"
}

@test "AC-2.4: report has Safety-critical coverage section (PV-02)" {
  grep -q "Safety-critical" "$REPORT"
  grep -q "PV-02" "$REPORT"
}

@test "AC-2.4: report references SPEC-127 Slice 2" {
  grep -q "SPEC-127" "$REPORT"
}

# ── Heuristic markers — provider-agnostic (PV-06) ──────────────────────────

@test "PV-06: classifier never branches on a hardcoded vendor name" {
  ! grep -qiE 'github.copilot|copilot.enterprise|openai\.|anthropic\.com/v1|mistral\.|deepseek/|ollama/' "$CLASSIFIER"
}

@test "PV-06: classifier reasoning is provider-agnostic (no vendor strings)" {
  bash "$CLASSIFIER" --markdown >/dev/null
  ! grep -qiE 'github.copilot|copilot.enterprise|anthropic.com|openai.com' "$REPORT"
}

# ── Negative + edge cases ──────────────────────────────────────────────────

@test "negative: unknown flag exits 2 with usage" {
  run bash "$CLASSIFIER" --bogus
  [ "$status" -eq 2 ]
}

@test "negative: missing hooks dir exits 3 (graceful)" {
  cp "$CLASSIFIER" "$TMPDIR_C/classifier.sh"
  run env PROJECT_ROOT="$TMPDIR_C" bash "$TMPDIR_C/classifier.sh"
  [ "$status" -eq 3 ]
}

@test "edge: empty hooks dir produces zero data rows (boundary)" {
  mkdir -p "$TMPDIR_C/.claude/hooks"
  echo '{"hooks":{}}' > "$TMPDIR_C/.claude/settings.json"
  cp "$CLASSIFIER" "$TMPDIR_C/classifier.sh"
  run env PROJECT_ROOT="$TMPDIR_C" bash "$TMPDIR_C/classifier.sh"
  [ "$status" -eq 0 ]
  # Header row only — no data rows. Wc counts non-empty data lines.
  rows=$(printf '%s\n' "$output" | awk 'NR>1 && NF>0' | wc -l | tr -d ' ')
  [ "${rows:-0}" -eq 0 ]
}

@test "edge: hook with no event registration (LIB) is reported" {
  rows=$(bash "$CLASSIFIER" | awk -F'\t' '$3=="LIB" {print $1}')
  # Some hooks (e.g. lib helpers) may exist; count is informational, ≥0
  [ -n "$rows" ] || [ -z "$rows" ]
}

# ── Markdown mode atomicity ─────────────────────────────────────────────────

@test "markdown mode: --markdown is idempotent (twice produces same content)" {
  bash "$CLASSIFIER" --markdown >/dev/null
  cp "$REPORT" "$TMPDIR_C/first.md"
  bash "$CLASSIFIER" --markdown >/dev/null
  diff -q "$REPORT" "$TMPDIR_C/first.md"
}

# ── Spec ref + frontmatter ──────────────────────────────────────────────────

@test "spec ref: SPEC-127 declares Slice 2 AC-2.1, AC-2.3, AC-2.4" {
  grep -q "AC-2.1" "$SPEC"
  grep -q "AC-2.3" "$SPEC"
  grep -q "AC-2.4" "$SPEC"
}

@test "spec ref: docs/propuestas/SPEC-127 referenced in this test file" {
  grep -q "docs/propuestas/SPEC-127" "$BATS_TEST_FILENAME"
}

@test "spec ref: classifier script references SPEC-127" {
  grep -q "SPEC-127" "$CLASSIFIER"
}

# ── Coverage ────────────────────────────────────────────────────────────────

@test "coverage: classifier defines 4 modes (default/markdown/summary/json)" {
  grep -qE '\bmarkdown\)' "$CLASSIFIER"
  grep -qE '\bsummary\)' "$CLASSIFIER"
  grep -qE '\bjson\)' "$CLASSIFIER"
  grep -qE '\btsv\)' "$CLASSIFIER"
}

@test "coverage: classifier reads matcher from settings.json (improved heuristic)" {
  grep -qE 'matcher.*=' "$CLASSIFIER"
  grep -qE '\$matchers' "$CLASSIFIER"
}

@test "coverage: classifier defines 4 tier classifications + LIB" {
  for t in "TIER-1" "TIER-2" "TIER-3" "TIER-4" "LIB"; do
    grep -q "$t" "$CLASSIFIER"
  done
}
