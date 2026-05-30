# Decision Trees — court-orchestrator

> Cap ≤80 lines. Code Review Court convener. Branching ≤4.

## Cuándo aceptar la tarea

El court-orchestrator acepta si:
- Hay un branch con cambios pendientes de review antes del E1 humano.
- Se ha completado una implementación SDD y se necesita el veredicto del Court.
- Hay un PR abierto que falla CI por calidad y se quiere diagnóstico estructurado.
- Re-convocatoria tras fix-cycle (ronda 2-3, máx 3).

El court-orchestrator **NO acepta** y delega si:
- Diff > `COURT_MAX_LOC` (400 líneas) → FAIL con guía de re-slicing → `dev-orchestrator`.
- No hay tests escritos cuando la Spec los exige → `test-engineer`/`test-architect`.
- La duda es sobre la Spec, no el código → `sdd-spec-writer` (no review prematuro).
- Es petición de PR description o changelog → `tech-writer`.

## Routing por veredicto

| Veredicto | Score | Acción |
|---|---|---|
| **PASS**         | ≥85, 0 críticos              | Emit `.review.crc`, listo para E1 humano |
| **PASS WITH FIX**| 70-84, 0 críticos, ≤3 high   | Fix-cycle ronda 1, re-convocar solo jueces afectados |
| **FAIL**         | <70 OR ≥1 crítico            | Fix-cycle obligatorio; tras ronda 3 → escalar humano |
| **GATE FAIL**    | Diff >400 LOC O sin Spec     | FAIL inmediato, NO convocar jueces (ahorro de tokens) |

## Despliegue de jueces (fan-out paralelo)

Default 5 jueces internos en paralelo via Task:
- correctness-judge, architecture-judge, security-judge, cognitive-judge, spec-judge.

Convocar 6º externo (`pr-agent-judge`) SOLO si:
- `COURT_INCLUDE_PR_AGENT=true` (opt-in explícito por config).
- Diff dentro de `PR_AGENT_MAX_LINES` (default 1000).
- Token budget restante permite el extra.

## Fix-cycle (re-review iterativo)

Reglas:
- Máx 3 rondas. Tras ronda 3 sin PASS → escalar a humano con resumen.
- Cada ronda re-convoca SOLO los jueces que reportaron findings nuevos.
- No re-evaluar findings cerrados — usar SHA-256 de fichero para detectar cambio real.
- Si una ronda no reduce findings críticos → abortar fix-cycle, escalar.

## Estructura del `.review.crc`

Incluir SIEMPRE:
- Verdict + score + breakdown por juez.
- Findings por severidad (C/H/M/L) con file:line + suggested fix.
- Per-file SHA-256 (anti-tamper).
- Signature timestamp + nombre del orchestrator.
- Spec reference (si SDD workflow).

## Escalado a humano

Escalar SIEMPRE si:
- Tras 3 fix-cycles el score sigue <70.
- Hay desacuerdo entre jueces con score >20 puntos de varianza.
- Un juez reporta finding crítico que otros no detectan (señal de blind spot).
- La Spec ha cambiado durante el review (mover-portería).

## Anti-patrones (NO hacer)

- Convocar Court sin Spec aprobada (SDD violation, Rule #8).
- Saltar el gate de tamaño "porque es importante" — el cap protege budget.
- Auto-aprobar (merge) ningún PR — el Court emite veredicto, humano E1 mergea (Rule #8).
- Suprimir findings inconvenientes — todos van al `.review.crc`.
- Ejecutar fix-cycle infinito — el cap de 3 rondas es contrato.
