---
name: sales-pipeline-analyst
description: "Analista de Pipeline de Ventas: analiza salud del pipeline con metodología MEDDIC y produce forecast conservador con deals en riesgo."
summary: "Semáforo RAG por deal, forecast conservador, acciones recomendadas. Documenta supuestos de % cierre por etapa."
maturity: stable
context: fork
context_cost: medium
context_tier: L3
category: "professional-domain/sales"
tags: ["ventas", "pipeline", "MEDDIC", "forecast", "CRM", "salud-deal"]
trigger:
  keywords: ["pipeline", "forecast", "salud del pipeline", "deals en riesgo", "qué va a cerrar", "revisión comercial"]
---

# Skill: Sales Pipeline Analyst

Analiza el pipeline de ventas para producir una visión de salud por deal,
forecast conservador y acciones priorizadas para el período en análisis.
Metodología basada en MEDDIC como criterio de calificación.

## Cuándo usarlo

- Revisión semanal o mensual del pipeline con el equipo comercial
- Antes de una presentación de forecast a dirección
- Cuando un deal lleva tiempo estancado sin avance claro
- Para decidir en qué deals concentrar esfuerzo en el período

## Inputs requeridos

| Campo | Descripción |
|---|---|
| `deals` | Lista de oportunidades con: empresa, valor, etapa, fecha cierre esperada |
| `criterios_MEDDIC` | Para cada deal: qué criterios MEDDIC están cubiertos |
| `periodo_analisis` | Mes / trimestre que se está revisando |
| `objetivo_periodo` | Target numérico del período |

## Output producido

1. **Salud por deal**: semáforo MEDDIC (VERDE / AMARILLO / ROJO) con justificación
2. **Forecast conservador**: suma de deals VERDE × 90% + AMARILLO × 40%
3. **Deals en riesgo**: lista priorizada con causa de riesgo y acción inmediata
4. **Acciones recomendadas**: por deal, con responsable y fecha límite
5. **Supuestos documentados**: % de cierre por etapa utilizados en el forecast

## Restricciones absolutas

- SIEMPRE documentar los % de cierre por etapa usados en el forecast
- No aplicar % optimistas sin justificación explícita
- Si falta información MEDDIC para un deal, marcarlo como AMARILLO por defecto
- No fabricar datos de pipeline — trabajar solo con lo aportado

## Relación con otros skills

- **Upstream**: `sales-account-research` — brief de cuenta para enriquecer deals
- **Paralelo**: `sales-objection-analyzer` — cada objeción activa afecta al semáforo
- **Downstream**: informe ejecutivo con forecast al management
