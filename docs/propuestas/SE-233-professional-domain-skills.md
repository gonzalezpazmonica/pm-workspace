---
id: SE-233
title: "Familia de Skills professional-domain — ventas, legal, controlling, finanzas, RRHH"
status: PROPOSED
priority: P2
effort: "XL (16h)"
author: Savia
proposed_at: "2026-06-28"
era: 237
tags: ["professional-domain", "sales", "legal", "controlling", "finance", "labour", "RRHH"]
---

# SE-233 — Familia de Skills professional-domain

## Problema

El gap de adopción de IA en dominios no técnicos es significativo. Los equipos de
desarrollo y ops adoptan herramientas de IA rápidamente; los equipos de ventas, legal,
controlling, finanzas y RRHH siguen trabajando sin asistencia de IA en sus tareas
específicas, pese a que estas tareas representan entre el 40-60% del coste operativo
de muchas organizaciones.

Las razones son:
1. Las herramientas genéricas no conocen el marco legal ni las convenciones del dominio
2. Los profesionales no técnicos no saben cómo formular prompts efectivos
3. No hay guardrails que prevengan el uso irresponsable (inventar cifras, citar artículos falsos)

Esta spec crea la familia `professional-domain` con 17 skills organizadas en 5 sub-familias,
cada una con contexto de dominio pre-cargado, disclaimers obligatorios y marcadores
`[DATO PENDIENTE]` para prevenir la invención de información crítica.

## Sub-familias y skills (17 skills total)

### professional-domain/sales (4 skills)

| Skill | Función |
|---|---|
| `sales-account-research` | Investigación de cuenta objetivo: firmografía, buyers, pain points, triggers |
| `sales-objection-analyzer` | Análisis de objeciones de ventas y respuestas argumentadas |
| `sales-pipeline-analyst` | Diagnóstico de pipeline: conversión, forecast, cuellos de botella |
| `sales-proposal-writer` | Redacción de propuestas comerciales estructuradas |

### professional-domain/legal (3 skills)

| Skill | Función |
|---|---|
| `legal-compliance-checker` | Auditoría de procesos contra RGPD, LO 3/2018, ET, CCom |
| `legal-contract-reviewer` | Revisión de contratos con identificación de cláusulas de riesgo |
| `legal-document-drafter` | Redacción de documentos legales con artículos exactos |

### professional-domain/controlling (3 skills)

| Skill | Función |
|---|---|
| `controlling-kpi-analyst` | Análisis de KPIs de negocio con benchmark y diagnóstico |
| `controlling-management-report` | Generación de informe de gestión mensual/trimestral |
| `controlling-variance-analyzer` | Análisis de desviaciones presupuestarias con causas y acciones |

### professional-domain/finance (3 skills)

| Skill | Función |
|---|---|
| `finance-cash-flow-analyst` | Análisis y proyección de flujo de caja |
| `finance-financial-report-writer` | Redacción de memorias financieras y notas explicativas |
| `finance-investment-analyst` | Análisis de inversiones: VAN, TIR, payback, escenarios |

### professional-domain/labour (4 skills)

| Skill | Función |
|---|---|
| `labour-document-drafter` | Redacción de cartas de despido, sanciones, acuerdos de extinción (ET) |
| `labour-convention-analyzer` | Análisis de convenios colectivos y consulta al BOE |
| `labour-conflict-resolver` | Análisis de conflictos laborales con opciones de resolución y cálculo de improcedente |
| `labour-onboarding-offboarding` | Checklists y documentación de entrada/salida con plazos duros SS/SEPE |

## Principios transversales

### 1. Disclaimer profesional obligatorio

Todo output de cualquier skill de `professional-domain` termina con un disclaimer
adaptado al dominio:

```
AVISO: Documento generado con asistencia de IA. Borrador orientativo.
REQUIERE revisión y validación por [profesional cualificado del dominio]
antes de cualquier uso. La IA puede cometer errores en [contexto específico].
Verifique siempre contra [fuente autoritativa del dominio].
```

Los disclaimers específicos por dominio están en `docs/rules/domain/professional-domain-disclaimer.md`.

### 2. No inventar datos críticos

Ningún skill de `professional-domain` inventa:
- Artículos de ley o convenio no proporcionados en el input
- Cifras financieras o salariales no proporcionadas
- Nombres de empresas, personas o productos no mencionados
- Fechas o plazos sin base normativa verificable

### 3. Marcadores [DATO PENDIENTE]

Cuando falta información crítica para completar un output, la skill inserta:
`[DATO PENDIENTE: "descripción exacta del dato faltante"]`

El output es utilizable con estos marcadores — el profesional completa los huecos.
Esto es preferible a inventar información que podría ser incorrecta o peligrosa.

### 4. Gradación de riesgo

Cada skill clasifica sus outputs por riesgo de error:
- **ALTO** (legal, laboral): requiere siempre revisión de profesional cualificado
- **MEDIO** (financiero, controlling): requiere revisión antes de uso externo
- **BAJO** (sales, investigación): puede usarse con revisión superficial

## Criterios de aceptación

1. Los 17 skills existen con estructura completa (SKILL.md + DOMAIN.md + prompt.md)
2. Cada SKILL.md tiene ≤ 150 líneas (criterio de mantenibilidad)
3. Todos los skills de categoría ALTO tienen disclaimer obligatorio en prompt.md
4. Todos los skills de categoría ALTO tienen marcadores [DATO PENDIENTE] implementados
5. `docs/rules/domain/professional-domain-disclaimer.md` documenta todos los disclaimers por dominio
6. `docs/rules/domain/skill-families-registry.md` incluye la familia professional-domain
7. `docs/guides_es/domain-skills-adoption-guide.md` con guía por perfil de usuario
8. Tests BATS cubren los 4 skills de labour (implementados en este sprint)
9. La familia `labour` usa referencias exactas del ET (art. 54, 55, 52, 53, 56, 58, 60, 68)
10. Ningún skill genera texto sobre personas reales sin disclaimers de privacidad

## Qué NO incluye esta spec

- Integración directa con sistemas ERP o CRM (SAP, Salesforce, etc.)
- Tramitación efectiva ante organismos públicos (TGSS, SEPE, AEAT, Registro Mercantil)
- Representación legal o asesoramiento jurídico vinculante
- Cálculo de cuotas exactas de Seguridad Social (requiere acceso a bases actualizadas)
- Predicción de resultados judiciales

## Plan de implementación

| Sprint | Sub-familia | Responsable |
|---|---|---|
| 1 (actual) | labour (4 skills) | Savia |
| 2 | legal (3 skills) — ya en nido | Agente laboral |
| 3 | sales (4 skills) — ya en nido | Agente comercial |
| 4 | controlling (3 skills) — ya en nido | Agente financiero |
| 5 | finance (3 skills) — ya en nido | Agente financiero |

## Dependencias

- SE-162 (Knowledge Graph) — para integración futura de datos de dominio
- SE-167 (Skill Maturity Kanban) — para seguimiento de madurez de las 17 skills
- `docs/rules/domain/professional-domain-disclaimer.md` — debe existir antes de publicar

## Riesgos

- **Calidad jurídica**: los skills legales y laborales son los de mayor riesgo; un error
  puede tener consecuencias económicas reales. Mitigación: disclaimer + [DATO PENDIENTE] + revisión humana obligatoria
- **Desactualización**: las tablas salariales y tipos de cotización cambian anualmente.
  Los DOMAIN.md deben tener fecha de revisión y proceso de actualización.
- **Adopción**: el gap de adopción que motiva esta spec también aplica aquí. Sin guía
  de adopción por perfil de usuario, los skills no se usarán.
