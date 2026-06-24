---
spec_id: SE-217
title: "autoresearch patterns: agent-run-log, time-budget, surface-guard"
status: PROPOSED
priority: P2
effort: M
era: 204
origin: https://github.com/karpathy/autoresearch (85.8k stars, MIT)
resource: "https://github.com/karpathy/autoresearch"
inspiration: karpathy/autoresearch — autonomous ML research loop
deps:
  - autonomous-safety.md (AGENT_TASK_TIMEOUT_MINUTES — implemented)
  - session-action-log.sh (implemented)
  - code-improvement-loop skill (implemented)
  - overnight-sprint skill (implemented)
created: 2026-06-09
---

# SE-217 — autoresearch patterns: agent-run-log, time-budget, surface-guard

## Contexto

[karpathy/autoresearch](https://github.com/karpathy/autoresearch) (85.8k stars, MIT) es un framework de investigación ML autónoma donde un agente LLM itera indefinidamente sobre un training script: modifica código, mide una métrica, acepta o descarta con `git reset`, y repite. ~100 experimentos por noche sin supervisión humana.

Tres patrones son directamente extraíbles a pm-workspace **sin dependencia de GPU ni ML**:

1. **`results.tsv`** — log estructurado de experimentos agénticos con commit hash, métrica, status y descripción.
2. **Time budget como unidad de comparación** — un presupuesto fijo hace los experimentos comparables entre sí.
3. **Surface guard** — el agente solo puede editar un subconjunto declarado de ficheros. Todo lo demás es read-only.

## Alcance de SE-217

3 slices independientes, todos de bajo riesgo y alta aplicabilidad inmediata.

---

## Slice 1 — Agent Run Log (`scripts/agent-run-log.sh`) ~3h

### Problema

`session-action-log.sh` registra acciones (log/fail/error) pero no experimentos con ciclo keep/discard. Cuando `code-improvement-loop` o `overnight-sprint` ejecutan N tareas, no hay registro estructurado de qué funcionó, qué falló, con qué score, y qué commit lo implementó. El análisis post-sesión es manual.

### Solución

Script `scripts/agent-run-log.sh` — log append-only de experimentos agénticos en `output/agent-run-log-{date}.tsv`. Formato TSV inspirado directamente en `results.tsv` de autoresearch, adaptado al dominio de pm-workspace.

### Contrato

```bash
# Registrar inicio de experimento
bash scripts/agent-run-log.sh start \
  --run-id "overnight-20260609" \
  --task "fix-auth-validator" \
  --hypothesis "El validator de FluentValidation falta para el campo NationalId"

# Registrar resultado (keep)
bash scripts/agent-run-log.sh keep \
  --run-id "overnight-20260609" \
  --task "fix-auth-validator" \
  --commit "abc1234" \
  --score 87 \
  --metric "quality-score" \
  --description "Validator añadido, 14/14 tests pasan"

# Registrar resultado (discard)
bash scripts/agent-run-log.sh discard \
  --run-id "overnight-20260609" \
  --task "fix-auth-validator" \
  --reason "Tests pasan pero quality-score bajó de 84 a 71"

# Registrar crash
bash scripts/agent-run-log.sh crash \
  --run-id "overnight-20260609" \
  --task "fix-auth-validator" \
  --error "build FAILED: tipo no encontrado"

# Resumen de un run
bash scripts/agent-run-log.sh summary --run-id "overnight-20260609"

# Listar todos los runs
bash scripts/agent-run-log.sh list
```

### Formato TSV (`output/agent-run-log-{date}.tsv`)

```
run_id	task	status	score	metric	commit	elapsed_s	hypothesis	description	ts
overnight-20260609	fix-auth-validator	keep	87	quality-score	abc1234	142	Validator faltante	14/14 tests pasan	2026-06-09T22:15:00Z
overnight-20260609	remove-session-cache	discard		quality-score		98	Eliminar caché sesión	Latencia degradó	2026-06-09T22:17:00Z
overnight-20260609	refactor-auth-handler	crash		quality-score		23	Refactor auth handler	build FAILED	2026-06-09T22:20:00Z
```

### Columnas

| Columna | Tipo | Descripción |
|---|---|---|
| `run_id` | string | Identificador del run |
| `task` | string | ID de tarea o descripción corta |
| `status` | enum | `keep` \| `discard` \| `crash` \| `pending` |
| `score` | float\|empty | Métrica objetiva si existe |
| `metric` | string | Nombre de la métrica (`quality-score`, `test-coverage`, `ci-pass`) |
| `commit` | string\|empty | Hash corto del commit si se hizo keep |
| `elapsed_s` | int | Segundos de ejecución |
| `hypothesis` | string | Qué se intentó |
| `description` | string | Resultado en lenguaje natural |
| `ts` | ISO8601 | Timestamp UTC |

### Integración

- `overnight-sprint`: llamar `start` al inicio de cada tarea, `keep`/`discard`/`crash` al final
- `code-improvement-loop`: ídem
- `eval-improvement-suggest.sh` (SE-215): leer el log para detectar hipótesis ya descartadas ("What Not To Try")
- SE-216 Slice 1 (scratchpad): alimentar sección "What Not To Try" con los `discard` del log

### Ficheros

```
scripts/agent-run-log.sh              # script principal
tests/test-se-217-agent-run-log.bats  # suite BATS ≥15 tests, score ≥80
output/agent-run-log-{date}.tsv       # generado en runtime (gitignored)
```

### Criterios de aceptación

```
AC-01: start crea entrada con status=pending en el TSV
AC-02: keep actualiza status a keep, registra commit y score
AC-03: discard actualiza status a discard con reason en description
AC-04: crash actualiza status a crash con error en description
AC-05: summary muestra tabla: total / keep / discard / crash / keep_rate%
AC-06: list muestra todos los run_ids con fecha y conteos
AC-07: dos llamadas simultáneas a keep no corrompen el TSV (append atómico)
AC-08: --run-id inexistente en keep/discard/crash falla con mensaje claro
AC-09: el TSV es parseable con python3 -c "import csv; list(csv.DictReader(open(...), delimiter='\t'))"
AC-10: elapsed_s se calcula automáticamente desde el start si no se pasa explícitamente
```

---

## Slice 2 — Time Budget Enforcer (`scripts/agent-time-budget.sh`) ~2h

### Problema

`autonomous-safety.md` define `AGENT_TASK_TIMEOUT_MINUTES=15` como safety gate. Pero el timeout es solo de seguridad — no se usa como **unidad de comparación** entre experimentos. autoresearch demuestra que un tiempo fijo hace los experimentos comparables: el agente optimiza "el mejor resultado posible en T minutos", no "el mejor resultado abstracto".

### Solución

Script `scripts/agent-time-budget.sh` que envuelve cualquier comando con un presupuesto de tiempo explícito, registra elapsed y status en el agent-run-log, y captura el score si se proporciona un score-cmd.

### Contrato

```bash
# Ejecutar con presupuesto de tiempo
bash scripts/agent-time-budget.sh run \
  --budget 15 \
  --run-id "overnight-20260609" \
  --task "fix-auth-validator" \
  --cmd "dotnet test tests/ --filter Category=Unit" \
  --score-cmd "bash scripts/extract-test-score.sh"

# Salida:
# BUDGET_STATUS: completed | timeout | crash
# ELAPSED_S: 87
# SCORE: 94

# Ver resumen de presupuestos de un run
bash scripts/agent-time-budget.sh report --run-id "overnight-20260609"
```

### Reglas de negocio

| # | Regla |
|---|---|
| RN-01 | Si el cmd no termina en `--budget` minutos → SIGTERM + status `timeout` |
| RN-02 | Si el cmd termina con exit != 0 → status `crash` |
| RN-03 | Si termina en tiempo → status `completed`, score = resultado de `--score-cmd` |
| RN-04 | El resultado se registra en agent-run-log si `--run-id` + `--task` presentes |
| RN-05 | Sin `--score-cmd`, score queda vacío pero status se registra igualmente |
| RN-06 | `--budget 0` desactiva el timeout (útil en tests) |

### Ficheros

```
scripts/agent-time-budget.sh              # script principal
tests/test-se-217-time-budget.bats        # suite BATS ≥12 tests, score ≥80
```

### Criterios de aceptación

```
AC-01: cmd que termina antes del budget → status completed, elapsed correcto
AC-02: cmd que supera el budget → SIGTERM a los N minutos, status timeout
AC-03: cmd con exit != 0 → status crash, error capturado
AC-04: --budget 0 → sin timeout, cmd corre hasta terminar
AC-05: con --run-id + --task → entrada registrada en agent-run-log automáticamente
AC-06: sin --score-cmd → score vacío, resto de campos correctos
AC-07: --budget negativo → error con mensaje claro
AC-08: múltiples runs del mismo task → entradas separadas (no sobreescribe)
```

---

## Slice 3 — Surface Guard (`scripts/agent-surface-guard.sh`) ~2h

### Problema

En sesiones autónomas, los agentes pueden editar cualquier fichero del repo. No hay declaración explícita de qué puede tocar el agente vs qué es read-only. Un agente que edita `CLAUDE.md`, `opencode.json` o `.claude/hooks/` por error puede romper el workspace.

autoresearch resuelve esto con una convención simple: `train.py` se puede editar, `prepare.py` es read-only. El agente lo sabe porque `program.md` lo declara explícitamente.

### Solución

Script `scripts/agent-surface-guard.sh` que define, valida y documenta la superficie de edición permitida para una sesión agéntica.

### Contrato

```bash
# Declarar superficie de edición para un run
bash scripts/agent-surface-guard.sh declare \
  --run-id "overnight-20260609" \
  --editable "src/ tests/ output/" \
  --readonly "CLAUDE.md opencode.json .claude/hooks/ scripts/" \
  --forbidden ".git/ .confidentiality-signature"

# Verificar que los staged files respetan la superficie
bash scripts/agent-surface-guard.sh verify \
  --run-id "overnight-20260609"
# Exit 0: superficie OK
# Exit 1: ficheros fuera de superficie modificados, lista en stderr

# Generar bloque de contexto para el agente
bash scripts/agent-surface-guard.sh context --run-id "overnight-20260609"
# Output:
# ## Superficie de edición
# EDITABLE:  src/, tests/, output/
# READ-ONLY: CLAUDE.md, opencode.json, .claude/hooks/, scripts/
# FORBIDDEN: .git/, .confidentiality-signature

# Listar superficies activas
bash scripts/agent-surface-guard.sh list
```

### Superficie por defecto para sesiones autónomas

```
EDITABLE (default):  output/, projects/*/source/, tests/
READONLY (default):  CLAUDE.md, opencode.json, .claude/, scripts/, docs/rules/
FORBIDDEN (default): .git/, .confidentiality-signature, .claude/settings.json
```

### Integración

- `overnight-sprint`: declarar superficie al inicio, `verify` antes de cada `git commit`
- `code-improvement-loop`: ídem
- `commit-guardian`: llamar `verify` como gate adicional si `SAVIA_SURFACE_GUARD=true`
- SE-216 Slice 1 (scratchpad): incluir output de `context` en el scratchpad generado

### Ficheros

```
scripts/agent-surface-guard.sh              # script principal
tests/test-se-217-surface-guard.bats        # suite BATS ≥15 tests, score ≥80
.evo/{run_id}/surface.json                  # superficie declarada (runtime, gitignored)
```

### Criterios de aceptación

```
AC-01: declare crea surface.json con editable/readonly/forbidden correctos
AC-02: verify con staged files todos en EDITABLE → exit 0
AC-03: verify con staged file en READONLY → exit 1, mensaje identifica el fichero
AC-04: verify con staged file en FORBIDDEN → exit 1, mensaje "FORBIDDEN"
AC-05: context genera bloque Markdown con las 3 secciones
AC-06: sin --run-id en verify → usa defaults seguros
AC-07: list muestra run_ids con superficies declaradas y fecha
AC-08: fichero en EDITABLE y READONLY simultáneamente → READONLY tiene precedencia
AC-09: directorio vacío en editable → no produce error
AC-10: --run-id inexistente en verify con defaults → funciona sin error
```

---

## Esfuerzo total

| Slice | Script | Tests | Esfuerzo | Riesgo |
|---|---|---|---|---|
| 1 — Agent Run Log | `agent-run-log.sh` | `test-se-217-agent-run-log.bats` | ~3h | Bajo |
| 2 — Time Budget | `agent-time-budget.sh` | `test-se-217-time-budget.bats` | ~2h | Bajo |
| 3 — Surface Guard | `agent-surface-guard.sh` | `test-se-217-surface-guard.bats` | ~2h | Bajo |
| **Total** | | | **~7h** | **Bajo** |

## Orden de implementación recomendado

1. Slice 1 (Run Log) — base que usan los otros dos
2. Slice 3 (Surface Guard) — independiente, alto impacto en safety
3. Slice 2 (Time Budget) — integra con Run Log

## Referencias

- Repositorio origen: https://github.com/karpathy/autoresearch (85.8k stars, MIT)
- Ficheros clave: `train.py` (loop keep/discard), `program.md` (surface declaration), `prepare.py` (READ-ONLY)
- Relacionado: `docs/rules/domain/autonomous-safety.md` (AGENT_TASK_TIMEOUT_MINUTES)
- Relacionado: `scripts/session-action-log.sh` (precursor del Run Log)
- Relacionado: SE-216 Slice 1 (scratchpad — consume Run Log)
