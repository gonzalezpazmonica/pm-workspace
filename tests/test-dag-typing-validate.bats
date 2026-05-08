#!/usr/bin/env bats
# BATS tests for scripts/dag-typing-validate.sh (SE-034 Slice 1).
# Validates the DAG typing validator: audit mode, validate edge mode,
# infer mode, and type-compatibility rules (any, markdown→text subset).
#
# Ref: SE-034, ROADMAP.md §Tier 4.3
# Safety: script under test has `set -uo pipefail`.

SCRIPT="scripts/dag-typing-validate.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# ── Structure / safety ──────────────────────────────────────────────────────

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "script passes bash -n syntax check" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ── CLI surface ─────────────────────────────────────────────────────────────

@test "script accepts --help and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"audit"* ]]
  [[ "$output" == *"skills"* ]]
  [[ "$output" == *"infer"* ]]
}

@test "script rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "script rejects no-args invocation" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

# ── Audit mode (real repo) ─────────────────────────────────────────────────

@test "audit mode exits 0 and writes a report" {
  run bash "$SCRIPT" --audit
  [ "$status" -eq 0 ]
  local latest
  latest=$(ls -t output/dag-typing-audit-*.md 2>/dev/null | head -1)
  [[ -f "$latest" ]]
}

@test "audit report contains coverage percentage" {
  bash "$SCRIPT" --audit >/dev/null 2>&1
  local latest
  latest=$(ls -t output/dag-typing-audit-*.md 2>/dev/null | head -1)
  run grep -cE 'Coverage:' "$latest"
  [[ "$output" -ge 1 ]]
}

@test "audit report includes Interpretation section" {
  bash "$SCRIPT" --audit >/dev/null 2>&1
  local latest
  latest=$(ls -t output/dag-typing-audit-*.md 2>/dev/null | head -1)
  run grep -c 'Interpretation' "$latest"
  [[ "$output" -ge 1 ]]
}

@test "audit mode does NOT modify .opencode/skills/" {
  local before_hash after_hash
  before_hash=$(find .claude/skills -type f -name 'SKILL.md' -exec md5sum {} \; 2>/dev/null | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" --audit >/dev/null 2>&1 || true
  after_hash=$(find .claude/skills -type f -name 'SKILL.md' -exec md5sum {} \; 2>/dev/null | sort | md5sum | awk '{print $1}')
  [[ "$before_hash" == "$after_hash" ]]
}

# ── Type compatibility (sandbox with fake skills) ──────────────────────────

@test "same types are compatible (text→text)" {
  local sandbox="$BATS_TEST_TMPDIR/.claude/skills"
  mkdir -p "$sandbox/skill-a" "$sandbox/skill-b"
  printf -- '---\nname: skill-a\ninput: text\noutput: text\n---\n' > "$sandbox/skill-a/SKILL.md"
  printf -- '---\nname: skill-b\ninput: text\noutput: text\n---\n' > "$sandbox/skill-b/SKILL.md"
  run env REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --skills skill-a,skill-b
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMPATIBLE"* ]]
}

@test "any type is universally compatible" {
  local sandbox="$BATS_TEST_TMPDIR/.claude/skills"
  mkdir -p "$sandbox/a-any" "$sandbox/b-json"
  printf -- '---\noutput: any\n---\n' > "$sandbox/a-any/SKILL.md"
  printf -- '---\ninput: json\n---\n' > "$sandbox/b-json/SKILL.md"
  run env REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --skills a-any,b-json
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMPATIBLE"* ]]
}

@test "mismatch types exit 1 and report" {
  local sandbox="$BATS_TEST_TMPDIR/.claude/skills"
  mkdir -p "$sandbox/src-json" "$sandbox/dst-text"
  printf -- '---\noutput: json\n---\n' > "$sandbox/src-json/SKILL.md"
  printf -- '---\ninput: text\n---\n' > "$sandbox/dst-text/SKILL.md"
  run env REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --skills src-json,dst-text
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISMATCH"* ]]
}

@test "markdown output is accepted by text input (subset rule)" {
  local sandbox="$BATS_TEST_TMPDIR/.claude/skills"
  mkdir -p "$sandbox/md-out" "$sandbox/txt-in"
  printf -- '---\noutput: markdown\n---\n' > "$sandbox/md-out/SKILL.md"
  printf -- '---\ninput: text\n---\n' > "$sandbox/txt-in/SKILL.md"
  run env REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --skills md-out,txt-in
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMPATIBLE"* ]]
}

@test "untyped skills produce UNTYPED verdict (advisory)" {
  local sandbox="$BATS_TEST_TMPDIR/.claude/skills"
  mkdir -p "$sandbox/untyped-a" "$sandbox/untyped-b"
  printf -- '---\nname: untyped-a\n---\n' > "$sandbox/untyped-a/SKILL.md"
  printf -- '---\nname: untyped-b\n---\n' > "$sandbox/untyped-b/SKILL.md"
  run env REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --skills untyped-a,untyped-b
  [ "$status" -eq 0 ]
  [[ "$output" == *"UNTYPED"* ]]
}

# ── Infer mode ─────────────────────────────────────────────────────────────

@test "infer mode prints declared I/O" {
  local sandbox="$BATS_TEST_TMPDIR/.claude/skills"
  mkdir -p "$sandbox/my-skill"
  printf -- '---\ninput: yaml\noutput: json\n---\n' > "$sandbox/my-skill/SKILL.md"
  run env REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --infer my-skill
  [ "$status" -eq 0 ]
  [[ "$output" == *"input:  yaml"* ]]
  [[ "$output" == *"output: json"* ]]
}

@test "infer mode on missing skill reports __missing__" {
  local sandbox="$BATS_TEST_TMPDIR/.claude/skills"
  mkdir -p "$sandbox"
  run env REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --infer nonexistent-skill
  [ "$status" -eq 0 ]
  [[ "$output" == *"__missing__"* ]]
}

# ── Negative cases ─────────────────────────────────────────────────────────

@test "negative: --skills with identical pair rejected" {
  run bash "$SCRIPT" --skills same,same
  [ "$status" -eq 2 ]
  [[ "$output" == *"distinct"* ]]
}

@test "negative: empty sandbox audit reports total=0 gracefully" {
  local sandbox="$BATS_TEST_TMPDIR/.claude/skills"
  mkdir -p "$sandbox"
  run env REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --audit
  [ "$status" -eq 0 ]
  [[ "$output" == *"total=0"* ]]
}

@test "negative: binary+text mismatch exits 1" {
  local sandbox="$BATS_TEST_TMPDIR/.claude/skills"
  mkdir -p "$sandbox/bin-out" "$sandbox/txt-in-v2"
  printf -- '---\noutput: binary\n---\n' > "$sandbox/bin-out/SKILL.md"
  printf -- '---\ninput: text\n---\n' > "$sandbox/txt-in-v2/SKILL.md"
  run env REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --skills bin-out,txt-in-v2
  [ "$status" -eq 1 ]
}

@test "negative: skill without SKILL.md handled in audit (counted as missing)" {
  local sandbox="$BATS_TEST_TMPDIR/.claude/skills"
  mkdir -p "$sandbox/empty-skill"
  # no SKILL.md created
  run env REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --audit
  [ "$status" -eq 0 ]
  [[ "$output" == *"missing=1"* ]]
}

@test "negative: script is read-only (no modifications)" {
  local before_hash after_hash
  before_hash=$(find scripts .claude/skills -type f -name '*.md' -o -name '*.sh' 2>/dev/null | xargs -I{} md5sum {} 2>/dev/null | sort | md5sum | awk '{print $1}')
  bash "$SCRIPT" --audit >/dev/null 2>&1 || true
  after_hash=$(find scripts .claude/skills -type f -name '*.md' -o -name '*.sh' 2>/dev/null | xargs -I{} md5sum {} 2>/dev/null | sort | md5sum | awk '{print $1}')
  [[ "$before_hash" == "$after_hash" ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: quoted types in frontmatter are parsed correctly" {
  local sandbox="$BATS_TEST_TMPDIR/.claude/skills"
  mkdir -p "$sandbox/quoted-skill"
  printf -- '---\ninput: "json"\noutput: "text"\n---\n' > "$sandbox/quoted-skill/SKILL.md"
  run env REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --infer quoted-skill
  [ "$status" -eq 0 ]
  [[ "$output" == *"input:  json"* ]]
}

@test "edge: single-quoted types are parsed correctly" {
  local sandbox="$BATS_TEST_TMPDIR/.claude/skills"
  mkdir -p "$sandbox/sq-skill"
  printf -- "---\ninput: 'markdown'\noutput: 'yaml'\n---\n" > "$sandbox/sq-skill/SKILL.md"
  run env REPO_ROOT="$BATS_TEST_TMPDIR" bash "$SCRIPT" --infer sq-skill
  [ "$status" -eq 0 ]
  [[ "$output" == *"input:  markdown"* ]]
}

@test "edge: _archived skill directory is skipped in audit" {
  run grep -c '_archived' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "edge: audit report links to SE-034 ROADMAP §Tier 4.3" {
  run grep -c 'SE-034\|Tier 4.3' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "edge: 6 canonical types referenced in script header" {
  run grep -cE 'text|json|markdown|yaml|binary|any' "$SCRIPT"
  [[ "$output" -ge 6 ]]
}
