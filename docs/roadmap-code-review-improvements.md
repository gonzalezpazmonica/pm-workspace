# Code Review Improvements Roadmap

Based on analysis of Claude's code review capabilities (March 2026), this roadmap identifies improvements for pm-workspace's review pipeline.

## Current State

pm-workspace already has a mature review pipeline:

- **`code-reviewer` agent** — quality gate before merge (Opus 4.6)
- **`consensus-validation` skill** — 3-judge panel (reflection-validator, code-reviewer, business-analyst) with weighted scoring: `(reflection × 0.4) + (code × 0.3) + (business × 0.3)`. Veto rule for security/GDPR findings
- **`verification-lattice` skill** — 5-layer verification (deterministic → semantic → security → agentic → human)
- **`scoring-curves` rule** — piecewise linear normalization replacing binary pass/fail (PR size, context usage, file size, velocity deviation, test coverage, Brier confidence)
- **`risk-scoring` skill** — 4-tier risk escalation (Low/Medium/High/Critical) with automatic routing to appropriate review level
- **`dag-scheduling` skill** — parallel agent orchestration via DAGs with worktree isolation
- **`performance-audit` skill** — static performance analysis (complexity, async anti-patterns, hotspots, N+1 detection)
- **PR Guardian** — 9-gate CI workflow (`.github/workflows/pr-guardian.yml`): description quality, conventional commits, CLAUDE.md guard, ShellCheck, Gitleaks, hook safety, context impact, CHANGELOG enforcement, PR digest

## Remaining Gaps

### 1. Performance Audit as 4th Consensus Judge (Priority: High)

**Gap**: `performance-audit` exists as a standalone skill but is NOT integrated into the `consensus-validation` 3-judge panel. Performance findings don't participate in the weighted consensus score or veto rules.

**Improvement**: Add `performance-audit` as a 4th judge in `consensus-validation`. Proposed weight distribution: `(reflection × 0.3) + (code × 0.3) + (business × 0.2) + (performance × 0.2)`. Performance findings with severity CRITICAL should trigger veto (same as security).

**Files**: `.claude/skills/consensus-validation/SKILL.md`

### 2. Parallel Consensus Execution (Priority: Medium)

**Gap**: The `dag-scheduling` skill exists for SDD agent orchestration but is not used by `consensus-validation`. The 3 judges could run in parallel via DAG but currently execute sequentially within a single prompt.

**Improvement**: Wire `consensus-validation` to dispatch judges via `dag-scheduling` (no dependencies between judges → all run in parallel cohort). Reduces review time from ~120s sequential to ~40s parallel.

**Files**: `.claude/skills/consensus-validation/SKILL.md`, `.claude/skills/dag-scheduling/SKILL.md`

### 3. Adaptive Review Depth via Risk Routing (Priority: Medium)

**Gap**: `risk-scoring` calculates 4-tier risk levels but the routing is advisory — all PRs still go through the same consensus panel regardless of tier.

**Improvement**: Enforce risk-based routing: Low-risk PRs (docs, formatting) skip consensus panel entirely and auto-merge after Gate 1-5. Medium-risk gets standard 3-judge. High/Critical gets 4-judge (with performance) + human reviewer requirement.

**Files**: `.claude/skills/risk-scoring/SKILL.md`, `.github/workflows/pr-guardian.yml`

### 4. Confidence Calibration on Findings (Priority: Low)

**Gap**: `scoring-curves` provides Brier score calibration at the PR level, but individual findings from consensus judges lack per-finding confidence. A judge might flag something with high certainty vs. uncertainty, but both get the same weight.

**Improvement**: Each judge emits per-finding confidence (0.0–1.0). Low-confidence findings (<0.5) get flagged as "needs human review" rather than contributing to the aggregate score. Enables auto-fix for high-confidence findings.

**Files**: `.claude/skills/consensus-validation/SKILL.md`, `.claude/rules/domain/scoring-curves.md`

## Implementation Order

1. Integrate `performance-audit` as 4th judge in consensus-validation
2. Wire `dag-scheduling` for parallel judge execution
3. Enforce risk-scoring routing in PR Guardian workflow
4. Per-finding confidence calibration

## References

- PR Guardian: `.github/workflows/pr-guardian.yml` (9 gates)
- Code Reviewer: `.claude/agents/code-reviewer.md`
- Consensus Validation: `.claude/skills/consensus-validation/SKILL.md`
- Verification Lattice: `.claude/skills/verification-lattice/SKILL.md`
- Scoring Curves: `.claude/rules/domain/scoring-curves.md`
- Risk Scoring: `.claude/skills/risk-scoring/SKILL.md`
- DAG Scheduling: `.claude/skills/dag-scheduling/SKILL.md`
- Performance Audit: `.claude/skills/performance-audit/SKILL.md`
