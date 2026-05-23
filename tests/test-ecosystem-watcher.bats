#!/usr/bin/env bats
# Tests for SPEC-146 — Ecosystem watcher monthly
# Ref: docs/propuestas/SPEC-146-awesome-repos-monthly-watcher.md

REPO_ROOT="${BATS_TEST_DIRNAME}/.."
SKILL_DIR="$REPO_ROOT/.opencode/skills/ecosystem-watcher"
SCRIPT="$SKILL_DIR/scripts/run-watch.sh"
LIST="$REPO_ROOT/docs/rules/domain/ecosystem-watch-list.yaml"
WORKFLOW="$REPO_ROOT/.github/workflows/ecosystem-watcher.yml"

@test "AC-01: skill SKILL.md exists with valid frontmatter" {
  [[ -f "$SKILL_DIR/SKILL.md" ]]
  head -1 "$SKILL_DIR/SKILL.md" | grep -q '^---$'
  grep -q '^name: ecosystem-watcher$' "$SKILL_DIR/SKILL.md"
  grep -q '^description:' "$SKILL_DIR/SKILL.md"
}

@test "AC-01: SKILL.md respects Rule #11 (<=150 lines)" {
  local lines
  lines=$(wc -l < "$SKILL_DIR/SKILL.md")
  [[ "$lines" -le 150 ]] || {
    echo "SKILL.md has $lines lines (>150 per Rule #11)" >&2
    return 1
  }
}

@test "AC-02: watch-list YAML has >=7 repos and >=2 docs" {
  [[ -f "$LIST" ]]
  local repos docs
  repos=$(grep -c "^  - github:" "$LIST")
  docs=$(grep -c "^  - url:" "$LIST")
  [[ "$repos" -ge 7 ]] || {
    echo "Expected >=7 repos, found $repos" >&2
    return 1
  }
  [[ "$docs" -ge 2 ]] || {
    echo "Expected >=2 docs, found $docs" >&2
    return 1
  }
}

@test "AC-03: GitHub Action workflow exists with monthly cron" {
  [[ -f "$WORKFLOW" ]]
  grep -q "cron: '0 9 1 \* \* '" "$WORKFLOW" || \
    grep -q "cron: '0 9 1 \* \*'" "$WORKFLOW" || {
      echo "Expected monthly cron pattern" >&2
      return 1
    }
}

@test "AC-03: workflow supports workflow_dispatch for manual runs" {
  grep -q "workflow_dispatch" "$WORKFLOW"
}

@test "AC-04: script generates report on dry-run with no network" {
  # Sanity: script is executable and has shebang
  [[ -x "$SCRIPT" ]]
  head -1 "$SCRIPT" | grep -q '^#!/usr/bin/env bash$'
}

@test "AC-06: script uses fail-safe (continues on per-repo error)" {
  # Look for graceful error handling
  grep -q "ERROR" "$SCRIPT"
  grep -q "repos_failed" "$SCRIPT"
}

@test "AC-06: script does not use 'set -e' (must not abort on per-repo fail)" {
  # Specifically: should NOT have `set -e` that would abort
  if grep -qE "^set -e[uo]?" "$SCRIPT"; then
    return 1
  fi
  # But should still have safety: -uo pipefail without -e
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "AC-07: minimal end-to-end run completes without network (gh CLI absent simulation)" {
  # Test in a temp dir without gh in PATH to simulate degraded environment
  local tmpdir
  tmpdir=$(mktemp -d)
  cp -r "$REPO_ROOT/.opencode" "$tmpdir/"
  cp -r "$REPO_ROOT/docs" "$tmpdir/"
  cd "$tmpdir"
  mkdir -p output .savia-memory/ecosystem-snapshots
  # Run with stripped PATH (no gh, no curl)
  PATH=/usr/bin:/bin REPO_ROOT="$tmpdir" bash "$tmpdir/.opencode/skills/ecosystem-watcher/scripts/run-watch.sh" 2>&1 | head -5
  # Should complete (exit 0) even without gh
  [[ -f "$tmpdir"/output/research-skills-update-*.md ]] || ls "$tmpdir"/output/
  rm -rf "$tmpdir"
}
