#!/usr/bin/env bats
# Ref: SPEC-147 — Decision trees for top-10 agents (Slice 1: 3 pilots)
# Validates: structural existence, symlink, frontmatter link, ≤80 line cap.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TREES_DIR="$REPO_ROOT/.claude/agents/decision-trees"
  TREES_SYMLINK="$REPO_ROOT/.opencode/agents/decision-trees"
  PILOTS=("architect" "code-reviewer" "security-guardian")
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
  # Sweep both catalogs — every reference must resolve.
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
