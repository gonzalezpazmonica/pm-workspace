# /sprint-review

Genera el resumen para la Sprint Review con todos los datos del sprint cerrado.

## Uso
```
/sprint-review [proyecto] [--sprint "Sprint 2026-XX"]
```
Si no se indica sprint, usa el sprint actual (o el último cerrado).

## Pasos de Ejecución

1. Obtener todos los work items del sprint con estado final
2. Separar: items completados (Done/Closed) vs no completados (moved/rollback)
3. Calcular velocity del sprint: sum(StoryPoints de items Done)
4. Comparar con velocity media de los últimos `VELOCITY_AVERAGE_SPRINTS` sprints
5. Calcular porcentaje de Sprint Goal cumplido
6. Obtener bugs encontrados durante el sprint
7. Listar items arrastrados al siguiente sprint
8. Generar el documento con la skill `executive-reporting`
9. Guardar en `output/sprints/YYYYMMDD-review-<proyecto>.docx`

## Formato de Salida

```
## Sprint Review — [Sprint Name] — [Fecha]

### Resumen Ejecutivo
- Sprint Goal: [objetivo] → ✅ Cumplido / ⚠️ Parcial / ❌ No cumplido
- Velocity: X SP (media últimos 5: Y SP) → tendencia 📈/📉

### Items Completados (X SP)
| ID | Título | SP | Responsable |
...

### Items No Completados → Backlog
| ID | Título | SP | Motivo |
...

### Bugs del Sprint
...

### Métricas del Sprint
- Cycle Time medio: X días
- Bug Escape Rate: X%
- Capacity Utilization: X%

### Demo Notes
[espacio para notas de la review]
```
