---
name: controlling-variance-analyzer
description: "Análisis de desviaciones real vs budget con causa raíz, narrativa para dirección y semáforo RAG."
summary: |
  Analiza desviaciones presupuestarias (5 tipos: volumen/precio/mix/eficiencia/calendario).
  Produce tabla RAG + narrativa ejecutiva + acciones correctoras cuantificadas.
  Input: real + budget + período. Output: informe de desviaciones para dirección.
maturity: stable
context: isolated
context_cost: medium
category: "professional-domain/controlling"
tags: ["controlling", "presupuesto", "desviaciones", "variance", "gestión", "CFO"]
priority: "high"
---

# controlling-variance-analyzer — Analizador de Desviaciones Presupuestarias

## Cuándo usar esta skill

- Al cerrar el mes y comparar resultados reales con el budget/forecast.
- En revisiones de mitad de año para reforecast.
- Al preparar la presentación al CFO o al consejo sobre desviaciones materiales.
- Para identificar la causa raíz de una desviación antes de la reunión de dirección.

## Inputs requeridos

| Campo | Descripción | Ejemplo |
|---|---|---|
| `datos_reales` | P&L o partidas reales del período | Tabla con ventas, costes, márgenes |
| `datos_budget` | Budget o forecast de referencia | Mismo formato que reales |
| `período` | Mes, trimestre o acumulado | Junio 2026 / Q2 2026 / YTD Jun-26 |
| `materialidad` | Umbral de desviación significativa | 5% o 50.000€ (el mayor) |

Si el usuario no aporta datos reales, genera plantilla vacía con [DATO REAL PENDIENTE] en cada celda.

## Outputs producidos

1. **Tabla resumen con RAG** — partida / real / budget / desviación € / desviación % / semáforo
2. **Análisis de desviaciones materiales** — causa + impacto cuantificado + tipo de desviación (5 tipos)
3. **Narrativa ejecutiva** — bullet points por área, formato dirección
4. **Acciones correctoras** — ordenadas por impacto potencial con responsable y plazo

## Outputs excluidos

- Auditoría de los datos reales (se trabaja con los datos aportados como válidos)
- Proyecciones de cierre de año (requiere forecast actualizado)

## Disclaimer

Todo output incluye disclaimer de controlling. Ver `docs/rules/domain/professional-domain-disclaimer.md`.

## Relación con otras skills

- **Upstream**: `controlling-kpi-analyst` (contexto de KPIs antes del análisis)
- **Downstream**: `controlling-management-report` (las desviaciones alimentan el informe de gestión)
