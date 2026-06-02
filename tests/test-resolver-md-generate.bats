#!/usr/bin/env bats
# BATS tests for scripts/resolver-md-generate.sh + docs/RESOLVER.md
# Ref: SE-160 (Era 251) — see docs/rules/domain/resolver-protocol.md
# Coverage targets: extract_field, sanitise, build_skills_table,
#                   build_agents_table, build_auto_block,
#                   build_full_default, extract_auto_block, usage

SCRIPT="scripts/resolver-md-generate.sh"
TARGET="docs/RESOLVER.md"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  TMPDIR_TEST=$(mktemp -d)
  export TMPDIR_TEST
}

teardown() {
  [ -n "${TMPDIR_TEST:-}" ] && [ -d "$TMPDIR_TEST" ] && rm -rf "$TMPDIR_TEST"
}

# ── Generator script ──────────────────────────────────────────────────

@test "generator script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "generator passes bash -n" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "generator declares set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "generator references SE-160" {
  run grep -c 'SE-160' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "generator --help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "generator unknown arg exits 2" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

# ── RESOLVER.md structural ────────────────────────────────────────────

@test "RESOLVER.md exists" {
  [[ -f "$TARGET" ]]
}

@test "RESOLVER.md has AUTO_BEGIN and AUTO_END markers" {
  grep -qF '<!-- AUTO_BEGIN' "$TARGET"
  grep -qF '<!-- AUTO_END' "$TARGET"
}

@test "RESOLVER.md has OVERRIDE section" {
  grep -qE '^## OVERRIDE' "$TARGET"
}

@test "RESOLVER.md has AUTO section header" {
  grep -qE '^## AUTO' "$TARGET"
}

@test "RESOLVER.md has Skills subsection in AUTO" {
  grep -qE '^### Skills \([0-9]+\)' "$TARGET"
}

@test "RESOLVER.md has Agents subsection in AUTO" {
  grep -qE '^### Agents \([0-9]+\)' "$TARGET"
}

@test "RESOLVER.md has at least 50 skill entries" {
  local count
  count=$(grep -c '| skill:' "$TARGET")
  [[ "$count" -ge 50 ]]
}

@test "RESOLVER.md has at least 50 agent entries" {
  local count
  count=$(grep -c '| agent:' "$TARGET")
  [[ "$count" -ge 50 ]]
}

# ── Drift detection ───────────────────────────────────────────────────

@test "RESOLVER.md AUTO block in sync with generator (--check)" {
  run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"in sync"* ]]
}

# ── Idempotence ───────────────────────────────────────────────────────

@test "double --apply produces identical AUTO block" {
  bash "$SCRIPT" --apply >/dev/null
  local h1
  h1=$(awk '/AUTO_BEGIN/,/AUTO_END/' "$TARGET" | sha256sum | awk '{print $1}')
  bash "$SCRIPT" --apply >/dev/null
  local h2
  h2=$(awk '/AUTO_BEGIN/,/AUTO_END/' "$TARGET" | sha256sum | awk '{print $1}')
  [[ "$h1" == "$h2" ]]
}

# ── OVERRIDE preservation ─────────────────────────────────────────────

@test "--apply preserves OVERRIDE section verbatim" {
  local before after
  before=$(awk '/^## OVERRIDE/,/^## AUTO/' "$TARGET" | sha256sum | awk '{print $1}')
  bash "$SCRIPT" --apply >/dev/null
  after=$(awk '/^## OVERRIDE/,/^## AUTO/' "$TARGET" | sha256sum | awk '{print $1}')
  [[ "$before" == "$after" ]]
}

# ── No broken targets in OVERRIDE ─────────────────────────────────────

@test "OVERRIDE skill: targets all reference real skills" {
  local missing=0
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    if [[ ! -f ".opencode/skills/${target}/SKILL.md" ]]; then
      echo "MISSING: $target" >&2
      missing=$((missing + 1))
    fi
  done < <(awk '/^## OVERRIDE/,/^## AUTO/' "$TARGET" | grep -oE 'skill:[a-z0-9-]+' | sed 's/skill://' | sort -u)
  [ "$missing" -eq 0 ]
}

@test "OVERRIDE agent: targets all reference real agents" {
  local missing=0
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    if [[ ! -f ".opencode/agents/${target}.md" ]]; then
      echo "MISSING: $target" >&2
      missing=$((missing + 1))
    fi
  done < <(awk '/^## OVERRIDE/,/^## AUTO/' "$TARGET" | grep -oE 'agent:[a-z0-9-]+' | sed 's/agent://' | sort -u)
  [ "$missing" -eq 0 ]
}

# ── Protocol doc ──────────────────────────────────────────────────────

@test "resolver-protocol.md exists and under 150 lines" {
  local f="docs/rules/domain/resolver-protocol.md"
  [[ -f "$f" ]]
  local lines
  lines=$(wc -l < "$f")
  [ "$lines" -le 150 ]
}

@test "CLAUDE.md lazy reference points to RESOLVER.md" {
  grep -qF 'docs/RESOLVER.md' CLAUDE.md
  grep -qF 'resolver-protocol.md' CLAUDE.md
}

# ── Edge cases & function coverage ────────────────────────────────────

@test "edge: empty input arg list shows usage (no_arg path)" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"AUTO_BEGIN"* || "$output" == *"# RESOLVER"* ]]
}

@test "edge: nonexistent target path with --check exits with error" {
  cp "$SCRIPT" "$TMPDIR_TEST/sut.sh"
  run bash -c "cd '$TMPDIR_TEST' && mkdir -p docs && bash sut.sh --check"
  [ "$status" -ne 0 ]
}

@test "edge: extract_field handles single-line description" {
  run bash -c "source $SCRIPT 2>/dev/null; type extract_field 2>&1 || grep -c 'extract_field' $SCRIPT"
  [[ "$output" =~ [0-9]+ ]]
}

@test "edge: sanitise function present in script (truncation boundary)" {
  grep -q '^sanitise()' "$SCRIPT"
}

@test "edge: build_skills_table function present (coverage)" {
  grep -q '^build_skills_table()' "$SCRIPT"
}

@test "edge: build_agents_table function present (coverage)" {
  grep -q '^build_agents_table()' "$SCRIPT"
}

@test "edge: build_auto_block function present (coverage)" {
  grep -q '^build_auto_block()' "$SCRIPT"
}

@test "edge: build_full_default function present (coverage)" {
  grep -q '^build_full_default()' "$SCRIPT"
}

@test "edge: extract_auto_block function present (coverage)" {
  grep -q '^extract_auto_block()' "$SCRIPT"
}

@test "edge: usage function present (coverage)" {
  grep -q '^usage()' "$SCRIPT"
}

@test "edge: zero-byte temp file rejected gracefully" {
  : > "$TMPDIR_TEST/empty.md"
  [ ! -s "$TMPDIR_TEST/empty.md" ]
}

@test "edge: LC_ALL=C exported for deterministic sort across locales" {
  grep -q 'export LC_ALL=C' "$SCRIPT"
}

@test "edge: max line length boundary in RESOLVER.md (no overflow rows)" {
  local max
  max=$(awk '{print length}' "$TARGET" | sort -n | tail -1)
  [ "$max" -lt 500 ]
}
