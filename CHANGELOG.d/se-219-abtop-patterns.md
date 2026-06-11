# SE-219 — abtop patterns: 5 observability scripts

**Date:** 2026-06-11
**PR:** #835

## SE-219 S1 — session-status.sh

scripts/session-status.sh: consultable JSON snapshot of current session
(actions_total, actions_pass, actions_fail, consecutive_failures, last_action, session_id)
Inspiration: abtop --json one-shot snapshot pattern

## SE-219 S2 — context-meter.sh

scripts/context-meter.sh: context window % as first-class metric
(env vars → snapshot JSON → fallback; --threshold-warn/critical configurable)
Inspiration: abtop context window gauge with compaction detection

## SE-219 S3 — session-cleanup.sh

scripts/session-cleanup.sh: register/list/cleanup/orphans for child processes
(SIGTERM → sleep → SIGKILL; exit 0 always; output/.session-pids-*.json)
Inspiration: abtop orphan port/process detection

## SE-219 S4 — profile-discover.sh

scripts/profile-discover.sh: auto multi-profile discovery (~/.claude + ~/.claude-*)
(sessions/ + projects/ criterion; CLAUDE_EXTRA_PROFILE_DIRS; --json)
Inspiration: abtop multi-profile auto-discovery by naming convention

## SE-219 S5 — agent-tick.sh

scripts/agent-tick.sh: light/heavy tick separation in autonomous loops
(AGENT_HEAVY_TICK_INTERVAL throttle; --mode light|heavy; --status; exit 0 always)
Inspiration: abtop App::tick_no_summaries() — separate cheap reads from LLM calls
Note: overnight-sprint/code-improvement-loop integration requires human review
