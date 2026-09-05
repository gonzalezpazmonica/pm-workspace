# SE-380 — Capability Lifecycle, Usage & Complexity Budget

**Estado:** PROPOSED (pendiente de aprobación humana — Fase E, audit GPT-5.6 2026-09-05)
**Prioridad:** P1 · **Developer Type:** agent-team · **Context Risk:** high
**Origen:** auditoría externa §11 + §16 (Entropy) + §17 (Usage Telemetry) + §18 (Advisor) — consolidadas tras reconciliación

## 1. Motivación

- Lifecycle parcial: SE-167 cubre skills; agents/commands/hooks no tienen lifecycle (F2).
- Sin presupuesto de complejidad: el crecimiento es ilimitado por defecto.
- Uso parcialmente medido: `skill-usage-tracker.py` (SPEC-SE-030, local, jsonl rolling) y `skills-usage-audit.sh` (SPEC-109, estático) cubren skills; commands y agents sin señal.
- Overlap medido (SE-270) pero sin motor de propuestas de consolidación.
- Sin métrica de entropía arquitectónica: no se puede responder "¿esta feature reduce complejidad total?".

## 2. Alcance

### 2.1 Lifecycle (4 kinds)

`experimental → active → deprecated → retired` con metadata obligatoria:

```yaml
status: active
introduced: 2026-09-05
owner: <domain>
usage_hypothesis: <qué problema resuelve y para quién>
retirement_criterion: <condición medible de retirada>
replaced_by: null
last_reviewed: 2026-09-05
```

`deprecated` = fuera del routing primario, compatibilidad temporal, warning en invocación, puntero a replacement.

### 2.2 Admission test (toda capability nueva responde)

1. ¿Reutiliza una existente? 2. ¿Amplía una existente? 3. ¿Es configuración? 4. ¿Es opción de una skill? 5. ¿Es un script detrás de otra capability? 6. ¿Qué capability elimina o reemplaza? 7. ¿Cómo se medirá su uso?

### 2.3 Métrica de entropía (fórmula A VALIDAR en feasibility probe — no usar literal)

```
capability_entropy =
    active_capabilities
  + w1·overlap_weight + w2·mirror_weight + w3·dependency_edges
  + w4·routing_ambiguity + w5·manual_sync_surfaces + w6·exception_count
```

Objetivo: que una feature pueda subir capabilities pero bajar entropía total. Pesos calibrados contra el historial del repo antes de fijarlos.

### 2.4 Telemetría de uso local (extensión SPEC-SE-030)

Cobertura de commands y agents. Local-only, metadata-only, sin contenido N3+, configurable, sin telemetría externa (CRIT-001). Métricas: capability, invocations, successful_runs, failed_runs, last_used, avg_cost, avg_duration, human_corrections.

### 2.5 Consolidation Advisor (propose-only)

Candidatos MERGE / DELETE / GENERALIZE / RENAME / ALIAS / DEPRECATE consumiendo registry (SE-375) + usage + overlap (SE-270). **Nunca elimina ni depreca automáticamente** — todo es propuesta para la operadora.

## 3. Reglas

| # | Regla | Severidad |
|---|---|---|
| RN-01 | Ninguna eliminación/retirada automática | P0 (violación = abort) |
| RN-02 | Nueva capability sin admission test registrado → no entra | P1 |
| RN-03 | Budget por kind con ratchet: nunca subir | P1 |
| RN-04 | deprecated sin replaced_by/retirement_criterion → P2 | P2 |
| RN-05 | Telemetría con contenido de conversación → P0 (solo metadata) | P0 |
| RN-06 | Métricas por release: added/merged/retired/deprecated/reactivated/unused/overlap_candidates | P2 |

## 4. Criterios de aceptación

- Lifecycle visible en registry (SE-375) para los 6 kinds.
- Primer informe de entropía con fórmula validada y baseline congelado.
- Primer informe de candidatos a consolidación (propuestas, cero ejecutadas).
- Telemetría local operando para skills+commands+agents sin contenido de conversación.

## 5. OpenCode Implementation Plan

PENDING-APPROVAL — feasibility probe previo obligatorio para la fórmula de entropía.

## Referencias

- Auditoría externa §11, §16, §17, §18 · SE-167 · SE-270 · SPEC-SE-030 · SPEC-109 · SE-371
