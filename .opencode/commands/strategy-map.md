---
name: strategy-map
description: Mapa estratégico — iniciativas, dependencias, contribución a objetivos
developer_type: all
agent: task
context_cost: high
---

# /strategy-map

> 🦉 Savia despliega el mapa estratégico: iniciativas, dependencias y contribución a OKRs.

---

## Cargar perfil

Grupo: **Reporting** — cargar:

- `company/strategy.md` — OKRs e iniciativas
- `company/structure.md` — departamentos, equipos
- `projects/{proyecto}/CLAUDE.md` — para cada proyecto (timeline, dependencias)

---

## Subcomandos

- `/strategy-map` — mapa completo con timeline
- `/strategy-map --initiative {name}` — detalle profundo de una iniciativa
- `/strategy-map --dependencies` — grafo de dependencias inter-iniciativas

---

## Flujo

### Paso 1 — Enumerar iniciativas estratégicas

Iniciativas = agrupaciones de proyectos que persiguen un OKR.

Estructura: Objetivo → Iniciativa(s) → Proyectos, Owner, Timeline

### Paso 2 — Mapear dependencias

Tipos:
- **Hard**: X bloqueado por Y (X no puede comenzar sin Y)
- **Soft**: X preferible antes que Y (optimiza pero no bloquea)
- **Conflicto**: ambas usan mismo recurso (serializar)

Ejemplo: "Backend API 95% → Auth Service puede comenzar"

### Paso 3 — Calcular contribución a OKRs

Para cada iniciativa:
- Contribuye a: KR1, KR2
- Peso: % del target alcanzado
- Criticidad: 🔴 crítica / 🟡 importante / 🟢 soporte

### Paso 4 — Presentar timeline visual

ASCII timeline Q1-Q4 con:
- Progress bar de cada iniciativa
- Blocked/waiting/in-progress state
- Hitos clave
- Ruta crítica

### Paso 5 — Validar interdependencias

Preguntas:
- ¿Todos los hard blockers identificados?
- ¿Hay conflictos de recurso?
- ¿Cada iniciativa tiene owner?
- ¿Suma de contribuciones ≥ target de OKR?

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: strategy_mapping
initiatives_total: {n}
critical_path_weeks: {n}
dependencies_critical: {n}
resource_conflicts: {n}
timeline_months: {n}
map_file: "output/YYYYMMDD-strategy-map.md"
```

---

## Restricciones

- **NUNCA** cambiar ownership automáticamente
- **NUNCA** postponer iniciativas sin confirmación
- **NUNCA** omitir hard dependencies
- Hitos alineados a sprints reales (no aspiracionales)
- Ruta crítica = viva (recalcular cada sprint)
- Cada iniciativa debe tener owner + team
