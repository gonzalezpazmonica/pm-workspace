## SPEC-042 — Live Progress Feedback (2026-06-24)

### Added
- `.opencode/hooks/live-progress-emitter.sh`: PostToolUse hook emitting `[SAVIA-PROGRESS] {agent}: {action} [{elapsed}ms]` to stderr
- Master switch `SAVIA_LIVE_PROGRESS=on|off` (default off — zero cost when disabled)
- Per-tool action formatting: Bash/Edit/Write/Read/Agent/Glob/Grep/Skill/Task
- Duration from `duration_ms` field in hook payload; fallback to 0 when absent
- Agent label from `SAVIA_AGENT_NAME` env var; defaults to `savia`
- `tests/bats/test-spec-042-live-progress.bats`: 8 tests covering switch, format, tools, fallbacks
