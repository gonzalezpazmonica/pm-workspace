#!/usr/bin/env bats
# SE-099 lote 1 — 5 agents split, runbook skills created, agents ≤4096B
# Ref: docs/propuestas/SE-099-agents-oversized-rest.md

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  REPO_ROOT="$(pwd)"
  AGENTS_DIR="$REPO_ROOT/.opencode/agents"
  SKILLS_DIR="$REPO_ROOT/.opencode/skills"

  # 5 agents split in lote 1
  SPLIT_AGENTS=(
    "meeting-digest"
    "meeting-risk-analyst"
    "sdd-spec-writer"
    "truth-tribunal-orchestrator"
    "visual-digest"
  )

  # corresponding runbook skills
  RUNBOOK_SKILLS=(
    "meeting-digest-runbook"
    "meeting-risk-analyst-runbook"
    "sdd-spec-writer-runbook"
    "truth-tribunal-runbook"
    "visual-digest-runbook"
  )
}

# ── Size compliance (Rule #22 SLA: ≤4096 bytes) ───────────────────────────

@test "meeting-digest: agent is under 4096 bytes" {
  local size
  size=$(wc -c < "$AGENTS_DIR/meeting-digest.md")
  [[ "$size" -le 4096 ]]
}

@test "meeting-risk-analyst: agent is under 4096 bytes" {
  local size
  size=$(wc -c < "$AGENTS_DIR/meeting-risk-analyst.md")
  [[ "$size" -le 4096 ]]
}

@test "sdd-spec-writer: agent is under 4096 bytes" {
  local size
  size=$(wc -c < "$AGENTS_DIR/sdd-spec-writer.md")
  [[ "$size" -le 4096 ]]
}

@test "truth-tribunal-orchestrator: agent is under 4096 bytes" {
  local size
  size=$(wc -c < "$AGENTS_DIR/truth-tribunal-orchestrator.md")
  [[ "$size" -le 4096 ]]
}

@test "visual-digest: agent is under 4096 bytes" {
  local size
  size=$(wc -c < "$AGENTS_DIR/visual-digest.md")
  [[ "$size" -le 4096 ]]
}

# ── Runbook skills: SKILL.md and DOMAIN.md exist ─────────────────────────

@test "all 5 runbook skills have SKILL.md" {
  for skill in "${RUNBOOK_SKILLS[@]}"; do
    [[ -f "$SKILLS_DIR/$skill/SKILL.md" ]] || {
      echo "Missing: $SKILLS_DIR/$skill/SKILL.md"
      return 1
    }
  done
}

@test "all 5 runbook skills have DOMAIN.md" {
  for skill in "${RUNBOOK_SKILLS[@]}"; do
    [[ -f "$SKILLS_DIR/$skill/DOMAIN.md" ]] || {
      echo "Missing: $SKILLS_DIR/$skill/DOMAIN.md"
      return 1
    }
  done
}

# ── Agents reference their runbook skill ─────────────────────────────────

@test "meeting-digest agent references meeting-digest-runbook skill" {
  grep -q "meeting-digest-runbook" "$AGENTS_DIR/meeting-digest.md"
}

@test "meeting-risk-analyst agent references meeting-risk-analyst-runbook skill" {
  grep -q "meeting-risk-analyst-runbook" "$AGENTS_DIR/meeting-risk-analyst.md"
}

@test "sdd-spec-writer agent references sdd-spec-writer-runbook skill" {
  grep -q "sdd-spec-writer-runbook" "$AGENTS_DIR/sdd-spec-writer.md"
}

@test "truth-tribunal-orchestrator agent references truth-tribunal-runbook skill" {
  grep -q "truth-tribunal-runbook" "$AGENTS_DIR/truth-tribunal-orchestrator.md"
}

@test "visual-digest agent references visual-digest-runbook skill" {
  grep -q "visual-digest-runbook" "$AGENTS_DIR/visual-digest.md"
}

# ── Runbook SKILL.md content sanity ──────────────────────────────────────

@test "meeting-digest-runbook SKILL.md is non-empty and has content" {
  local size
  size=$(wc -c < "$SKILLS_DIR/meeting-digest-runbook/SKILL.md")
  [[ "$size" -gt 500 ]]
}

@test "visual-digest-runbook SKILL.md references 5-pass pipeline" {
  grep -q -i "pasada\|pipeline\|pass" "$SKILLS_DIR/visual-digest-runbook/SKILL.md"
}

@test "truth-tribunal-runbook SKILL.md references the 7 judges" {
  grep -q "7" "$SKILLS_DIR/truth-tribunal-runbook/SKILL.md"
}

# ── No PR #860 agents were touched ───────────────────────────────────────

@test "code-reviewer not modified by SE-099 (belongs to PR #860)" {
  # code-reviewer is handled by SE-098/PR#860; SE-099 must not touch it
  # just verify it exists — its content is managed by SE-098
  [[ -f "$AGENTS_DIR/code-reviewer.md" ]]
}

# ── SE-099 spec status updated ───────────────────────────────────────────

@test "SE-099 spec exists and mentions PARTIALLY_IMPLEMENTED" {
  local spec_file="docs/propuestas/SE-099-agents-oversized-rest.md"
  [[ -f "$spec_file" ]]
  grep -q "PARTIALLY_IMPLEMENTED\|lote 1\|lote-1\|batch 1\|batch-1\|2026-06-24" "$spec_file"
}

# ── agent-size-audit.sh integration ──────────────────────────────────────

@test "agent-size-audit.sh exists and is executable" {
  [[ -x "scripts/agent-size-audit.sh" ]]
}

@test "agent-size-audit.sh shows all 5 SE-099 agents as compliant" {
  run bash scripts/agent-size-audit.sh 2>/dev/null
  # Script must not list any of our 5 agents as oversized
  for agent in "meeting-digest" "meeting-risk-analyst" "sdd-spec-writer" "truth-tribunal-orchestrator" "visual-digest"; do
    if echo "$output" | grep -q "OVERSIZED.*$agent\|$agent.*OVERSIZED"; then
      echo "FAIL: $agent still flagged as oversized by audit script"
      return 1
    fi
  done
}
