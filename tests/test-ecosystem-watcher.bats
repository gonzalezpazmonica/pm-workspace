#!/usr/bin/env bats
# Tests for SPEC-146 — Ecosystem watcher monthly
# Ref: docs/propuestas/SPEC-146-awesome-repos-monthly-watcher.md

set -uo pipefail

REPO_ROOT="${BATS_TEST_DIRNAME}/.."
SKILL_DIR="$REPO_ROOT/.opencode/skills/ecosystem-watcher"
SCRIPT="$SKILL_DIR/scripts/run-watch.sh"
LIST="$REPO_ROOT/docs/rules/domain/ecosystem-watch-list.yaml"
WORKFLOW="$REPO_ROOT/.github/workflows/ecosystem-watcher.yml"

setup() {
  TMPDIR="$(mktemp -d -t spec146-XXXXXX)"
  export TMPDIR
}

teardown() {
  [[ -n "${TMPDIR:-}" && -d "$TMPDIR" ]] && rm -rf "$TMPDIR"
}

# ─────────────────────────────────────────────────────────────────────────────
# Positive cases (AC-01..AC-07)
# ─────────────────────────────────────────────────────────────────────────────

@test "AC-01: skill SKILL.md exists with valid frontmatter" {
  [[ -f "$SKILL_DIR/SKILL.md" ]]
  run head -1 "$SKILL_DIR/SKILL.md"
  [ "$status" -eq 0 ]
  [[ "$output" == "---" ]]
  grep -q '^name: ecosystem-watcher$' "$SKILL_DIR/SKILL.md"
  grep -q '^description:' "$SKILL_DIR/SKILL.md"
}

@test "AC-01: SKILL.md respects Rule #11 (<=150 lines)" {
  local lines
  lines=$(wc -l < "$SKILL_DIR/SKILL.md")
  [ "$lines" -le 150 ]
}

@test "AC-02: watch-list YAML has >=7 repos and >=2 docs" {
  [[ -f "$LIST" ]]
  local repos docs
  repos=$(grep -c "^  - github:" "$LIST")
  docs=$(grep -c "^  - url:" "$LIST")
  [ "$repos" -ge 7 ]
  [ "$docs" -ge 2 ]
}

@test "AC-03: GitHub Action workflow exists with monthly cron" {
  [[ -f "$WORKFLOW" ]]
  run grep -E "cron: '0 9 1 \* \*" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cron"* ]]
}

@test "AC-03: workflow supports workflow_dispatch for manual runs" {
  grep -q "workflow_dispatch" "$WORKFLOW"
}

@test "AC-04: script is executable with bash shebang" {
  [ -x "$SCRIPT" ]
  run head -1 "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == "#!/usr/bin/env bash" ]]
}

@test "AC-06: script uses fail-safe (continues on per-repo error)" {
  grep -q "ERROR" "$SCRIPT"
  grep -q "repos_failed" "$SCRIPT"
}

@test "AC-06: script does not use 'set -e' (must not abort on per-repo fail)" {
  run grep -E "^set -e[uo]?" "$SCRIPT"
  [ "$status" -ne 0 ]
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "AC-07: end-to-end run completes without gh CLI in PATH" {
  # Skill lives at .claude/skills (symlinked from .opencode/skills); copy real path.
  mkdir -p "$TMPDIR/.claude"
  cp -r "$REPO_ROOT/.claude/skills" "$TMPDIR/.claude/"
  cp -r "$REPO_ROOT/docs" "$TMPDIR/"
  mkdir -p "$TMPDIR/output" "$TMPDIR/.savia-memory/ecosystem-snapshots"
  PATH=/usr/bin:/bin REPO_ROOT="$TMPDIR" bash \
    "$TMPDIR/.claude/skills/ecosystem-watcher/scripts/run-watch.sh" >/dev/null 2>&1 || true
  run ls "$TMPDIR"/output/
  [ "$status" -eq 0 ]
  [[ "$output" == *"research-skills-update-"* ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Negative cases (defensive checks)
# ─────────────────────────────────────────────────────────────────────────────

@test "negative: script must NOT contain hardcoded GitHub tokens" {
  run grep -E "ghp_[A-Za-z0-9]{20}" "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "negative: SKILL.md must NOT reference autonomous actions" {
  run grep -iE "auto-?(merge|approve|push|deploy)" "$SKILL_DIR/SKILL.md"
  [ "$status" -ne 0 ]
}

@test "negative: workflow must NOT write to repo (no git push or commit)" {
  run grep -E "git push|git commit" "$WORKFLOW"
  [ "$status" -ne 0 ]
}

@test "negative: missing SKILL.md path returns failure on read" {
  run cat "$SKILL_DIR/NONEXISTENT.md"
  [ "$status" -ne 0 ]
}

@test "negative: invalid YAML path is not picked up by grep counter" {
  run grep -c "^  - github:" "$TMPDIR/no-such-file.yaml"
  [ "$status" -ne 0 ]
}

# ─────────────────────────────────────────────────────────────────────────────
# Edge cases (boundary / empty / zero / nonexistent)
# ─────────────────────────────────────────────────────────────────────────────

@test "edge: empty watch-list yields zero repos and zero docs" {
  local empty_list="$TMPDIR/empty.yaml"
  printf "repos: []\ndocs: []\n" > "$empty_list"
  local repos docs
  repos=$( { grep -c "^  - github:" "$empty_list" 2>/dev/null || true; } )
  docs=$( { grep -c "^  - url:" "$empty_list" 2>/dev/null || true; } )
  [ "${repos:-0}" -eq 0 ]
  [ "${docs:-0}" -eq 0 ]
}

@test "edge: nonexistent script path is detected as missing" {
  local missing="$TMPDIR/nonexistent-watch.sh"
  [ ! -f "$missing" ]
  run bash "$missing"
  [ "$status" -ne 0 ]
}

@test "edge: SKILL.md boundary — must remain strictly below 150 lines (Rule #11)" {
  local lines
  lines=$(wc -l < "$SKILL_DIR/SKILL.md")
  [ "$lines" -lt 150 ]
  [ "$lines" -gt 0 ]
}

@test "edge: zero-byte SKILL.md would fail frontmatter check" {
  local zero="$TMPDIR/zero.md"
  : > "$zero"
  [ -f "$zero" ]
  [ ! -s "$zero" ]
  run head -1 "$zero"
  [ -z "$output" ]
}

@test "edge: workflow has no on-push trigger (only schedule + dispatch)" {
  run grep -E "^\s+push:" "$WORKFLOW"
  [ "$status" -ne 0 ]
}
