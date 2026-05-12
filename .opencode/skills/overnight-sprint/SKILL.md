---
name: overnight-sprint
description: Modo autónomo nocturno — ejecuta tareas de bajo riesgo en bucle, genera PRs pendientes de revisión humana
summary: |
  Sprint autonomo nocturno: ejecuta tareas de bajo riesgo en bucle.
  Genera PRs Draft en ramas agent/overnight-*.
  Revision humana obligatoria al dia siguiente.
maturity: experimental
context: fork
agent: dev-orchestrator
category: "sdd-framework"
tags: ["autonomous", "overnight", "batch", "low-risk"]
priority: "medium"
---

# Skill: Overnight Sprint

> **Regla de seguridad**: `@docs/rules/domain/autonomous-safety.md` — NUNCA merge, SIEMPRE PR Draft con reviewer humano.

## Cuándo usar esta skill

- Hay tareas de bajo riesgo acumuladas (fix de linter, mejora de tests, documentación, refactoring menor)
- El equipo quiere aprovechar horas no laborables para avanzar trabajo mecánico
- Se busca generar PRs listos para revisión humana al inicio del siguiente día

## Qué produce

1. **PRs en Draft** — uno por tarea completada, asignados a `AUTONOMOUS_REVIEWER`
2. **results.tsv** — registro de cada intento: `output/overnight-results-{YYYYMMDD}.tsv`
3. **Informe resumen** — `output/overnight-summary-{YYYYMMDD}.md`
4. **Audit log** — `output/agent-runs/overnight-{YYYYMMDD}-audit.log`

## Prerequisitos (gate de arranque)

```
1. AUTONOMOUS_REVIEWER configurado en pm-config.local.md    → si no: ❌ ABORT
2. OVERNIGHT_SPRINT_ENABLED = true                           → si no: ❌ ABORT
3. Hay tareas etiquetadas como overnight-safe en el backlog  → si no: ⚠️ nada que hacer
4. Tests del proyecto pasan en estado actual (baseline)      → si no: ❌ ABORT
5. Auto Mode activado (claude --enable-auto-mode)            → si no: ⚠️ warning, continuar
```

## Auto Mode — Red de seguridad complementaria

Desde Claude Code 2026-03-24, el flag `--enable-auto-mode` activa un classifier
pre-tool-call que bloquea acciones potencialmente destructivas (rm masivo,
exfiltración de datos sensibles, ejecución de código malicioso) sin detener
el bucle autónomo. Es complementario a los gates de `autonomous-safety.md`
— no reemplaza `AUTONOMOUS_REVIEWER` ni `AGENT_MAX_CONSECUTIVE_FAILURES`,
añade una capa extra de defensa en profundidad.

Activar: `claude --enable-auto-mode` al lanzar la sesión que invoca esta skill,
o desde Desktop/VS Code Settings → Claude Code → Auto Mode.

## Flujo completo

```
Humano ejecuta /overnight-sprint
    ↓
Validar prerequisitos (reviewer, enabled, tareas, baseline tests)
    ↓
Mostrar lista de tareas candidatas → PEDIR CONFIRMACIÓN HUMANA
    ↓
[Humano confirma] → Registrar baseline de métricas
    ↓
LOOP (hasta max_tasks o max_failures o fin de tareas):
  ↓
  Tomar siguiente tarea del backlog
  ↓
  Crear rama: agent/overnight-{YYYYMMDD}-{tarea_id}
  ↓
  Crear worktree aislado
  ↓
  Implementar tarea (time-box: AGENT_TASK_TIMEOUT_MINUTES)
  ↓
  Ejecutar tests
  ↓
  ¿Tests pasan Y métricas no degradan?
    SÍ → Crear PR Draft con reviewer → registrar en results.tsv como "pr-created"
    NO → Descartar rama → registrar como "discarded"
  ↓
  ¿Crash o timeout?
    SÍ → Registrar como "crash" o "timeout" → incrementar contador de fallos
  ↓
  ¿Fallos consecutivos >= AGENT_MAX_CONSECUTIVE_FAILURES?
    SÍ → ABORT → registrar razón
  ↓
  Siguiente tarea
    ↓
Generar informe resumen
    ↓
Notificar a AUTONOMOUS_REVIEWER
```

## Cuándo NO usar

- Para tareas de alto riesgo (cambios de arquitectura, migraciones, cambios de API pública)
- Si no hay un reviewer humano configurado
- Si los tests del proyecto no pasan (baseline roto)
- Para tareas que requieren decisiones de diseño (el agente NO decide arquitectura)

## Formato de results.tsv

```tsv
timestamp	tarea_id	rama	status	tests_pass	metricas_delta	pr_url	descripcion
2026-03-12T01:15:00	AB-1234	agent/overnight-20260312-fix-lint	pr-created	true	coverage:+2.1%	https://...	Fix linter warnings in auth module
2026-03-12T01:32:00	AB-1235	agent/overnight-20260312-add-tests	pr-created	true	coverage:+5.3%	https://...	Add unit tests for user service
2026-03-12T01:48:00	AB-1236	agent/overnight-20260312-refactor-dto	discarded	true	complexity:+0.2	-	Refactor DTOs - complexity increased
2026-03-12T02:05:00	AB-1237	agent/overnight-20260312-update-deps	crash	-	-	-	Dependency update caused build failure
```

## Restricciones estrictas

```
NUNCA → Hacer merge de un PR
NUNCA → Aprobar un PR
NUNCA → Hacer commit en rama de humano (main, develop, feature/*)
NUNCA → Crear tareas en el backlog
NUNCA → Modificar configuración del proyecto
NUNCA → Instalar dependencias nuevas sin que estén en la tarea
SIEMPRE → PR en Draft con AUTONOMOUS_REVIEWER asignado
SIEMPRE → Ramas agent/overnight-*
SIEMPRE → Registrar CADA intento en results.tsv
SIEMPRE → Generar audit log
```

## Métricas de éxito

| Métrica | Objetivo |
|---------|----------|
| PRs creados por sesión | ≥ 5 |
| Tasa de aceptación (PRs merged por humano) | ≥ 70% |
| Crashes por sesión | ≤ 3 |
| Tiempo medio por tarea | ≤ AGENT_TASK_TIMEOUT_MINUTES |
