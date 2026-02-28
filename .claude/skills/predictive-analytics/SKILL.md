---
name: predictive-analytics
description: Fórmulas de predicción sprint, Monte Carlo simplificado y flow metrics
context: fork
context_cost: medium
agent: azure-devops-operator
---

# Predictive Analytics Skill

## §1 Monte Carlo Simplificado

**Entrada**: velocity_history, items_remaining (pts), sprint_length, current_day

**Algoritmo**: for i=1 to 1000: sim_velocity = random(velocity_history); sprints_needed = ceil(remaining / velocity); completion_date = current_day + (sprints_needed * sprint_length); results.append(date)

**Salida**: percentiles P50, P70, P85, P95 (fechas posibles)

**Interpretación**:
- P50: fecha más probable (50% chances)
- P70/P85: recomendado para comunicar (balance realista/optimista)
- P95: caso conservador (worst-case razonable)

---

## §2 Confidence Intervals

**Cálculo**: P_X = percentile(results, X%) | Ejemplo: P70 = results[700] de 1000

**Audiencia**: Equipo interno→P50, Product Owner→P85, Ejecutivos→P95, Cliente→P70-P85

**Advertencia**: Nunca comunicar P50 como promesa sin contexto de variabilidad

---

## §3 Flow Efficiency

**Fórmula**: (Active Time / Total Elapsed Time) × 100
- **Active**: "Active", "In Progress", "In Review" (en días)
- **Total**: "Created" a "Closed" (en días)

**Interpretación**:
- <30%: muy baja (colas/bloqueado)
- 30-50%: aceptable
- 50-70%: buena
- >70%: excelente

**Ejemplo**: Item 13 días total | 7 días Active + 1 día Review = 8 activos | 8/13 = 61.5%

**Agregado**: Team FE = promedio(FE todos items completados en período)

---

## §4 WIP Aging Alertas

**Fórmula**:
```
cycle_time_avg = promedio(últimos 20 items completados)
age = hoy - fecha_entrada_estado

ROJO:  age > 2.0 × cycle_time_avg   → investigar bloqueo
AMBER: age > 1.5 × cycle_time_avg   → verificar progreso
VERDE: age ≤ 1.5 × cycle_time_avg   → monitorear normal
```

**Ejemplo**: cycle_time=5d | ROJO>10d, AMBER>7.5d, VERDE≤7.5d

---

## §5 Throughput Trend

**Entrada**: items_completed_per_week (últimas 4-8 semanas)

**Linear Regression**: slope = cov(x,y) / var(x)
- slope > 0: IMPROVING ↑
- slope ≈ 0: STABLE →
- slope < 0: DECLINING ↓

**Requisito**: mínimo 4 data points, ignorar outliers

---

## §6 Azure DevOps Integration

**WIQL - Velocity por Sprint**:
```
SELECT [System.Id], [System.Title], [Microsoft.VSTS.Scheduling.StoryPoints]
WHERE [System.TeamProject] = @project AND [System.IterationPath] = @iteration AND [System.State] = 'Closed'
```

**WIQL - State Transitions** (Lead/Cycle Time):
```
SELECT [System.Id], [System.ChangedDate], [System.State]
WHERE [System.TeamProject] = @project AND [System.ChangedDate] >= @startDate
```

**WIQL - WIP Aging**:
```
SELECT [System.Id], [System.Title], [System.State], [System.StateChangeDate]
WHERE [System.State] IN ('Active', 'In Progress')
```

---

## §7 Limitaciones

| Técnica | Limitación |
|---------|-----------|
| Monte Carlo | No considera cambios de equipo; regenerar si hay alta rotación |
| Flow Metrics | Requiere logging consistente de transiciones de estado |
| Velocity Trend | Mínimo 6 sprints para anomalía detection; vacaciones distorsionan |
| Factores no-cuantitativos | Moral, requisitos calidad, acoplamiento técnico no se miden |

---

## §8 Recomendaciones

1. No usar predicciones como "compromisos" fijos
2. Usar como inputs para planeación y comunicación
3. Revisar factores explicativos regularmente
4. Ajustar modelos si el equipo experimenta cambios
5. Combinar datos cuantitativos + insights cualitativos

