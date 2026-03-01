---
name: perf-audit
description: Auditoría estática de rendimiento — detecta hotspots, async anti-patterns y funciones pesadas
developer_type: all
agent: architect
context_cost: medium
---

# /perf-audit {path} [--lang LANG] [--top N] [--strict] [--lang es|en]

> Escanea el código fuente para identificar funciones con mayor peso computacional, anti-patrones async y oportunidades de optimización.

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

- `{path}` — Ruta del proyecto a escanear (default: proyecto actual)
- `--lang LANG` — Forzar lenguaje (saltar detección): dotnet, typescript, python, java, go, rust
- `--top N` — Mostrar top N hotspots (default: 20)
- `--strict` — Incluir hallazgos MEDIUM y LOW (default: solo CRITICAL y HIGH)
- `--lang es|en` — Idioma del informe (default: es). Detectar de CLAUDE.md si existe.

## Prerequisitos

Cargar skill: `@.claude/skills/performance-audit/SKILL.md`
Cargar regla: `@.claude/rules/domain/performance-patterns.md`

## Ejecución (7 pasos)

### Paso 1 — Detectar lenguaje
Usar detection de `architecture-intelligence` (file patterns, extensions, config).
Si `--lang` proporcionado, saltar detección. Cargar `references/perf-{lang}.md`.

### Paso 2 — Escanear complejidad (Fase 1 — 40%)
Para cada fichero de código fuente:
- Parsear funciones/métodos
- Calcular **complejidad ciclomática**: contar ramas (if, else, switch case, for, while, catch, &&, ||, ternario)
- Calcular **complejidad cognitiva**: penalizar anidamiento (+1 por nivel), breaks en flujo (break, continue, goto, early return)
- Medir: method length (LOC), nesting depth, fan-out, parameter count

### Paso 3 — Detectar async anti-patterns (Fase 2 — 25%)
Con el fichero de referencia perf-{lang}.md cargado:
- Buscar cada anti-pattern listado en el código fuente
- Verificar blocking calls en contextos async
- Detectar sync-over-async, floating promises, goroutine leaks según lenguaje

### Paso 4 — Identificar hotspots (Fase 3 — 20%)
Calcular score compuesto por función:
```
hotspot_score = (cyclomatic × 0.4) + (cognitive × 0.3) + (method_length/10 × 0.15) + (nesting_depth × 0.1) + (fan_out × 0.05)
```
Detectar estimated O() por loops anidados. Ordenar por score, tomar top N.

### Paso 5 — Verificar cobertura de tests (Fase 4 — 15%)
Para cada hotspot:
- Buscar ficheros `*Test*`, `*Spec*`, `test_*`, `*_test.*` que referencien la función/clase
- Marcar: TESTED | UNTESTED
- Si UNTESTED → elevar severidad +1 nivel

### Paso 6 — Clasificar y asignar IDs
Asignar severidad según matriz del SKILL.md y performance-patterns.md.
Cada hallazgo: `PA-{NNN}` secuencial. Marcar `[AUTO-FIX]` o `[MANUAL]`.

### Paso 7 — Calcular score y generar informe
```
Performance Score = 100 - Σ(CRITICAL×15 + HIGH×8 + MEDIUM×3 + LOW×1)
```
Guardar en: `output/performance/{proyecto}-audit-{fecha}.md`

## Output

```markdown
# Performance Audit — {proyecto}

**Lenguaje**: {lang} ({confianza}% detección)
**Fecha**: {ISO date}
**Performance Score**: {X}% | Funciones analizadas: {N} | Hotspots: {N}

## Resumen
| Severidad | Count | Auto-fix | Manual | Tested | Untested |
|-----------|-------|----------|--------|--------|----------|
| CRITICAL  | N     | N        | N      | N      | N        |
| HIGH      | N     | N        | N      | N      | N        |

## Top Hotspots

### PA-001 [CRITICAL] [AUTO-FIX] {función} — Cyclomatic: {N}, Cognitive: {N}
**Fichero**: {path}:{line}
**Métricas**: Length: {N} LOC | Nesting: {N} | Fan-out: {N} | Est. O({x})
**Problema**: {descripción del anti-pattern o complejidad excesiva}
**Tests**: {TESTED|UNTESTED}
**Acción**: `/perf-fix PA-001`

## Async Issues
{lista de anti-patterns async detectados}

## Detección por fase
| Fase | Peso | Hallazgos |
|------|------|-----------|
| Complejidad | 40% | {N} funciones sobre umbral |
| Async | 25% | {N} anti-patterns |
| Hotspots | 20% | Top {N} por score compuesto |
| Test coverage | 15% | {N} untested de {M} hotspots |

## Siguientes pasos
- Auto-fix: `/perf-fix PA-001 PA-003`
- Informe ejecutivo: `/perf-report {path}`
- Re-audit tras fixes: `/perf-audit {path}`
```

## Notas
- El audit NO modifica código. Solo analiza y reporta.
- Los IDs PA-NNN son estables para referencia en `/perf-fix`.
- Usar mismo idioma en audit, fix y report para consistencia.
