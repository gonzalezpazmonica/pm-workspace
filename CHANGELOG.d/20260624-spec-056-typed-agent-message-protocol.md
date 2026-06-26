## SPEC-056 — Typed Agent Message Protocol (2026-06-24)

### Added
- `scripts/agent-message-schema.py`: AgentMessage + ContentBlock dataclasses with full validation
  - ContentBlock types: text, code, result, error, decision (+ tool_result, file_ref, thinking, image)
  - AgentMessage fields: id (UUID), sender, receiver, role, content_blocks, ts (ISO-8601), session_id
  - CLI: `--validate <json>` (exit 0/1), `--schema` (JSON Schema), `--example` (valid message)
- `tests/scripts/test_agent_message_schema.py`: 25 pytest tests covering all acceptance criteria

### Changed
- `docs/agent-notes-protocol.md`: Added "Message Schema (SPEC-056)" section with CLI reference,
  ContentBlock type table, and valid example JSON message

### Tests
- 25/25 passing — validate accepts valid, rejects no-id, rejects empty blocks,
  --schema valid JSON Schema, --example parseable, ContentBlock.type validated
