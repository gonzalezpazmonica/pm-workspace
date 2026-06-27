---
name: finance-cash-flow-analyst
description: "Análisis de liquidez y forecast de tesorería con ratios, períodos de riesgo y recomendaciones concretas."
summary: |
  Evalúa liquidez con ratios exactos (corriente/ácida/inmediata/cobertura).
  Identifica períodos de riesgo y palancas de optimización del circulante.
  Input: datos tesorería + obligaciones próximas. Output: evaluación + forecast.
maturity: stable
context: isolated
context_cost: medium
category: "professional-domain/finance"
tags: ["finanzas", "tesorería", "liquidez", "NOF", "CCC", "cash-flow", "circulante"]
priority: "high"
---

# finance-cash-flow-analyst — Analista de Tesorería

## Cuándo usar esta skill

- Al evaluar la posición de liquidez actual y el riesgo a corto plazo.
- Al preparar un forecast de tesorería (13 semanas o mensual).
- Al identificar palancas de mejora del circulante (DSO, DPO, inventario).
- Al evaluar capacidad de endeudamiento adicional.
- Ante tensiones de liquidez para priorizar pagos y negociar con proveedores.

## Inputs requeridos

| Campo | Descripción | Ejemplo |
|---|---|---|
| `posicion_inicial` | Saldo de tesorería actual | 500k€ en cuenta corriente |
| `cobros_previstos` | Cobros esperados con fechas | Tabla de vencimientos de clientes |
| `pagos_obligaciones` | Pagos comprometidos | Nóminas, proveedores, préstamos, impuestos |
| `período` | Horizonte de análisis | 13 semanas / 6 meses |

## Outputs producidos

1. **Evaluación de liquidez** — 4 ratios con semáforo y comparativa
2. **Forecast de tesorería** — tabla semana/mes con saldo proyectado
3. **Períodos de riesgo** — semanas/meses con saldo negativo o inferior a mínimo operativo
4. **Recomendaciones** — acciones concretas ordenadas por impacto en liquidez

## Disclaimer

Todo output incluye disclaimer financiero completo. Ver `docs/rules/domain/professional-domain-disclaimer.md`.

## Relación con otras skills

- **Upstream**: `controlling-kpi-analyst` (ratios de circulante)
- **Downstream**: `finance-financial-report-writer` (comunicar posición a banco o inversores)
