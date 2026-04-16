# Spec: Tools-by-Task — Skills que aceptan N targets por llamada

**Task ID:**        SPEC-TOOLS-BY-TASK
**PBI padre:**      Structural tool call reduction (repowise pattern)
**Sprint:**         2026-08
**Fecha creacion:** 2026-04-11
**Creado por:**     Savia (research: github.com/repowise-dev/repowise)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     6h
**Estado:**         Pendiente
**Max turns:**      30
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

repowise publica un benchmark reproducible vs Claude Code vanilla: -36% coste,
-49% tool calls, -89% ficheros leidos. El patron estructural que mas contribuye
a esa reduccion es **tools diseñadas por tarea, no por entidad**: una sola
llamada acepta N targets en vez de encadenar N llamadas por entidad.

Ejemplo: en vez de `read(file1) -> read(file2) -> read(file3)`, una llamada
unica `get_context([file1, file2, file3])` que devuelve los tres resultados
agrupados con deduplicacion y ordenamiento.

pm-workspace tiene el patron parcialmente (`pbi-decompose-batch`) pero la mayoria
de skills y commands asumen target unico. Cambiar esto es el win estructural
mas rentable de la investigacion (10/10 relevancia).

**Objetivo:** definir el contrato "tools-by-task" aplicable a skills pm-workspace
y refactorizar los 10 commands/skills mas usados para soportar N targets.

**Criterios de Aceptacion:**
- [ ] Contrato documentado en `docs/rules/domain/tools-by-task.md`
- [ ] 10 commands/skills refactorizados (lista en seccion 6)
- [ ] Backward compatible: target unico sigue funcionando
- [ ] Deduplicacion y ordering consistente entre llamadas
- [ ] Metricas pre/post: reduccion de tool calls >=30% en benchmark
- [ ] Test BATS con >=80 score

---

## 2. Contrato Tecnico

### 2.1 Shape de entrada

```
# Target unico (backward compat)
/debt-analyze --file src/auth/login.cs

# N targets (nuevo)
/debt-analyze --file src/auth/login.cs,src/auth/register.cs,src/auth/oauth.cs
/debt-analyze --files-from .pending-audit.txt
```

Formato CSV o path a fichero con lista. Maximo targets por llamada: 20.
Si N > 20, el command divide internamente en chunks y reporta en un solo
output agregado.

### 2.2 Shape de salida

Cuando hay N targets, el output agrupa por target con separadores claros:

```markdown
# Debt Analysis — 3 files

## src/auth/login.cs
- score: 6.2/10
- critical: 1
- ...

## src/auth/register.cs
- score: 8.1/10
- ...

## Aggregated metrics
- avg_score: 7.1
- total_critical: 2
- files_analyzed: 3
```

### 2.3 Deduplicacion

Si dos targets leen el mismo fichero subyacente (ej: dos commands que ambos
incluyen `CLAUDE.md` como contexto), se lee UNA sola vez y se reutiliza.

### 2.4 Reglas de ordering

- Targets en el output aparecen en el orden en que se pasaron
- Metricas agregadas al final, no intercaladas
- Si un target falla, se marca con `[ERROR]` pero no bloquea el resto

### 2.5 Idempotencia

`tool(x,y,z)` == `tool(x) + tool(y) + tool(z)` en resultado pero con menos
llamadas API. El usuario no debe notar diferencia funcional.

---

## 3. Reglas de Negocio

| ID | Regla | Error si viola |
|----|-------|----------------|
| TBT-01 | Max 20 targets por llamada | Chunking automatico interno |
| TBT-02 | Backward compat: target unico sigue funcionando igual | Bug |
| TBT-03 | Dedup de lecturas de ficheros comunes | Desperdicio de tokens |
| TBT-04 | Un target fallido NO aborta el resto | UX deteriorada |
| TBT-05 | Output ordenado por input order, no alfabetico | Confusion |
| TBT-06 | Metricas agregadas al final, separadas de resultados individuales | Parsing ambiguo |

---

## 4. Constraints

| Dimension | Requisito |
|-----------|-----------|
| Dependencias | Zero nuevas; solo bash + jq |
| Compatibilidad | Backward compat obligatoria |
| Performance | N targets en 1 llamada <= 1.5x latencia de 1 target |
| Limites | 20 targets hard cap por llamada |
| Observabilidad | agent-trace registra `targets_count` por invocacion |

---

## 5. Test Scenarios

### Target unico backward compat

```
GIVEN   /debt-analyze --file foo.cs (formato antiguo)
WHEN    ejecutado
THEN    funciona identico a antes
AND     agent-trace registra targets_count=1
```

### Multi-target CSV

```
GIVEN   /debt-analyze --file a.cs,b.cs,c.cs
WHEN    ejecutado
THEN    output contiene 3 secciones + agregado
AND     tool calls API <= 2 (vs 3 en patron antiguo)
```

### Multi-target con fallo parcial

```
GIVEN   /debt-analyze --file exists.cs,missing.cs,other.cs
WHEN    ejecutado
THEN    exists.cs y other.cs tienen output completo
AND     missing.cs marcado como [ERROR: file not found]
AND     exit code = 0 (no bloquea)
```

### Chunking automatico

```
GIVEN   --file con 35 targets
WHEN    ejecutado
THEN    internamente divide en 2 chunks (20 + 15)
AND     output final agregado, transparente al usuario
```

### Deduplicacion

```
GIVEN   dos commands en batch ambos leen CLAUDE.md
WHEN    tools-by-task orchestration
THEN    CLAUDE.md se lee 1 vez, no 2
AND     cache hit registrado en trace
```

### Benchmark de reduccion

```
GIVEN   scenario sintetico con 10 files a auditar
WHEN    ejecutado con patron antiguo (10 llamadas)
AND     ejecutado con tools-by-task (1 llamada N=10)
THEN    tools-by-task: <=5 tool calls (vs 10)
AND     reduccion >= 50%
```

---

## 6. Ficheros a Crear/Modificar

| Accion | Fichero | Que hacer |
|--------|---------|-----------|
| Crear | docs/rules/domain/tools-by-task.md | Contrato formal |
| Crear | scripts/tools-by-task-parse.sh | Parser CSV/lista helper |
| Crear | tests/test-tools-by-task.bats | Suite BATS |
| Modificar | .claude/commands/debt-analyze.md | Soporte N targets |
| Modificar | .claude/commands/perf-audit.md | Soporte N targets |
| Modificar | .claude/commands/spec-verify.md | Soporte N targets |
| Modificar | .claude/commands/code-patterns.md | Soporte N targets |
| Modificar | .claude/commands/a11y-audit.md | Soporte N targets |
| Modificar | .claude/commands/comprehension-report.md | Soporte N targets |
| Modificar | .claude/commands/security-review.md | Soporte N targets |
| Modificar | .claude/commands/arch-fitness.md | Soporte N targets |
| Modificar | .claude/commands/test-architect.md | Soporte N targets |
| Modificar | .claude/commands/dependency-map.md | Soporte N targets |
| Modificar | .claude/skills/codebase-map/SKILL.md | Documentar batch API |

---

## 7. Metricas de exito

| Metrica | Objetivo | Medicion |
|---------|----------|----------|
| Reduccion de tool calls | >= 30% en escenarios N>=3 | agent-trace antes/despues |
| Reduccion de tokens input | >= 20% | Benchmark reproducible |
| Backward compat | 100% | Tests existentes siguen pasando |
| Adopcion | 10 commands refactorizados | Conteo en docs/specs |

---

## Checklist Pre-Entrega

- [ ] tools-by-task.md publicado con contrato formal
- [ ] Parser CSV/lista funcional con tests
- [ ] 10 commands refactorizados y testeados
- [ ] Benchmark publicado en docs/ con cifras antes/despues
- [ ] Backward compat verificada (tests existentes verdes)
- [ ] agent-trace registra targets_count
- [ ] Tests BATS >=80 score
