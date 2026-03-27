# Guide: Context and Memory Optimization (SPEC-041)

> Just as the brain consolidates memories during sleep, Savia now
> intelligently organizes and compresses context to maintain performance
> even in long, intensive sessions.

---

## 1. Why it matters

Context is the scarcest resource in an LLM. When it fills up, performance
degrades: Claude starts ignoring instructions, makes errors, forgets decisions.
SPEC-041 introduces 5 improvements to delay that moment and recover quality on compaction.

---

## 2. The 5 improvements in practice

| # | Proposal | What changes for you |
|---|----------|---------------------|
| P1 | Tier-based compaction | /compact preserves critical decisions, compresses the rest |
| P2 | Calibrated thresholds | 4 zones instead of 1: fewer unnecessary interruptions |
| P3 | Memory quality gate | Important entries are flagged for verification |
| P4 | Agent output compression | Multi-agent sessions use less context |
| P5 | Importance-weighted search | Tier A entries appear first in `/memory-recall` |

---

## 3. New context zones (P2)

Before: a single alert at 50% (ultra-conservative, interrupted too often).
Now: 4 zones based on evidence from TurboQuant paper (arXiv:2504.19874).

```
GREEN ZONE     < 50%    No action. Optimal performance.
GRADUAL ZONE   50-70%   Soft suggestion: "you can /compact when ready"
ALERT ZONE     70-85%   Heavy operations blocked until /compact
CRITICAL ZONE  > 85%    Full block. Run /compact now.
```

Real degradation starts at ~70%, not 50%. This gives you 20% more usable headroom.

---

## 4. Tier-based compaction (P1)

When /compact runs, conversation turns are automatically classified:

| Tier | What it includes | Treatment |
|------|-----------------|-----------|
| **A** | Decisions, corrections, current turn | Verbatim — preserve 100% |
| **B** | Last-hour conversation, relevant outputs | Compress to bullets (~95% semantics) |
| **C** | Confirmations, UX banners, `git status` | Discard |

Tier B is saved to `session-hot.md` (TTL 24h) and reinjected on restart.

---

## 5. Memory quality gate (P3)

Each entry in memory-store.jsonl now has:
- `importance_tier`: A, B, or C (auto-assigned by type)
- `quality`: unverified, high, medium, low
- `questions`: [] (for future verification)

To see quality status:
```bash
bash scripts/memory-verify.sh check-all
```

To verify a specific entry:
```bash
bash scripts/memory-verify.sh verify feedback_push_pr
```

---

## 6. Agent output compression (P4)

In active dev-sessions, subagent outputs >200 tokens are automatically
compressed to 5-8 bullets. Raw output is saved to
`output/dev-sessions/compressed-raw/` for traceability.

To enable manually (outside dev-session):
```bash
export SDD_COMPRESS_AGENT_OUTPUT=true
```

---

## 7. Importance-weighted search (P5)

The `importance_tier` field affects ranking in `/memory-recall`:
- Tier A weights 3× (corrections and decisions)
- Tier B weights 1× (patterns and references)
- Tier C weights 0.3× (sessions and entities)

Auto-assigned types:

| Tier A | Tier B | Tier C |
|--------|--------|--------|
| feedback, correction, decision, project | pattern, convention, discovery, reference, architecture, bug | session-summary, entity, config |

---

## 8. Related commands

```
/compact               — Compact with Tier A/B/C classification
/memory-recall         — Search weighted by importance_tier
/context-status        — View current context zone
bash scripts/memory-verify.sh check-all   — Quality report
bash scripts/memory-verify.sh verify <key> — Verify entry
```
