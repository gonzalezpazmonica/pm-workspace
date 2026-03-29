# /trace-optimize — Analyze agent traces and suggest prompt improvements

Analyze agent execution traces to identify which agents need optimization
and what patterns cause failures. SPEC-044 Phase 1 (analysis + dry-run).

## Parameters

- `$ARGUMENTS` — optional agent name to analyze a specific agent

## Flow

1. Run `scripts/trace-pattern-extractor.sh` with arguments
2. Display ranked candidates with scores and patterns
3. For each candidate with patterns, show recommended fixes
4. Save analysis to `output/trace-analysis/`

## Execution

```bash
bash scripts/trace-pattern-extractor.sh $ARGUMENTS
```

## Output format

Show results as a table:

| Agent | Traces | Failure% | Budget% | Score | Patterns |
|-------|--------|----------|---------|-------|----------|

For agents with patterns, show recommended actions.

If no candidates found, report "All agents operating within thresholds."
