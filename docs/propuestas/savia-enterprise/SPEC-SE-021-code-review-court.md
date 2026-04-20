---
status: PROPOSED
---

# SPEC-SE-021 — Code Review Court

> **Priority:** P0 · **Estimate (human):** 10d · **Estimate (agent):** 10h · **Category:** complex · **Type:** agentic code review + quality orchestration + cognitive load reduction

## Problem statement

AI agents can produce code 10-50x faster than humans can review it.
SmartBear's Cisco study confirms that human review quality degrades
sharply after 400 LOC. A PM or tech lead who reviews 3 agent-generated
PRs in a morning is cognitively spent by lunch — the 4th PR gets
rubber-stamped. This is a Nyquist-Shannon violation: the feedback
frequency is lower than the production frequency, so defects pass
undetected.

The current Savia code-reviewer agent is a single perspective. It
catches what one generalist reviewer would catch. What it misses:
architectural boundary violations, spec-alignment drift, security
attack surface in context, cognitive complexity for the on-call
engineer who'll debug it at 3AM, and over-engineering patterns that
AI reliably introduces (single-use factories, unnecessary abstractions,
redundant indirection).

Source: Bryan Finster, "AI Broke Your Code Review" (2026).

## Objective

Replace single-pass code review with a **Code Review Court**: a panel
of 5 specialized agent-judges, each reviewing from a distinct angle,
producing a structured verdict persisted as `.review.crc` with per-file
SHA-256 signatures. An orchestrator manages the cycle: review → fix
assignment → re-review until all gaps are resolved. The human reviewer
(E1 gate) evaluates the Court's FINDINGS, not the raw diff.

## Principles affected

- **#5 El humano decide** — E1 remains human. The Court produces
  findings; the human approves or rejects based on them.
- **#3 Honestidad radical** — findings are direct, severity-weighted,
  with no sugar-coating. If the code is weak, the Court says so.

## Design

### The 5 Judges

Each judge is a fresh subagent with isolated context — no fatigue,
no anchoring bias from the implementation session.

| Judge | Focus | What it catches that others miss |
|-------|-------|----------------------------------|
| **correctness-judge** | Logic, tests, edge cases | Off-by-one, missing error paths, untested branches |
| **architecture-judge** | Boundaries, coupling, patterns | Layer violations, circular deps, wrong abstraction level |
| **security-judge** | OWASP, PII, injection, auth | Attack surface, credential exposure, injection vectors |
| **cognitive-judge** | Debuggability at 3AM, naming, complexity | Cyclomatic >15, deep nesting, misleading names, missing logs |
| **spec-judge** | Implementation vs approved spec | Missing acceptance criteria, extra scope, divergent behavior |

Each judge receives:
- The diff (files changed, not the full repo)
- The approved spec (if SDD workflow was used)
- The test output (pass/fail + coverage)
- The language pack conventions

Each judge produces a structured verdict.

### Verdict format (per judge)

```yaml
judge: "architecture-judge"
reviewed_at: "2026-04-12T10:30:00Z"
files_reviewed: ["src/service.ts", "src/controller.ts"]
verdict: "conditional"   # pass | conditional | fail
findings:
  - id: "ARCH-001"
    file: "src/service.ts"
    line: 47
    severity: "high"       # critical | high | medium | low | info
    category: "layer-violation"
    description: "Service calls repository directly bypassing domain layer"
    suggestion: "Route through domain entity method"
    auto_fixable: false
  - id: "ARCH-002"
    file: "src/controller.ts"
    line: 12
    severity: "medium"
    category: "coupling"
    description: "Controller imports 4 services — fan-out exceeds 3"
    suggestion: "Extract facade or use mediator pattern"
    auto_fixable: false
summary:
  total_findings: 2
  critical: 0
  high: 1
  medium: 1
  low: 0
  pass_rate: "0/2 files clean"
```

### The `.review.crc` artifact

After all 5 judges complete, the orchestrator produces a consolidated
`.review.crc` file per PR:

```yaml
---
review_id: "CRC-2026-0412-001"
pr_ref: "#537"
branch: "feat/user-auth"
spec_ref: "SPEC-AUTH-001"
reviewed_at: "2026-04-12T11:00:00Z"
review_round: 1
judges:
  correctness: { verdict: "pass", findings: 0 }
  architecture: { verdict: "conditional", findings: 2 }
  security: { verdict: "pass", findings: 0 }
  cognitive: { verdict: "conditional", findings: 1 }
  spec: { verdict: "pass", findings: 0 }
consolidated:
  verdict: "conditional"    # pass | conditional | fail
  total_findings: 3
  blocking: 1               # high + critical
  advisory: 2               # medium + low + info
  score: 72                 # 0-100, weighted by severity
  batch_size_check: "pass"  # FAIL if diff > 400 LOC
files:
  - path: "src/service.ts"
    sha256: "a3b4c5d6..."
    findings: ["ARCH-001"]
    status: "needs-fix"
  - path: "src/controller.ts"
    sha256: "e7f8g9h0..."
    findings: ["ARCH-002", "COG-001"]
    status: "needs-fix"
  - path: "src/auth.ts"
    sha256: "i1j2k3l4..."
    findings: []
    status: "clean"
signature:
  hash: "sha256-of-entire-crc-content"
  reviewed_by: "code-review-court-v1"
---
```

### Scoring model

```
score = 100 - (critical × 25) - (high × 10) - (medium × 3) - (low × 1)
```

Aligned with `severity-classification.md` and `adversarial-security.md`.

| Score | Verdict | E1 action |
|-------|---------|-----------|
| 90-100 | pass | Human quick-reviews findings (< 5 min) |
| 70-89 | conditional | Human reviews findings + advisory items |
| 50-69 | conditional-heavy | Human reviews all findings, may request rework |
| < 50 | fail | Automatic rework cycle before human sees it |

### Batch-size gate (Nyquist enforcement)

Before the Court convenes, the orchestrator checks:
- `git diff --stat` → total lines changed
- If > 400 LOC → **FAIL** with message: "Split PR into slices ≤ 400 LOC.
  Human review quality degrades sharply above this threshold (SmartBear)."
- Slicing guidance provided (by file, by feature, by layer)

This enforces the Nyquist bound: smaller batches = higher review frequency
= defect detection exceeds production rate.

### Fix cycle orchestration

When verdict is `conditional` or `fail`:

```
1. Orchestrator creates fix tasks from findings (one per finding)
2. Each fix task assigned to the original dev agent (or a fresh one)
3. Fix agent receives: finding + file + spec excerpt + test context
4. Fix agent patches the code
5. Orchestrator re-convenes ONLY the affected judge(s)
6. If new findings emerge → back to step 2 (max 3 rounds)
7. After 3 rounds without pass → escalate to human
```

The `.review.crc` records every round:
```yaml
rounds:
  - round: 1
    verdict: "conditional"
    findings: 3
    fixed: 0
  - round: 2
    verdict: "conditional"
    findings: 1
    fixed: 2
  - round: 3
    verdict: "pass"
    findings: 0
    fixed: 1
```

### E1 human gate — findings, not diffs

The human reviewer receives:
1. The `.review.crc` summary (score, verdict, findings by judge)
2. The spec (what was supposed to be built)
3. The Court's per-file status (clean / needs-fix / fixed)
4. A "tribal knowledge" checklist: "Is there anything the Court can't
   know that only you know about this codebase?"

The human does NOT read every line of diff. They read the Court's
findings, verify the spec was met, and add their domain knowledge.
Time per review: ~10-15 min instead of 2-4 hours.

### Integration with inclusive-review

If the developer has `review_sensitivity: true` in their accessibility
profile, the Court's findings are reformatted through `inclusive-review.md`
rules before delivery. Severity stays the same; language adapts.

### Integration with existing Savia agents

| existing agent | Court role | relationship |
|---|---|---|
| `code-reviewer` | Becomes `correctness-judge` baseline | Extended, not replaced |
| `security-guardian` | Feeds `security-judge` with pre-commit scan | Complementary |
| `security-attacker` | `security-judge` can invoke for targeted scans | On-demand |
| `coherence-validator` | Becomes `spec-judge` baseline | Extended |
| `reflection-validator` | Court orchestrator uses for meta-validation | Advisory |
| `architect` | `architecture-judge` baseline | Extended |

### New agents

| agent | level | purpose |
|-------|-------|---------|
| `court-orchestrator` | L4 | Convenes judges, manages fix cycles, produces `.review.crc` |
| `correctness-judge` | L1 | Logic, tests, edge cases |
| `architecture-judge` | L1 | Boundaries, coupling, patterns |
| `security-judge` | L1 | OWASP, PII, injection, auth |
| `cognitive-judge` | L1 | Debuggability, naming, complexity |
| `spec-judge` | L1 | Implementation vs approved spec |
| `fix-assigner` | L2 | Creates fix tasks from findings, assigns to dev agents |

### New commands

| command | output |
|---------|--------|
| `/court-review [PR\|branch\|files]` | Convenes the Court, produces `.review.crc` |
| `/court-status [PR]` | Shows current round, findings, score |
| `/court-findings [--severity high+]` | Lists open findings needing attention |
| `/court-fix [finding-id]` | Assigns fix to dev agent, triggers re-review |
| `/court-approve [PR]` | Human E1 gate: approve after reviewing findings |
| `/court-history [--project X]` | Shows review history with trend metrics |

### Events

```json
{"event": "court.convened", "pr": "#537", "judges": 5, "loc": 320}
{"event": "court.verdict", "pr": "#537", "round": 1, "score": 72, "verdict": "conditional"}
{"event": "court.fix_assigned", "finding_id": "ARCH-001", "assigned_to": "typescript-developer"}
{"event": "court.fix_verified", "finding_id": "ARCH-001", "round": 2}
{"event": "court.passed", "pr": "#537", "final_score": 95, "rounds": 3}
{"event": "court.e1_approved", "pr": "#537", "approved_by": "@tech-lead"}
```

### Metrics (operational intelligence)

| metric | purpose |
|--------|---------|
| Avg score by judge type | Which perspective catches most issues? |
| Fix-round count distribution | How many rounds until pass? |
| E1 override rate | How often does the human disagree with the Court? |
| Finding-to-fix time | How fast are findings resolved? |
| Repeat finding rate | Same issue recurring across PRs → systemic |
| Score trend per developer agent | Is agent code quality improving over time? |

## Acceptance criteria

1. `.review.crc` schema validates with JSON Schema (15+ fields).
2. 5 judges produce independent verdicts in parallel (fork agents).
3. `court-orchestrator` produces consolidated `.review.crc` from all 5 verdicts.
4. Batch-size gate rejects diffs > 400 LOC with slicing guidance.
5. Fix cycle completes end-to-end: finding → fix task → dev agent → re-review by affected judge.
6. Max 3 fix rounds enforced; 4th → escalate to human.
7. E1 human gate receives findings summary, not raw diff.
8. `.review.crc` per-file SHA-256 matches actual file content at review time.
9. Score formula `100 - (C×25 + H×10 + M×3 + L×1)` produces correct results.
10. Inclusive-review reformatting works when `review_sensitivity: true`.
11. Repeat-finding detection flags same issue across 3+ PRs.
12. 20+ BATS tests, SPEC-055 score ≥ 80.
13. `pr-plan` 11/11 gates.

## Out of scope

- Visual review (UI screenshots) — covered by `visual-qa-agent`.
- Performance benchmarking during review — future enhancement.
- ML-based finding prioritization — v1 uses severity weights only.
- Cross-repo review (reviewing changes in dependency repos) — future.
- Real-time review during coding (pair-review model) — future.

## Dependencies

- **Blocked by:** SE-001 (layer contract for agent registration).
- **Enhances:** every spec that produces code (SE-003, SE-004, SE-005, SE-009, SE-014).
- **Integrates with:** existing code-reviewer, security-guardian, coherence-validator, architect agents.
- **Soft deps:** SE-013 (dual estimation — Court overhead factored into agent-hours estimate).

## Migration path

- Feature-flag `CODE_REVIEW_COURT_ENABLED=false` → existing single-pass review.
- Gradual adoption: start with `correctness-judge` + `spec-judge` only (2 judges), add others incrementally.
- `.review.crc` files stored alongside PR (in branch, committed).

## Impact statement

The Code Review Court solves the Nyquist problem: agents produce code at
10x human speed, the Court reviews at 5x human speed (5 parallel judges),
and the human reviews FINDINGS at 10x the speed of reviewing raw diffs.
The math works: production frequency ≤ review frequency × batch-size
reduction. For a consultancy deploying 20+ agent-generated PRs per week,
this is the difference between "we shipped fast and broke things" and
"we shipped fast and caught everything before it hit production."

## Sources

- Bryan Finster, "AI Broke Your Code Review" (2026, Substack)
- SmartBear / Cisco Systems, "Best Practices for Code Review" (LOC thresholds)
- Nyquist-Shannon sampling theorem (applied to software delivery)
- Savia `severity-classification.md` (Rule of Three pattern)
- Savia `code-comprehension.md` (debuggability at 3AM criterion)
- Savia `consensus-protocol.md` (multi-judge validation, adapted)
- Savia `adversarial-security.md` (score formula)
- Savia `inclusive-review.md` (accessibility-aware review language)
