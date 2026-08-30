---
name: overnight-sprint
description: Usar cuando se quiere ejecutar tareas de bajo riesgo de forma autónoma durante la noche.
metadata:
  # --- metadata.savia.* (SE-333) ---
  savia.agent: dev-orchestrator
  savia.category: sdd-framework
  savia.context: fork
    savia.loop_level: L2  # L0=draft | L1=report-only | L2=assisted | L3=unattended — ver docs/rules/domain/loop-phasing.md
  savia.maturity: experimental
  savia.priority: medium
  savia.summary: "Sprint autonomo nocturno: ejecuta tareas de bajo riesgo en bucle. Genera PRs Draft en ramas agent/overnight-*. Revision humana obligatoria al dia siguiente."
  savia.tags: "autonomous, overnight, batch, low-risk"
---

## Subagent Scope Guard

> If you were dispatched as a subagent to execute a specific delegated task,
> **skip this skill's full orchestration workflow**. Execute only the assigned
> task, report result (DONE / DONE_WITH_CONCERNS / BLOCKED), and return.
> This guard prevents runaway skill activation in nested agent contexts.

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
2. Doble opt-in (SPEC-186):                                  → si no: ❌ ABORT
   bash scripts/savia-double-optin-check.sh \
     --skill overnight-sprint --confirm-autonomous
   Requiere AMBOS: OVERNIGHT_SPRINT_ENABLED=true Y flag explicito.
3. Hay tareas etiquetadas como overnight-safe en el backlog  → si no: ⚠️ nada que hacer
4. Tests del proyecto pasan en estado actual (baseline)      → si no: ❌ ABORT
5. Auto Mode activado (claude --enable-auto-mode)            → si no: ⚠️ warning, continuar
```

## Auto Mode — Red de seguridad complementaria

`claude --enable-auto-mode` añade un classifier pre-tool-call que bloquea
acciones destructivas (rm masivo, exfiltración, código malicioso) sin detener
el bucle autónomo. Complementa `autonomous-safety.md` — no lo reemplaza.

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
  Implementar tarea → tests → ¿pasan? → PR Draft / descartar
  ↓
  Coherence Court (SE-350): registrar la tarea completada como premisa
    bash scripts/coherence-court.sh premises overnight-{YYYYMMDD} add decision \
      "task {id} completado: {desc}" --stage task-{id}
    # Gate determinista (sin LLM): verify coherente con el flujo
    bash scripts/coherence-court.sh check --flow overnight-{YYYYMMDD} --stage-output <artefacto>
  ↓ crash/timeout → contador fallos
  ↓ fallos >= MAX → ABORT
  ↓ Siguiente tarea → … → Informe → Notificar AUTONOMOUS_REVIEWER
```

## Cuándo NO usar

- Tareas de alto riesgo (arquitectura, migraciones, API pública)
- Sin reviewer humano configurado / baseline roto
- Tareas que requieren decisiones de diseño

## Formato de results.tsv

```
timestamp  tarea_id  rama  status  tests_pass  pr_url
2026-03-12T01:15:00  AB-1234  agent/overnight-…  pr-created  true  https://…
2026-03-12T02:05:00  AB-1237  agent/overnight-…  crash  -  -
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

> **Metricas**: PRs/sesion ≥5, aceptacion ≥70%, crashes ≤3. SE-206: `scripts/agent-wait-idle.sh`.

## Loop State

Este skill usa STATE.md canónico. Schema: `docs/rules/domain/loop-state-schema.md`.
Inicializar: `bash scripts/loop-state-init.sh --skill overnight-sprint`
## Modo CI Unblock (--mode ci-unblock)

Desbloquea PRs con CI roto por orden PR# ASC. Ver `CI-UNBLOCK.md`. Prerequisito: `CI_UNBLOCK_NEST_ENABLED=true` + doble opt-in SPEC-186.

```
/overnight-sprint --mode ci-unblock [--repo owner/repo] [--limit N]
```

## Token Exhaustion Recovery (SE-250)

Si una iteración falla, detectar causa antes de contar el fallo:

```bash
bash scripts/detect-token-exhaustion.sh --log "$ITER_LOG"
```

Escalación: `token_exhaustion` → subir tier (fast→mid, mid→heavy con `ALLOW_HEAVY_ESCALATION=true`).
`logic_error` o `unknown` → no escalar. Registrar `tier_escalated` en `results.tsv`.

## Feedback acotado de gates (lección SE-347 / PMA)

Un **gate** es una verificación (comando shell) que debe pasar antes de dar la
tarea por terminada. Si falla, NO repitas a ciegas:
1. Alimenta la siguiente iteración con **output acotado** del error (≤ el
   output del gate, truncado), no la traza completa.
2. Límites duros por tarea: continuations 3 · turns 12 · tokens 80k ·
   wall-clock 30min → al superarlos, ABORT y `requires-human`.
3. Mismo motivo 2 veces seguidas → detener y `GATE_STUCK`.
Ejemplo: `bash <gate>.sh && echo GATE_PASS`; si no pasa, recoge el error
acotado y reintenta UNA vez con causa distinta.

## Coherence Court (SE-350) — cableado anti-saturación

El bucle registra **automáticamente** cada tarea completada como premisa de
coherencia del flujo (`premises add decision ... --stage task-{id}`). Esto es
**determinista y sin LLM** (JSONL local en `data/coherence-premises-{flujo}.jsonl`),
por lo que no añade coste al bucle nocturno.

**NUNCA** convocar la auditoría LLM de 4 jueces por tarea — saturaría el sprint.
La auditoría completa (`/coherence-court --flow overnight-{YYYYMMDD}`) se invoca
**una vez al final del sprint** (o en la revisión E1 humana), y solo si el humano
lo pide o `COHERENCE_AUDIT_JUDGES=1`. Ver `docs/rules/domain/coherence-court.md`.

Policy:
- Gate determinista (premises + check): **siempre ON** en el bucle, coste ~0.
- Auditoría LLM (4 jueces): **opt-in al final**, nunca por tarea.
- CRIT-001: las premisas viven en texto plano local; cero red.


