---
name: task-criticality-system
description: >
  Sistema de priorizacion y criticidad multi-nivel con WSJF, Cost of Delay,
  auto-escalado temporal y scheduling inteligente. 4 niveles: portfolio,
  proyecto, equipo, persona.
type: spec
status: refined
priority: P0
frameworks: WSJF, Cost-of-Delay, RICE, Eisenhower, Kano
---

# Spec: Sistema de Criticidad y Priorizacion Multi-Nivel

Referencia de frameworks: `spec-criticality-frameworks.md`

## Problema

PM de consultora gestiona 3+ proyectos, 30+ personas, cientos de tareas.
Sin priorizacion cruzada automatica, items sin fecha fija se posponen.
No hay vista unificada de criticidad across proyectos.

## Arquitectura: framework por nivel

| Nivel | Scope | Framework | Complemento |
|-------|-------|-----------|-------------|
| 1. Portfolio | Cross-project | WSJF + Cost of Delay | Kano (discovery) |
| 2. Proyecto | Sprint backlog | RICE adaptado | MoSCoW (validacion) |
| 3. Equipo | Carga squad | Capacity + WIP limits | Value vs Effort |
| 4. Persona | Dia a dia | Eisenhower + auto-schedule | Motion/Reclaim |

## Nivel 1 — Portfolio (WSJF + Cost of Delay)

`WSJF = Cost_of_Delay / Job_Size`
`CoD = User_Value + Time_Criticality + Risk_Reduction` (Fibonacci 1-20)

Perfiles de urgencia (Reinertsen): Standard (decay lineal), Fixed-date
(cliff en deadline), Expedite (step function → P0 auto), Intangible (decay
lento → aplica confidence_decay).

## Nivel 2 — Proyecto (RICE adaptado)

`priority = (Reach × Impact × Confidence × urgency_multiplier) / Effort`
Reach (1-100), Impact (0.25-3), Confidence (50-100% × decay), Effort (SP).
Post-scoring: validar que top items serian "Must" en MoSCoW.

## Nivel 3 — Equipo (capacity)

WIP <=2/persona, bus factor, skill gap, sobrecarga >110% 2+ sprints.

## Nivel 4 — Persona (Eisenhower + auto-schedule)

Urgent×Important 2x2 + auto-scheduling: items por criticality_score →
huecos libres → alerta proactiva si no cabe → recomputo al cancelar
reunion → proteger 2h focus/dia.

## Modelo de criticidad unificado (5 dimensiones)

| Dimension | Peso | Fuente |
|-----------|------|--------|
| Impacto de negocio | 0.30 | Manual + Kano |
| Urgencia temporal | 0.25 | Auto (deadline) + perfil CoD |
| Dependencias | 0.20 | Auto (grafo bloqueos) |
| Confianza | 0.15 | Auto (decay) + manual |
| Esfuerzo inverso | 0.10 | SP invertidos (quick wins) |

```
criticality = (impacto×0.30) + (urgencia×0.25) + (deps×0.20)
            + (confianza×0.15) + (esfuerzo_inv×0.10)
esfuerzo_inv = 6 - min(5, ceil(SP/4))
```

P0 Critical (>=4.0), P1 High (3.0-3.9), P2 Medium (2.0-2.9), P3 Low (<2.0)

## Auto-escalado temporal

```
days<=0: urgencia=5 (P0 auto)  |  1-2d: base+3 (cap 5)
3-7d: base+2  |  7-14d: base+1  |  >14d: base
```

Fixed-date: cliff en fecha. Intangible: no auto-escala, usa confidence_decay.

## Confidence decay

```
<=14d: 1.0 | 15-30d: 0.9 | 31-60d: 0.75 | 61-90d: 0.5 | >90d: 0.3
confianza_efectiva = confianza_base × confidence_decay
```

Items olvidados en backlog bajan solos. Validacion = cualquier update.

## Comandos nuevos

- `/criticality-dashboard` — vista cross-project P0-P3, heatmap
- `/criticality-assess {item}` — desglose de 5 dimensiones
- `/criticality-rebalance` — redistribuir carga por criticidad

## Comandos a integrar

`/my-focus` (elige por score), `/sprint-autoplan` (RICE+capacity),
`/calendar-plan` (focus→criticos), `/daily-routine` (P0+P1 al inicio),
`/team-workload` (heatmap criticidad), `/calendar-deadlines` (auto-escalado),
`/backlog-prioritize` (RICE+decay), `/backlog-groom` (P3+decay<0.3→eliminar)

## Reglas de negocio

1. P0 sin asignar → alerta inmediata
2. P0 sin movimiento >24h → escala al PM
3. >3 P0 simultaneos → alerta capacidad critica
4. P3 con confidence <0.3 → candidatos eliminacion
5. Recalculo diario (o al cambiar estado)
6. Override manual con justificacion (expira 30 dias)
7. Fixed-date (compliance) siempre >= P1
8. Expedite → P0 sin scoring (override del sistema)
9. WSJF recalcula por sprint; RICE por daily
