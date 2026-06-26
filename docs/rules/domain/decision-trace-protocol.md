---
context_tier: L2
token_budget: 600
---

# Decision Trace Protocol — SPEC-188 P5

> Feature flag: SAVIA_DECISION_TRACE=on (default off).
> Ref: docs/propuestas/SPEC-188-root-cause-investigation-architecture.md

## What is a decision trace

A structured JSON artefact capturing the reasoning behind an agent decision.
Not an action log — the audit trail of WHY.

## When to write one

Required (when SAVIA_DECISION_TRACE=on):
- Source file changes with LOC >= 30.
- Hook file changes (any LOC).
- Spec status transitions (PROPOSED to IMPLEMENTED).
- When responsibility-judge Layer 2 evaluates SHORTCUT.

Recommended:
- Choosing a library, design pattern, or data schema.
- A decision that discards 2 or more valid alternatives.

## Expected JSON format

Required fields: ts, agent, decision, rationale, confidence (0.0 to 1.0).
Optional: alternatives, causal_chain, spec_ref.

confidence ranges:
- 0.70 or above: high (multiple evidence, alternatives rejected with reason)
- 0.40 to 0.69: medium (partial evidence)
- below 0.40: low, should escalate to human reviewer

## Storage

Traces are written to output/decision-traces/ with filename:
YYYYMMDDTHHMMSS-{agent}-{hash8}.json

The directory is excluded from git due to volume. Anonymised summaries
may be promoted to the repository on demand.

## CLI

python3 scripts/decision-trace-writer.py \
  --agent AGENT_NAME \
  --decision "Short decision description" \
  --rationale "Why this was chosen" \
  --confidence 0.85 \
  --output output/decision-traces/

List recent: ls output/decision-traces/ | sort -r | head -20
Read a trace: python3 -m json.tool output/decision-traces/FILENAME.json

## Integration with SPEC-188

failure-pattern-memory.sh (P1) reads traces on re-failure detection.
Code Review Court consumes traces as context for architecture judges.
calibration-judge evaluates coherence between confidence and rationale.

## Feature flag

SAVIA_DECISION_TRACE=on or off. Default off.
When off: JSON printed to stdout, no file written.
Capture hook exits 0 without action when off.
