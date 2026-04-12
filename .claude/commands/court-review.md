# /court-review — Convene the Code Review Court

Runs the Code Review Court on the current branch's diff against main.
5 specialized judges review in parallel, producing a `.review.crc` verdict.

## Usage

```
/court-review                    # review all changed files
/court-review --spec SPEC-FILE   # include spec for spec-judge
/court-review --files "a.ts b.ts" # review specific files only
```

## Flow

1. **Batch-size gate**: `bash scripts/court-review.sh check` — FAIL if > 400 LOC
2. **Skeleton**: generate `.review.crc` skeleton with file SHA-256 hashes
3. **Judges**: launch 5 subagents in parallel:
   - `correctness-judge`: logic, tests, edge cases
   - `architecture-judge`: boundaries, coupling, patterns
   - `security-judge`: OWASP, PII, injection
   - `cognitive-judge`: debuggability at 3AM, complexity
   - `spec-judge`: implementation vs spec
4. **Consolidate**: score = 100 - (C×25 + H×10 + M×3 + L×1)
5. **Write**: `.review.crc` to branch root
6. **Report**: summary to user

## Verdicts

| Score | Verdict | Next step |
|-------|---------|-----------|
| 90-100 | pass | Show summary, human E1 quick-approves |
| 70-89 | conditional | Show findings, suggest fixes |
| < 70 | fail | Auto-trigger fix cycle, max 3 rounds |

## Fix cycle (if verdict != pass)

1. `fix-assigner` creates tasks from findings
2. Dev agent applies fixes
3. Only affected judge(s) re-review
4. Repeat until pass or 3 rounds exhausted → escalate to human

## Output

- `.review.crc` file in branch root (committed)
- Summary in conversation: score, verdict, findings count by judge, top blocking items
