---
context_tier: L1
token_budget: 640
---

# Regla: Seguridad en Modos Autónomos — Supervisión humana obligatoria

> **REGLA INMUTABLE** — overnight-sprint, code-improvement-loop, tech-research-agent y cualquier modo sin supervisión en tiempo real. Implementa Genesis **A9 SUPERVISED EXECUTION** (`attention-anchor.md`, SE-080). Detalle operativo: `autonomous-safety-reference.md`.

**La IA propone, el humano dispone** (§3, §9 de `savia-ethical-principles.md`). Ningún agente autónomo decide algo irreversible; todo output autónomo es propuesta pendiente de revisión humana.

## Git

```
NUNCA   commit en rama humana (main, develop, feature/* humana) · merge de ninguna rama
NUNCA   push --force · borrar ramas ajenas
SIEMPRE rama propia agent/{modo}-{fecha}-{descripcion}, derivada de main/develop
SIEMPRE commits solo en agent/*, prefijo agent({modo}):
```

## PRs

```
NUNCA   aprobar un PR · auto-asignarse reviewer
NUNCA   merge sin permiso expreso REGISTRADO de la operadora
NUNCA   marcar ready for merge sin grant expreso y gates de riesgo/CI
SIEMPRE PR Draft; body con métricas antes/después, cambio y riesgo
SIEMPRE reviewer distinto y elegible → pedir revisión; operadora única → Draft
        para su revisión, sin pedir self-review a GitHub
SIEMPRE tier 3/4: revisión humana explícita del PR concreto (SE-362)
SIEMPRE tier 1/2: grant de merge expreso vigente (SE-343) + CI
```

Merge: `autonomous-safety-merge-grant.md`. Sin operadora ni reviewer elegible (`AUTONOMOUS_REVIEWER`, fuentes locales gitignored): abortar.

## Investigación

NUNCA crear tareas en backlog sin aprobación, cambiar configuración por hallazgos ni instalar dependencias. Las recomendaciones son propuestas.

## Fail-safe

Time-box por tarea (`AGENT_TASK_TIMEOUT_MINUTES`, 15). Abortar tras `AGENT_MAX_CONSECUTIVE_FAILURES` (3) fallos consecutivos o misma acción 3+ veces. Registrar cada intento. Contexto > 80% → compactar y reevaluar. Audit log en `output/agent-runs/`.

## Obligaciones enlazadas

- **Doble opt-in** (SPEC-186): variable persistente + `--confirm-autonomous`.
- **Handback Obligation** (SE-332): bloqueo → escalar al padre inmediato; termina en manual.
- **Subagent Scope Guard** (SE-146): subagente ejecuta solo su tarea, reporta y retorna.
- **Maker-checker** (L2+): `maker-checker-protocol.md`.
- **Dual Pool** (SE-235): proposal = rama `agent/*` no mergeada; result state = en main con PR aprobado por humano.
- Emergency-mode (SPEC-122) no bypassa ningún gate.
