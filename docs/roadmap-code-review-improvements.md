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

## Implemented (v2.74.0)

All 4 gaps have been implemented:

### 1. Performance Audit as 4th Consensus Judge — DONE

Added `performance-auditor` as 4th judge in `consensus-validation`. Weight distribution: `(reflection × 0.3) + (code × 0.3) + (business × 0.2) + (performance × 0.2)`. Performance CRITICAL findings trigger veto. Verdicts: OPTIMAL→1.0, DEGRADED→0.5, REGRESSION→0.0.

### 2. Parallel Consensus Execution — DONE

Wired `consensus-validation` to dispatch all 4 judges via `dag-scheduling` as a single parallel cohort (no dependencies). Timeout: 40s per judge, 120s total.

### 3. Adaptive Review Depth via Risk Routing — DONE

Made risk-scoring routing enforced (not advisory): Low-risk skips consensus (auto-merge after Gates 1-5), Medium runs standard 4-judge, High/Critical runs full panel + human reviewer.

### 4. Confidence Calibration on Findings — DONE

Added per-finding confidence curve to `scoring-curves.md`: ≥0.90 auto-applicable, 0.75 include in consensus, 0.50 flag for human review, ≤0.30 exclude from aggregate, ≤0.15 suppress.

## References

- PR Guardian: `.github/workflows/pr-guardian.yml` (9 gates)
- Code Reviewer: `.claude/agents/code-reviewer.md`
- Consensus Validation: `.claude/skills/consensus-validation/SKILL.md`
- Verification Lattice: `.claude/skills/verification-lattice/SKILL.md`
- Scoring Curves: `.claude/rules/domain/scoring-curves.md`
- Risk Scoring: `.claude/skills/risk-scoring/SKILL.md`
- DAG Scheduling: `.claude/skills/dag-scheduling/SKILL.md`
- Performance Audit: `.claude/skills/performance-audit/SKILL.md`
