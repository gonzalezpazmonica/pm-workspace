---
version_bump: minor
section: Added
---

### Added

- SPEC-142: OpenCode plugin auto-redact-credentials uses tool.execute.before to mutate args before tool execution. Redacts GitHub/OpenAI/Anthropic/AWS tokens and connection strings before they reach the LLM. Integrated into savia-foundation plugin chain. Includes TS Vitest tests and BATS smoke tests.

