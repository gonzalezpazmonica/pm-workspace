# /team:workload

Muestra la carga de trabajo por persona: items asignados, horas remaining y balance de equipo.

## Uso
```
/team:workload [proyecto]
```

## Pasos de Ejecución

1. Ejecutar WIQL para obtener todos los items activos del sprint actual asignados a cada persona
2. Para cada persona del equipo (leer de `projects/<proyecto>/equipo.md`):
   a. Items en estado Active o In Progress
   b. Items en estado New (pendientes de iniciar)
   c. Items en estado Resolved/Done (completados)
   d. Sum(RemainingWork) = carga pendiente total
   e. Count(Active items) = WIP actual
3. Comparar WIP con WIP_LIMIT_PER_PERSON
4. Detectar items sin asignar (unassigned) en el sprint
5. Mostrar distribución visual de la carga

## Formato de Salida

```
## Team Workload — [Proyecto] — [Sprint] — [Hoy]

| Persona | New | Active (WIP) | Done | Remaining (h) | Alerta |
|---------|-----|-------------|------|---------------|--------|
| Juan García | 3 | 2 ✅ | 5 | 18h | OK |
| Ana López | 1 | 3 ⚠️ | 4 | 24h | WIP alto |
| Pedro Ruiz | 0 | 1 ✅ | 8 | 4h | OK |

**WIP Limit configurado:** 2 items por persona

### 📋 Items Sin Asignar (en sprint)
| ID | Título | Tipo | SP |
|----|---------|----|-----|
| AB#XXXX | ... | Task | — |

### 📊 Distribución de Carga (Remaining Work)
Juan García  ████████████████ 18h
Ana López    ████████████████████████ 24h
Pedro Ruiz   ████ 4h

**Recomendación:** Redistribuir X task de Ana López a Pedro Ruiz (4h disponibles).
```
