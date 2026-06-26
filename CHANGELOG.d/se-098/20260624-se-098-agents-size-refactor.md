---
spec_id: SE-098
date: 2026-06-24
type: refactor
---

# SE-098 — Split top-5 oversized agents

## Summary

Refactored top-5 largest agents to comply with Rule #22 (<4096B SLA).
All 5 agents now under the 4096B SLA limit.

## Changes

### Agents refactored

| Agent | Before | After | Reduction |
|---|---|---|---|
| truth-tribunal-orchestrator | 7659B / 198L | 3754B / 84L | -51% |
| code-reviewer | 6890B / 148L | 3949B / 80L | -43% |
| security-guardian | 6552B / 136L | 3724B / 91L | -43% |
| test-runner | 6540B / 142L | 3243B / 75L | -50% |
| commit-guardian | 6508B / 149L | 4128B / 100L | -37% |

### Reference files created

- `.opencode/agents/references/truth-tribunal-orchestrator-tiered.md` — tiered execution config
- `.opencode/agents/references/truth-tribunal-orchestrator-output-schema.md` — .truth.crc schema
- `.opencode/agents/references/code-reviewer-report-format.md` — report format template
- `.opencode/agents/references/security-guardian-report-format.md` — audit report format
- `.opencode/agents/references/commit-guardian-report-format.md` — pre-commit report format

### New scripts

- `scripts/agents-size-checker.sh` — lists agents by size, WARN >200L, FAIL >400L, supports --json

### Tests

- `tests/bats/test-se-098-agents-size.bats` — 7 tests, all passing

## Technique

Verbose YAML schemas, ASCII art report formats, and multi-paragraph policy sections
extracted to `references/` files. Agent core instructions preserved intact.
Agents remain functionally equivalent — only documentation verbosity reduced.
