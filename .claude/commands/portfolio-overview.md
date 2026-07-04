---
name: portfolio-overview
description: Vista bird's-eye de todos los proyectos — semáforo, velocidad comparada, dependencias
developer_type: all
agent: none
context_cost: medium
tier: extended
---

# /portfolio-overview

> 🦉 Savia te muestra el mapa completo de tu portfolio en una sola vista.

---

## Cargar perfil de usuario

Grupo: **Reporting** — cargar:

- `identity.md` — nombre
- `projects.md` — todos los proyectos
- `preferences.md` — language, date_format

---

## Subcomandos

- `/portfolio-overview` — vista completa
- `/portfolio-overview --compact` — solo semáforo sin detalles
- `/portfolio-overview --deps` — foco en dependencias inter-proyecto

---

## Flujo

### Paso 1 — Recopilar estado de cada proyecto

Para cada proyecto en `projects.md`:

1. Sprint actual: nombre, % completado, días restantes
2. Velocity: actual vs. media 3 sprints (↑/→/↓)
3. Health score: 0-100 (del `/health-dashboard`)
4. Riesgo más alto: severidad + descripción corta
5. Próximo milestone: qué y cuándo

### Paso 2 — Generar tabla semáforo

```
🦉 Portfolio Overview — {fecha}

| Proyecto | Estado | Sprint | Velocity | Health | Risk | Milestone |
|---|---|---|---|---|---|---|
| {nombre} | 🟢 | S14 78% ▓▓▓▓░ 3d | 42 → | 85/100 | 🟢 Low | MVP 15-Mar |
| {nombre} | 🟡 | S8 45% ▓▓░░░ 5d | 38 ↓ | 62/100 | 🟡 Med | Beta 01-Apr |
| {nombre} | 🔴 | S3 20% ▓░░░░ 2d | 25 ↓↓ | 41/100 | 🔴 High | Alpha 20-Mar |
```

### Paso 3 — Mapa de dependencias (si `--deps` o hay bloqueos)

```
Dependencias inter-proyecto:
  {proyecto-A} ──blocks──→ {proyecto-B} (API de autenticación, 5 días)
  {proyecto-C} ──waits───→ {proyecto-A} (Migración DB, sprint S15)
```

Solo mostrar si hay dependencias activas o bloqueos.

### Paso 4 — Resumen y tendencia

```
📊 Portfolio Summary:
  Proyectos activos: {N} | 🟢 {n} | 🟡 {n} | 🔴 {n}
  Team utilization: {N}% | Velocity trend: {↑/→/↓}
  Bloqueos activos: {N}

💡 Atención:
  {1-2 items que requieren acción}
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: portfolio_overview
total_projects: 3
green: 2
yellow: 1
red: 0
active_blocks: 1
avg_health: 72
avg_utilization: 85
velocity_trend: stable
```

---

## Restricciones

- **NUNCA** más de 15 proyectos en la tabla (si hay más, paginar)
- **NUNCA** incluir detalles técnicos — solo indicadores de alto nivel
- Cada fila debe caber en una línea (truncar si necesario)
- Datos reales obligatorios — sin datos → indicar "N/D"
