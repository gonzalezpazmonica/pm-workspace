# SPEC-058: OpenTelemetry Agent Tracing Standard

> Status: **DRAFT** | Fecha: 2026-03-30
> Origen: AgentScope (agentscope-ai/agentscope) — OTel-native @trace_llm decorators
> Impacto: Enterprise-grade observability, third-party monitoring integration

---

## Problem

Savia traces agent execution via `agent-trace-log.sh` (PostToolUse hook),
writing JSONL to `output/agent-trace/`. This custom format:

1. **Is not queryable** by standard observability tools (Grafana, Jaeger, Datadog)
2. **Lacks distributed trace context** — no trace_id linking parent command
   to child agents to grandchild tool calls
3. **Has no span hierarchy** — a dev-session with 5 slices, each invoking
   developer + tester + reviewer, produces flat log lines with no tree structure
4. **Cannot be exported** to enterprise monitoring stacks without custom adapters

Commands like `/agent-cost` and `/agent-efficiency` parse JSONL manually.
This works for pm-workspace but blocks adoption in organizations that require
standard observability pipelines.

## Inspiration

AgentScope implements OpenTelemetry-native tracing with decorators:
- `@trace_llm` — instruments model calls with token usage, latency, errors
- `@trace_reply` — instruments agent reply lifecycle
- `@trace_format` — instruments prompt formatting

Traces export to any OTLP-compatible backend (Jaeger, Grafana Tempo,
Langfuse, Arize Phoenix). AgentScope Studio consumes these traces for
visual debugging.

## Proposed Design

### Trace Hierarchy

```
Trace: /dev-session start AB#1234
  └─ Span: orchestrator (dev-orchestrator)
     ├─ Span: slice-1-implement (dotnet-developer)
     │   ├─ Span: llm-call (claude-sonnet-4-6, 4200 tokens)
     │   ├─ Span: tool-use (Edit: UserService.cs)
     │   └─ Span: tool-use (Bash: dotnet build)
     ├─ Span: slice-1-validate (test-engineer)
     │   └─ Span: llm-call (claude-sonnet-4-6, 2100 tokens)
     └─ Span: slice-1-review (code-reviewer)
         └─ Span: llm-call (claude-opus-4-6, 3500 tokens)
```

### Span Attributes (OTel Semantic Conventions)

| Attribute | Type | Example |
|-----------|------|---------|
| `agent.name` | string | "dotnet-developer" |
| `agent.model` | string | "claude-sonnet-4-6" |
| `agent.budget_tokens` | int | 8500 |
| `agent.tokens_used` | int | 4200 |
| `agent.verdict` | string | "PASS" |
| `task.spec_ref` | string | "AB#1234" |
| `task.slice` | int | 1 |
| `tool.name` | string | "Edit" |
| `tool.target` | string | "UserService.cs" |

### Export Backends

| Backend | Transport | Use case |
|---------|-----------|----------|
| JSONL (current) | File append | Local analysis, backward compat |
| OTLP/gRPC | Network | Jaeger, Grafana Tempo |
| OTLP/HTTP | Network | Langfuse, Arize Phoenix |
| Console | Stdout | Development debugging |

### Implementation

**Phase 1 — Schema alignment** (no new dependencies):
- Define span schema in `docs/rules/domain/agent-trace-schema.md`
- Update `agent-trace-log.sh` to emit JSONL with OTel-compatible fields
  (trace_id, span_id, parent_span_id, attributes)
- `/agent-cost` and `/agent-efficiency` read new fields

**Phase 2 — OTLP export** (optional dependency):
- `scripts/trace-export.sh` reads JSONL, converts to OTLP, sends to collector
- Requires: `otel-cli` or Python `opentelemetry-sdk` (not installed by default)
- Graceful degradation: if no collector configured, JSONL-only (current behavior)

**Phase 3 — Live tracing** (future):
- Hook into Task tool invocation to generate spans in real time
- Requires Claude Code hook support for span context propagation

## Constraints

- Phase 1 adds ZERO new dependencies (schema change only)
- JSONL backward compatibility: old format still parseable
- No telemetry sent externally without explicit opt-in configuration
- Privacy: span attributes never contain PII or project data (only agent names,
  token counts, verdicts)

## What Does NOT Change

- agent-trace-log.sh hook (still PostToolUse, still async)
- `/agent-cost` command (reads enhanced JSONL)
- Agent implementation (agents do not generate traces themselves)

## Success Criteria

- JSONL traces include trace_id + parent_span_id for hierarchical queries
- `/agent-cost` shows span tree (parent -> children) for dev-sessions
- Optional: traces viewable in Jaeger/Grafana via `scripts/trace-export.sh`
