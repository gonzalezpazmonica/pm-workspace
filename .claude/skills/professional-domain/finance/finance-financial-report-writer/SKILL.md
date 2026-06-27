---
name: finance-financial-report-writer
description: "Redacta informes financieros adaptados a la audiencia (inversores/banco/regulador/dirección) con ratios comentados."
summary: |
  Genera informes financieros con ratios exactos, análisis de tendencias y outlook.
  Adapta tono y contenido a inversores, banco, regulador o dirección.
  Input: EEFF + período + audiencia + tone. Output: informe con narrativa.
maturity: stable
context: isolated
context_cost: medium
category: "professional-domain/finance"
tags: ["finanzas", "informe-financiero", "inversores", "banco", "regulador", "reporting"]
priority: "high"
---

# finance-financial-report-writer — Redactor de Informes Financieros

## Cuándo usar esta skill

- Al preparar el informe financiero semestral o anual para inversores.
- Al redactar el informe de gestión para el banco en un proceso de refinanciación.
- Al preparar documentación para reguladores (CNMV, Banco de España, AEPD).
- Al generar el commentary financiero para el informe anual corporativo.

## Inputs requeridos

| Campo | Descripción | Ejemplo |
|---|---|---|
| `estados_financieros` | P&L, balance, cash flow | EEFF del período |
| `período` | Período cubierto | FY2025 / H1 2026 |
| `audiencia` | Destinatario del informe | `inversores`, `banco`, `regulador`, `dirección` |
| `tone` | Tono del informe | `optimista`, `neutro`, `conservador` |
| `comparativa` | Período(s) de referencia | Año anterior, budget, sector |

## Outputs producidos

1. **Informe estructurado** — adaptado a la audiencia con todas las secciones requeridas
2. **Ratios financieros comentados** — con fórmulas, tendencias y benchmark
3. **Análisis de tendencias** — evolución multi-período
4. **Narrativa de outlook** — perspectivas con tono adaptado a la audiencia

## Restricción crítica para regulador

Para audiencia `regulador`: máxima formalidad, cero interpretaciones propias, cero proyecciones sin base verificable, referencia explícita a normativa aplicable en cada afirmación.

## Disclaimer

Todo output incluye disclaimer financiero completo. Ver `docs/rules/domain/professional-domain-disclaimer.md`.

## Relación con otras skills

- **Upstream**: `controlling-kpi-analyst` + `finance-cash-flow-analyst`
- **Complementaria**: `finance-investment-analyst` (para sección de inversiones del informe)
