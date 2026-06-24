---
spec_id: SE-206
title: Agent idle detection — tui-idle equivalent
status: IMPLEMENTED
applied_at: "2026-06-24"
priority: P1
effort: M
era: 200
origin: output/research/orca-savia-20260607.md
inspiration: Orca 'orca terminal wait --for tui-idle'
---

# SE-206 — Agent Idle Detection

## Resumen
`scripts/agent-wait-idle.sh` detecta cuando un proceso de agente AI está idle (sin output nuevo), evitando timeouts fijos en overnight-sprint y code-improvement-loop.

## Motivación
overnight-sprint usa sleep fijos. Si el agente termina antes → tiempo perdido. Si tarda más → siguiente task inyectado con agente ocupado.

## Scope
1. `scripts/agent-wait-idle.sh` — polling de I/O via /proc/PID/fdinfo o log mtime
2. `docs/rules/domain/agent-idle-protocol.md`
3. overnight-sprint SKILL.md: mención de agent-wait-idle.sh

## AC
- AC1: exit 0 = idle, exit 1 = timeout, exit 2 = PID muerto
- AC2: --idle-threshold y --timeout configurables
- AC3: --json output para parsing programático
- AC4: overnight-sprint SKILL referencia el script
