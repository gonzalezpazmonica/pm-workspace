---
name: finance-investment-analyst
description: "Análisis de inversiones con Investment Memo estructurado, DCF, IRR/VAN/Payback y tablas de sensibilidad."
summary: |
  Produce Investment Memo de 9 secciones con valoración, riesgos y estructura.
  Trabaja con proyecciones del cliente; marca [SUPUESTO A VALIDAR] donde inventa.
  Input: descripción inversión + proyecciones + tasa descuento. Output: Investment Memo.
maturity: stable
context: isolated
context_cost: high
category: "professional-domain/finance"
tags: ["finanzas", "inversión", "DCF", "IRR", "VAN", "Investment Memo", "valoración"]
priority: "high"
---

# finance-investment-analyst — Analista de Inversiones

## Cuándo usar esta skill

- Al evaluar una inversión nueva (capex, adquisición, nuevo negocio).
- Al preparar un Investment Memo para comité de inversiones o board.
- Al comparar alternativas de inversión con metodología consistente.
- Al realizar due diligence financiero preliminar.

## Inputs requeridos

| Campo | Descripción | Ejemplo |
|---|---|---|
| `descripcion` | Descripción de la inversión | Adquisición empresa X por 5M€ |
| `proyecciones` | Flujos de caja o P&L proyectado | Tabla con 5 años de proyecciones |
| `tasa_descuento` | WACC o tasa de retorno mínima requerida | 10% WACC |
| `factores_riesgo` | Principales riesgos identificados | Dependencia cliente único, regulatorio |

Si no se aportan proyecciones, no las fabrica: genera plantilla con [SUPUESTO A VALIDAR].

## Outputs producidos

1. **Investment Memo** — 9 secciones estándar
2. **Valoración con múltiples métricas** — DCF, IRR, VAN, Payback, MoM según aplique
3. **Tabla de sensibilidad** — variaciones en supuestos clave (WACC ±2pp, crecimiento ±5pp)
4. **Lista de datos pendientes** — qué falta para completar el análisis

## Outputs excluidos

- Valoración de activos cotizados en tiempo real
- Due diligence legal o fiscal (requiere especialista)
- Recomendación de inversión con carácter de asesoramiento financiero regulado

## Disclaimer

Todo output incluye disclaimer financiero completo. Ver `docs/rules/domain/professional-domain-disclaimer.md`.

## Relación con otras skills

- **Complementaria**: `finance-cash-flow-analyst` (liquidez post-inversión)
- **Downstream**: `finance-financial-report-writer` (comunicación a inversores)
