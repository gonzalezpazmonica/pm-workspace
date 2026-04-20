---
id: SE-045
title: SE-045 — Session-init split fast-path sync + bootstrap async
status: ENTERPRISE_ONLY
scope: savia-enterprise
origin: output/audit-arquitectura-20260420.md (architect audit)
author: Savia
priority: Critica (Enterprise) · N/A (dev)
effort: M 12h
gap_link: Latency session-init 468ms vs SLA 20ms (solo en deployments con daemons activos)
approved_at: null
applied_at: null
decision_note: "2026-04-20 — Aplicable a deployments Savia Enterprise con Ollama/Shield/bridge activos. NO aplicar en maquinas dev sin capacidad de inferencia — el coste de latencia (300-500ms) es aceptado por no justificar cambio en hook critico."
expires: "2026-05-20"
---

# SE-045 — Session-init split fast-path sync + bootstrap async

## Scope

**Aplica solo a deployments Savia Enterprise** donde Ollama, Shield daemon y/o bridge estan activos localmente y los curl probes a `127.0.0.1:11434/8444/8443` completan rapido. En esas maquinas, cachear el estado evita latencia acumulada por sesion.

**NO aplica a maquinas de desarrollo sin capacidad de inferencia** (caso del ordenador de la usuaria): los daemons no existen, los timeouts expiran, pero el coste se considera aceptable frente al riesgo de modificar un hook critico en entorno single-user.

## Purpose

Hook critico fuera de SLA por 23x en deployments Enterprise. Impact directo UX de usuarias de Savia Enterprise en cada arranque. Split fast-path sincrono menor a 20ms + lazy async con cache TTL 5 min.

**Gap enlazado**: Latency session-init 468ms vs SLA 20ms (ver audit-arquitectura-20260420.md). Nota: el 468ms medido en maquina dev se debe a curl timeouts de daemons ausentes, no a daemons lentos.

## Objective

Unico y medible: cerrar el gap descrito con Slice 1 scaffolding + BATS tests.

## Slicing

- **Slice 1**: probe/scaffolding + BATS tests (≥15 tests, ≥80 auditor score).
- **Slice 2**: implementacion enforcement o integracion.
- **Slice 3**: rollout + deprecation de comportamiento anterior si aplica.

## Acceptance criteria

- Script ejecutable con --help, --json, exit codes 0/1/2.
- Tests BATS con isolation guards (read-only, no side effects en repo).
- Documentacion en docs/rules/domain/ si aplica (≤150 lineas).

## Refs

- audit-arquitectura-20260420.md §Matriz de desincronizaciones
- audit-new-specs-20260420.md §SE-045
- audit-roadmap-reprioritization-20260420.md
