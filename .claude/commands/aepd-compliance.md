---
name: aepd-compliance
description: Auditoría de cumplimiento AEPD para IA agéntica — framework 4 fases
developer_type: all
agent: task
context_cost: high
---

# /aepd-compliance

> Auditar cumplimiento AEPD para agentes autónomos de IA.

Framework: @.claude/skills/regulatory-compliance/references/aepd-framework.md

---

## Sintaxis

```
/aepd-compliance [proyecto] [--agent nombre] [--full] [--fix]
```

- Sin args → audita pm-workspace/Savia como agente autónomo
- `--agent` → audita un agente específico del catálogo
- `--full` → auditoría completa de los 24 agentes
- `--fix` → propone correcciones automáticas

---

## Flujo

### Paso 1 — Identificar agentes a auditar

Sin `--agent`: auditar Savia (agente principal).
Con `--full`: iterar los 24 agentes de `agents-catalog.md`.
Con `--agent X`: auditar solo el agente especificado.

### Paso 2 — Fase 1: Descripción Tecnológica

Para cada agente, documentar:
- Modelo (Opus/Sonnet/Haiku), tools disponibles, permisos
- Datos que procesa (ficheros, APIs, secrets)
- Nivel de autonomía (supervisado/semi-autónomo/autónomo)
- Leer frontmatter del agente en `.claude/agents/`

### Paso 3 — Fase 2: Análisis de Cumplimiento

Verificar 7 requisitos RGPD/AEPD contra la implementación:
- Base jurídica, minimización, transparencia
- Limitación de finalidad, exactitud, conservación, seguridad
- Buscar evidencias en: hooks, rules, settings.json

### Paso 4 — Fase 3: Evaluación de Vulnerabilidades

Para cada vulnerabilidad del framework AEPD:
- ¿Existe mitigación implementada?
- ¿Está documentada?
- ¿Es verificable (hook, test, log)?

### Paso 5 — Fase 4: Medidas Protectoras

Verificar existencia y estado de:
- EIPD (Evaluación de Impacto), supervisión humana
- Trazabilidad, derecho de oposición, evaluación periódica
- Protocolo de notificación de brechas

### Paso 6 — Scoring y Reporte

Calcular score AEPD (4 fases ponderadas).
Clasificar: Conforme / Parcial / No conforme / Riesgo crítico.

---

## Output

Fichero: `output/aepd-YYYYMMDD-{proyecto|workspace}.md`

Secciones:
- Score global AEPD (0-100%) con nivel de conformidad
- Matriz agente × fase (si `--full`)
- Hallazgos por fase (priorizados por severidad)
- Evidencias encontradas (hooks, rules, logs)
- Gaps detectados con recomendación de corrección
- Plan de acción (si `--fix`: correcciones propuestas)
- Mapeo cruzado EU AI Act + NIST + ISO 42001

**Integración**: Alimenta `/governance-report` y `/governance-certify`.

---

## Ejemplo de Output

```
AEPD Compliance — pm-workspace (Savia)
Score: 82% — CONFORME

Fase 1 (Tecnología):    90% ✅  Agentes bien documentados
Fase 2 (Cumplimiento):  75% ⚠️  Falta EIPD formal
Fase 3 (Vulnerabilidades): 85% ✅  Scope guard activo
Fase 4 (Medidas):       78% ⚠️  Protocolo brechas incompleto

Top 3 acciones:
1. Crear EIPD formal para Savia (CRITICAL)
2. Completar protocolo notificación brechas 72h (HIGH)
3. Documentar base jurídica por agente (MEDIUM)
```
