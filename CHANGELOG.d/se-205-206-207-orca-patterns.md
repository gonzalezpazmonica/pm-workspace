# SE-205/206/207 — Orca patterns for Savia

Date: 2026-06-07
PR: #828
Origin: output/research/orca-savia-20260607.md

## SE-205 — Typed orchestration protocol (P1)
- scripts/orchestration-protocol.sh: task-create/dispatch/send/check/status
- Message types: worker_done, escalation, heartbeat, decision_gate
- JSON file persistence in .savia/orchestration/ (no external deps)
- Circuit breaker: 3 failures -> task=failed
- docs/rules/domain/orchestration-protocol.md

## SE-206 — Agent idle detection (P1)
- scripts/agent-wait-idle.sh: poll /proc/PID/fdinfo or log mtime
- exit 0=idle, 1=timeout, 2=dead, 3=arg error
- --idle-threshold, --timeout, --json flags
- .claude/skills/overnight-sprint/SKILL.md: references agent-wait-idle.sh
- docs/rules/domain/agent-idle-protocol.md

## SE-207 — Lightweight Eng Review template (P2)
- docs/rules/domain/lightweight-eng-review.md: rule + criteria LER vs SDD
- docs/templates/lightweight-eng-review.md: copy-paste template (9 sections)

Tests: 41 new (21 SE-205 + 20 SE-206)
Specs: docs/propuestas/SE-205..207.md (APPROVED)
