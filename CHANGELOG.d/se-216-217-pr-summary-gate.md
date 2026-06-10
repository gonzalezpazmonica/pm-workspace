# SE-216/217 + pr-summary-gate hook

**Date:** 2026-06-10
**PR:** #833

## SE-217 — autoresearch patterns (karpathy/autoresearch, MIT)

scripts/agent-run-log.sh: TSV keep/discard/crash log per autonomous experiment
scripts/agent-surface-guard.sh: declare editable/readonly/forbidden file surface per run
scripts/agent-time-budget.sh: fixed time budget enforcer with BUDGET_STATUS output
tests/test-se-217-{agent-run-log,surface-guard,time-budget}.bats: 51 tests

## SE-216 Slices 1-3 — evo patterns (evo-hq/evo, Apache-2.0)

scripts/agent-scratchpad.sh: shared structured scratchpad for multi-agent sessions
scripts/agent-gate.sh: inherited quality gates pre/post with cascade
scripts/frontier-strategy.sh: 5 selection strategies (argmax, top_k, epsilon_greedy, softmax, pareto_per_task)
tests/test-se-216-{agent-scratchpad,agent-gate,frontier-strategy}.bats: 59 tests

## pr-summary-gate hook

.claude/hooks/pr-summary-gate.sh: PreToolUse hook that blocks gh pr create unless
.pr-summary.md passes LLM quality review (no jargon, user-facing prose, heading,
mtime < 24h). Fixes root cause: G_SUMMARY gate was opt-in via /pr-plan only.
.claude/settings.json: registered matcher Bash(gh pr create*)

docs/propuestas/SE-216-evo-patterns.md, SE-217-autoresearch-patterns.md: spec docs
