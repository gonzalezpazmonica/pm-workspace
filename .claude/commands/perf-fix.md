---
name: perf-fix
description: Optimización test-first de hallazgos de rendimiento — crea tests si no existen, aplica fix, re-verifica
developer_type: all
agent: developer
context_cost: medium
---

# /perf-fix {PA-NNN} [PA-MMM...] [--dry-run]

> Aplica optimizaciones de rendimiento con garantía test-first: verifica (o crea) tests antes de modificar código.

---

## 1. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Quality & PRs** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/workflow.md`
   - `profiles/users/{slug}/tools.md`
3. Adaptar output según `identity.rol` y `tools.ide`, `tools.git_mode`
4. Si no hay perfil → continuar con comportamiento por defecto

---

## 2. Parámetros

- `{PA-NNN}` — IDs de hallazgos a corregir (uno o más, del informe de `/perf-audit`)
- `--dry-run` — Solo muestra qué cambios se harían sin aplicarlos

## Prerequisitos

- Informe de `/perf-audit` existente en `output/performance/`
- Cargar skill: `@.claude/skills/performance-audit/SKILL.md`
- Cargar referencia del lenguaje: `@references/perf-{lang}.md`

## Ejecución (6 pasos)

### Paso 1 — Leer informe y extraer hallazgos
Buscar el informe más reciente en `output/performance/`.
Para cada PA-NNN solicitado, extraer: fichero, función, línea, tipo de issue, severidad.
Si el ID no existe → error con lista de IDs válidos.

### Paso 2 — VERIFICAR TESTS (obligatorio)
Para cada función objetivo:
1. Buscar ficheros de test que referencien la función/clase
2. Evaluar cobertura: ¿cubren los paths principales? ¿edge cases?

**Si tests EXISTEN y son suficientes** → continuar al Paso 3.

**Si tests NO EXISTEN o son insuficientes** → CREAR characterization tests:
- Analizar la función: inputs, outputs, side effects, branches
- Crear **Golden Master tests** que capturan el comportamiento actual:
  - Happy path con inputs típicos
  - Edge cases detectados en análisis de complejidad (null, empty, boundary)
  - Branches principales (cada rama del if/switch con mayor complejidad)
- Naming: `{ClassName}PerformanceTests` o `test_{function}_perf_baseline`
- Comentar: `// Characterization test — captures current behavior before optimization`

### Paso 3 — Ejecutar baseline
Ejecutar tests de la función (usando test runner del lenguaje).
- **TODOS deben PASAR** → registrar como baseline
- **Si alguno FALLA** → STOP. Reportar: "Tests existentes fallan antes de optimización. Corregir tests primero."

### Paso 4 — Aplicar optimización
Según tipo de hallazgo, aplicar la corrección:

**Complejidad excesiva**:
- Extract method para reducir cyclomatic/cognitive
- Simplify conditions (guard clauses, early returns)
- Replace nested conditionals con polymorphism o strategy

**Async anti-patterns**:
- Convertir blocking a async/await
- Reemplazar sequential await por parallel execution
- Corregir sync-over-async, fire-and-forget, missing cancellation

**N+1 queries**:
- Añadir eager loading (Include, select_related, JOIN FETCH)
- Implementar batch queries o DataLoader

**Memory / allocation**:
- Pre-allocate collections
- StringBuilder / string.Join para concatenación
- Move allocation fuera de loops

Si `--dry-run`: mostrar diff propuesto sin aplicar y terminar.

### Paso 5 — Re-ejecutar tests
Ejecutar los mismos tests del baseline:
- **TODOS PASAN** → optimización exitosa
  - Reportar métricas antes/después (complejidad, LOC, nesting)
  - Marcar hallazgo como `[FIXED]` en informe
- **ALGUNO FALLA** → REVERTIR cambio
  - `git checkout -- {fichero}`
  - Reportar: "Optimización revierte comportamiento. Requiere revisión manual."
  - Marcar como `[REVERT — MANUAL REVIEW]`

### Paso 6 — Actualizar informe
En el fichero de audit más reciente:
- Cambiar estado: `[CRITICAL]` → `[FIXED]` para hallazgos corregidos
- Recalcular Performance Score
- Añadir sección "Fix Log" con timestamp y métricas antes/después

## Output

```markdown
# Performance Fix Log — {fecha}

## Hallazgos procesados

### PA-001 [FIXED] {función}
**Antes**: Cyclomatic: 25, Cognitive: 30, LOC: 85
**Después**: Cyclomatic: 8, Cognitive: 10, LOC: 35
**Tests**: 3 existentes + 2 characterization creados → 5/5 PASS
**Cambios**: Extract method (×3), guard clauses, early return
**Ficheros modificados**: {lista}

### PA-003 [REVERT — MANUAL REVIEW] {función}
**Razón**: Test `should_calculate_total_with_discount` FAIL tras optimización
**Acción requerida**: revisar lógica de descuento antes de refactorizar

## Score actualizado
**Antes**: 45% (POOR) | **Después**: 68% (NEEDS_WORK) | **Mejora**: +23 puntos
```

## Notas
- NUNCA optimiza sin tests. Si no existen, los crea primero.
- Los characterization tests capturan comportamiento ACTUAL (incluso bugs).
- Si la optimización cambia comportamiento → es un bug de la optimización, no del test.
- Los fixes se aplican uno a uno para aislar regresiones.
