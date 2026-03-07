---
name: verify-layer
description: Run specific verification layer for debugging
context_cost: medium
argument-hint: "[layer-number] [task-id]"
---

# /verify-layer {N} {task-id}

Run a single verification layer in isolation for debugging or re-running failed layers.

## Parameters

- `layer-number` (required): 1-5 (Deterministic, Semantic, Security, Agentic, Human)
- `task-id` (required): Task ID (AB#1234) or branch name
- `--with-previous` (optional): Include previous layer results in context (default: auto)
- `--format` (optional): Output format: markdown | json (default: markdown)

## Layer Descriptions

| Layer | Agent | Input | Output |
|---|---|---|---|
| 1 | Scripts | None | Pass/Fail + errors |
| 2 | code-reviewer | Layer 1 | Mapping + criteria |
| 3 | security-reviewer | Layers 1-2 | Security scan + findings |
| 4 | architect | Layers 1-3 | Architecture analysis + risk |
| 5 | Human | Layers 1-4 | Manual approval |

## Usage Scenarios

**Scenario 1: Layer 1 failed, fixed code, retry**
```
/verify-layer 1 AB#1234
→ Re-run lint, format, tests only
→ No dependency on other layers
```

**Scenario 2: Layer 3 security findings, apply fix, verify**
```
/verify-layer 3 AB#1234
→ Security scan with fresh context
→ Previous layers' outputs used for context
```

**Scenario 3: Debug Layer 2 semantic mapping**
```
/verify-layer 2 AB#1234 --with-previous
→ Receive Layer 1 results in context
→ Verify acceptance criteria mapping
```

## Flujo

1. Load task/branch metadata
2. If layer > 1: optionally load previous layer results
3. Execute layer verification
4. Save output to `output/verification/{task-id}/layer{N}.json`
5. Display results with status
