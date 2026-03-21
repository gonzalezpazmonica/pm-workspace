---
name: model-upgrade-audit
description: "Audit workspace components for prompt debt when a new model is available. Detect workarounds, propose simplifications, compare with evals."
category: governance
tags: [model, upgrade, prompt-debt, simplification, audit]
priority: medium
disable-model-invocation: false
user-invocable: true
allowed-tools: [Read, Write, Glob, Grep, Bash, Task]
---

# Model Upgrade Audit

Analyzes agents, skills, and prompts for workarounds that newer models handle natively. Proposes token-saving simplifications backed by evidence.

## Decision Checklist

1. Is a new model available in config? If NO -> abort, nothing to audit.
2. Scope defined? (full | list | changed-since) If NO -> default to full.
3. Are evals available for target components? If NO -> warn, audit without comparison.
4. Is this a major model jump (e.g., Sonnet -> Opus)? If YES -> recommend full scope.
5. Has previous audit been run? If YES -> show delta since last audit.

## Parameters

| Param | Required | Default | Description |
|---|---|---|---|
| scope | No | full | `full`, `agents`, `skills`, `rules`, or comma-separated list |
| model_new | No | (auto-detect) | Model to audit against |
| changed_since | No | - | Only audit components changed since Era N |

## Workaround Patterns

| Pattern | Signal | Severity |
|---|---|---|
| Emphatic repetition | Same instruction >= 2x | Medium |
| Negative overload | >3 "don't/never/avoid" per prompt | Low |
| Compensatory few-shot | Basic capability examples | Medium |
| Defensive parsing | Regex fallback for bad output | High |
| Coded retries | Retry loops for model failure | High |
| Bloated prompt | >2000 tokens procedural | Medium |

## Execution Flow

```
1. Inventory: glob agents/*.md + skills/*/SKILL.md + rules/domain/*.md
2. For each component:
   a. Count tokens (wc -w * 1.3)
   b. Scan for workaround patterns (regex)
   c. Classify: simplifiable | no_change | review_needed
3. For simplifiable components:
   a. Propose simplified version
   b. Estimate token reduction
4. Generate YAML report -> output/model-audit/
5. Summary in chat (output-first pattern)
```

## Output

Report: `output/model-audit/{date}-audit.yaml`

Summary:
```
Model Audit: {model_old} -> {model_new}
Components: {N} audited | {N} simplifiable | {N} no change
Token savings: ~{N} tokens/session ({pct}% reduction)
Risk: {N} low | {N} medium | {N} high
```

## Application Flow

- `APPLY` (risk: low) -> auto-apply with backup
- `REVIEW` (risk: medium) -> Draft PR for human review
- `SKIP` (risk: high) -> log for manual review

## Integration

- Consumes feasibility-probe historical data for comparison
- Feeds into `/agent-efficiency` for token tracking
- Triggers after model config change in pm-config.md
