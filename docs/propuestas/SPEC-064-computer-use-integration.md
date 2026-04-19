---
id: SPEC-064
title: SPEC-064 — Computer Use Integration: Live Visual QA and Accessibility Audit
status: Proposed
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-064 — Computer Use Integration: Live Visual QA and Accessibility Audit

> Status: Proposed | Author: Savia | Date: 2026-03-30
> Research: output/20260330-computer-use-research.md
> Depends on: visual-qa-agent, web-e2e-tester, e2e-screenshot-validation rule
> Related: SPEC-060-saviadivergent (body double deferred to Phase 3)

---

## Problem

Savia's visual QA and accessibility testing rely on static screenshots (visual-qa-agent) or Playwright
scripts (web-e2e-tester). Both have gaps:
- visual-qa-agent cannot INTERACT with the UI — it only analyzes pre-captured images
- web-e2e-tester requires Playwright setup and scripted test flows
- Neither can perform exploratory testing (navigate freely, discover unexpected states)
- Accessibility audits miss dynamic behaviors (focus traps, keyboard navigation, live regions)

Claude's Computer Use Tool (beta) fills these gaps by enabling live screenshot + click + type + scroll
interactions inside a sandboxed container. It does NOT replace Playwright for CI/CD — it complements it.

## Scope

### In scope
1. **Live Visual QA**: visual-qa-agent gains ability to navigate web apps, trigger states, then analyze
2. **Accessibility Keyboard Audit**: automated keyboard-only navigation to verify tab order and focus
3. **Exploratory Smoke Testing**: zero-config smoke tests for new projects without Playwright setup
4. **Container infrastructure**: Docker image with browser + Xvfb for safe Computer Use execution

### Out of scope
- Direct desktop control (security risk, container-only)
- Replacing Playwright in CI/CD pipelines (Playwright is faster and more reliable)
- SaviaDivergent body double (requires direct desktop access — deferred to Phase 3 pending Dispatch)
- IDE integration (Bash/Edit tools are already superior for code operations)

## Architecture

```
User: /visual-qa-live http://localhost:8081
  |
  v
Savia orchestrator
  |
  v
Docker container (Xvfb + Chromium + Computer Use handler)
  |
  +--> Claude API (beta: computer-use-2025-11-24)
  |      |
  |      +--> screenshot -> Claude analyzes
  |      +--> Claude returns action (click, type, scroll)
  |      +--> Handler executes action in container
  |      +--> Loop until task complete
  |
  v
Output: screenshots + findings -> output/visual-qa/{project}/
```

### Container Image

Based on Anthropic's reference implementation with additions:
- Chromium (not Firefox — better Computer Use compatibility)
- Xvfb at 1280x800 (recommended resolution per Anthropic docs)
- axe-core CLI for accessibility baseline
- Screenshot capture handler with coordinate scaling

### Agent Integration

**visual-qa-agent** gains a new mode: `--live` flag triggers Computer Use instead of static analysis.
The agent's existing scoring rubric (0-100), finding format, and output structure remain unchanged.

**web-e2e-tester** gains a `--exploratory` flag for Computer Use-based smoke testing when Playwright
is not set up. Falls back gracefully if Docker is unavailable.

## New Command

```
/visual-qa-live {url} [--viewport 1280x800] [--a11y] [--max-steps 20]
```

- Launches container, navigates to URL
- If `--a11y`: runs keyboard-only navigation audit (Tab through all elements, verify focus visible)
- Takes screenshots at each major state transition
- Outputs findings to `output/visual-qa/{project}/live-{timestamp}/`
- Max 20 steps default (prevents runaway API costs — each step is ~1K tokens)

## Accessibility Audit Protocol

1. Tab through all elements, screenshot after each. Verify: focus visible, role correct, label present
2. Enter/Space on interactive elements, verify behavior. Check for focus traps
3. Output: ordered element list with focus state, missing labels, broken tab order
4. Catches issues axe-core misses: visual focus indicators, dynamic content, keyboard traps

## Limitations (Radical Honesty)

- **Accuracy**: Claude misclicks ~10-15% of the time on small UI elements. Not suitable for
  pixel-precise interactions. Keyboard shortcuts are more reliable than mouse clicks.
- **Latency**: 3-8 seconds per action. A 20-step exploration takes 1-3 minutes. Acceptable for
  QA audits, not for rapid iteration.
- **Cost**: ~1K tokens per step (screenshot + reasoning). 20 steps = ~20K tokens = ~$0.06 (Sonnet).
  Budget-aware: respect agent-context-budget protocol.
- **Beta**: Computer Use is beta. Coordinate accuracy may degrade on complex UIs. Dropdowns and
  overlays are known weak points. Results should be treated as advisory, not definitive.
- **Container only**: Cannot inspect user's actual desktop. Web apps must be accessible via URL
  from inside the container (localhost needs Docker network bridge).

## Security

- Container runs with minimal privileges (no host filesystem access)
- Network restricted to target URL + Anthropic API (allowlist)
- No login credentials stored in container (passed via env vars if needed)
- Prompt injection risk: web content can influence Claude's actions — container isolation mitigates
- All screenshots stored locally in output/ (gitignored), never transmitted externally

## Implementation Phases

### Phase 1 — Container + Basic Navigation (1 sprint)
- Dockerfile based on Anthropic reference implementation
- Computer Use handler (screenshot, click, type, scroll, coordinate scaling)
- `/visual-qa-live` command with basic navigation and screenshot capture
- Integration with visual-qa-agent scoring

### Phase 2 — Accessibility Audit (1 sprint)
- Keyboard-only navigation protocol
- Focus state detection via screenshots
- axe-core baseline comparison
- Integration with a11y-audit and a11y-report commands

### Phase 3 — SaviaDivergent Visual Guide (future, depends on Dispatch)
- IF Anthropic's Dispatch matures to allow safe desktop access:
  - Annotated screenshot guidance for guided-work-protocol
  - Visual "body double" check-ins (screenshot context, not continuous monitoring)
  - This phase is speculative and deferred until Dispatch exits research preview

## Success Criteria

- visual-qa-agent --live finds >= 80% of visual defects found by manual QA on test app
- Accessibility audit correctly identifies tab order for >= 90% of interactive elements
- Zero security incidents from container escapes in 30 days of use
- Average exploration cost < $0.10 per session (< 30 steps)

## Token Budget

~2K setup + ~1K/step + ~3K analysis. 20-step session = ~25K tokens (Sonnet 4.6). Fits dev-session budget.

## References

- [Computer Use Tool API](https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool)
- [Anthropic Reference Implementation](https://github.com/anthropics/anthropic-quickstarts/tree/main/computer-use-demo)
- Agents: visual-qa-agent.md, web-e2e-tester.md | Rule: e2e-screenshot-validation.md
- Related: SPEC-060-saviadivergent.md
