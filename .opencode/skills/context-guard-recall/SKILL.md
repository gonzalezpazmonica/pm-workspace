---
name: context-guard-recall
description: Retrieve stored summaries from any agent or flow via recall_summary returning SummaryV1.
---

# Skill: context-guard-recall

> Retrieve stored context-guard summaries from any agent or flow.
> Spec §2.5: recall_summary(run_id, summary_id?) returns SummaryV1.
> Confidentiality enforced: N3/N4/N4b summaries not accessible from N1 context.

## When to use

- After a long flow completes and you need to check what decisions were taken.
- When an agent starts and needs prior context without re-inflating conversation.
- To audit what artifacts were produced in previous summarization checkpoints.

## How to invoke

### Via MCP tool (recommended from agents)

Call the savia-context-guard MCP server with tool name recall_summary:

  run_id: "my-flow-run-001"
  summary_id: "summary-001"   # optional -- omit for latest
  caller_confidentiality: "N1"

### Via CLI (from shell or Bash hook)

  bash scripts/context-guard-recall.sh <run_id> [--summary-id summary-001] [--caller-level N1]

### Via Python

  from scripts.lib.context_guard.store import SummaryStore
  from pathlib import Path

  store = SummaryStore(base_dir=Path("output/context-guard"), confidentiality="N1")
  data = store.load(run_id="my-run", summary_id=None)  # None = latest

## Output format (summary_v1)

The returned summary includes structured metadata (decisions, artifacts, errors,
tools) plus a prose_summary field. Full schema: schemas/summary-v1.schema.json.

  _meta:
    run_id, index, tier_used, retried, tokens_before, tokens_after,
    confidentiality, saved_at

## Confidentiality rules (Spec §2.8)

Caller N1 can only access N1 summaries. N3 callers can access N1-N3.
Violation returns 403 Forbidden -- never silent.

## Listing all summaries for a run

  python3 -m scripts.lib.context_guard.cli list <run_id>

## Storage layout

- Default (N1-N2): output/context-guard/{run_id}/summary-NNN.yaml
- Sensitive (N4/N4b): output/context-guard/N4/{run_id}/summary-NNN.yaml
- Trace events: output/context-guard/{run_id}/trace.jsonl

## See also

- docs/context-guard.md
- schemas/summary-v1.schema.json
- .opencode/agents/context-summarizer.md
- .opencode/hooks/context-guard-monitor.{sh,ts}
