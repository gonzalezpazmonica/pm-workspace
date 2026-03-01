# /kpi-dashboard

Muestra el dashboard completo con todos los KPIs definidos en docs/kpis-equipo.md.

## 1. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Reporting** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/preferences.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/tone.md`
3. Adaptar output según `preferences.language`, `preferences.detail_level`, `preferences.report_format` y `tone.formality`
4. Si no hay perfil → continuar con comportamiento por defecto

## 2. Uso
```
/kpi-dashboard [proyecto] [--sprints N]
```
`--sprints N`: número de sprints para análisis de tendencia (default: 5).

## 3. Pasos de Ejecución

1. Leer `docs/kpis-equipo.md` para obtener la lista de KPIs y sus umbrales
2. Para cada KPI, ejecutar la query/API correspondiente (ver fuentes en kpis-equipo.md)
3. Calcular tendencia comparando con los últimos N sprints
4. Aplicar semáforo según umbrales configurados
5. Generar vista de dashboard en terminal + opcionalmente guardar como HTML en `output/`

## KPIs Calculados

| KPI | Fuente | Método de cálculo |
|-----|--------|-------------------|
| Velocity | WIQL + WorkItems | Sum(SP) de items Done del sprint |
| Sprint Burndown | Analytics OData | WorkItemSnapshot diario |
| Cycle Time | WorkItem Revisions | Fecha Resolved - Fecha Active |
| Lead Time | WorkItem Revisions | Fecha Done - Fecha Created |
| Capacity Utilization | Capacities API + WIQL | CompletedWork / Capacity configurada |
| Sprint Goal Hit Rate | sprints/ historial local | % sprints con goal cumplido |
| Bug Escape Rate | WIQL filtrado | Bugs post-release / total items release |
| Throughput | Analytics OData | Items Done por semana |

## Formato de Salida

```
## KPI Dashboard — [Proyecto] — [Sprint actual] — [Fecha]

### Velocity (SP por sprint)
Sprint N-4: 32 SP ████████████████
Sprint N-3: 28 SP ██████████████
Sprint N-2: 35 SP █████████████████
Sprint N-1: 30 SP ███████████████
Sprint N:   33 SP ████████████████  ← actual
Media: 31.6 SP | Tendencia: 📈 +4%

### Sprint Goal Hit Rate (últimos 5 sprints)
✅✅❌✅✅ → 80% | Umbral objetivo: 80% 🟢

### Cycle Time (días)
Media: 3.2 días | P75: 5.1 días | P95: 9.2 días

### Capacity Utilization
Equipo: 84% | Objetivo: 70-90% 🟢

### Bug Escape Rate
Sprint actual: 2% | Umbral máximo: 5% 🟢

### 📊 Resumen Semáforo
| KPI | Valor | Umbral | Estado |
|-----|-------|--------|--------|
| Velocity | 33 SP | > 28 | 🟢 |
| Goal Hit Rate | 80% | > 80% | 🟢 |
| Cycle Time | 3.2d | < 5d | 🟢 |
| Capacity | 84% | 70-90% | 🟢 |
| Bug Escape | 2% | < 5% | 🟢 |
```
