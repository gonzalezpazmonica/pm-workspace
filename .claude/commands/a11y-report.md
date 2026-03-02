---
name: /a11y-report
description: "Reporte de conformidad de accesibilidad para stakeholders y legal. Tres formatos: ejecutivo (resumen + score), técnico (detalles completos + código), legal (declaración VPAT/Section 508). Tracking de tendencias. Exportable."
developer_type: all
agent: task
context_cost: medium
---

# /a11y-report — Reporte de Conformidad WCAG 2.2

Genera reportes de accesibilidad formatados para diferentes audiencias. Ideal para comunicar conformidad a liderazgo, equipos técnicos y cumplimiento regulatorio.

## Sintaxis

```bash
/a11y-report [--format executive|technical|legal] [--period month|quarter] [--lang es|en]
```

## Parámetros

- `--format`:
  - `executive` — Resumen ejecutivo (score + gráficos + recomendaciones)
  - `technical` — Informe técnico detallado (code, métricas, tendencias)
  - `legal` — Declaración de conformidad (VPAT, Section 508)
- `--period`:
  - `month` — Reporte del mes actual
  - `quarter` — Reporte del trimestre actual
- `--lang`: Idioma (`es` o `en`)

## Formatos de Salida

**Executive**
- Puntuación WCAG (0-100)
- Desglose por severidad
- Top 5 problemas críticos
- Recomendaciones accionables
- Gráficos de tendencia (si hay histórico)

**Technical**
- Matriz detallada de hallazgos
- Código fuente problemático
- Comparación con benchmark
- Métricas de cobertura por componente
- Historial de cambios

**Legal**
- Declaración de conformidad
- Mapeo a WCAG 2.2 AA/AAA
- Limitaciones conocidas
- Plan de remediación
- Auditor y fecha

## Exportación

- PDF (requiere pandoc/wkhtmltopdf)
- Excel (tablas + gráficos)
- Markdown (documentación)
- JSON (API)

## Ejemplos

```bash
/a11y-report --format executive --period month --lang es
/a11y-report --format technical --period quarter
/a11y-report --format legal --lang es
```

## Características

**Multi-audiencia**: Ejecutivo, técnico, legal.

**Tendencias**: Tracking histórico de mejoras.

**Exportación**: PDF, Excel, Markdown, JSON.

**Auditoría**: Trazabilidad completa de problemas.

**Legal-ready**: Declaraciones VPAT/Section 508.

## Integración

Funciona con histórico de `/a11y-audit`. Requiere auditorías previas para mostrar tendencias.
