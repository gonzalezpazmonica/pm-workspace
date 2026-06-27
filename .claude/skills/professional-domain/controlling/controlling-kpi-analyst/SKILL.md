---
name: controlling-kpi-analyst
description: "Evalúa KPIs de gestión, identifica tendencias y genera narrativa comentada con semáforo y alertas."
summary: |
  Analiza KPIs con fórmulas exactas, benchmarks sectoriales y semáforo.
  Identifica outliers y genera narrativa para controllers y dirección.
  Input: KPI data + benchmark + comparativa. Output: tabla evaluación + narrativa.
maturity: stable
context: isolated
context_cost: medium
category: "professional-domain/controlling"
tags: ["controlling", "KPI", "ratios", "ROIC", "NOF", "CCC", "gestión"]
priority: "high"
---

# controlling-kpi-analyst — Analista de KPIs de Gestión

## Cuándo usar esta skill

- Al evaluar el desempeño mensual o trimestral con ratios financieros.
- Para identificar tendencias preocupantes antes de que escalen.
- Al preparar el cuadro de mando para la dirección.
- Para comparar KPIs contra benchmark sectorial o año anterior.

## Inputs requeridos

| Campo | Descripción | Ejemplo |
|---|---|---|
| `kpi_data` | KPIs del período con valores reales | ROE: 12%, margen EBITDA: 18% |
| `benchmark` | Referencia de comparación (opcional) | Benchmark sectorial o año anterior |
| `comparativa` | Períodos a comparar | Q2-26 vs Q2-25 vs Q1-26 |
| `tipo_empresa` | Sector y modelo negocio | Servicios profesionales / Industrial / SaaS |

## Outputs producidos

1. **Tabla de evaluación** — KPI / real / referencia / semáforo / tendencia (↑↓→)
2. **Análisis de outliers** — KPIs fuera de rango con causa probable
3. **Narrativa comentada** — para cada KPI material, causa + impacto + acción
4. **Indicadores de alerta** — señales de deterioro estructural (no solo puntual)

## Disclaimer sobre benchmarks

Los benchmarks sectoriales son aproximaciones de mercado, no datos certificados. La skill señala explícitamente qué datos son sectoriales aproximados vs datos verificados del cliente.

## Disclaimer

Todo output incluye disclaimer de controlling. Ver `docs/rules/domain/professional-domain-disclaimer.md`.

## Relación con otras skills

- **Upstream**: datos de `controlling-variance-analyzer`
- **Downstream**: `controlling-management-report` (los KPIs alimentan la sección de indicadores)
