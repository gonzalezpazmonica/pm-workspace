---
name: value-stream-map
description: Mapa de valor end-to-end — idea→producción, waste, cuellos de botella
developer_type: all
agent: task
context_cost: high
---

# /value-stream-map

> 🦉 Savia mapea tu flujo de valor completo para identificar dónde se pierde tiempo.

---

## Cargar perfil de usuario

Grupo: **Reporting** — cargar:

- `identity.md` — nombre, rol
- `preferences.md` — language, detail_level
- `projects.md` — proyecto target
- `tone.md` — formality

---

## Subcomandos

- `/value-stream-map` — mapa completo del flujo de valor
- `/value-stream-map --bottlenecks` — solo cuellos de botella
- `/value-stream-map --compare {sprint1} {sprint2}` — evolución entre sprints

---

## Flujo

### Paso 1 — Identificar fases del flujo

Mapear las fases del ciclo de vida de una feature:

```
Idea → Discovery → Refinamiento → Sprint Planning → Desarrollo
→ Code Review → QA → UAT → Deploy → Producción
```

### Paso 2 — Medir tiempos por fase

Para cada fase, calcular desde datos de Azure DevOps / git:

| Fase | Tiempo activo | Tiempo en espera | % Wait |
|---|---|---|---|
| Discovery → Refinement | {N} días | {N} días | {N}% |
| Refinement → Dev | {N} días | {N} días | {N}% |
| Dev → Review | {N} horas | {N} horas | {N}% |
| Review → QA | {N} horas | {N} horas | {N}% |
| QA → Deploy | {N} días | {N} días | {N}% |

### Paso 3 — Calcular métricas Lean

```
📊 Value Stream Metrics
  Lead Time total: {N} días (idea → producción)
  Process Time: {N} días (solo trabajo activo)
  Wait Time: {N} días (en espera/cola)
  Flow Efficiency: {process_time / lead_time * 100}%

  🎯 Benchmark: Flow Efficiency >25% = saludable
```

### Paso 4 — Identificar waste (Lean 7 wastes)

| Waste | Detectado | Impacto |
|---|---|---|
| Esperas entre fases | {descripción} | 🔴/🟡/🟢 |
| Handoffs excesivos | {N} traspasos | 🔴/🟡/🟢 |
| Retrabajo | {N}% PBIs devueltos | 🔴/🟡/🟢 |
| Sobreproducción | Features sin usar | 🔴/🟡/🟢 |
| Context switching | Items en paralelo | 🔴/🟡/🟢 |

### Paso 5 — Generar recomendaciones

Priorizar por impacto: reducir el waste más costoso primero.

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: value_stream_map
project: sala-reservas
lead_time_days: 14.5
process_time_days: 4.2
flow_efficiency: 29%
bottlenecks: 2
top_waste: "wait_between_review_and_qa"
```

---

## Restricciones

- **NUNCA** inventar tiempos — usar solo datos reales del proyecto
- **NUNCA** comparar equipos entre sí — solo evolución del mismo equipo
- Si no hay datos suficientes → indicar qué falta y cómo obtenerlo
- Tono constructivo: el objetivo es mejorar, no señalar culpables
