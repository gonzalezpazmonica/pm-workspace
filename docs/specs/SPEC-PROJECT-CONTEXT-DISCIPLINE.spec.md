# Spec: Project Context Discipline — Static/Dynamic marker enforcement for `projects/*/CLAUDE.md`

**Task ID:**        SPEC-PROJECT-CONTEXT-DISCIPLINE
**PBI padre:**      Context optimization discipline (research: Context vs Tokens report 2026-05)
**Sprint:**         2026-09
**Fecha creacion:** 2026-05-13
**Creado por:**     Savia

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     4.5h
**Estado:**         Pendiente
**Max turns:**      25
**Modelo:**         claude-sonnet-4-6

**Depends-on:**     SPEC-CACHE-HIT-TRACKING (must be implemented and have >=14d data before this spec can enforce ratio thresholds)

---

## 0. Prerequisites (BLOCKING)

This spec CANNOT enter enforcing mode until:

1. SPEC-CACHE-HIT-TRACKING is implemented and `~/.savia/usage.db` exists with
   tables `turns`, `sessions`, `file_state`.
2. At least 14 days of cache_read / cache_creation telemetry has been collected
   per-project (filterable by file path prefix `projects/<slug>/CLAUDE.md`).
3. Per-project cache hit rate baseline is computed and stored as
   `~/.savia/usage.db:project_context_baseline (project, hit_rate, computed_at)`.

While prerequisites are not met, the audit command runs in `informational` mode:
it reports static/dynamic ratio and lists violations but does NOT block writes
or fail CI. Enforcement gate checks
`SELECT count(*) FROM turns WHERE ts > datetime('now','-14 days') AND file_path LIKE 'projects/%/CLAUDE.md'` >= 200
at command startup.

---

## 1. Contexto y Objetivo

El informe "Context vs Tokens" (108 ejecuciones, 2026-05) reveló que:

- La estabilidad del contenido cargado en cada turno determina el cache hit rate,
  no la longitud absoluta del fichero.
- Ficheros `projects/*/CLAUDE.md` mezclan contenido estable (arquitectura,
  glosario, heurísticas validadas) con contenido volátil (sprint actual, estado
  del backlog, fechas, métricas del día).
- La mezcla rompe el prefix cache: cualquier edición del bloque dinámico
  invalida el cache del bloque estático que vive en el mismo fichero.

**Problema:** Rule #11 (150 líneas máx) NO captura el problema real.
`projects/trazabios_main/CLAUDE.md` tiene 471 líneas pero el problema no es
la longitud — es que ~30% del contenido cambia semanalmente y rompe el cache
del 70% que es estable.

**Objetivo:** introducir marcadores explícitos `<!-- [STATIC] -->` /
`<!-- [DYNAMIC] -->` en `projects/*/CLAUDE.md` y un comando de auditoría
`/project-context-audit` que mida ratio static/dynamic y proponga splits
cuando el ratio cae bajo 80%.

---

## 2. Alcance

### Incluye

- Convención de marcadores `<!-- [STATIC] -->` y `<!-- [DYNAMIC] -->` aplicada a
  bloques (secciones delimitadas por `##` o `###`).
- Comando `/project-context-audit [project-slug]` que:
  - Parsea marcadores en `projects/<slug>/CLAUDE.md`.
  - Calcula ratio = líneas_static / total_líneas.
  - Reporta secciones sin marcador como `[UNMARKED]` (default: tratadas como dynamic).
  - Cruza con `~/.savia/usage.db` para mostrar hit rate observado.
  - Sugiere extracción de bloques dynamic a `projects/<slug>/context/{name}.md`.
- Hook PreToolUse INFORMATIVO (no bloqueante) cuando se edita
  `projects/*/CLAUDE.md`: muestra ratio actual y warning si <80%.
- Regla en `docs/rules/domain/project-context-discipline.md`.
- Suite BATS con 6+ escenarios (parseo, ratio, unmarked, edge cases).

### Excluye

- Modificar contenido real de `projects/*/CLAUDE.md` (eso lo hacen specs privadas
  por proyecto, ej. SPEC-D02 para Trazabios).
- Bloquear writes (siempre informativo en esta spec).
- Aplicar la convención a `_HUB.md`, `GLOSSARY.md` u otros ficheros del proyecto.
- Auditar `CLAUDE.md` raíz del workspace (cubierto por Rule #11).

---

## 3. Acceptance Criteria

- **AC-01**: Comando `/project-context-audit <slug>` existe y se ejecuta sin error
  sobre cualquier `projects/<slug>/CLAUDE.md` válido.
- **AC-02**: Comando reporta ratio static/dynamic con precisión ±1pp comparado
  con conteo manual de marcadores.
- **AC-03**: Secciones sin marcador se reportan como `[UNMARKED]` con número de
  línea y primeras 60 chars del heading.
- **AC-04**: Si ratio static <80%, comando emite WARNING con lista de bloques
  dynamic candidatos a extracción y path sugerido `projects/<slug>/context/`.
- **AC-05**: Hook PreToolUse en Edit/Write sobre `projects/*/CLAUDE.md` muestra
  ratio actual y NO bloquea (exit 0 siempre).
- **AC-06**: Si prerequisitos NO cumplidos, comando muestra banner
  `[INFORMATIONAL MODE — SPEC-CACHE-HIT-TRACKING pending]` y omite cruce con
  `usage.db`.
- **AC-07**: Si prerequisitos cumplidos, comando muestra hit rate observado
  del proyecto en los últimos 14d junto al ratio teórico.
- **AC-08**: Regla `project-context-discipline.md` documenta la convención de
  marcadores con 3+ ejemplos canónicos.
- **AC-09**: Suite BATS pasa con score >=80 en `test-architect` auditor.

---

## 4. Convención de marcadores

### Sintaxis

```markdown
<!-- [STATIC] -->
## Arquitectura del proyecto

Contenido estable: stack, layers, glosario, heurísticas validadas.

<!-- [/STATIC] -->

<!-- [DYNAMIC] -->
## Sprint actual

Contenido volátil: sprint vigente, backlog, métricas del día.

<!-- [/DYNAMIC] -->
```

### Reglas

- Un marcador abre con `<!-- [STATIC] -->` o `<!-- [DYNAMIC] -->` en línea propia.
- Cierra con `<!-- [/STATIC] -->` o `<!-- [/DYNAMIC] -->` en línea propia.
- NO se permite anidar. NO se permite mezclar STATIC dentro de DYNAMIC.
- Una sección sin marcador se reporta como `[UNMARKED]` y cuenta como dynamic.
- Marcadores aplican a bloques de `##` o `###`, NO a líneas sueltas.

### Ejemplos canónicos (documentados en la regla)

1. **Stack técnico** → STATIC (cambia <1×/quarter).
2. **Heurísticas T1-T5 / glosario de dominio** → STATIC.
3. **Sprint actual + número** → DYNAMIC (cambia cada 2 semanas).
4. **Backlog top 5 + estado** → DYNAMIC (cambia diario).
5. **Reglas inmutables del proyecto** → STATIC.

---

## 5. Implementación

### Ficheros a crear

- `scripts/project-context-audit.py` — parser + reporter.
- `.opencode/hooks/project-context-discipline.sh` — hook PreToolUse informativo.
- `.opencode/commands/project-context-audit.md` — slash command.
- `docs/rules/domain/project-context-discipline.md` — convención + ejemplos.
- `tests/test-project-context-audit.bats` — 6 escenarios mínimo.

### Esquema de salida del comando

```
Project: trazabios_main
File:    projects/trazabios_main/CLAUDE.md  (471 lines)
Ratio:   static=312 (66%), dynamic=98 (21%), unmarked=61 (13%)
Status:  WARNING (target: static >=80%)

[INFORMATIONAL MODE — SPEC-CACHE-HIT-TRACKING pending, no hit_rate cross-ref]

UNMARKED blocks:
  L120  ## Sprint 2026-09 — pendientes
  L245  ## Riesgos activos
  L389  ## Decisiones recientes

DYNAMIC blocks candidatos a extracción:
  L120  → projects/trazabios_main/context/current-sprint.md
  L245  → projects/trazabios_main/context/active-state.md
```

---

## 6. Tests (BATS)

1. **TC-01**: Parser cuenta correctamente líneas static/dynamic en fichero válido.
2. **TC-02**: Secciones sin marcador se reportan como UNMARKED con nº línea.
3. **TC-03**: Ratio <80% emite WARNING en stdout.
4. **TC-04**: Marcadores anidados detectados como ERROR (exit 1).
5. **TC-05**: Hook PreToolUse exit 0 incluso con ratio bajo.
6. **TC-06**: Modo informational activo si `~/.savia/usage.db` no existe.

---

## 7. Definition of Done

- Los 9 AC pasan en CI local (`bash scripts/validate-ci-local.sh`).
- Suite BATS verde y auditada por `test-architect` (score >=80).
- Regla `project-context-discipline.md` revisada por humano.
- Comando documentado en `.opencode/commands/references/command-catalog.md`.
- README sin cambios (regla interna, no toca API pública).
- Banner `[INFORMATIONAL MODE]` mostrado correctamente cuando prereqs faltan.

---

## 8. Riesgos

- **R1**: Adopción baja — devs ignoran marcadores. **Mitigación**: hook
  informativo en cada edit recuerda el ratio actual.
- **R2**: Marcadores se desincronizan con contenido (bloque marcado STATIC pero
  edita semanalmente). **Mitigación**: cuando prereqs cumplidos, comando cruza
  marcador con frecuencia real de edición (git log) y reporta `[DRIFT]`.
- **R3**: Ratio 80% es arbitrario. **Mitigación**: documentar en la regla que
  el target se recalibrará tras 30d de datos reales (futura spec
  `SPEC-CONTEXT-METRICS-DASHBOARD`).
- **R4**: Falsos positivos UNMARKED en secciones muy cortas (1-2 líneas).
  **Mitigación**: parser ignora bloques <3 líneas.
