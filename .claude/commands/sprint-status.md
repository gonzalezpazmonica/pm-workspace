# /sprint:status

Muestra el estado completo del sprint actual de un proyecto.

## Uso
```
/sprint:status [proyecto]
```
Si no se indica proyecto, usar el definido en `AZURE_DEVOPS_DEFAULT_PROJECT`.

## Pasos de Ejecución

1. Cargar variables de entorno desde `.claude/.env`
2. Leer el CLAUDE.md del proyecto indicado (`projects/<proyecto>/CLAUDE.md`)
3. Usar la skill `sprint-management` para obtener el sprint actual
4. Obtener work items del sprint con campos: Id, Title, State, AssignedTo, WorkItemType, CompletedWork, RemainingWork, StoryPoints
5. Calcular:
   - Total Story Points planificados vs completados
   - RemainingWork total del equipo
   - Distribución de items por estado (New, Active, Resolved, Closed)
   - Distribución por persona
6. Mostrar alertas si:
   - Alguna persona supera el WIP_LIMIT_PER_PERSON (default: 2 items Active)
   - RemainingWork excede la capacity restante del sprint
   - Hay bugs sin asignar
7. Presentar resumen en formato tabla markdown con semáforo 🟢🟡🔴

## Formato de Salida

```
## Sprint Status — [Nombre Sprint] — [Fecha]

**Sprint Goal:** [objetivo del sprint]
**Días restantes:** X | **Capacidad restante:** Xh

### Progreso General
| Métrica | Valor | Estado |
|---------|-------|--------|
| Story Points | X/Y completados | 🟢/🟡/🔴 |
| Remaining Work | Xh | 🟢/🟡/🔴 |
| Items Done | X/Y | 🟢/🟡/🔴 |

### Items por Estado
...

### Carga por Persona
...

### ⚠️ Alertas
...
```
