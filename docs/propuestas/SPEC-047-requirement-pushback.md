# SPEC-047: Requirement Pushback Pass

> Status: APPROVED — Phase 1
> Author: Savia
> Date: 2026-03-29

## Problem

Specs are written with assumptions baked in. Nobody challenges them before
implementation starts. This leads to over-engineered solutions, missed
simpler alternatives, and implicit assumptions that only surface during
code review or production incidents.

## Solution

A "pushback pass" that reads a spec and generates structured questions:
- Challenges key claims and assumptions
- Proposes simpler alternatives where complexity is unjustified
- Identifies missing context or ambiguous requirements
- Flags scope creep indicators

## Phase 1 — Script (this phase)

`scripts/requirement-pushback.sh` takes a spec file path and outputs
a JSON report with:

```json
{
  "spec_file": "path/to/spec.md",
  "timestamp": "ISO-8601",
  "questions": [
    {
      "type": "assumption|complexity|ambiguity|scope",
      "section": "heading where found",
      "claim": "the original text",
      "question": "the pushback question"
    }
  ],
  "summary": {
    "total_questions": N,
    "by_type": {"assumption": N, "complexity": N, ...}
  }
}
```

### Analysis heuristics

1. **Assumptions**: statements with "must", "always", "never", "all",
   "every" without justification
2. **Complexity**: multi-step pipelines, >3 components, >5 config params
3. **Ambiguity**: vague terms like "fast", "scalable", "flexible",
   "robust" without metrics
4. **Scope**: feature lists >5 items, "Phase N" references suggesting
   unbounded growth

## Phase 2 (future)

Integration with `/spec-review` as an automatic pre-check.
LLM-powered deeper analysis using Claude as a judge.

## Phase 3 (future)

Historical tracking: which pushback questions led to spec changes.

## Success criteria

- Script runs in <2s on any spec file
- Generates >=1 question for specs with obvious assumptions
- Zero false positives on empty or minimal specs (returns empty questions)
- JSON output parseable by downstream tools
