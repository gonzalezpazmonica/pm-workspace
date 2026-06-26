---
spec_id: SE-216
title: "evo patterns: scratchpad, gates, frontier strategies, tree search"
status: IMPLEMENTED
priority: P2
effort: L
era: 204
origin: output/research/evo-hq-savia-20260609.md
resource: "https://github.com/evo-hq/evo"
inspiration: evo-hq/evo v0.5.0 (Apache-2.0) — autonomous codebase research
deps:
  - SE-211 (typed memory schema — implemented)
  - SE-215 (eval-driven improvement loop — implemented)
  - code-improvement-loop skill (implemented)
  - overnight-sprint skill (implemented)
  - dag-scheduling skill (implemented)
created: 2026-06-09
---

# SE-216 — evo patterns: scratchpad, gates heredados, frontier strategies, tree search

## Contexto

[evo-hq/evo](https://github.com/evo-hq/evo) es un orquestador de autoresearch autónomo para codebases (v0.5.0, Apache-2.0). Inspirado en Karpathy/autoresearch, añade tres piezas que pm-workspace no tiene en forma equivalente:

1. **Scratchpad compartido**: estado serializado que leen todos los subagentes al inicio — más rico que MEMORY.md actual (incluye árbol de experimentos, hipótesis descartadas, anotaciones de patrones, frontier rankeado).
2. **Gates heredados en cascada**: quality gates pre/post que bloquean el commit de un experimento si fallan, con herencia por rama. Más riguroso que el `commit-guardian` actual, que solo opera pre-push.
3. **Frontier strategies**: 5 políticas de selección de nodos en el árbol (argmax, top-k, ε-greedy, softmax, pareto_per_task). El `pareto_per_task` preserva "especialistas" por tarea que un score agregado ocultaría — aplicable a `run-agent-evals.sh`.
4. **Tree search sobre hill climbing**: el grafo de experimentos (`graph.json`) mantiene múltiples ramas activas simultáneamente. Actualmente `code-improvement-loop` y `overnight-sprint` son hill climb lineal — colapsan a un único camino.

## Alcance de SE-216

SE-216 es una **Era de 4 slices independientes**, ordenados por ROI descendente. Cada slice es implementable por separado. Los slices 1 y 2 son bajo riesgo y alto impacto directo. Los slices 3 y 4 son más complejos y opcionales en primera instancia.

---

## Slice 1 — Agent Scratchpad (`scripts/agent-scratchpad.sh`) ~4h

### Problema

Los subagentes lanzados por `dag-scheduling`, `overnight-sprint` y `code-improvement-loop` tienen contexto aislado. No hay estado compartido estructurado entre ellos. `MEMORY.md` es un índice plano de decisiones, no un documento de trabajo multi-agente.

### Solución

Script `scripts/agent-scratchpad.sh` que genera y actualiza un documento de trabajo compartido en `output/scratchpad-{run_id}.md`. Los agentes lo leen al inicio del turno y pueden añadir anotaciones al finalizar.

### Contrato

```bash
# Generar scratchpad para una sesión
bash scripts/agent-scratchpad.sh generate \
  --run-id <run_id> \
  --agents "code-reviewer security-guardian drift-auditor" \
  --context-files "CLAUDE.md docs/ROADMAP.md"

# Añadir anotación desde un agente
bash scripts/agent-scratchpad.sh annotate \
  --run-id <run_id> \
  --agent "code-reviewer" \
  --finding "AB#1234: validación faltante en endpoint POST /patients" \
  --severity "high"

# Añadir hipótesis descartada ("What Not To Try")
bash scripts/agent-scratchpad.sh discard \
  --run-id <run_id> \
  --hypothesis "Eliminar caché de sesión para reducir memoria" \
  --reason "Probado en run-0012: degradó latencia p95 de 80ms a 340ms"

# Leer scratchpad completo (para contexto de agente)
bash scripts/agent-scratchpad.sh read --run-id <run_id>
```

### Estructura del scratchpad generado

```markdown
# Agent Scratchpad — run-{run_id}

**Generated:** {timestamp} | **Agents:** {list} | **Round:** {N}

## Estado actual
{resumen del objetivo de la sesión}

## Frontier (tareas pendientes rankeadas)
1. [PRIORITY: HIGH] AB#1234 — validación faltante...
2. [PRIORITY: MED]  AB#1235 — cobertura test <60%...

## Anotaciones por agente
### code-reviewer (Round 1)
- [HIGH] AB#1234: ...
### security-guardian (Round 1)
- [MED] Dependency X tiene CVE-2026-XXXX

## What Not To Try
- "Eliminar caché de sesión" → Probado run-0012: latencia p95 340ms (vs 80ms)
- "Incrementar timeout BATS a 600s" → Probado run-0008: enmascara tests lentos

## Cross-cutting notes
{notas que aplican a múltiples tareas}
```

### Ficheros

```
scripts/agent-scratchpad.sh         # script principal
tests/test-se-216-scratchpad.bats   # suite BATS ≥15 tests, score ≥80
output/scratchpad-{run_id}.md       # generado en runtime (gitignored)
```

### Integración

- `overnight-sprint`: añadir `bash scripts/agent-scratchpad.sh generate` al inicio + `annotate` tras cada tarea
- `dag-scheduling`: pasar `--scratchpad-run-id` a cada nodo del DAG
- `code-improvement-loop`: leer scratchpad antes de seleccionar próxima mejora

### Criterios de aceptación

```
AC-01: generate crea output/scratchpad-{run_id}.md con las secciones canónicas
AC-02: annotate añade entry en la sección del agente correspondiente con timestamp
AC-03: discard añade entry en "What Not To Try" con reason
AC-04: read devuelve el contenido completo sin truncar
AC-05: dos agentes pueden llamar a annotate simultáneamente sin corrupción (advisory lock)
AC-06: generate con --agents vacío falla con mensaje claro
AC-07: el scratchpad no contiene datos PII ni credenciales
```

---

## Slice 2 — Inherited Gates (`scripts/agent-gate.sh`) ~3h

### Problema

`commit-guardian` verifica antes del push pero no tiene concepto de herencia ni de "experimento que falla un gate = no cuenta su resultado". En `overnight-sprint` y `code-improvement-loop`, si un agente hace un cambio que rompe tests, el cambio puede colarse si el commit-guardian no está en el path correcto.

### Solución

Script `scripts/agent-gate.sh` que define gates reutilizables con herencia en cascada. Un gate falla → la rama se marca `FAILED` y no avanza. Los gates se asocian a un `run_id` y se heredan por todos los agentes/ramas que derivan de él.

### Contrato

```bash
# Añadir gate a un run (todos los agentes del run lo heredan)
bash scripts/agent-gate.sh add \
  --run-id <run_id> \
  --name "tests-pass" \
  --phase pre \
  --cmd "bash scripts/validate-ci-local.sh" \
  --on-fail "block"    # block | warn | skip

# Añadir gate a una rama específica (hereda + override)
bash scripts/agent-gate.sh add \
  --run-id <run_id> \
  --branch "agent/fix-auth" \
  --name "security-scan" \
  --phase post \
  --cmd "bash scripts/confidentiality-scan.sh --pr"

# Ejecutar todos los gates de una rama
bash scripts/agent-gate.sh run \
  --run-id <run_id> \
  --branch "agent/fix-auth" \
  --phase pre

# Estado de gates (qué pasa, qué falla)
bash scripts/agent-gate.sh status --run-id <run_id>
```

### Reglas de negocio

| # | Regla |
|---|---|
| RN-01 | Un gate `block` que falla detiene la ejecución del agente con exit code 1 |
| RN-02 | Un gate `warn` que falla emite WARNING a stderr pero no detiene |
| RN-03 | Los gates de `run_id` root se heredan por todas las ramas — no se pueden suprimir |
| RN-04 | Una rama puede añadir gates adicionales pero no eliminar los heredados |
| RN-05 | La fase `pre` corre antes de que el agente edite código; `post` después del benchmark |
| RN-06 | El estado de gates se persiste en `.evo/{run_id}/gates.json` |

### Ficheros

```
scripts/agent-gate.sh               # script principal
tests/test-se-216-gates.bats        # suite BATS ≥15 tests, score ≥80
.evo/{run_id}/gates.json            # estado en runtime (gitignored)
```

### Criterios de aceptación

```
AC-01: add crea el gate en gates.json con los campos correctos
AC-02: run ejecuta el cmd y retorna exit 0 si pasa, exit 1 si falla (phase=block)
AC-03: gates de run_id root aparecen en todas las ramas sin añadirlos explícitamente
AC-04: una rama no puede eliminar un gate heredado (error claro)
AC-05: status muestra tabla con gate, fase, estado (PASS/FAIL/PENDING) por rama
AC-06: run con phase=pre no ejecuta gates post, y viceversa
AC-07: gate con cmd inexistente falla con mensaje "command not found: {cmd}"
```

---

## Slice 3 — Frontier Strategies (`scripts/frontier-strategy.sh`) ~4h

### Problema

`code-improvement-loop` y `eval-improvement-suggest.sh` (SE-215) seleccionan la próxima tarea de forma simple (primer item de la lista, o score mayor). No hay política de exploración configurable. Cuando hay múltiples métricas (cobertura + latencia + corrección), un score agregado oculta especialistas.

### Solución

Script `scripts/frontier-strategy.sh` que implementa las 5 estrategias de evo y se puede invocar desde cualquier skill que necesite seleccionar el próximo ítem de un conjunto rankeado.

### Estrategias implementadas

| Estrategia | Comportamiento | Cuándo usar |
|---|---|---|
| `argmax` | Siempre el item con mayor score | Exploit puro, convergencia conocida |
| `top_k` | Los K mejores en round-robin | Paralelismo fijo |
| `epsilon_greedy` | Best con prob 1-ε, random con prob ε | Balance exploit/explore configurable |
| `softmax` | Muestreo ponderado por exp(score/T) | Exploración proporcional al score |
| `pareto_per_task` | Preserva especialistas por tarea (dominación set-cover) | Multi-métrica, default recomendado |

### Contrato

```bash
# Input: JSON de items con scores por tarea
# Output: JSON con item(s) seleccionados

bash scripts/frontier-strategy.sh select \
  --strategy pareto_per_task \
  --k 3 \
  --input-file output/eval-report-latest.json

# Formato input (un item por eval case):
# [{"id": "skill-abc", "scores": {"correctness": 0.8, "latency": 0.6}, "metadata": {...}}]

# Formato output:
# [{"id": "skill-abc", "reason": "pareto-specialist: correctness", "rank": 1}]

# Con epsilon-greedy
bash scripts/frontier-strategy.sh select \
  --strategy epsilon_greedy \
  --epsilon 0.15 \
  --k 1 \
  --input-file output/eval-report-latest.json
```

### Integración con SE-215

`eval-improvement-suggest.sh` acepta `--strategy` para seleccionar qué eval cases priorizar:

```bash
bash scripts/eval-improvement-suggest.sh \
  --strategy pareto_per_task \
  --k 3
```

### Ficheros

```
scripts/frontier-strategy.sh              # script principal (Python inline o bash+python3)
tests/test-se-216-frontier-strategy.bats  # suite BATS ≥20 tests, score ≥80
docs/rules/domain/frontier-strategies.md  # referencia de algoritmos
```

### Criterios de aceptación

```
AC-01: argmax devuelve el item con score más alto
AC-02: top_k=3 devuelve exactamente 3 items distintos
AC-03: epsilon_greedy con epsilon=0 es equivalente a argmax
AC-04: epsilon_greedy con epsilon=1 es equivalente a random
AC-05: softmax con T→0 converge a argmax; con T→∞ a uniforme
AC-06: pareto_per_task preserva ≥1 especialista por tarea aunque no sea el mejor global
AC-07: pareto_per_task con una sola tarea es equivalente a argmax
AC-08: input vacío retorna [] con mensaje claro
AC-09: --strategy desconocida falla con lista de estrategias válidas
AC-10: output JSON es válido y parseable con python3 -c "import json; json.load(...)"
```

---

## Slice 4 — Experiment Graph (`scripts/experiment-graph.sh`) ~6h

### Problema

`overnight-sprint` y `code-improvement-loop` operan en modo hill-climb lineal: una rama, una dirección. Si una hipótesis falla, se descarta y se avanza. No hay memoria de ramas alternativas prometedoras ni posibilidad de volver a explorar.

### Solución

Script `scripts/experiment-graph.sh` que mantiene un grafo persistente de experimentos en `output/graph-{run_id}.json`. Cada nodo representa un experimento (hipótesis + rama git + score + estado). Los agentes pueden derivar nodos hijos, marcarlos como committed/discarded, y el grafo sirve de estado para frontier-strategy.

> **Nota**: Este slice tiene mayor complejidad y riesgo de integración. Implementar sólo tras validar Slices 1-3 en producción.

### Contrato

```bash
# Inicializar grafo para una sesión
bash scripts/experiment-graph.sh init \
  --run-id <run_id> \
  --root-branch main \
  --objective "mejorar cobertura de tests al 85%"

# Crear nodo hijo (nuevo experimento)
bash scripts/experiment-graph.sh branch \
  --run-id <run_id> \
  --parent <node_id> \
  --hypothesis "Añadir tests parametrizados para edge cases de auth" \
  --branch-name "agent/exp-auth-tests-$(date +%Y%m%d)"

# Marcar nodo como committed (score mejoró + gates OK)
bash scripts/experiment-graph.sh commit \
  --run-id <run_id> \
  --node <node_id> \
  --score 0.87

# Marcar nodo como discarded
bash scripts/experiment-graph.sh discard \
  --run-id <run_id> \
  --node <node_id> \
  --reason "Score regresó de 0.82 a 0.71 — hipótesis incorrecta"

# Ver árbol actual
bash scripts/experiment-graph.sh show --run-id <run_id>

# Obtener frontier para frontier-strategy
bash scripts/experiment-graph.sh frontier \
  --run-id <run_id> \
  --format json  # → input para frontier-strategy.sh
```

### Estructura del grafo (`graph.json`)

```json
{
  "run_id": "run-0042",
  "objective": "mejorar cobertura al 85%",
  "created": "2026-06-09T22:00:00Z",
  "nodes": {
    "root": {
      "id": "root",
      "parent": null,
      "status": "committed",
      "score": 0.72,
      "hypothesis": "baseline",
      "branch": "main",
      "created": "2026-06-09T22:00:00Z",
      "committed_at": "2026-06-09T22:00:00Z"
    },
    "n001": {
      "id": "n001",
      "parent": "root",
      "status": "committed",
      "score": 0.81,
      "hypothesis": "Añadir tests parametrizados para auth edge cases",
      "branch": "agent/exp-auth-tests-20260609",
      "scores_by_task": {"coverage": 0.87, "latency": 0.75}
    },
    "n002": {
      "id": "n002",
      "parent": "root",
      "status": "discarded",
      "score": 0.69,
      "hypothesis": "Eliminar caché de sesión",
      "discard_reason": "latencia p95 degradó 80ms → 340ms"
    }
  }
}
```

### Ficheros

```
scripts/experiment-graph.sh              # script principal
tests/test-se-216-experiment-graph.bats  # suite BATS ≥20 tests, score ≥80
output/graph-{run_id}.json               # generado en runtime (gitignored)
```

### Criterios de aceptación

```
AC-01: init crea graph.json con nodo root y campos obligatorios
AC-02: branch crea nodo hijo con parent correcto y status "pending"
AC-03: commit actualiza status a "committed" y registra score y timestamp
AC-04: discard actualiza status a "discarded" y registra reason
AC-05: show imprime árbol con glyphs (C=committed, D=discarded, P=pending, F=failed)
AC-06: frontier devuelve solo nodos con status "committed" o "pending"
AC-07: dos agentes pueden llamar a branch simultáneamente sin colisión de node_id
AC-08: run_id inexistente en branch/commit/discard falla con mensaje claro
AC-09: el graph.json es válido JSON tras cualquier operación
AC-10: show con árbol de 50+ nodos no supera 3s de ejecución
```

---

## Esfuerzo total

| Slice | Script | Tests | Esfuerzo | Riesgo |
|---|---|---|---|---|
| 1 — Agent Scratchpad | `agent-scratchpad.sh` | `test-se-216-scratchpad.bats` | ~4h | Bajo |
| 2 — Inherited Gates | `agent-gate.sh` | `test-se-216-gates.bats` | ~3h | Bajo |
| 3 — Frontier Strategies | `frontier-strategy.sh` | `test-se-216-frontier-strategy.bats` | ~4h | Medio |
| 4 — Experiment Graph | `experiment-graph.sh` | `test-se-216-experiment-graph.bats` | ~6h | Alto |
| **Total** | | | **~17h** | |

## Orden de implementación recomendado

1. Slice 2 (Gates) — más directamente aplicable hoy, bajo riesgo
2. Slice 1 (Scratchpad) — mejora inmediata para dag-scheduling y overnight-sprint
3. Slice 3 (Frontier Strategies) — integra con SE-215 eval loop
4. Slice 4 (Experiment Graph) — sólo si Slices 1-3 demuestran valor en producción

## Dependencias entre slices

```
Slice 2 (Gates) ──────────────── standalone
Slice 1 (Scratchpad) ─────────── standalone
Slice 3 (Frontier) ──────────── depende de SE-215 output format
Slice 4 (Experiment Graph) ───── depende de Slice 1 (scratchpad) + Slice 2 (gates) + Slice 3 (frontier)
```

## Referencias

- Repositorio origen: https://github.com/evo-hq/evo (v0.5.0)
- Ficheros clave: `plugins/evo/src/evo/scratchpad.py`, `frontier_strategies.py`, `core.py`
- Paper frontier pareto: GEPA arXiv:2507.19457
- Análisis completo: `output/research/evo-hq-savia-20260609.md`
