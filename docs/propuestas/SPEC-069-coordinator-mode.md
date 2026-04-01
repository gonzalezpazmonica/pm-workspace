# SPEC-069: Coordinator Mode Exploration

**Status**: Research | **Date**: 2026-04-01 | **Era**: 168

---

## Discovery

Architecture review (2026-03-31) found two undocumented env vars:
- `CLAUDE_CODE_COORDINATOR_MODE` — multi-agent coordination
- `CLAUDE_CODE_PROACTIVE` — autonomous/proactive agent mode

## Investigation Results

### CLAUDE_CODE_COORDINATOR_MODE

Not documented in official Claude Code docs. Found in source code analysis.
Likely enables native TeamCreate/SendMessage orchestration patterns.

**Current pm-workspace approach**: Manual orchestration via `Task` tool +
agent frontmatter + dag-scheduling skill.

**If coordinator mode works**: Could simplify overnight-sprint and
dev-session orchestration significantly — native multi-agent without
custom Task orchestration.

**Risk**: Undocumented feature. May change without notice.

### CLAUDE_CODE_PROACTIVE

Enables agent to take actions without explicit user request.
Potentially useful for:
- Overnight sprint (agent works autonomously on task list)
- Background monitoring (watch for CI failures, alert)
- Auto-suggest (proactive skill activation)

**Risk**: Conflicts with Rule #8 (human approval for irreversible actions).
Must be combined with autonomous-safety.md guardrails.

## Recommendation

**Phase 1 (now)**: Document findings. Do NOT enable in production.
**Phase 2 (when documented)**: Test in isolated worktree with safe tasks.
**Phase 3 (if stable)**: Integrate into overnight-sprint with guardrails.

## Blockers

Both features are undocumented. Enabling them in production without
understanding their behavior would violate our "investigate before act"
principle. Wait for official documentation or community validation.

## Related

- `autonomous-safety.md` — guardrails for autonomous operations
- `overnight-sprint` skill — primary beneficiary of coordinator mode
- `dag-scheduling` skill — could be simplified if coordinator works
