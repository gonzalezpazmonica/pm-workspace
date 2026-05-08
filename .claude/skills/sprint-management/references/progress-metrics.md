# Métricas de Progreso del Sprint — Cálculos

## 1. Story Points: Planificado vs Completado

```bash
SP_completados = sum(StoryPoints donde State IN ('Done','Closed','Resolved'))
SP_planificados = sum(StoryPoints de todos los PBIs del sprint)
Progreso_pct = (SP_completados / SP_planificados) * 100
```

**Ejemplo:**
- Planificado: 40 SP
- Completado: 28 SP
- Progreso: 28/40 = 70%

## 2. Remaining Work Total

```bash
RemainingWork_total = sum(RemainingWork donde State IN ('New','Active','In Progress'))
```

**Ejemplo:**
- 15 items activos con restante promedio 4h = 60h pendientes

## 3. Capacidad Disponible Restante

```bash
Dias_restantes = (finishDate - today) en días hábiles
Capacity_restante = Dias_restantes * TEAM_HOURS_PER_DAY * TEAM_FOCUS_FACTOR * num_personas
```

**Ejemplo:**
- 5 días restantes
- 5 personas
- 8h/día * 0.75 = 6h productivas/día
- Capacity: 5 * 6 * 5 = 150h disponibles

## 4. Análisis de Riesgo

```bash
if RemainingWork_total > Capacity_restante:
    estado = "🔴 RIESGO — No hay capacidad para completar"
elif RemainingWork_total > Capacity_restante * 0.8:
    estado = "🟡 AL LÍMITE — Poco margen"
else:
    estado = "🟢 OK — Hay margen de seguridad"
```

## 5. Distribución por Estado

```bash
New = count(items donde State = 'New')
Active/In Progress = count(items donde State IN ('Active','In Progress'))
Done = count(items donde State IN ('Done','Closed','Resolved'))
```

Mostrar en tabla: `| Estado | Cantidad | % | RemainingWork |`

## 6. Distribución por Persona

| Persona | Items | RemainingWork | Capacity | % Utilización | Estado |
|---------|-------|---|---|---|---|
| Juan | 5 | 20h | 30h | 67% | OK |
| María | 8 | 35h | 30h | 117% | SOBRE-CARGADO |

Fórmula: `% = RemainingWork / Capacity * 100`

## 7. Velocity Histórica

```bash
Para i=1 hasta VELOCITY_SPRINTS:
    SP_completados_sprint_i = query(sprint_i)
    velocity_sprints.append(SP_completados_sprint_i)

velocity_media = sum(velocity_sprints) / len(velocity_sprints)
tendencia = "↑ Creciente" / "→ Estable" / "↓ Decreciente"
```

**Ejemplo:**
- Últimos 5 sprints: [35, 38, 40, 36, 42]
- Media: 38.2 SP
- Tendencia: Estable con picos
