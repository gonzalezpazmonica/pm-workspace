# /board-flow

Analiza el flujo de trabajo del board: WIP actual, cuellos de botella y métricas de flujo.

## Uso
```
/board-flow [proyecto]
```

## Pasos de Ejecución

1. Obtener configuración del board (columnas, WIP limits) vía API:
   `GET {org}/{project}/{team}/_apis/work/boards/{boardName}`
2. Obtener items en cada columna del board con timestamps de transición
3. Calcular por columna:
   - Items actuales (WIP)
   - WIP limit configurado
   - Tiempo medio en columna (avg age of items)
   - Items bloqueados (si se usa el campo "Blocked")
4. Calcular Cycle Time = fecha Resolved - fecha Active (usando WorkItem Revisions)
5. Detectar cuellos de botella: columnas con WIP >= límite o avg age > umbral
6. Calcular Lead Time = fecha Done - fecha Created
7. Mostrar Cumulative Flow Diagram (datos para los últimos 14 días) si Analytics está disponible

## Formato de Salida

```
## Board Flow Analysis — [Proyecto] — [Fecha]

### Estado del Board
| Columna | Items | WIP Limit | Avg Age | Estado |
|---------|-------|-----------|---------|--------|
| New | 12 | — | 5.2 días | — |
| Active | 3 | 5 | 2.1 días | 🟢 OK |
| In Review | 5 | 3 | 4.8 días | 🔴 EXCEDE WIP |
| Done | 8 | — | — | 🟢 |

### ⚡ Flow Efficiency & WIP Aging
- **Flow Efficiency** : 58% ↑ (meta: >60%)
- **%C&A (Quality)** : 94% (items sin rework)

**WIP Aging (Items en Progreso)**
| ID | Tipo | Días | Status |
|----|------|------|--------|
| FEAT-801 | Feature | 8 | 🟡 AMBER |
| BUG-345 | Bug | 5 | 🟢 OK |
| DEBT-12 | Debt | 3 | 🟢 OK |

### ⚠️ Cuellos de Botella Detectados
- **In Review**: WIP 5/3 (excede límite). Items: AB#1001 (6 días), AB#1008 (3 días)
- **FEAT-801 (8 días)**: Aproximándose a umbral de riesgo (1.5× cycle time = 7.5 días)

### Métricas de Flujo
- Cycle Time medio: 5.0 días (último sprint)
- Lead Time medio: 12.3 días (último sprint)
- Flow Efficiency: 58% (Activos / Total Elapsed)
- Throughput: 14 items/semana
- **→ Para análisis detallado de Flow Metrics**: ejecutar `/flow-metrics`

### Recomendaciones
- Revisar PR de AB#1001 (lleva 6 días en Review sin actividad)
- Considerar aumentar capacidad de Review o reducir WIP de Active
- Investigar FEAT-801: en riesgo de sobrepasarse el ciclo time normal
- Mejorar Flow Efficiency: target 60%+ (revisar items bloqueados en New)
```
