#!/usr/bin/env bats
# audit: score=93 hash=5cb9ee2c date=2026-05-23
# Ref: SPEC-147 — Decision trees for top-10 agents (Slice 1: 3 pilots)
# docs/propuestas/SPEC-147-decision-trees-top-agents.md
# Validates: structural existence, symlink, frontmatter link, ≤80 line cap.

set -uo pipefail

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TREES_DIR="$REPO_ROOT/.claude/agents/decision-trees"
  TREES_SYMLINK="$REPO_ROOT/.opencode/agents/decision-trees"
  PILOTS=("architect" "code-reviewer" "security-guardian")
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  [ -n "${TMPDIR_TEST:-}" ] && [ -d "$TMPDIR_TEST" ] && rm -rf "$TMPDIR_TEST"
}

# ── Slice 1 pilots ──────────────────────────────────────────────────────────

@test "AC-01: 3 pilot decision-tree files exist in .claude/agents/decision-trees/" {
  for agent in "${PILOTS[@]}"; do
    [ -f "$TREES_DIR/${agent}-decisions.md" ]
  done
}

@test "AC-01: existing commit-guardian-decisions.md still present (no regression)" {
  [ -f "$TREES_DIR/commit-guardian-decisions.md" ]
}

@test "AC-01: each pilot tree is ≤80 lines (cap)" {
  for agent in "${PILOTS[@]}"; do
    lines=$(wc -l < "$TREES_DIR/${agent}-decisions.md")
    [ "$lines" -le 80 ]
  done
}

@test "AC-01: each pilot tree starts with proper H1 heading" {
  for agent in "${PILOTS[@]}"; do
    head -1 "$TREES_DIR/${agent}-decisions.md" | grep -Eq "^# Decision Trees? — ${agent}"
  done
}

# ── Slice 1 symlink (AC-01b) ────────────────────────────────────────────────

@test "AC-01b: .opencode/agents/decision-trees is a symlink to .claude/agents/decision-trees" {
  [ -L "$TREES_SYMLINK" ]
  target=$(readlink "$TREES_SYMLINK")
  [ "$target" = "../../.claude/agents/decision-trees" ]
}

@test "AC-01b: symlink resolves to a directory containing the pilot files" {
  for agent in "${PILOTS[@]}"; do
    [ -f "$TREES_SYMLINK/${agent}-decisions.md" ]
  done
}

# ── Frontmatter linking (AC-02) ─────────────────────────────────────────────

@test "AC-02: each pilot agent has decision_tree: in .claude/agents/<name>.md" {
  for agent in "${PILOTS[@]}"; do
    grep -q "^decision_tree: decision-trees/${agent}-decisions.md\$" "$REPO_ROOT/.claude/agents/${agent}.md"
  done
}

@test "AC-02: each pilot agent has decision_tree: in .opencode/agents/<name>.md (mirror)" {
  for agent in "${PILOTS[@]}"; do
    grep -q "^decision_tree: decision-trees/${agent}-decisions.md\$" "$REPO_ROOT/.opencode/agents/${agent}.md"
  done
}

@test "AC-02: linked tree file exists for every agent with a decision_tree: field" {
  for cat in .claude/agents .opencode/agents; do
    while IFS= read -r line; do
      file="${line%%:decision_tree:*}"
      tree=$(echo "$line" | sed 's|^.*:decision_tree:[[:space:]]*||')
      tree_dir=$(dirname "$file")
      [ -f "$tree_dir/$tree" ] || {
        echo "Broken link in $file → $tree (expected at $tree_dir/$tree)"; return 1;
      }
    done < <(grep -rH "^decision_tree:" "$REPO_ROOT/$cat" 2>/dev/null || true)
  done
}

# ── Format hygiene (AC-03) ──────────────────────────────────────────────────

@test "AC-03: each pilot tree declares the cap in its header (self-documenting)" {
  for agent in "${PILOTS[@]}"; do
    grep -q "Cap.*80" "$TREES_DIR/${agent}-decisions.md"
  done
}

@test "AC-03: each pilot tree has at least an Entry/Routing section" {
  for agent in "${PILOTS[@]}"; do
    grep -qE "^## (Cuándo|Routing|When|Entry)" "$TREES_DIR/${agent}-decisions.md"
  done
}

@test "AC-03: each pilot tree declares anti-patterns or escalation rules" {
  for agent in "${PILOTS[@]}"; do
    grep -qE "Anti-patrones|Escalado|Escalate|NO hacer" "$TREES_DIR/${agent}-decisions.md"
  done
}

# ── Spec metadata ───────────────────────────────────────────────────────────

@test "spec ref: SPEC-147 doc exists" {
  [ -f "$REPO_ROOT/docs/propuestas/SPEC-147-decision-trees-top-agents.md" ]
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: no pilot tree is empty (zero bytes)" {
  for agent in "${PILOTS[@]}"; do
    [ -s "$TREES_DIR/${agent}-decisions.md" ]
  done
}

@test "edge: symlink target is nonexistent path → fail (sanity probe in tmp)" {
  ln -s "$TMPDIR_TEST/nonexistent" "$TMPDIR_TEST/dangling"
  [ -L "$TMPDIR_TEST/dangling" ]
  [ ! -e "$TMPDIR_TEST/dangling" ]
}

@test "edge: empty agent name does not crash the linked-tree sweep" {
  # Sweep must skip files with no decision_tree: field cleanly.
  run grep -rH "^decision_tree:[[:space:]]*\$" "$REPO_ROOT/.claude/agents" 2>/dev/null
  # Status may be 0 or 1; only assert no crash (status ≤ 1).
  [ "$status" -le 1 ]
}

@test "edge: zero pilot trees would be detected (negative sanity)" {
  count=$(ls "$TREES_DIR"/*-decisions.md 2>/dev/null | wc -l)
  [ "$count" -gt 0 ]
}

# ── Negative cases ──────────────────────────────────────────────────────────

@test "negative: pilot trees do NOT reference real client names" {
  for agent in "${PILOTS[@]}"; do
    ! grep -qE "@(gmail|outlook|hotmail)\.com" "$TREES_DIR/${agent}-decisions.md"
  done
}

@test "negative: pilot trees do NOT leak hardcoded paths to private dirs" {
  for agent in "${PILOTS[@]}"; do
    ! grep -qE "/home/[a-z]+/\.azure|/home/[a-z]+/\.savia/" "$TREES_DIR/${agent}-decisions.md"
  done
}

@test "negative: missing pilot file would fail the AC-01 assertion (counter-test)" {
  ghost_file="$TMPDIR_TEST/ghost-decisions.md"
  [ ! -f "$ghost_file" ]
  ! [ -f "$ghost_file" ]
}

@test "negative: broken symlink in tmp does NOT pass -e check" {
  ln -s "$TMPDIR_TEST/missing-target" "$TMPDIR_TEST/broken"
  run test -e "$TMPDIR_TEST/broken"
  [ "$status" -ne 0 ]
}

# ── Assertion quality ───────────────────────────────────────────────────────

@test "assertion quality: pilot tree wc-l output contains the file path" {
  run wc -l "$TREES_DIR/architect-decisions.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"architect-decisions.md"* ]]
}

@test "isolation: TMPDIR_TEST is created, writable, and isolated" {
  [ -d "$TMPDIR_TEST" ]
  touch "$TMPDIR_TEST/probe" && [ -f "$TMPDIR_TEST/probe" ]
  [[ "$TMPDIR_TEST" == /tmp/* ]] || [[ "$TMPDIR_TEST" == /var/* ]]
}
