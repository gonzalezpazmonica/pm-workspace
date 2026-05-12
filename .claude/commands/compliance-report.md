---
name: compliance-report
description: Generar informe ejecutivo de compliance regulatorio con tendencias y roadmap
developer_type: all
agent: architect
context_cost: high
---

# /compliance-report {path} [--format md|docx] [--compare] [--lang es|en]

> Genera un informe ejecutivo de cumplimiento regulatorio basado en los resultados de `/compliance-scan`, con análisis de tendencias y roadmap de remediación.

---

## Parámetros

- `{path}` — Ruta del proyecto (default: proyecto actual)
- `--format` — Formato de salida: `md` (default) o `docx`
- `--compare` — Comparar con scans anteriores (si existen en `output/compliance/`)
- `--sectors` — Filtrar por sectores específicos (default: todos los detectados)
- `--lang` — Idioma del informe: `es` (default) o `en`. Usar mismo idioma que el scan.

## Prerequisitos

- Al menos un `/compliance-scan` previo en `output/compliance/`
- Si `--format docx`: cargar skill `docx` para generación de Word
- Cargar skill: `@.claude/skills/regulatory-compliance/SKILL.md`

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Governance** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/preferences.md`
3. Adaptar idioma y nivel de detalle según `preferences.language` y `preferences.detail_level`
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Ejecución (4 pasos)

### Paso 4 — Recopilar datos
Leer todos los informes en `output/compliance/{proyecto}-scan-*.md` y `{proyecto}-fix-*.md`.
Ordenar cronológicamente. Identificar sector(es) y regulaciones verificadas.
Extraer scores con fórmula documentada: `(requisitos cumplidos / total) × 100`.

### Paso 5 — Analizar tendencias (si --compare)
Comparar compliance score entre scans:
- Tendencia: mejorando / estable / empeorando
- Issues resueltos vs nuevos vs recurrentes
- Regulaciones con más incumplimientos

### Paso 6 — Generar informe (7 secciones)

```markdown
# Informe de Compliance Regulatorio — {proyecto}

**Fecha**: {ISO date} | **Sector**: {sector(s)} | **Score**: {X}% ({N}/{M} requisitos)

## 1. Resumen Ejecutivo
Score actual y delta vs scan anterior. N hallazgos críticos. M corregidos.

## 2. Regulaciones Aplicables
| Regulación | Artículos | Requisitos | Cumple | Score |
|------------|-----------|------------|--------|-------|

## 3. Hallazgos por Severidad
### CRITICAL ({N}) — {auto-fix} auto-fixables, {manual} manuales
- RC-001: {desc} [FIXED ✅] | RC-004: {desc} [AUTO-FIX] | RC-006: {desc} [MANUAL]
### HIGH / MEDIUM / LOW

## 4. Tendencia (si --compare)
| Fecha | Score | CRITICAL | HIGH | Δ Score |
Issues resueltos / nuevos / recurrentes

## 5. Roadmap de Remediación
### Quick Wins (auto-fix, corregir hoy): RC-XXX con `/compliance-fix`
### Medio plazo (1-2 sprints): esfuerzo estimado en días
### Largo plazo (arquitectónico): qué requiere cada cambio

## 6. Riesgo si no se corrige
| Regulación | Sanción máxima | Probabilidad | Impacto |
| HIPAA      | $1.9M/categoría| {alta/media}  | {desc}  |
| GDPR       | 4% o €20M     | {alta/media}  | {desc}  |

## 7. Recomendaciones
1-5 recomendaciones priorizadas para dirección / compliance officers.
Re-escanear tras correcciones: `/compliance-scan {path}`
```

### Paso 7 — Exportar
- Si `--format md`: Guardar en `output/compliance/{proyecto}-report-{fecha}.md`
- Si `--format docx`: Generar Word usando skill `docx`

## Output

Fichero en `output/compliance/{proyecto}-report-{fecha}.{ext}` (fecha obligatoria)

## Notas
- El informe está pensado para dirección / compliance officers, no técnico.
- La sección de riesgo incluye sanciones reales por regulación.
- Con `--compare`, el informe muestra evolución para auditorías periódicas.
- Complementa a `/ai-risk-assessment` (EU AI Act) con compliance sectorial.
- Usar siempre el mismo idioma (--lang) que el scan original para coherencia.
