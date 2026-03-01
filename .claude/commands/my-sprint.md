---
name: my-sprint
description: Vista personal del sprint — items asignados, progreso, cycle time, PRs pendientes
developer_type: all
agent: none
context_cost: medium
---

# /my-sprint

> 🦉 Savia te muestra tu vista personal del sprint. Solo lo que te importa a ti.

---

## Cargar perfil de usuario

Grupo: **Sprint & Daily** — cargar:

- `identity.md` — nombre (para filtrar items asignados)
- `workflow.md` — daily_time, primary_mode
- `projects.md` — proyectos activos
- `tone.md` — alert_style, celebrate

---

## Subcomandos

- `/my-sprint` — vista personal del sprint activo
- `/my-sprint --all` — incluir items completados
- `/my-sprint --history` — últimos 3 sprints

---

## Flujo

### Paso 1 — Filtrar items asignados al usuario

Obtener work items del sprint actual donde `Assigned To` = usuario activo.
Clasificar por estado: New, Active, In Progress, Done.

### Paso 2 — Calcular métricas personales

| Métrica | Cálculo |
|---|---|
| Items completados | Done / Total asignados × 100 |
| Cycle time personal | Media de tiempo desde Active→Done |
| PRs pendientes | PRs creados por mí sin merge |
| PRs esperando mi review | PRs donde soy reviewer |
| Story points completados | Suma de effort/story points de items Done |

### Paso 3 — Mostrar vista personal

```
🦉 Mi Sprint — {sprint-name} — {nombre}

📊 Mi progreso: {completados}/{total} ({%}) ▓▓▓░░

📋 En progreso ({N}):
  #{id} {título} — {tipo} — {días en progreso}
  #{id} {título} — {tipo} — {días en progreso}

⏳ Pendientes ({N}):
  #{id} {título} — {tipo} — {prioridad}

🔄 PRs:
  Creados por mí: {N} pendientes de merge
  Esperando mi review: {N}

⏱️ Mi cycle time: {N} días (equipo: {N} días)

{si completados > 0: 🎉 celebración adaptada al tone}
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: my_sprint
user: nombre.apellido
total_assigned: 8
completed: 5
in_progress: 2
pending: 1
cycle_time_days: 2.3
prs_created: 2
prs_reviewing: 1
```

---

## Restricciones

- **NUNCA** mostrar items de otros miembros del equipo
- **NUNCA** comparar rendimiento con compañeros
- Vista personal y privada — sin juicios de productividad
