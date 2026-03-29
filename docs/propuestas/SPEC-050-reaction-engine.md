# SPEC-050: Reaction Engine for SDD Pipeline

> Status: **DRAFT** | Fecha: 2026-03-30
> Origen: ComposioHQ/agent-orchestrator — declarative reaction system
> Impacto: Cierre automatico del feedback loop CI/review en dev-sessions

---

## Problema

Cuando un agente SDD abre un PR y el CI falla o un reviewer pide cambios,
hoy no hay mecanismo automatico para re-inyectar ese feedback al agente.
El flujo se detiene hasta que el humano interviene manualmente. Consecuencias:

- PRs con CI rojo quedan abandonados hasta la proxima sesion
- Comentarios de code review no llegan al agente que implemento
- No hay retries configurables ni escalacion automatica
- El humano hace de router manual entre GitHub y el agente

agent-orchestrator resuelve esto con un sistema de reacciones declarativas:
eventos (ci-failed, changes-requested) se mapean a acciones (send-to-agent,
notify, auto-merge) con retries y escalacion. pm-workspace tiene los
handoff-templates pero no cierra el loop automaticamente.

---

## Arquitectura

### Configuracion declarativa (por proyecto)

```yaml
# projects/{p}/reactions.yaml
reactions:
  ci-failed:
    auto: true
    action: send-to-agent    # re-invocar agente con CI logs
    retries: 2
    escalate_after: 3         # tras 3 intentos → humano
  changes-requested:
    auto: true
    action: send-to-agent    # re-invocar con review comments
    retries: 1
    escalate_after: 2
  approved-and-green:
    auto: false               # notificar, no auto-merge (Rule #5)
    action: notify
  agent-stuck:
    threshold: "15m"
    action: notify
    priority: urgent
```

### Eventos detectables

| Evento | Fuente | Deteccion |
|--------|--------|-----------|
| ci-failed | GitHub Actions / Azure Pipelines | gh pr checks --json |
| changes-requested | GitHub PR review | gh pr view --json reviews |
| approved-and-green | PR aprobado + CI verde | Combinacion de ambos |
| agent-stuck | Timeout sin actividad | dev-session state.json |
| merge-conflicts | PR no mergeable | gh pr view --json mergeable |

### Flujo de reaccion

```
1. Hook post-push detecta PR abierto por agente
2. Poller (cada 60s) consulta estado CI + reviews
3. Si evento detectado → buscar reaccion en reactions.yaml
4. Si auto=true → ejecutar accion:
   - send-to-agent: reinyectar contexto via Task al developer agent
   - notify: alertar al humano via canal configurado
5. Incrementar contador de retries
6. Si retries >= escalate_after → escalar a humano (Escalation handoff)
7. Si estado cambia (ej: ci-failed → ci-passing) → reset contadores
```

### Integracion con handoff-templates

La reaccion `send-to-agent` usa el template QA Fail (handoff #3) para
estructurar el feedback al agente. Campos requeridos: failures[], attempt,
context. La reaccion `escalate` usa el template Escalation (handoff #4).

---

## Integracion

### Con dev-session-protocol.md

El reaction engine se activa en Fase 5 (Integrate & Review). Cuando el
agente abre PR, el engine monitorea hasta merge o escalacion.

### Con autonomous-safety.md

Las reacciones respetan Rule #5 (humano decide): auto-merge esta
DESHABILITADO por defecto. Solo notify + send-to-agent son auto.

### Con parallel-execution.md

En ejecucion paralela, cada agente tiene su propio tracker de reacciones
(por sessionId). Las reacciones no interfieren entre agentes.

---

## Restricciones

- NUNCA auto-merge sin confirmacion humana (autonomous-safety.md)
- Retries maximos configurables, default 2 para CI, 1 para reviews
- Escalacion obligatoria tras max retries (handoff Escalation)
- El poller NO se ejecuta en contexto principal — es un script background
- reactions.yaml es opcional; sin el, comportamiento actual (manual)
- Budget por reintento: mismo budget que el agente original

---

## Implementacion por fases

### Fase 1 — Deteccion de eventos (~2h)
- [ ] Script `scripts/reaction-poller.sh`: consulta CI + reviews de PRs abiertos
- [ ] Parseo de reactions.yaml por proyecto. Test: detectar ci-failed en PR mock

### Fase 2 — Ejecucion de reacciones (~2h)
- [ ] send-to-agent: reinvocar developer agent con contexto de fallo
- [ ] notify: mostrar alerta. Test: CI fail → agente recibe logs → fix → CI pasa

### Fase 3 — Escalacion + metricas (~1h)
- [ ] Contador de retries con reset en cambio de estado
- [ ] Escalacion a humano con handoff template. Tracking: reactions/proyecto

---

## Ficheros afectados

| Fichero | Accion |
|---------|--------|
| `scripts/reaction-poller.sh` | Crear — detector de eventos |
| `.claude/rules/domain/reaction-engine.md` | Crear — regla de reacciones |
| `.claude/rules/domain/handoff-templates.md` | Modificar — template Reaction |
| `.claude/rules/domain/dev-session-protocol.md` | Modificar — activar en Fase 5 |

---

## Metricas de exito

- PRs con CI rojo resueltos automaticamente sin intervencion humana: >60%
- Tiempo medio entre CI fail y fix re-push: <10min (vs horas hoy)
- Escalaciones innecesarias: <10% de reacciones
- False positive rate (reaccion cuando no necesaria): <5%
