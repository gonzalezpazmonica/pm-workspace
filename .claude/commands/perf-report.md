---
name: perf-report
description: Informe ejecutivo de rendimiento — hotspots, async issues, roadmap y tendencias
developer_type: all
agent: architect
context_cost: medium
---

# /perf-report {path} [--format md|docx] [--compare] [--sprint] [--lang es|en]

> Genera un informe ejecutivo de rendimiento con 6 secciones: resumen, hotspots, async, test coverage, roadmap y riesgos.

---

## Parámetros

- `{path}` — Ruta del proyecto (default: proyecto actual)
- `--format md|docx` — Formato de salida (default: md)
- `--compare` — Incluir tendencia entre auditorías anteriores
- `--sprint` — Mostrar solo mejoras del sprint actual
- `--lang es|en` — Idioma del informe (default: es)

## Prerequisitos

- Al menos un informe de `/perf-audit` en `output/performance/`
- Cargar skill: `@.claude/skills/performance-audit/SKILL.md`

## Ejecución (4 pasos)

### Paso 1 — Recopilar datos
Leer el informe de audit más reciente en `output/performance/`.
Si `--compare`: leer todos los informes anteriores del mismo proyecto.
Si `--sprint`: filtrar hallazgos FIXED desde último audit sin tag FIXED.

### Paso 2 — Analizar tendencias (si --compare)
Comparar entre auditorías:
- Performance Score: evolución temporal
- Hallazgos por severidad: tendencia (mejorando/empeorando/estable)
- Nuevos hallazgos vs corregidos
- Funciones que empeoran entre auditorías (regresiones)

### Paso 3 — Generar informe ejecutivo
Estructura obligatoria (6 secciones):

**Sección 1 — Resumen ejecutivo**
- Performance Score actual con rango (GOOD/NEEDS_WORK/POOR/CRITICAL)
- Fórmula: `Score = 100 - Σ(CRITICAL×15 + HIGH×8 + MEDIUM×3 + LOW×1)`
- Hallazgos totales por severidad
- Funciones analizadas vs hotspots detectados
- Lenguaje y fecha de análisis

**Sección 2 — Top Hotspots (máx. 10)**
- Tabla: función, fichero, cyclomatic, cognitive, LOC, nesting, O(), estado
- Ordenados por hotspot_score descendente
- Marcados: UNTESTED en rojo, TESTED en verde

**Sección 3 — Async Issues**
- Anti-patterns detectados agrupados por tipo
- Impacto estimado (blocking thread, deadlock risk, memory leak)
- Fix recomendado por cada tipo

**Sección 4 — Test Coverage Gaps**
- Hotspots sin cobertura de tests
- Riesgo: optimización sin red de seguridad
- Recomendación: crear characterization tests antes de optimizar

**Sección 5 — Roadmap de Optimización**
- Priorización sugerida: CRITICAL → HIGH → MEDIUM
- Esfuerzo estimado por hallazgo (CRITICAL ~8h, HIGH ~4h, MEDIUM ~2h)
- Sprints estimados para llegar a score ≥80 (GOOD)
- Dependencias entre fixes (ej: necesita tests antes de refactor)

**Sección 6 — Análisis de Riesgo**
- Impacto si NO se optimiza: latencia bajo carga, timeouts, degradación UX
- Áreas de mayor riesgo (hot paths sin tests y con alta complejidad)
- Comparación con umbrales de la industria
- Recomendación final: urgente / planificado / monitorizar

### Paso 4 — Guardar informe
Guardar en: `output/performance/{proyecto}-report-{fecha}.md` (o .docx si --format docx)

## Output Template

```markdown
# Performance Report — {proyecto}

**Fecha**: {ISO date}
**Lenguaje**: {lang}
**Performance Score**: {X}% ({rango})
**Fórmula**: Score = 100 - Σ(CRITICAL×15 + HIGH×8 + MEDIUM×3 + LOW×1)

---

## 1. Resumen Ejecutivo
{párrafo con métricas clave y conclusión}

## 2. Top Hotspots
| # | Función | Fichero | Cycl. | Cogn. | LOC | Nest. | O() | Tests | Estado |
|---|---------|---------|-------|-------|-----|-------|-----|-------|--------|

## 3. Async Issues
{agrupados por tipo con impacto y fix}

## 4. Test Coverage Gaps
{hotspots sin tests con riesgo}

## 5. Roadmap de Optimización
| Prioridad | PA-ID | Función | Esfuerzo | Sprint | Dependencias |
|-----------|-------|---------|----------|--------|--------------|

**Sprints estimados para GOOD (≥80%)**: {N}

## 6. Análisis de Riesgo
{impacto, áreas críticas, recomendación}

---
*Generado por pm-workspace `/perf-report`*
```

## Notas
- Si no existe informe de audit previo, sugerir ejecutar `/perf-audit` primero.
- El formato docx usa la misma estructura pero con estilos de documento.
- Las tendencias con `--compare` requieren al menos 2 auditorías del mismo proyecto.
- Usar mismo idioma (`--lang`) en audit, fix y report para consistencia.
