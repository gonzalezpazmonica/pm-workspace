---
name: flow-intake
description: Intake continuo — mover items Spec-Ready a Production y asignar a builders
developer_type: pm
agent: azure-devops-operator
context_cost: moderate
max_context: 4000
allowed_modes: [pm, lead, all]
---

# /flow-intake — Intake Continuo de Features a Producción

> Proceso semiautomático: validar specs listos, evaluar capacidad, asignar builders, mover a Production.

## Uso
`/flow-intake [--dry-run] [--auto-assign] [--spec {ID}] [--project {nombre}]`

## Subcomandos
- `--dry-run` (default): Muestra items candidatos sin cambios
- `--auto-assign`: Asigna automáticamente a builders disponibles
- `--spec {PBI#XXXX}`: Procesar una sola spec (reduce contexto, previene overflow)
- `--project {nombre}`: Proyecto específico (default: activo)

## Flujo principal

### 1. Descubrimiento
Ejecutar WIQL para encontrar items candidatos:
```
SELECT * FROM workitems 
WHERE [Area Path] = '{Project}/Exploration' 
  AND [State] = 'Spec-Ready'
  AND [System.TeamProject] = '{Project}'
  ORDER BY [Changed Date] DESC
```

### 2. Validación por item
Para cada spec-ready:
- Validar: Acceptance criteria rellenada ≥ 3 items
- Validar: DoD pre-checklist completado (70%+ ítems marcados)
- Validar: Outcome ID (Epic) linkada
- Validar: Story Points estimados (1-21)

Si falta algo → marcar YELLOW (aviso), incluir en reporte.

### 3. Evaluación de capacidad (builders)
Listar builders del equipo (asignees en Production area):
- Por cada builder: contar WIP actual (items en [Ready, Building, Gate-Review])
- Comparar con WIP limit del equipo
- Calcular disponibilidad: max_wip - wip_actual

### 4. Matching & Asignación
Para cada item spec-ready:
- Buscar builder con mejor match: skill + menor WIP + contexto (último sprint trabajó en similar)
- Modo `--dry-run`: mostrar propuesta ("→ asignar a {builder}")
- Modo `--auto-assign`: hacer el cambio + mover a Production + set Ready

### 5. Transición
- Area Path: {Project}/Exploration → {Project}/Production
- State: Spec-Ready → Ready
- Asignado a: {builder}
- Tag: "intake-{date}" para auditoría

## Output
```
INTAKE CANDIDATES — {proyecto} — {date}

Candidatos validados ............... {N}
Validación fallida ................. {N} ⚠️
Builders disponibles ............... {M}

Propuesta de asignación:
┌──────────┬─────────────────┬──────────┬─────────┐
│ ID       │ Feature         │ Asignado │ WIP/Max │
├──────────┼─────────────────┼──────────┼─────────┤
│ PBI#1234 │ Pagos ACH       │ Carlos   │  2/5    │
│ PBI#1235 │ Reportes        │ Ana      │  1/5    │
└──────────┴─────────────────┴──────────┴─────────┘

⚠️ 2 items con validación incompleta (ver detalle)

Próximos pasos:
- --auto-assign para ejecutar las asignaciones
- /flow-board para ver tablero actualizado
```

Si >30 líneas → guardar en `projects/{proyecto}/.flow/intake-{date}.md`

## Gestión de bloqueadores
- Builder con WIP al límite → mostrar como "NO DISPONIBLE"
- Spec sin outcome → marcar como "REQUIERE LINAJE"
- Falta DoD → sugerir completar antes de intake
