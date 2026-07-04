---
name: team-skills-matrix
description: Matriz de skills del equipo — quién sabe qué, bus factor, pair programming
developer_type: all
agent: task
context_cost: high
tier: extended
---

# /team-skills-matrix

> 🦉 Savia mapea las competencias del equipo para detectar riesgos y oportunidades.

---

## Cargar perfil de usuario

Grupo: **Team & Workload** — cargar:

- `identity.md` — nombre, rol
- `projects.md` — proyecto target
- `tone.md` — alert_style

---

## Subcomandos

- `/team-skills-matrix` — matriz completa
- `/team-skills-matrix --bus-factor` — solo análisis de bus factor
- `/team-skills-matrix --pairs` — sugerencias de pair programming

---

## Flujo

### Paso 1 — Analizar contribuciones por módulo

Para cada miembro del equipo, analizar git log:

1. Ficheros modificados → módulos/áreas de expertise
2. Frecuencia de contribución → nivel de conocimiento
3. Recencia → conocimiento activo vs. histórico

### Paso 2 — Construir matriz

| Módulo | Dev-A | Dev-B | Dev-C | Bus Factor |
|---|---|---|---|---|
| Auth | ⬛⬛⬛ | ⬛⬜⬜ | ⬜⬜⬜ | 🔴 1 |
| API | ⬛⬛⬜ | ⬛⬛⬛ | ⬛⬜⬜ | 🟢 2 |
| UI | ⬜⬜⬜ | ⬛⬛⬜ | ⬛⬛⬛ | 🟡 2 |

Nivel: ⬛⬛⬛ Expert, ⬛⬛⬜ Proficient, ⬛⬜⬜ Basic, ⬜⬜⬜ None

### Paso 3 — Calcular bus factor

Bus factor por módulo = personas con nivel ≥ Proficient.

| Bus Factor | Estado |
|---|---|
| 1 | 🔴 Crítico — una persona ausente = bloqueo |
| 2 | 🟡 Riesgo — transferir conocimiento |
| 3+ | 🟢 Saludable |

### Paso 4 — Sugerir pair programming

Para módulos con bus factor ≤ 2:
Emparejar expert con basic/none para transferencia de conocimiento.

```
🦉 Skills Matrix — {proyecto}

📊 Equipo: {N} personas · {N} módulos

{tabla de matriz}

🔴 Bus Factor Crítico ({N} módulos):
  Auth — solo @Dev-A · Pair sugerido: @Dev-B
  Deploy — solo @Dev-C · Pair sugerido: @Dev-A

💡 Pairs recomendados esta semana:
  @Dev-A + @Dev-B → Auth module (bus factor 🔴)
  @Dev-C + @Dev-A → Deploy scripts (bus factor 🔴)
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: team_skills_matrix
team_size: 4
modules: 8
critical_bus_factor: 2
at_risk_bus_factor: 3
healthy_bus_factor: 3
suggested_pairs: 2
```

---

## Restricciones

- **NUNCA** publicar la matriz sin consentimiento del Tech Lead
- **NUNCA** usar como herramienta de evaluación de rendimiento
- Objetivo: transferencia de conocimiento, no ranking
