# SPEC-056: Typed Agent Message Protocol

> Status: **DRAFT** | Fecha: 2026-03-30
> Origen: AgentScope (agentscope-ai/agentscope) — Msg class with ContentBlocks
> Impacto: Type safety, routing, and auditability in agent-to-agent communication

---

## Problem

Savia agents communicate via plain text strings passed through Task tool prompts.
There is no structured message format — the orchestrator embeds everything
(instructions, context files, expected output format) into a single text blob.
This causes three problems:

1. **No type safety**: A developer agent returning code cannot be distinguished
   from one returning an error explanation without parsing heuristics.
2. **No routing metadata**: Messages carry no sender identity, timestamp, or
   content type — making audit trails reconstruction fragile.
3. **No multimodal support**: Images, tool results, and thinking traces are
   flattened into text, losing structure that downstream agents could use.

## Inspiration

AgentScope defines `Msg(name, content, role)` where content can be a string
or a sequence of typed `ContentBlock` objects: TextBlock, ImageBlock,
ToolUseBlock, ToolResultBlock, ThinkingBlock. This enables typed routing,
structured storage, and multimodal agent pipelines.

## Proposed Design

### Message Schema

```yaml
AgentMessage:
  id: string          # UUID, unique per message
  sender: string      # agent name (e.g., "dotnet-developer")
  receiver: string    # target agent or "orchestrator"
  timestamp: string   # ISO 8601 UTC
  role: string        # "agent" | "orchestrator" | "human" | "system"
  content_blocks:
    - type: "text"
      text: "Implementation complete. 3 files modified."
    - type: "tool_result"
      tool: "dotnet test"
      status: "pass"
      summary: "42/42 passed"
    - type: "file_ref"
      path: "src/UserService.cs"
      action: "modified"
  metadata:
    spec_ref: "AB#1234"
    slice: 3
    tokens_used: 4200
```

### Content Block Types

| Type | Fields | Use case |
|------|--------|----------|
| text | text | General communication |
| tool_result | tool, status, summary, output | Test results, build output |
| file_ref | path, action, diff_summary | Files created/modified |
| error | code, message, suggestion | Structured error reporting |
| thinking | reasoning | Agent chain-of-thought (audit) |
| image | path, description | Screenshots, diagrams |

### Integration Points

1. **Handoff templates** (handoff-templates.md): Migrate 7 templates to use
   AgentMessage as the transport format instead of ad-hoc YAML.
2. **agent-trace-log.sh**: Extract metadata fields directly from messages
   instead of parsing output heuristics.
3. **consensus-validation**: Judges receive typed messages, can access
   tool_result blocks directly for evidence verification.
4. **dev-session protocol**: Slice handoffs carry file_ref blocks, enabling
   automated conflict detection between slices.

### Serialization

Messages serialize to JSONL for disk persistence (compatible with existing
agent-trace format). In-memory representation is a Python/TypeScript dict.

## What Changes

| Component | Before | After |
|-----------|--------|-------|
| Task prompts | Plain text blob | Structured AgentMessage |
| Handoff templates | 7 ad-hoc YAML formats | 7 templates wrapping AgentMessage |
| agent-trace-log | Parse output heuristics | Read message.metadata directly |
| Error reporting | Free text | error ContentBlock with code + suggestion |

## What Does NOT Change

- Agent frontmatter format (unchanged)
- Claude Code Task tool invocation (still plain text prompt, but structured)
- Human-facing output (Savia renders messages to natural language)

## Scope

- Define AgentMessage schema in `docs/rules/domain/agent-message-schema.md`
- Update handoff-templates.md to reference schema
- Update agent-trace-log.sh to extract metadata from structured messages
- No code implementation — this is a protocol spec for agent authors

## Risks

- Overhead: Adding structure to every message adds ~50 tokens per exchange
- Adoption: Existing agents must be updated incrementally (not big-bang)

## Success Criteria

- All 7 handoff templates use AgentMessage format
- agent-trace-log extracts sender, receiver, tokens_used without heuristics
- Error blocks from agents contain actionable suggestions (not just text)
