---
name: stakeholder-align
description: Resolución de conflictos entre stakeholders con datos objetivos
developer_type: all
agent: task
context_cost: medium
---

# /stakeholder-align

> 🦉 Cuando dos stakeholders quieren cosas distintas, Savia trae datos objetivos a la mesa.

---

## Cargar perfil

Grupo: **Strategic Alignment** — cargar:

- `CLAUDE.md` — proyecto activo
- `company/identity.md` — estructura y roles
- `company/strategy.md` — OKRs y prioridades estratégicas
- `projects/{proyecto}/CLAUDE.md` — config proyecto
- Items en conflicto: descripción, esfuerzo, valor, dependencias

---

## Subcomandos

- `/stakeholder-align` — modo interactivo: describir conflicto
- `/stakeholder-align --items {id1} {id2} ...` — comparación objetiva de items
- `/stakeholder-align --scenario {nombre}` — evaluar escenario "qué pasa si"
- `/stakeholder-align --dependency-chain {id}` — mostrar impacto cascada de prioridades

---

## Flujo

### Paso 1 — Identificar el conflicto

Escuchar descripción del PM:

```
PM: "El CPO quiere Feature X, el CTO quiere Bug Fix Y.
     Ambos dicen que es crítico. No caben los dos en el sprint."
```

Detectar patrones:
- Conflicto de prioridad (ambos urgentes)
- Conflicto de capacidad (no hay suficientes recursos)
- Conflicto de dependencia (uno bloquea al otro)
- Conflicto de alineación (X avanza OKR1, Y avanza OKR2)

### Paso 2 — Recopilar datos objetivos

Dimensiones clave por item: esfuerzo (SP), valor de negocio, OKR alineado, dependencias, bloqueadores, timeline.

NO incluir: opiniones, emociones, política. Solo hechos.

### Paso 3 — Presentar matriz de comparación

```markdown
# Stakeholder Conflict Analysis

Conflicto: Feature X vs Bug Fix Y | Capacidad: 1 sprint (13 SP)

## Comparación Objetiva

| Dimensión | Feature X | Bug Fix Y | Mejor para... |
|-----------|-----------|-----------|---------------|
| **Esfuerzo** | 13 SP | 3 SP | ✅ Bug Fix (3x menor) |
| **Business Value** | $500K MRR | Risk mitigation | Depende de prioridad |
| **OKR Alignment** | OKR 1.2 (Revenue) | OKR 3.1 (Quality) | Ambos estratégicos |
| **Timeline** | 2 sprints realista | 1 sprint | ✅ Bug Fix (más rápido) |
| **Dependencies** | Requiere Feature W | Ninguno | ✅ Bug Fix (independiente) |
| **Blocker Impact** | Bloquea 2 features | Detiene 1 feature | Comparables |
| **User Impact** | 100% usuarios (new feature) | 5% usuarios (fix) | Feature X (more reach) |

## Capacity Analysis

**Available this sprint**: 13 SP
**Option 1** — Feature X: 13 SP ✅ Fits | Bug Fix: PUSHED to next sprint 🔴
**Option 2** — Bug Fix Y: 3 SP ✅ Fits | Feature X: Delayed, falta 10 SP 🟡
**Option 3** — Split: Feature X descoped (8 SP, MVP) + Bug Y (3 SP) = 11 SP ✅
```

### Paso 4 — Escenarios de resolución

Basados en datos (capacidad, esfuerzo, OKR alineación, riesgos):

**Opción 1 — Bug Fix prioritario**: Criticidad técnica + independencia. Risk: Feature X se retrasa.

**Opción 2 — Feature X prioritario**: Business value + revenue. Risk: Técnico se retrasa, churn.

**Opción 3 — Hybrid (recomendado)**: Bug Fix (3 SP) este sprint + Feature X MVP (8 SP) = 11 SP. Feature X Expansion próximo sprint.

**Opción 4 — More resources**: Si hay capacity, ejecutar ambos en 2 sprints (requiere confirmación recurso).

### Paso 5 — Recomendación final

```markdown
## Recomendación Data-Driven

🎯 Opción 3 (Hybrid) es la más equilibrada:

- Resuelve riesgo técnico crítico ahora (Bug Fix): 🟢 CTO satisfied
- Avanza revenue objetivo con MVP validado: 🟢 CPO satisfied
- Mantiene trajectory ambos OKRs: 🟢 Strategic aligned
- Usa la semana que Analytics team estará libre para Bug Fix: 🟢 Resource optimized

**Propuesta al team:**
Sprint {N}: Bug Fix (3 SP) + Feature X MVP (8 SP) = 11 SP
Sprint {N+1}: Feature X Expansion (5 SP) + Team backlog

**Decisión final:** Requiere confirmación de:
1. CPO — acepta MVP Feature X este sprint
2. CTO — acepta que Bug Fix va primero pero rápido
3. Tech Lead — valida que Feature X se puede descopear sin romper arquitectura
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: stakeholder_alignment
conflict_type: "priority|capacity|dependency|strategy"
stakeholders_involved: ["{name1}", "{name2}"]
items_analyzed: {n}
recommended_option: "{number}"
 okr_impact: "{summary}"
file_path: "output/alignment/YYYYMMDD-stakeholder-align-{proyecto}.md"
decision_ready: {boolean}
```

---

## Restricciones

- **NUNCA** tomar decisiones que debería tomar el PM — Savia prepara datos, no decide
- **NUNCA** favorecer a un stakeholder por rango/seniority — usar datos solo
- **NUNCA** incluir política personal o historial de conflictos previos
- Matriz de comparación: máximo 8 dimensiones (evitar saturación)
- Si datos no están disponibles, marcar como "TBD" — no inventar metrics
- Recomendación es "data-driven but human-owned": PM elige la opción final
