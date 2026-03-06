# AI Exposure Metrics — Métricas de Exposición Laboral a la IA

> Define cómo medir el impacto de la IA en roles y equipos.
> Fuente: Anthropic "Labor Market Impacts of AI" (2026).

---

## Principio

La exposición a la IA no es binaria ("automatizable" o "no"). Existen dos
dimensiones: lo que la IA **podría** hacer (teórica) y lo que **ya** hace
(observada). La diferencia es el gap de adopción — una ventana para actuar.

---

## Métricas Core

### 1. Theoretical Exposure (TE)

Porcentaje de tareas del rol que un LLM podría realizar con calidad aceptable.

```
TE = Σ(peso_tarea × capacidad_ia) / Σ(peso_tarea)
```

Capacidad IA por tarea: 0 (imposible) a 1 (automatizable al 100%).

### 2. Observed Exposure (OE)

Porcentaje de tareas que YA se están automatizando en la práctica.

```
OE = Σ(peso_tarea × uso_real_ia) / Σ(peso_tarea)
```

Uso real: 0 (sin IA) a 1 (totalmente automatizado).

### 3. Adoption Gap (AG)

```
AG = TE - OE
```

Interpretación: AG alto = margen para automatizar más. AG bajo = ya cerca del techo.

### 4. Augmentation Ratio (AR)

```
AR = tareas_augmentadas / (tareas_augmentadas + tareas_automatizadas)
```

- AR > 0.7 — IA como copiloto (saludable)
- AR 0.4-0.7 — Transición mixta (vigilar)
- AR < 0.4 — Sustitución dominante (reskilling urgente)

---

## Clasificación de Riesgo por Rol

| OE | Riesgo | Acción |
|---|---|---|
| > 60% | 🔴 Alto | Plan de reskilling inmediato (8 semanas) |
| 30-60% | 🟡 Medio | Monitorizar + plan preventivo (12 semanas) |
| < 30% | 🟢 Bajo | Augmentation; optimizar uso de IA |

---

## Junior Hiring Gap Index

Mide si un equipo deja de incorporar perfiles junior en roles expuestos.

```
JHG = juniors_contratados_último_año / juniors_contratados_año_anterior
```

| JHG | Estado | Riesgo |
|---|---|---|
| > 0.85 | 🟢 Estable | Pipeline de talento sano |
| 0.60-0.85 | 🟡 Declive | Pipeline en riesgo |
| < 0.60 | 🔴 Crítico | Pipeline roto — sin relevo generacional |

Dato de referencia: caída del ~14% en contratación junior post-ChatGPT
(Anthropic, 2026).

---

## Taxonomía de Tareas

Cada tarea se clasifica en una de 4 categorías:

- **Cognitive-Routine** — reglas claras, repetitiva (alta automatización)
- **Cognitive-Nonroutine** — juicio, creatividad (augmentation)
- **Manual-Routine** — física y repetitiva (robótica, no LLM)
- **Manual-Nonroutine** — destreza física variable (baja exposición LLM)

---

## Integración

| Comando/Regla | Relación |
|---|---|
| `/ai-exposure-audit` | Comando principal que usa estas métricas |
| `/capacity-forecast --scenario automate` | Simula impacto de automatización |
| `/enterprise-dashboard team-health` | Incluye exposure score |
| `ai-competency-framework.md` | Define niveles de reskilling |
| `/team-skills-matrix` | Bus factor + exposure = riesgo compuesto |
| `/burnout-radar` | Correlaciona burnout con roles en transición |

---

## Referencias

- Anthropic, "The Labor Market Impacts of AI" (2026)
- O*NET OnLine — Occupational Information Network
- BLS Occupational Outlook Handbook — growth projections
- Eloundou et al. — "GPTs are GPTs" theoretical capability scores
