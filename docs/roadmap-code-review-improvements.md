# Code Review Improvements Roadmap

Based on analysis of Claude's code review capabilities (March 2026), this roadmap identifies improvements for pm-workspace's review pipeline.

## Current State

pm-workspace uses `code-reviewer` agent with 3-judge consensus panel (reflection, code-review, business). Reviews produce structured findings with severity levels. The `verification-lattice` skill provides multi-layer verification.

## Identified Gaps

### 1. Confidence Scoring (Priority: High)

**Gap**: Current reviews produce binary pass/fail findings without confidence levels.

**Improvement**: Add confidence scores (0.0–1.0) to each finding. Low-confidence findings get flagged for human review rather than blocking PRs. High-confidence findings auto-apply fixes.

**Files**: `.claude/agents/code-reviewer.md`, `.claude/skills/verification-lattice/SKILL.md`

### 2. Performance Analysis Agent (Priority: Medium)

**Gap**: No automated performance impact analysis during code review.

**Improvement**: Add a `performance-analyzer` agent that detects: N+1 queries, unnecessary re-renders, missing memoization, large bundle imports, algorithmic complexity regressions. Runs as a parallel judge alongside the existing 3-judge panel.

**Files**: New `.claude/agents/performance-analyzer.md`

### 3. Parallel Agent Dispatch (Priority: Medium)

**Gap**: Review agents run sequentially, increasing total review time.

**Improvement**: Dispatch all review judges (reflection, code-review, business, performance) in parallel using the existing `dag-scheduling` skill. Merge results after all complete.

**Files**: `.claude/skills/dag-scheduling/SKILL.md`, `.claude/skills/consensus-validation/SKILL.md`

### 4. Adaptive Review Depth (Priority: Low)

**Gap**: All PRs get the same review depth regardless of risk level.

**Improvement**: Use `risk-scoring` skill to classify PRs into tiers. High-risk PRs (security, data model, API changes) get full 3-judge + performance review. Low-risk PRs (docs, comments, formatting) get lightweight single-pass review.

**Files**: `.claude/skills/risk-scoring/SKILL.md`, `.claude/rules/domain/pr-guardian.md`

## Implementation Order

1. Confidence scoring on existing review findings
2. Performance analyzer as 4th parallel judge
3. DAG-based parallel dispatch of all judges
4. Risk-based adaptive depth using PR Guardian gates

## References

- PR Guardian: `.claude/rules/domain/pr-guardian.md` (8 gates)
- Code Reviewer: `.claude/agents/code-reviewer.md`
- Consensus Validation: `.claude/skills/consensus-validation/SKILL.md`
- Risk Scoring: `.claude/skills/risk-scoring/SKILL.md`
