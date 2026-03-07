# Changelog — pm-workspace

## [2.44.0] — 2026-03-07

### Added — Era 73: PM-Workspace as MCP Server

Expose project state as MCP server. External tools can query projects, tasks, metrics and trigger PM operations.

- **`/mcp-server-start {mode}`** — Start MCP server: local (stdio) or remote (SSE). Optional `--read-only`.
- **`/mcp-server-status`** — Server status: connections, requests, uptime.
- **`/mcp-server-config`** — Configure exposed resources, tools, and prompts.
- **`pm-mcp-server` skill** — 6 resources, 4 tools, 3 prompts. Token auth for remote, read-only mode.

---

## [2.45.0] — 2026-03-07

### Added — Era 74: Session Recording

Record, replay, and export agent sessions for auditing, documentation, and training.

- **`/record-start`** — Begin recording all session actions. Creates unique session ID, stores events in JSONL format.
- **`/record-stop`** — Stop recording. Summary: duration, events count, files modified.
- **`/record-replay {session-id}`** — Replay recorded session with timeline. Chronological view of all actions performed.
- **`/record-export {session-id}`** — Export as markdown report to output/recordings/. Includes timeline, decisions, modified files, commands executed.
- **`session-recording` skill** — Records commands executed, files modified, API calls made, decisions taken, agent-notes generated, with timestamps. Storage: `data/recordings/{session-id}.jsonl` (one event per line). Use cases: compliance audit, onboarding training, postmortem analysis, documentation of complex operations.

---

# Changelog — pm-workspace

