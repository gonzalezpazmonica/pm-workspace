---
spec_id: SE-205
title: Typed inter-agent orchestration protocol
status: IMPLEMENTED
applied_at: "2026-06-24"
priority: P1
effort: M
era: 200
origin: output/research/orca-savia-20260607.md
inspiration: Orca worker_done/dispatch/escalation/gates RPC+SQLite pattern
---

# SE-205 — Orchestration Protocol Tipado (patrón Orca)

## Resumen
Reemplazar el texto libre de agent-notes con mensajes tipados entre agentes: `worker_done`, `escalation`, `heartbeat`, `decision_gate`. Persistidos en JSON files bajo `.savia/orchestration/`. CLI via `scripts/orchestration-protocol.sh`.

## Motivación
El agent-notes-protocol.md usa texto libre. Cuando court-orchestrator coordina 4-6 agentes en paralelo, los handoffs son frágiles: sin circuit breaker real, sin task states verificables, sin heartbeat para tareas largas.

## Scope
1. `scripts/orchestration-protocol.sh` — CLI completo con task-create/dispatch/send/check/status
2. `docs/rules/domain/orchestration-protocol.md` — protocolo canónico
3. Integración en agent-notes-protocol.md

## AC
- AC1: `task-create` genera task_id único
- AC2: `send --type worker_done` crea mensaje JSON estructurado
- AC3: `check --wait --types worker_done` bloquea hasta recibir mensaje
- AC4: Circuit breaker: 3 fallos consecutivos → task=failed
- AC5: Todas las operaciones usan JSON files, sin deps externas
