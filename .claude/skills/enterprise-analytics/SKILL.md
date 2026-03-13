---
name: enterprise-analytics
description: "Enterprise analytics — SPACE metrics, portfolio aggregation, team health, risk matrix, forecasting"
maturity: beta
context: fork
agent: architect
context_cost: medium
dependencies: []
memory: project
category: "reporting"
tags: ["analytics", "space-metrics", "portfolio", "forecasting"]
priority: "medium"
---

# Skill: Enterprise Analytics

> Prerequisito: @.claude/rules/domain/enterprise-metrics.md

Orquesta cálculo de métricas SPACE, agregación portfolio, análisis de salud por equipo, detección de riesgos cross-proyecto, y forecasting.

## Flujo 1 — Portfolio (`portfolio`)

1. Leer data de todos los proyectos (velocity, deployments, lead time)
2. Calcular SPACE_avg por proyecto
3. Agregar portfolio score
4. Generar tabla: proyecto, velocity, health, trend, risk
5. Output: dashboard portfolio + top risks

## Flujo 2 — Team Health (`team-health`)

1. Leer data del equipo: velocidad, WIP, burnout, comunicación
2. Calcular cada dimensión SPACE (0-100)
3. Generar gráfico radar (5 ejes = 5 dimensiones)
4. Identificar fortalezas/debilidades
5. Output: scores + recomendaciones

## Flujo 3 — Risk Matrix (`risk-matrix`)

1. Mapear dependencies entre proyectos
2. Identificar críticas (red status, bloqueadas > 48h)
3. Calcular risk exposure por proyecto
4. Output: matriz 2D (likelihood × impact) + alertas

## Flujo 4 — Forecast (`forecast`)

1. Leer últimos 5 sprints de velocity
2. Calcular optimistic/likely/pessimistic ranges
3. Proyectar 2 quarters adelante
4. Output: gráfico + table con predictions + confidence intervals

## Errores

| Error | Acción |
|---|---|
| Equipo sin datos | Crear proyecto stub; mostrar datos insuficientes |
| Velocity inconsistente | Usar últimas 3 sprints válidos |
| Dependencies circulares | Alertar como CRÍTICO |

## Seguridad

- Métricas pueden ser compartidas (no hay PII)
- Forecasts son internos (no prometer a clientes sin validación)
