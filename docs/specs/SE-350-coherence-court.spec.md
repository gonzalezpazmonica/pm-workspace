# SE-350 — Coherence Court: jueces paralelos transversales de consistencia entre etapas

**Status:** APPROVED (implementation-ready)
**Fecha:** 2026-08-30
**Área:** Transversal / Agentic pipelines
**Deriva de:** Code Review Court (patrón de jueces paralelos existente, hoy acoplado al dominio de código)
**Criterio humano aplicable:** CRIT-001 (datos en infraestructura propia, N3+ jamás a cloud)

---

## 1. Objetivo

Extraer el patrón "jueces paralelos + scoring + gate" de Code Review Court a un
componente transversal **desacoplado del dominio de código**: **Coherence Court**.
Invocable por cualquier flujo agéntico multi-etapa de Savia para auditar la
**coherencia relativa** entre la salida de la etapa actual y las premisas /
decisiones / restricciones fijadas en etapas anteriores del mismo flujo.

## 2. Contexto

Savia implementa jueces paralelos en Code Review Court (5 jueces: correctness,
architecture, security, cognitive, spec) con scoring 0-100 y gate de 400 LOC.
Ese patrón resuelve validar *código*, pero la lógica subyacente —"verificar que
una salida es coherente con lo que la precede"— aplica a cualquier flujo
multi-etapa:

- Sprint nocturno (propuestas en ramas `agent/*` tras specs previas del mismo sprint).
- Investigación técnica autónoma (conclusiones de una fase vs hallazgos/restricciones de fases anteriores).
- Futuros dominios de análisis estratégico/prospectivo (PESTLE, escenarios, backcasting).

Hoy esa incoherencia entre etapas solo se detecta si el humano la nota en la
revisión final. Coherence Court la audita de forma sistemática y transversal.

**Rechazo explícito (CRIT-001):** el registro de premisas/decisiones previas es
texto plano local (`data/`), sin red, sin proveedor. Coherence Court no replica
ninguna telemetría a nube.

## 3. Qué hace / qué NO hace

### No hace
- No sustituye el juicio humano ni genera veredictos vinculantes por sí solo.
- No evalúa calidad o corrección absoluta de una salida — evalúa **coherencia
  relativa** con etapas anteriores del mismo flujo.
- No opera en flujos de una sola etapa (no hay "anterior" con qué comparar).

### Hace
1. Recibe como entrada: (a) la salida de la etapa actual (fichero/mensaje), y
   (b) el **registro de premisas** acumulado de etapas previas del mismo flujo.
2. Ejecuta **4 jueces de coherencia** en paralelo, cada uno especializado en un
   tipo de contradicción:
   - `coherence-factual-judge` — contradicción factual con premisas ya fijadas.
   - `coherence-scope-judge` — contradicción de alcance/restricciones.
   - `coherence-objectives-judge` — contradicción de objetivos declarados.
   - `coherence-premise-drift-judge` — deriva silenciosa de premisas.
3. Produce un score 0-100 y un listado de discrepancias, **en el mismo formato
   de salida que `.review.crc`** (schema gemelo `coherence-crc.schema.json`),
   para reutilizar tooling existente.
4. Aplica **puerta humana** (gate) cuando el score cae bajo el umbral
   configurable, coherente con el principio "el humano decide".

### Relación con Code Review Court
Code Review Court queda como la primera instancia concreta de Coherence Court
especializada en código; sus 5 jueces se mantienen tal cual. La **migración** de
Code Review Court para consumir Coherence Court **no es parte de esta spec**
(ver §6 y §8) — aquí solo se construye la infraestructura genérica.

## 4. Decisiones sobre las preguntas abiertas de la propuesta

| Pregunta | Decisión SE-350 | Justificación |
|---|---|---|
| ¿Premisas auto-derivadas de memoria o formato explícito? | **Formato explícito por flujo** (`data/coherence-premises-{flow}.jsonl`, JSONL append/upsert) | Determinista, auditable, testeable; consistente con SE-349. La auto-derivación desde memoria persistente queda como trabajo futuro |
| ¿Umbral configurable por flujo o global? | **Global por defecto + override por flujo** (`COHERENCE_SCORE_PASS` / `COHERENCE_SCORE_CONDITIONAL`; override por flujo vía `--threshold` y `rules/coherence.rules.yaml`) | Espejo de `COURT_SCORE_PASS`; un default sano con escape por flujo |
| ¿Migrar Code Review Court es parte de esta spec? | **No — spec de migración separada** | Mantiene el PR pequeño y reviewable; Coherence Court queda invocable desde ya |

## 5. Registro de premisas (schema v1, JSONL)

Fichero por flujo: `data/coherence-premises-{flow}.jsonl` (ya gitignored vía `/data/*`).
Cada línea es un premisa completa; `premise_id` identifica la premisa.

| Campo | Tipo | Valores | Nota |
|---|---|---|---|
| `schema_version` | string | `"1"` | Discriminador |
| `premise_id` | string | UUID | Clave |
| `flow` | string | nombre del flujo | |
| `stage` | string | etapa que fijó la premisa (ej. `stage-1`, `spec`) | |
| `kind` | string | `fact\|constraint\|objective\|decision` | Tipo de premisa |
| `content` | string | texto de la premisa | |
| `source` | string | path del artefacto (spec, informe, PBI) | opcional |
| `added_at` | ISO-8601 | | |

Subcomando `premises` de `coherence-court.sh` gestiona el registro:
`init`, `add`, `list`, `show`, `clear` (dev/test).

## 6. CLI — `scripts/coherence-court.sh`

```
coherence-court.sh check                                  # gate de flujo multi-etapa
coherence-court.sh premises <flow> init                   # crea registro vacío
coherence-court.sh premises <flow> add <kind> <content> [--stage S] [--source F]
                                                          # append (upsert por premise_id si se pasa --id)
coherence-court.sh premises <flow> list [--json]          # lista premisas del flujo
coherence-court.sh premises <flow> show <premise_id>      # una premisa
coherence-court.sh premises <flow> clear                  # vacía registro (dev/test)
coherence-court.sh skeleton <flow> <stage_output>         # genera .coherence.crc skeleton
coherence-court.sh score C H M L                          # score 0-100
coherence-court.sh gate <score> [--threshold N] [--conditional N]   # puerta humana
coherence-court.sh hash FILE                              # SHA-256
```

Reglas de implementación:

- Exit codes: `gate` → 0 = PASS, 2 = CONDITIONAL, 1 = FAIL (espejo de `court-score-aggregator.sh`).
- `check` falla (exit 1) si no hay registro de premisas del flujo con ≥1 premisa
  (flujo de una sola etapa) o si no se pasa `stage_output`.
- JSON engine: `python3` (disponible en el workspace). Si falta, degrada con aviso y exit 1.
- Todos los subcomandos con `set -uo pipefail`, estilo `court-review.sh`.

## 7. Jueces y orchestrator

Agentes nuevos en `.opencode/agents/`:

| Agent | Foco |
|---|---|
| `coherence-court-orchestrator` | Convoca los 4 jueces en paralelo, consolida `.coherence.crc`, aplica gate (L4) |
| `coherence-factual-judge` | La salida de la etapa N contradice un hecho fijado en etapas previas |
| `coherence-scope-judge` | La salida viola alcance/restricciones fijadas previamente |
| `coherence-objectives-judge` | La salida contradice objetivos declarados del flujo |
| `coherence-premise-drift-judge` | Cambio silencioso de premisa entre etapas sin declararlo |

Formato de veredicto por juez (YAML):

```yaml
judge: "coherence-factual-judge"
reviewed_at: "{ISO timestamp}"
flow_ref: "{flow}"
stage_ref: "{stage}"
verdict: "pass|conditional|fail"
score: {0-100}
confidence: {0.0-1.0}
findings:
  - id: "CFA-001"
    premise_id: "{premise_id}"
    severity: "critical|high|medium|low"
    kind: "contradiction|omission|scope-violation|premise-drift"
    detail: "{qué contradice y cómo}"
summary:
  total_findings: {N}
  critical: {N}
  high: {N}
  medium: {N}
  low: {N}
```

Score consolidado (misma fórmula que Code Review Court):

```
score = 100 - (critical × 25) - (high × 10) - (medium × 3) - (low × 1)
verdict = score >= 90 ? "pass" : score >= 70 ? "conditional" : "fail"
```

## 8. Criterios de aceptación

- AC-1: `check` sin registro de premisas del flujo → exit 1 con mensaje "flujo de una sola etapa".
- AC-2: `check` con registro de premisas y `stage_output` → PASS (exit 0).
- AC-3: `premises <flow> add` crea una entrada v1 con `premise_id`, timestamps ISO y kind validado.
- AC-4: `premises <flow> add` con kind inválido → error (exit 1).
- AC-5: `premises <flow> list --json` devuelve JSON parseable con todas las premisas.
- AC-6: `premises <flow> clear` deja el registro vacío (solo dev/test).
- AC-7: `skeleton` genera `.coherence.crc` con los 4 jueces, `flow_ref`, `stage_ref`, score 0.
- AC-8: `score` reproduce la fórmula 100 - (C×25 + H×10 + M×3 + L×1) con floor en 0.
- AC-9: `gate 95` → exit 0 (PASS); `gate 80` → exit 2 (CONDITIONAL); `gate 50` → exit 1 (FAIL); `--threshold` override respetado.
- AC-10: `hash` emite SHA-256 de 64 hex.
- AC-11: schema `.claude/schemas/coherence-crc.schema.json` es JSON válido y referencia los 4 jueces.
- AC-12: `rules/coherence.rules.yaml` define thresholds, pesos y override por flujo.
- AC-13: existen los 5 agentes en `.opencode/agents/` con frontmatter válido y ≤150 líneas.
- AC-14: suite BATS `tests/test-se-350-coherence-court.bats` ≥ 20 tests (validación manual local; bats en CI).
- AC-15: ninguna salida/registro contacta proveedor externo; cero red (CRIT-001).

## 9. Ficheros

| Acción | Path |
|---|---|
| CREATE | `docs/specs/SE-350-coherence-court.spec.md` |
| CREATE | `scripts/coherence-court.sh` |
| CREATE | `.claude/schemas/coherence-crc.schema.json` |
| CREATE | `rules/coherence.rules.yaml` |
| CREATE | `docs/rules/domain/coherence-court.md` |
| CREATE | `.claude/commands/coherence-court.md` |
| CREATE | `.opencode/agents/coherence-court-orchestrator.md` |
| CREATE | `.opencode/agents/coherence-factual-judge.md` |
| CREATE | `.opencode/agents/coherence-scope-judge.md` |
| CREATE | `.opencode/agents/coherence-objectives-judge.md` |
| CREATE | `.opencode/agents/coherence-premise-drift-judge.md` |
| CREATE | `tests/test-se-350-coherence-court.bats` |
| CREATE | `CHANGELOG.d/se350-coherence-court.md` |
| MODIFY (auto) | `AGENTS.md`, `docs/rules/domain/agents-catalog.md`, `docs/rules/domain/INDEX.md`, `.scm/INDEX.scm`, `CLAUDE.md` (contadores), `SKILLS.md` (si aplica) |

## 10. OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| spec | `docs/specs/SE-350-coherence-court.spec.md` | lectura directa |
| script | `scripts/coherence-court.sh` (bash + python3 heredoc) | invocación bash directa |
| tests | `tests/test-se-350-coherence-court.bats` | bats runner (CI) |
| agents | `.opencode/agents/coherence-*.md` | registry de agentes (AGENTS.md auto) |
| schema | `.claude/schemas/coherence-crc.schema.json` | lectura directa |
| rule | `docs/rules/domain/coherence-court.md` | lectura directa |

### Verification protocol

- [x] Funciona en runtime OpenCode (script bash puro, sin bindings de frontend)
- [x] Smoke test local de cada subcomando (ver §11)
- [ ] Tests bats ejecutados en CI (bats instalado localmente; validación local en este sprint)

### Portability classification

- [x] **PURE_BASH** — lógica en bash/python3 heredoc, cero bindings de frontend;
      corre idéntico en Claude Code y OpenCode.

## 11. Validación (ejecutada en esta sesión)

```
FLOW=test-flow
bash scripts/coherence-court.sh check --flow $FLOW --stage-output /tmp/x.txt   # exit 1 (sin premisas)
bash scripts/coherence-court.sh premises $FLOW init
bash scripts/coherence-court.sh premises $FLOW add constraint "Max 400 LOC" --stage stage-1
bash scripts/coherence-court.sh premises $FLOW add fact "El modulo X existe" --stage stage-1
bash scripts/coherence-court.sh premises $FLOW add objective "No romper API" --stage stage-1
bash scripts/coherence-court.sh check --flow $FLOW --stage-output /tmp/x.txt   # PASS
bash scripts/coherence-court.sh score 1 2 3 4      # score=52
bash scripts/coherence-court.sh gate 95            # exit 0
bash scripts/coherence-court.sh gate 80            # exit 2
bash scripts/coherence-court.sh gate 50            # exit 1
bash scripts/coherence-court.sh premises $FLOW clear
```

## 12. Trabajo futuro (fuera de scope)

- **Migración de Code Review Court**: spec separada que haga que `court-orchestrator`
  consuma Coherence Court (premisas + gate) en lugar de reimplementar.
- **Auto-derivación de premisas** desde memoria persistente (JSONL de decisiones,
  extraction automática) → subcomando `premises seed --from-memory`.
- **Integración con SE-349 (agent-runs ledger)**: correlacionar premisas de
  coherencia con el ledger de runs autónomos para trazar qué premisa vino de qué run.

## 13. Slice 2 — Cableado en flujos (IMPLEMENTED en esta sesión)

### Cableado

| Flujo | Punto de cableado | Coste |
|---|---|---|
| overnight-sprint (`overnight-sprint-loop.sh`) | `premises add decision` post-`TASK_DONE` + `_coherence_gate` al `LOOP_END` | determinista ~0 |
| tech-research-agent (skill) | premisas del plan al arrancar + gate `check` en cada transición de fase | determinista ~0 |
| code-improvement-loop (skill) | `premises add decision` por mejora que pasa las métricas | determinista ~0 |

### Política anti-saturación

- **Gate determinista** (premises + `check`, sin LLM): SIEMPRE ON en el bucle,
  coste ~0 (JSONL local + contador).
- **Auditoría LLM de 4 jueces**: OPT-IN al final del flujo (nunca por tarea),
  vía `/coherence-court --flow {flujo}` o `COHERENCE_AUDIT_JUDGES=1`. Ejecutar
  4 jueces por tarea en un bucle nocturno de N tareas = N×4 llamadas LLM (saturación).
- **Switch**: `OVERNIGHT_COHERENCE_GATE=off` desactiva el cableado (para tests/CI).

### Ficheros tocados en Slice 2

| Acción | Path |
|---|---|
| MODIFY | `scripts/overnight-sprint-loop.sh` (funciones `_coherence_register`/`_coherence_gate`) |
| MODIFY | `.claude/skills/overnight-sprint/SKILL.md`, `tech-research-agent/SKILL.md`, `code-improvement-loop/SKILL.md` |
| MODIFY | `docs/rules/domain/coherence-court.md` (sección "Flujos cableados") |
| MODIFY | `tests/test-se226-overnight-sprint-loop.bats` (+5 tests cableado) |
| MODIFY | `docs/rules/domain/rule-manifest.json` (regenerado — deuda SE-057/SE-338) |

### Validación Slice 2

```
bats tests/test-se226-overnight-sprint-loop.bats   # 13 tests OK (5 nuevos de cableado)
bash -n scripts/overnight-sprint-loop.sh            # sintaxis OK
bash scripts/rule-manifest-integrity.sh             # PASS tras regenerar manifest
```

## Referencias

- `docs/rules/domain/code-review-court.md` — patrón de jueces paralelos fuente
- `docs/specs/SE-236-court-numeric-scoring.md` — scoring 0-100, pesos, gate
- `docs/specs/SE-265-court-model-tiers.spec.md` — per-judge model tiers
- `docs/specs/SE-349-agent-runs-ledger.spec.md` — patrón JSONL upsert + CRIT-001
- `scripts/court-review.sh`, `scripts/court-score-aggregator.sh` — código de referencia
- `docs/technical-debt-2026-08-23.md` — deuda SE-057/SE-338 (rule-manifest)
- CRIT-001 (criterio operadora) — datos N3+ jamás a proveedor cloud
