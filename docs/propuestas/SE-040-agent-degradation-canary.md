---
id: SE-040
title: Agent Degradation Canary — detectar regresiones de modelo vía métricas canarias
status: PROPOSED
origin: Issue anthropics/claude-code#42796 (research 2026-04-18) — degradación Claude Code desde febrero con extended thinking reducido
author: Savia
related: agent-trace skill, session-actions.jsonl, SPEC-108 agent self-improvement
approved_at: null
applied_at: null
expires: "2026-06-18"
---

# SE-040 — Agent Degradation Canary

## Purpose

Si NO hacemos esto: cuando un proveedor de modelo (Anthropic, OpenAI, local) cambia la asignación de tokens internos (thinking budget, context compaction, reasoning depth), los agentes degradan su comportamiento sin aviso explícito — toman atajos, editan sin leer, piden permisos extra, saltan pasos de investigación. Con 65 agentes concurrentes, una regresión pequeña del modelo se amplifica en cascada de fallos coordinados que requieren supervisión humana masiva.

El issue anthropics/claude-code#42796 documenta un caso real: Read:Edit ratio cayó de 6.6 → 2.0 (70% menos investigación), violaciones de stop hooks pasaron de 0 a 173 en 3 semanas, frustración en prompts subió 68%, coste/día API × 57 (por iteración de correcciones). Todo sin cambio en código del usuario — solo downgrade silencioso del modelo.

Cost of inaction: sin canary, descubrimos degradación por acumulación de incidentes (agentes fallando, reviews humanos saturados, facturación que explota). Tardamos semanas en correlacionar. El canary adelanta detección a horas.

## Objective

**Único y medible**: introducir skill `agent-health-canary` que analiza la ventana móvil de las últimas 48h de `session-actions.jsonl` y calcula 5 métricas canarias con umbrales alertables. Criterio de éxito: detectar con <24h de delay cualquier degradación que cause ≥20% caída en al menos una métrica (medido retrospectivamente sobre incidente sintético inyectado).

NO es: fix automático. SÍ es: alerta temprana + métricas trackeables para decidir si escalar (cambiar de modelo, reportar al proveedor, pausar agentes afectados).

## Diseño

### 5 métricas canarias

| Métrica | Cálculo | Umbral alerta |
|---|---|---|
| **Read:Edit ratio** | reads / edits por agente en ventana | Caída >30% vs baseline 7d |
| **Stop hook violations** | `PreToolUse:Stop` blocked events | >10/día sin justificación |
| **Interrupt rate** | user interruptions / turns | >15% (baseline ~5%) |
| **Edit-without-read count** | Edits sin Read previo al mismo file | >3/sesión |
| **Token efficiency** | output_tokens / session_tokens | Caída >25% vs baseline |

### Fuentes de datos

Todas ya existen:
- `~/.claude-logs/session-actions.jsonl` — hooks logs append-only
- Agent traces via `agent-trace` skill
- Session metadata via `session-save` / `session-end`

Zero new instrumentation required — solo análisis.

### Output

`output/agent-health-{YYYY-MM-DD}.md` con:
- 5 métricas + baseline 7d
- Cambio % vs baseline (red si degradación ≥ umbral)
- Top 3 agentes afectados
- Recomendación: "healthy" / "watch" / "degraded — escalate"

### Skill invocation

```bash
/agent-health-canary [--window 48h] [--baseline 7d]
```

Opcional: cron semanal `scripts/agent-health-weekly-cron.sh` que emite alerta si estado=degraded.

## Slicing

### Slice 1 — Feasibility Probe (1.5h, blocking)

- Verificar que `session-actions.jsonl` tiene 7+ días de datos suficientes
- Extraer las 5 métricas sobre ventana actual
- Verificar que los thresholds tienen sentido contra histórico
- Decision gate: si datos insuficientes para baseline 7d, abort spec (no hay base para comparar)

### Slice 2 — Skill `agent-health-canary` (2h)

- Implementar las 5 métricas en `scripts/agent-health-canary.sh`
- Skill doc + comando `/agent-health-canary`
- Tests BATS ≥20 con fixtures (jsonl sintético)

### Slice 3 — Alerting + ratchet integration (1.5h)

- Ratchet baselines en `.ci-baseline/agent-health-{metric}.baseline`
- Integración opt-in en `ci-extended-checks.sh` check #11
- Weekly cron opcional

## Acceptance Criteria

- [ ] AC-01 Probe Slice 1 verifica viabilidad con datos reales
- [ ] AC-02 Skill `agent-health-canary` implementado con 5 métricas
- [ ] AC-03 Tests BATS ≥20 con auditor score ≥80
- [ ] AC-04 Doc `docs/rules/domain/agent-health-canary.md` con umbrales y playbook de respuesta
- [ ] AC-05 Ratchet baseline para detección de regresión week-over-week
- [ ] AC-06 Opcional: integración `ci-extended-checks.sh` check #11

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Métricas demasiado sensibles (false positives frecuentes) | Umbrales configurables + "watch" como estado intermedio |
| Baseline no disponible (repo reciente) | Degradación a "insufficient data" sin bloquear |
| Canary añade coste computacional | Todo es análisis offline de logs ya existentes |
| Privacidad: session-actions contiene contenido sensible | Análisis solo extrae métricas agregadas, no contenido |

## Aplicación Spec Ops

- **Simplicity**: 5 métricas canarias, no 50
- **Purpose**: coste de inaction cuantificado (Anthropic issue: ~$1500/día vs $26/día por cascada)
- **Probe/Repetition**: Slice 1 valida que hay datos suficientes antes de construir skill
- **Speed**: 3 slices ≤2h cada uno
- **Theory of Relative Superiority**: expires 2026-06-18

## Referencias

- anthropics/claude-code#42796 (2026-04): caso de degradación Feb 2026 con 173 stop hook violations, Read:Edit 6.6→2.0, API cost $26→$1504
- Skill `agent-trace` existente (traces ya capturados)
- `session-actions.jsonl` append-only log
- SPEC-108 agent self-improvement (complementario)
- ROADMAP.md §Tier 4 (este spec añadible como 4.10)

## Dependencia

Independiente. Priorizable alto si se observan síntomas similares en pm-workspace.
