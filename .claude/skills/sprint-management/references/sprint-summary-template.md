# Plantilla de Resumen de Sprint

## Formato Markdown

```markdown
## Estado del Sprint — [Nombre Sprint]
**Período:** [startDate] → [finishDate] | **Días restantes:** X | **Semana:** X/2

### Progreso General
- **Story Points:** X/Y completados (Z%)
- **Remaining Work:** Xh / **Capacity restante:** Yh
- **Items:** X Done | Y In Progress | Z New
- **Velocity:** [media_historica] SP (actual: 70% de media → ⚠️)

### Distribución por Estado
| Estado | Cantidad | % | RemainingWork |
|--------|----------|---|---|
| Done | 15 | 38% | — |
| In Progress | 18 | 45% | 65h |
| New | 7 | 17% | 30h |
| **Total** | **40** | **100%** | **95h** |

### Utilización por Persona
| Persona | Items | RemainingWork | Capacity | % | Estado |
|---------|-------|---|---|---|---|
| Juan García | 5 | 18h | 30h | 60% | 🟢 OK |
| María López | 8 | 35h | 30h | 117% | 🔴 SOBRE-CARGADO |
| Pedro Ruiz | 6 | 22h | 30h | 73% | 🟢 OK |
| Ana Martín | 9 | 20h | 30h | 67% | 🟢 OK |
| **Total Equipo** | **28** | **95h** | **120h** | **79%** | **🟢 OK** |

### Alertas y Riesgos
- 🔴 María López: 35h de trabajo en 30h de capacidad — **Redistribuir 5h**
- 🟡 Progreso bajo (70%): Revisar bloqueos en Daily
- 🟢 RemainingWork dentro de capacidad restante

### Próximas Acciones
- [ ] Reunión Daily con María para redistribuir tareas
- [ ] Revisar bloqueos en items "In Progress"
- [ ] Completar al menos 8 SP antes del viernes

### Burndown Estimado
```
100% ━━ [Estimado]  ◆ [Real hoy]
 80% ┃   ◆
 60% ┃       ◆
 40% ┃             ◆
 20% ┃                   ◆
  0% ┗━━━━━━━━━━━━━━━━━━
      L  M  X  J  V
```
```

## Instrucciones de Generación

1. Reemplazar placeholders:
   - `[Nombre Sprint]` → "Sprint 2026-04"
   - `[startDate]` → "2026-02-24"
   - `[finishDate]` → "2026-03-10"
   - X, Y, Z con números reales

2. Calcular indicadores:
   - % Utilización = (RemainingWork / Capacity) * 100
   - Estado: 🟢 si <85%, 🟡 si 85-100%, 🔴 si >100%
   - Tendencia: ↑↓→ basada en histórica velocity

3. Listar alertas solo si existen

4. Guardar como `projects/{proyecto}/sprints/{sprint}/summary.md`
