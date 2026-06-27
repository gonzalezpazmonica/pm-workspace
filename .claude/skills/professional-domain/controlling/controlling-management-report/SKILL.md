---
name: controlling-management-report
description: "Genera informes de gestión mensual adaptados a la audiencia (CFO/CEO/board/operaciones) con narrativa técnica."
summary: |
  Redacta informes de gestión con vocabulario técnico preciso (EBITDA/NOF/margen).
  Adapta tono y contenido a la audiencia sin perder rigor técnico.
  Input: datos financieros + período + audiencia. Output: informe estructurado.
maturity: stable
context: isolated
context_cost: medium
category: "professional-domain/controlling"
tags: ["controlling", "informe-gestión", "CFO", "reporting", "EBITDA", "management"]
priority: "high"
---

# controlling-management-report — Redactor de Informe de Gestión

## Cuándo usar esta skill

- Al preparar el pack mensual de gestión para la dirección.
- Al redactar el informe de resultados para el consejo de administración.
- Al generar el commentary del P&L para inversores o accionistas.
- Para traducir datos financieros en narrativa comprensible por no financieros (operaciones).

## Inputs requeridos

| Campo | Descripción | Ejemplo |
|---|---|---|
| `datos_financieros` | P&L, balance, o KPIs del período | Tabla con partidas y comparativas |
| `período` | Mes y acumulado | Junio 2026 / YTD Jun-26 |
| `audiencia` | Destinatario del informe | `CFO`, `CEO`, `board`, `operaciones` |
| `comparativa` | Referencia de comparación | Budget, año anterior, forecast |

## Outputs producidos

1. **Informe estructurado** — 7 secciones estándar adaptadas a la audiencia
2. **Narrativa por sección** — no genérica, con causa + comparativa + acción para cada cifra
3. **Marcadores [DATO PENDIENTE]** — para cada dato no aportado que es necesario para la sección
4. **Executive Summary** — 1 página máximo, auto-generado a partir del contenido

## Errores de vocabulario que detectan los controllers

No usar: "los resultados han sido buenos/malos", "ha habido una mejora/empeoramiento"
Usar: cifras + variación + causa + referencia

## Disclaimer

Todo output incluye disclaimer de controlling. Ver `docs/rules/domain/professional-domain-disclaimer.md`.

## Relación con otras skills

- **Upstream**: `controlling-variance-analyzer` (desviaciones para el commentary)
- **Paralelo**: `controlling-kpi-analyst` (KPIs del período para sección de indicadores)
