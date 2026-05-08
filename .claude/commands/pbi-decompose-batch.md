---
name: pbi-decompose-batch
description: Decompose multiple PBIs into technical tasks
---

---

# /pbi-decompose-batch

Descompone varios PBIs a la vez, optimizando las asignaciones en conjunto para equilibrar la carga global.

## 1. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **PBI & Backlog** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/workflow.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/tools.md`
3. Adaptar output según `identity.rol`, `workflow.sdd_active` y disponibilidad de `tools.azure_devops`
4. Si no hay perfil → continuar con comportamiento por defecto

## 2. Uso
```
/pbi-decompose-batch {id1,id2,id3} [--project {nombre}]
```

- `{id1,id2,id3}`: IDs separados por coma (ej: `1234,1235,1236`)
- `--project`: Proyecto AzDO (default: el del CLAUDE.md raíz)

## 3. Diferencia con /pbi-decompose individual

En el modo batch, la asignación de tasks es **global y coordinada**:
- El agente carga el estado de capacity del equipo una sola vez al inicio
- Tras descomponer el primer PBI y proponer asignaciones, actualiza internamente la carga simulada
- Al descomponer el segundo PBI, las horas ya asignadas (simuladas) del primer PBI se restan de la disponibilidad
- Resultado: **distribución equilibrada entre todos los PBIs**, no uno por uno

## 4. Pasos de Ejecución

1. **Cargar contexto** (igual que `/pbi-decompose`)
2. **Obtener todos los PBIs** en una sola pasada de la API
3. **Obtener capacity del equipo** (una sola llamada, estado actual)
4. Para cada PBI en orden de prioridad:
   a. Analizar + Inspeccionar código
   b. Descomponer en Tasks
   c. Estimar con factores de ajuste
   d. Asignar usando el estado de carga acumulado (no el estado inicial)
   e. Actualizar el estado de carga simulado para el siguiente PBI
5. **Presentar propuesta completa** de todos los PBIs juntos:
   - Una tabla por PBI
   - Vista de impacto consolidado en capacity del equipo al final
   - Alertas de sobre-asignación si las hay
6. Pedir confirmación global: "¿Creo todas estas Tasks en Azure DevOps?"
7. Crear en bloque tras confirmación

## Formato de Salida

```
📦 Descomposición batch — {N} PBIs — Proyecto {nombre}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 PBI #1234: {título} (5 SP)
   [tabla de tasks]
   Total: 17h

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 PBI #1235: {título} (3 SP)
   [tabla de tasks]
   Total: 10h

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 IMPACTO TOTAL EN EL EQUIPO
   ┌─────────────────┬──────────┬──────────┬──────────┬────────┐
   │ Persona         │ Capacity │ Prev.    │ +Nuevo   │ Total  │
   ├─────────────────┼──────────┼──────────┼──────────┼────────┤
   │ María García    │ 48h      │ 28h      │ +14h     │ 42h 🟢 │
   │ Carlos Ruiz     │ 48h      │ 35h      │ +8h      │ 43h 🟢 │
   │ Ana López       │ 30h      │ 18h      │ +5h      │ 23h 🟢 │
   │ Pedro Torres    │ 42h      │ 40h      │ +2h      │ 42h 🟡 │
   └─────────────────┴──────────┴──────────┴──────────┴────────┘
   Total tasks nuevas: N | Total horas nuevas: Xh

¿Creo todas estas Tasks en Azure DevOps? (s/n, o indica qué ajustar)
```
