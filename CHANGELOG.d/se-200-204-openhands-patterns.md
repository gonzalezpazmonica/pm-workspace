# SE-200..204 — OpenHands patterns for Savia

Date: 2026-06-07
PR: #827
Origin: output/research/openhands-savia-20260607.md

## SE-200 — LLM Condenser (rolling window context compression)
- scripts/context-condenser.sh + context-condenser.py
- docs/rules/domain/context-condenser-protocol.md
- Config: SAVIA_CONDENSER_MAX_SIZE=120, KEEP_HEAD=4, KEEP_TAIL=60

## SE-201 — Critic scoring in tribunals
- scripts/tribunal-critic.sh: score 0-100 (correctness+completeness+security+spec_compliance)
- court-orchestrator.md updated with critic cycle
- .savia/tribunal-scores.jsonl for score history

## SE-202 — Agent-based semantic hooks
- scripts/agent-hook-runner.sh: LLM gate, exit 0=allow/2=deny
- docs/rules/domain/agent-hook-protocol.md
- settings.json: SE-202 pattern documented

## SE-203 — Keyword triggers for skills
- 10 skills annotated with trigger.keywords
- scripts/skill-keyword-detector.sh: case-insensitive, --list, --json
- docs/rules/domain/skill-trigger-map.md

## SE-204 — Evaluation harness
- tests/evals/: 9 eval cases for sdd-spec-writer, court-orchestrator, business-analyst
- scripts/run-agent-evals.sh: structure validation + report generation

Tests: 106 new (24+18+20+26+18) across 5 BATS suites
Specs: docs/propuestas/SE-200..204.md (APPROVED)
SCM: 556 commands, 103 skills, 72 agents, 498 scripts
