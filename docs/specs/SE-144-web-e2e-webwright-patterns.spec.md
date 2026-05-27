# SE-144 — Web E2E Tester: adopt Webwright architectural patterns

**Status**: APPROVED
**Date**: 2026-05-26
**Author**: Savia (OpenCode)
**Branch**: feature/SE-144-web-e2e-webwright-patterns

---

## Problem

The current `web-e2e-tester` agent runs `npx playwright test` against a pre-written
test suite and reports pass/fail. This works for regression but has three limitations:

1. **No adaptive exploration**: cannot test flows not already in the suite.
2. **No visual self-verification**: screenshots are captured on failure but never
   evaluated — a human must inspect them.
3. **No reusable artefacts**: each run produces transient output; nothing is left
   that CI or another agent can re-execute with different parameters.

---

## Solution

Adopt three architectural patterns from microsoft/Webwright (MIT, 2026) — without
importing its codebase or its bugs:

| Pattern | Webwright origin | Savia adaptation |
|---|---|---|
| **Workspace-as-state** | `outputs/<task_id>/final_script.py` | `output/web-tasks/<task_id>/final_script.py` |
| **Write → Execute → Inspect → Repair loop** | Agent loop in `DefaultAgent.run()` | Explicit phases 3a–3d in the agent protocol |
| **Self-reflection gate** | `self_reflect_result.json` checked before `done=true` | Inline 2-stage judge using the host model (no OPENAI_API_KEY) |

No new Python dependencies. No external API calls. Playwright is already available.
The self-reflection uses the model already active in the OpenCode session.

---

## Acceptance Criteria

- [ ] AC-1: Agent protocol has explicit Write→Execute→Inspect→Repair loop (phases 3a–3d)
- [ ] AC-2: Each task run produces `output/web-tasks/<task_id>/` with:
  - `plan.md` — critical points checklist
  - `script.py` — parametrizable Playwright script
  - `run_log.txt` — stdout/stderr of the execution
  - `screenshots/` — one per action
- [ ] AC-3: Before marking a task done, agent runs self-reflection: evaluates each
  screenshot against the critical points and requires all points met
- [ ] AC-4: Self-reflection uses the host model (OpenCode) — zero external API calls
- [ ] AC-5: Existing regression suite flow (Phase 2, `npx playwright test`) is preserved
- [ ] AC-6: Agent file stays ≤150 lines (Rule 11)
- [ ] AC-7: AGENTS.md regenerated after agent file change

---

## Out of scope

- Importing Webwright as a Python dependency
- `image_qa` tool (requires OPENAI_API_KEY — Webwright bug #3)
- Task2UI mode (Webwright feature, not needed for Savia use case)
- Changes to `web-e2e-tester` tools or permission_level

---

## OpenCode Implementation Plan

### Classification
- **Type**: agent-enhancement
- **Risk**: LOW — additive changes to existing agent prompt; no code execution changes
- **Reversible**: YES — single file change

### Slices

| Slice | File | Description |
|---|---|---|
| S1 | `.opencode/agents/web-e2e-tester.md` | Rewrite agent protocol with Webwright patterns |

### Verification
```bash
# Check line count stays within Rule 11
wc -l .opencode/agents/web-e2e-tester.md   # must be ≤ 150

# Check AGENTS.md regenerated
grep "web-e2e-tester" AGENTS.md
```
