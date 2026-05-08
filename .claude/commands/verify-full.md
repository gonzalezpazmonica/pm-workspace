---
name: verify-full
description: Run 5-layer verification pipeline on task/branch
context_cost: high
argument-hint: "[task-id or branch-name]"
---

# /verify-full {task-id}

Run the complete 5-layer verification lattice sequentially on a task or branch.

## Parameters

- `task-id` (required): Task ID (AB#1234) or branch name (feat/...)
- `--stop-on-critical` (optional): Stop execution on critical failures (default: true)
- `--format` (optional): Output format: markdown | json | yaml (default: markdown)

## Razonamiento

1. Identify the task/branch being verified
2. Run Layer 1 (Deterministic) → collect results
3. Run Layer 2 (Semantic) with Layer 1 context
4. Run Layer 3 (Security) with Layers 1-2 context
5. Run Layer 4 (Agentic) with Layers 1-3 context
6. Prepare consolidated report for Layer 5 (Human)
7. Display summary with next steps

## Flujo

**Step 1:** Validate task-id or branch name
- Layer 1 can start immediately with no upstream context

**Step 2-4:** Progressive cascade
- Each layer receives previous results as input
- Stop on critical failure if `--stop-on-critical=true`

**Step 5:** Consolidate & prepare human review
- Merge all layer reports
- Flag dependencies for reviewer attention
- Save to `output/verification/{task-id}/`

## Examples

**✅ Correct:**
```
/verify-full AB#1234
→ 5-layer verification runs sequentially
→ All layers complete successfully
→ Consolidated report in output/verification/AB#1234/
```

**❌ Incorrect:**
```
/verify-full task-123
→ Task ID format unrecognized (should be AB#1234)
→ Error: Cannot identify task
```
