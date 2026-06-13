---
context_tier: L3
token_budget: 1200
---

# Recommendation Tribunal Extensions — opt-in features

> Reference for `recommendation-tribunal-orchestrator` agent. Loaded
> on-demand when the orchestrator needs the detailed protocol of any
> opt-in extension. Kept out of the agent prompt itself to respect
> Rule #22 (<4096 bytes per agent).

## Early-cancel (SPEC-196)

When `SAVIA_TRIBUNAL_EARLY_CANCEL=on` (default `on`) AND the orchestrator
runs in a shell-capable environment (bash tool available), the orchestrator
MAY launch `scripts/recommendation-tribunal/early-cancel.sh` in the
background immediately after dispatching the 4 Task calls. Pass the
simulated PIDs and the directory where each judge will write its JSON.

Behavior:
- If ANY judge emits `veto:true` with `confidence ≥ 0.95` before the others
  complete, early-cancel kills the remaining judges and returns a partial
  verdict. The aggregator then runs on whatever JSON files exist.
- Default threshold 0.95 (very conservative). Tunable via
  `SAVIA_TRIBUNAL_EARLY_CANCEL_THRESHOLD`.
- Disable globally with `SAVIA_TRIBUNAL_EARLY_CANCEL=off`.

This is a **latency optimization**. The deterministic verdict is identical
to the non-cancel path because the veto rule (`confidence ≥ 0.8`) is met
by the single triggering judge. Early-cancel saves the wall-clock of the
remaining judges.

NOTE: in pure-LLM mode (no shell), skip this step. The Task tool already
runs in parallel.

Spec: `docs/propuestas/SPEC-196-tribunal-freeze-done-elements.md`.

## Judge output validation (SPEC-198)

When `SAVIA_JUDGE_VERDICT_VALIDATE=warn` (or `=on`), each judge JSON
written to disk is round-tripped through
`scripts/recommendation-tribunal/judge_verdict.py` before aggregation.
Validation failures are logged to
`output/judge-verdict-validation-errors.jsonl` but do NOT block the
tribunal. The aggregator still extracts fields via raw JSON parsing for
backward compatibility. This is telemetry-only until promoted to `=block`.

Spec: `docs/propuestas/SPEC-198-judge-output-schema.md`.

## Iterative refinement loop (SPEC-195 + SPEC-197)

When `SAVIA_TRIBUNAL_ITERATIVE=on` (default `off` during pilot), the
orchestrator runs in iterative mode:

1. Round N: convene judges (per existing flow), aggregate verdict.
2. If verdict == PASS or VETO → exit, log iteration, return.
3. If verdict == WARN AND N < max_iter:
   - Call `bash scripts/recommendation-tribunal/iterate.sh compute-temperature
     --iteration N --max-iter <max>` → read `.temperature` from JSON.
   - Use that temperature for the next LLM regeneration call.
   - Build hints from judges' `reason` fields (e.g., "rule-violation cited
     Rule #24; rephrase to avoid empty validation").
   - Regenerate draft via LLM call with the hints + new temperature.
   - Call `bash scripts/recommendation-tribunal/iterate.sh evaluate-stop
     --iteration N --max-iter <max> --draft-hash <h> --previous-draft-hash
     <h-1> --judge-scores "85,92,78"` → if `.should_stop`, exit early.
4. Persist every iteration via `iterate.sh log-iteration` to
   `output/tribunal-iterations/<session>.jsonl`.

The annealing schedule starts at `SAVIA_ANNEAL_MAX_T` (0.9 default) for
exploration in round 0 and decays to `SAVIA_ANNEAL_MIN_T` (0.1) by the
last round for decisiveness. Exponent controls the curve shape
(2.0 default = quadratic decay, more time at low temperature).

Early-stop criteria (SPEC-195):
- `stability`: same draft-hash twice in a row → converged.
- `entropy`: judge-score variance below threshold → consensus.
- `max_iter`: hard ceiling reached.

This loop is OFF by default. Telemetry-only pilot phase: 30 days of
`output/tribunal-iterations/` data before promoting to default-on.

Specs: `docs/propuestas/SPEC-195-iterative-tribunal-early-stop.md` +
`docs/propuestas/SPEC-197-temperature-annealing.md`.
