---
context_tier: L2
spec: SE-231
token_budget: 600
---

# Court Turn Routing — Adaptive Judge Selection (SE-231)

> Ref: `scripts/court-turn-router.sh` · `tests/test-court-turn-router.bats`

## Problem

The `court-orchestrator` previously convened all 5 judges on every fix-cycle
round. This is wasteful: a round with only security findings has no need for
`architecture-judge` or `cognitive-judge`. Unnecessary judges consume tokens,
slow down the cycle, and generate noise in the findings aggregation.

## Solution

After each round, analyse the pending findings and route the next round to the
minimal set of judges that can address those findings. Only escalate to all 5
judges when findings span multiple domains (mixed) or when the last round is
reached and a final holistic check is needed.

## Routing table

| Dominant finding type | Keywords detected | Judges convened |
|---|---|---|
| security | injection, credential, owasp, pii, auth, xss, sql | security-judge, correctness-judge |
| architecture | coupling, layer, boundary, dependency, solid | architecture-judge, spec-judge |
| logic / edge cases | edge case, null, exception, error path, off-by-one | correctness-judge, cognitive-judge |
| spec mismatch | spec, acceptance criteria, requirement, dod | spec-judge, correctness-judge |
| naming / complexity | naming, complexity, cognitive, debuggab | cognitive-judge |
| mixed (2+ types) | any combination above | all 5 judges |
| last round override | round >= max_round - 1 | all 5 judges (always) |
| no match | no keyword detected | all 5 judges (conservative fallback) |

## Usage

```bash
bash scripts/court-turn-router.sh \
  --findings path/to/round-N-findings.json \
  --round 2 \
  --max-round 3
```

Output (stdout): one judge name per line.

```
security-judge
correctness-judge
```

Exit codes: `0` success · `1` file error · `2` usage error.

## Integration with court-orchestrator

Replace the static judge list in step 6 (fix cycle) with a dynamic call:

```
JUDGES=$(bash scripts/court-turn-router.sh \
  --findings "$FINDINGS_FILE" \
  --round "$CURRENT_ROUND" \
  --max-round "$COURT_MAX_FIX_ROUNDS")
```

Then dispatch only the judges in `$JUDGES` via the Task fan-out. The final
consolidation and `.review.crc` production (steps 4-5) are unchanged.

## Last-round safety net

When `round >= max_round - 1` the router always returns all 5 judges,
regardless of finding types. This guarantees a full holistic pass before the
cycle ends, preventing any domain from being missed if earlier rounds narrowed
the judge set too aggressively.

## Tests

Run with: `bats tests/test-court-turn-router.bats`

The suite covers: per-type routing, mixed escalation, last-round override,
exact judge counts (no duplicates, no extras), exit codes, and empty/missing
file handling.
