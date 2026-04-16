# Code Review Court — Multi-Judge Agentic Review

> Era 220. 5 specialized judges review AI-generated code in parallel.
> Human E1 reviews FINDINGS, not raw diffs.

## The Court

| Judge | Focus | Agent |
|-------|-------|-------|
| correctness | Logic, tests, edge cases, error paths | `correctness-judge` L1 |
| architecture | Boundaries, coupling, layer violations, patterns | `architecture-judge` L1 |
| security | OWASP, PII, injection, auth, credentials | `security-judge` L1 |
| cognitive | Debuggability at 3AM, naming, complexity, logs | `cognitive-judge` L1 |
| spec | Implementation vs approved spec, acceptance criteria | `spec-judge` L1 |

## Flow

```
1. /court-review PR|branch|files
2. Batch-size gate: reject if diff > 400 LOC (SmartBear threshold)
3. 5 judges review in parallel (fork agents, isolated context)
4. court-orchestrator consolidates → .review.crc
5. If verdict != pass → fix cycle (max 3 rounds)
6. Human E1 reviews findings summary, approves or rejects
```

## Scoring

```
score = 100 - (critical × 25) - (high × 10) - (medium × 3) - (low × 1)
```

| Score | Verdict | E1 action |
|-------|---------|-----------|
| 90-100 | pass | Quick-review findings (< 5 min) |
| 70-89 | conditional | Review findings + advisory |
| < 70 | fail | Automatic fix cycle before human sees it |

## .review.crc artifact

Per-PR file with YAML frontmatter: review_id, judges verdicts, consolidated
score, per-file SHA-256 + finding IDs, fix round history, signature hash.
Committed alongside the PR code.

## Fix cycle

1. Orchestrator creates fix tasks from findings
2. Dev agent patches code
3. ONLY affected judge(s) re-review (not all 5)
4. Max 3 rounds → escalate to human after 4th
5. Each round recorded in .review.crc

## Batch-size gate (Nyquist enforcement)

Diff > 400 LOC → FAIL with slicing guidance. Human review quality degrades
sharply above this threshold (SmartBear/Cisco). Enforced before judges run.

## Integration

- `inclusive-review.md`: findings reformatted if `review_sensitivity: true`
- `severity-classification.md`: Rule of Three for finding severity
- `consensus-protocol.md`: adapted scoring model with per-judge weights
- `adversarial-security.md`: security-judge reuses attacker patterns
- `code-comprehension.md`: cognitive-judge uses "debuggable at 3AM" criterion

## Events

```
court.convened, court.verdict, court.fix_assigned,
court.fix_verified, court.passed, court.e1_approved
```

## Commands

`/court-review`, `/court-status`, `/court-findings`,
`/court-fix`, `/court-approve`, `/court-history`

## Config

```
CODE_REVIEW_COURT_ENABLED = true
COURT_MAX_LOC = 400
COURT_MAX_FIX_ROUNDS = 3
COURT_SCORE_PASS = 90
COURT_SCORE_CONDITIONAL = 70
```
