---
name: compliance-report
description: Generar informe ejecutivo de compliance regulatorio con tendencias y roadmap
developer_type: all
agent: architect
context_cost: high
---

# /compliance-report {path} [--format md|docx] [--compare]

> Genera un informe ejecutivo de cumplimiento regulatorio basado en los resultados de `/compliance-scan`, con análisis de tendencias y roadmap de remediación.

---

## Parámetros

- `{path}` — Ruta del proyecto (default: proyecto actual)
- `--format` — Formato de salida: `md` (default) o `docx`
- `--compare` — Comparar con scans anteriores (si existen en `output/compliance/`)
- `--sectors` — Filtrar por sectores específicos (default: todos los detectados)

## Prerequisitos

- Al menos un `/compliance-scan` previo en `output/compliance/`
- Si `--format docx`: cargar skill `docx` para generación de Word
- Cargar skill: `@.claude/skills/regulatory-compliance/SKILL.md`

## Ejecución (4 pasos)

### Paso 1 — Recopilar datos
Leer todos los informes de scan en `output/compliance/{proyecto}-scan-*.md`.
Ordenar cronológicamente. Identificar sector(es) y regulaciones verificadas.

### Paso 2 — Analizar tendencias (si --compare)
Comparar compliance score entre scans:
- Tendencia: mejorando / estable / empeorando
- Issues resueltos vs nuevos
- Regulaciones con más incumplimientos recurrentes

### Paso 3 — Generar informe

Estructura del informe:

```markdown
# Informe de Compliance Regulatorio — {proyecto}

**Fecha**: {ISO date}
**Sector**: {sector(s)}
**Último scan**: {fecha}
**Compliance Score**: {X}%

---

## 1. Resumen Ejecutivo

Estado general del cumplimiento regulatorio del proyecto.
Score actual: {X}% ({tendencia} vs scan anterior).
{N} hallazgos críticos requieren atención inmediata.
{M} hallazgos han sido corregidos desde el último scan.

## 2. Regulaciones Aplicables

| Regulación | Artículos | Requisitos | Cumple | Score |
|------------|-----------|------------|--------|-------|
| {Reg A}    | §{arts}   | {N}        | {M}/{N}| {X}%  |
| {Reg B}    | §{arts}   | {N}        | {M}/{N}| {X}%  |

## 3. Hallazgos por Severidad

### CRITICAL ({N})
Requieren corrección inmediata. Riesgo de sanción regulatoria o breach.
- RC-001: {descripción} — {regulación} — {ficheros}
- RC-002: {descripción} — {regulación} — {ficheros}

### HIGH ({N})
Corregir en el próximo sprint. Controles de seguridad ausentes.
- RC-005: {descripción} — {regulación} — {ficheros}

### MEDIUM ({N}) (si --strict en scan)
Backlog. Mejoras recomendadas por la normativa.

### LOW ({N}) (si --strict en scan)
Nice to have. Best practices del sector.

## 4. Tendencia (si --compare)

| Fecha scan | Score | CRITICAL | HIGH | MEDIUM | Δ Score |
|------------|-------|----------|------|--------|---------|
| {fecha 1}  | {X}%  | {N}      | {N}  | {N}    | —       |
| {fecha 2}  | {Y}%  | {N}      | {N}  | {N}    | {+/-}%  |

Issues resueltos: {lista}
Issues nuevos: {lista}
Issues recurrentes: {lista}

## 5. Roadmap de Remediación

### Quick Wins (auto-fix disponible, corregir hoy)
- RC-001: `/compliance-fix RC-001` — {descripción breve}
- RC-003: `/compliance-fix RC-003` — {descripción breve}

### Medio plazo (1-2 sprints)
- RC-005: {descripción} — Esfuerzo estimado: {días}
- RC-008: {descripción} — Esfuerzo estimado: {días}

### Largo plazo (cambios arquitectónicos)
- RC-012: {descripción} — Requiere: {qué cambio}
- RC-015: {descripción} — Requiere: {qué cambio}

## 6. Riesgo si no se corrige

| Regulación | Sanción máxima | Probabilidad | Impacto |
|------------|---------------|--------------|---------|
| GDPR       | 4% facturación o €20M | {alta/media/baja} | {descripción} |
| {Reg B}    | {sanción}     | {prob}       | {impacto} |

## 7. Recomendaciones

1. {Recomendación prioritaria}
2. {Recomendación secundaria}
3. Re-escanear tras correcciones: `/compliance-scan {path}`
```

### Paso 4 — Exportar
- Si `--format md`: Guardar en `output/compliance/{proyecto}-report-{fecha}.md`
- Si `--format docx`: Generar Word usando skill `docx`

## Output

Fichero en `output/compliance/{proyecto}-report-{fecha}.{ext}`

## Notas
- El informe está pensado para dirección / compliance officers, no técnico.
- La sección de riesgo incluye sanciones reales por regulación.
- Con `--compare`, el informe muestra evolución para auditorías periódicas.
- Complementa a `/ai-risk-assessment` (EU AI Act) con compliance sectorial.
