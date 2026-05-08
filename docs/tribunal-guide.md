# Truth Tribunal — Operations & Calibration Guide

> SPEC-106 Phase 3 deliverable. Practical guide for running, debugging,
> and calibrating the Truth Tribunal report-reliability gate.

## What it does (in one paragraph)

The Truth Tribunal is a 7-judge panel that evaluates a report on 7
independent dimensions (factuality, source-traceability, hallucination,
coherence, calibration, completeness, compliance). Each judge runs
with **fresh context** — they don't see the generator's reasoning or
each other's verdicts. The orchestrator aggregates per-judge scores
with a profile-specific weight vector, applies absolute veto rules,
and emits one of: PUBLISHABLE, CONDITIONAL, ITERATE, ESCALATE,
NOT_EVALUABLE.

## How to use it

### Sync (manual)

```bash
/report-verify output/audits/yyyymmdd-foo.md
```

Convenes the tribunal, blocks until done, shows verdict, writes
`output/audits/yyyymmdd-foo.md.truth.crc` next to the report.

### Async (auto)

The `post-report-write.sh` hook (PostToolUse) detects when the assistant
writes a report-like markdown file and auto-enqueues a verification
request. Process pending requests:

```bash
/tribunal-status                    # see queue + recent verdicts
/tribunal-status --process 5        # process up to 5 pending
/tribunal-status --clean            # remove .done files >7 days old
```

The async worker stages each report as `.truth.pending` next to it.
The user (or a future Phase 2.5 in-session orchestrator) runs
`/report-verify` to convene the actual judges.

### Programmatic

```bash
bash scripts/truth-tribunal.sh detect-type <report>      # → executive|...|default
bash scripts/truth-tribunal.sh detect-tier <report>      # → N1|N2|N3|N4|N4b
bash scripts/truth-tribunal.sh weights <profile>         # → 7 weights
bash scripts/truth-tribunal.sh aggregate <report> <judges-dir>
bash scripts/truth-tribunal.sh verdict <report>          # → reads .truth.crc
```

## How report types are detected

Detection is heuristic, in this order:

1. **Frontmatter override**: `report_type: <profile>` in YAML frontmatter
   wins over everything else.
2. **Filename heuristic**: `ceo-report*` → executive, `compliance-*` →
   compliance, `*-audit-*` → audit, `*-digest*` → digest,
   `sprint-retro*` → subjective, otherwise → default.

Available profiles: `default`, `executive`, `compliance`, `audit`,
`digest`, `subjective`. Each has its own weight vector documented in
`.claude/rules/domain/truth-tribunal-weights.md`.

## How verdicts are computed

```
weighted_score = sum(judge_score * weight) for each of 7 judges

if abstentions ≥ 4         → NOT_EVALUABLE
elif any veto              → ITERATE
elif weighted_score ≥ 90   → PUBLISHABLE
elif weighted_score ≥ 70   → CONDITIONAL
else                       → ITERATE
```

**Compliance gate override**: for `compliance` and `audit` profiles,
the compliance-judge score must be ≥95 regardless of weighted score.
A compliance score below 95 forces ITERATE even when the rest looks
healthy.

## Veto rules (absolute)

A single judge emitting VETO blocks publication regardless of score:

| Judge | Veto trigger |
|-------|--------------|
| compliance | PII leak, tier violation, credential exposure |
| hallucination | fabrication with confidence ≥0.8 |
| factuality | contradicted claim with evidence |
| coherence | critical arithmetic error, direct contradiction |
| source-traceability | uncited claim in compliance/audit report |

## Calibration with the benchmark harness

`scripts/tribunal-benchmark.sh` validates the **aggregation layer**
(weights, thresholds, veto rules) against deterministic synthetic
fixtures. It does NOT validate the judge LLMs themselves — that
requires real model calls, which is intentionally out of scope for
the deterministic harness.

```bash
# Generate the default 6-case sample dataset
bash scripts/tribunal-benchmark.sh sample tests/fixtures/truth-tribunal-bench

# Run the benchmark
bash scripts/tribunal-benchmark.sh run tests/fixtures/truth-tribunal-bench

# Save results for later inspection
bash scripts/tribunal-benchmark.sh run <dataset> /tmp/results.jsonl
bash scripts/tribunal-benchmark.sh metrics /tmp/results.jsonl
```

The default sample exercises:

- Pure happy path on each profile (default, executive, audit)
- Mid-band scores → CONDITIONAL
- Uniformly low scores → ITERATE
- **Compliance gate override**: high overall, low compliance → ITERATE

Add more cases to detect drift after weight changes:

```
tests/fixtures/truth-tribunal-bench/
├── case-001/
│   ├── report.md            # frontmatter sets report_type
│   ├── expected.yaml        # ground truth { verdict, profile }
│   └── judges/
│       ├── factuality.yaml
│       ├── source-traceability.yaml
│       ├── ...
│       └── compliance.yaml
└── case-NNN/
    └── ...
```

A failing benchmark after a weight or threshold change means the
change broke something; investigate before merging.

## Calibrating real-world judge LLMs

The deterministic harness only validates the math. To calibrate the
actual judge models (e.g., does `factuality-judge` agree with humans?),
use this manual loop:

1. Pick 10-20 real reports from `output/` with known quality (good
   and bad).
2. For each, run `/report-verify <path>` and capture the `.truth.crc`.
3. Have a human annotate the per-judge scores they would give.
4. Compute disagreement: if a judge consistently differs from human
   by ≥20 points or in verdict direction, its prompt or weight needs
   attention.
5. Adjust weights in `.claude/rules/domain/truth-tribunal-weights.md`
   AND mirror them in `scripts/truth-tribunal.sh`'s `weights()` function.
6. Re-run the deterministic benchmark to confirm no regression on the
   aggregation layer.
7. Re-run the manual loop on the same sample to confirm improvement.

This is intentionally manual — automating "do humans agree" requires
yet another LLM judge, which reintroduces the original problem the
tribunal solves.

## Cache and TTL

Verdicts are cached by SHA256 of the report content under
`~/.savia/truth-tribunal/cache/`. TTL is 24 h by default; override
with `TRUTH_TRIBUNAL_CACHE_TTL=<seconds>`. Re-running `/report-verify`
on an unchanged report serves the cached verdict. Editing the report
invalidates the cache automatically because the hash changes.

## Iteration loop (Phase 2 + future)

When verdict is ITERATE, the orchestrator agent (in-session) is
expected to:

1. Compile per-judge findings into a structured feedback markdown
2. Hand back to the generating agent (or user) with explicit changes
   needed
3. After regeneration, re-run the tribunal
4. Cap at 3 iterations; the 4th forces ESCALATE to a human

The current Phase 2 worker stages reports but the iteration handoff
is manual: the user reads the verdict, decides whether to regenerate.
A future Phase 2.5 in-session orchestrator can close the loop
automatically.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Verdict NOT_EVALUABLE | ≥4 judges abstained | Provide more context to the report; judges abstain on ambiguity |
| Verdict ITERATE despite high weighted score | Compliance gate (compliance/audit profile, compliance <95) OR veto | Check `vetos:` field in `.truth.crc` |
| Weighted score doesn't match manual sum | Profile detection picked wrong profile | Add `report_type:` frontmatter to override |
| Cache returns stale verdict | Report content unchanged but you want re-evaluation | `/report-verify <path> --force` (Phase 2 supports `--force` flag) |
| Benchmark fails after weight change | Weights in script disagree with rule file | Sync `truth-tribunal.sh` `weights()` function with `.claude/rules/domain/truth-tribunal-weights.md` |

## Files

| Component | Path |
|---|---|
| Orchestration helper | `scripts/truth-tribunal.sh` |
| Async worker | `scripts/truth-tribunal-worker.sh` |
| Benchmark harness | `scripts/tribunal-benchmark.sh` |
| Async hook | `.opencode/hooks/post-report-write.sh` |
| Sync command | `.opencode/commands/report-verify.md` |
| Status dashboard | `.opencode/commands/tribunal-status.md` |
| Orchestrator agent | `.opencode/agents/truth-tribunal-orchestrator.md` |
| 7 judge agents | `.opencode/agents/{factuality,source-traceability,hallucination,coherence,calibration,completeness,compliance}-judge.md` |
| Weight rule | `.claude/rules/domain/truth-tribunal-weights.md` |
| Spec | `docs/propuestas/SPEC-106-truth-tribunal-report-reliability.md` |
| BATS Phase 1 | `tests/test-truth-tribunal.bats` |
| BATS Phase 2 | `tests/test-truth-tribunal-phase2.bats` |
| BATS Phase 3 | `tests/test-tribunal-benchmark.bats` |

## Honest limits

- The deterministic benchmark validates math, not LLM quality.
- The async worker stages requests; judge invocation needs an active
  Claude Code session (Phase 2 limit).
- Profile detection is heuristic; reports without an obvious filename
  pattern need a `report_type:` frontmatter.
- Cache is content-hash based; metadata changes (file rename, mtime)
  do not invalidate it. Edit the content to force re-evaluation.
