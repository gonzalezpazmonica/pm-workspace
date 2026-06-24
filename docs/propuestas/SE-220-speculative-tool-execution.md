---
spec_id: SE-220
title: Speculative Tool Execution — draft+verify pattern aplicado a tool calls y skill loading
status: APPROVED
priority: P2
effort: M (~18h)
era: 207
value: 75
urgency: 65
effort_score: 22
priority_score: 78.4
confidence: media — el patrón conceptual está validado (speculative decoding = 2-3× speedup en LLM serving); su aplicación a la capa de orquestación es novedosa para Savia y requiere feasibility-probe antes de slice completo.
bucket: Q3 2026
origin: investigación speculative decoding 2026-06-20. Speculative decoding clásico (EAGLE-3, Medusa, Lookahead) NO aplica al cloud de Anthropic (decoder opaco). Pero el principio draft+verify es transferible a la capa agéntica donde sí tenemos control.
related_specs:
  - SPEC-154 (priorización V×U/E aplicada en este scoring)
  - SPEC-185 (critical-facts anchor — prompt caching ya en producción)
  - SE-202 (agent-hook-runner — gate semántico LLM, base conceptual)
  - SE-217 (autoresearch patterns — time-budget para descarte de drafts)
  - prompt-caching.md (rule)
---

# SE-220 — Speculative Tool Execution

## Why

Hoy Savia ejecuta tool calls de forma **secuencial estricta**: el orquestador piensa → emite tool call → tool ejecuta → respuesta vuelve → orquestador piensa siguiente. Cada eslabón tiene latencia: think (~1-3s sonnet/opus) + tool exec (variable) + I/O.

Cuando una skill o agente tiene un patrón **predecible** (ej: `sprint-management` típicamente invoca varias queries WIQL + capacity + report-template), un modelo barato (haiku/qwen2.5:3b) puede **predecir** las próximas N tool calls mientras el orquestador grande aún está procesando.

**Pre-flight gate (innegociable)**: feasibility-probe sobre 1 caso real (`/sprint-status`) que demuestre acceptance rate ≥ 60% del predictor. Si <60%, ABORT — el patrón no aplica y se cierra como REJECTED.

## Insight central

Speculative Decoding garantiza salida idéntica al modelo grande porque verifica matemáticamente. Aquí garantizamos salida idéntica porque:

1. El **orquestador grande** (sonnet/opus) sigue siendo la autoridad — sus tool calls son las que valen.
2. El **predictor barato** (haiku/qwen2.5:3b) solo **pre-ejecuta** las tool calls que predice. Si acierta → tiempo ahorrado. Si falla → resultados se descartan, latencia idéntica al baseline.
3. **CRÍTICO**: solo aplica a tools idempotentes y read-only. NUNCA a tools con side effects.

## Scope

### IN-Scope (4 slices)

#### Slice 0 — Feasibility probe (3h) — **BLOQUEANTE**

Antes de cualquier slice posterior:

1. Capturar 20 ejecuciones reales de `/sprint-status` desde el session-action-log.
2. Extraer secuencias de tool calls.
3. Entrenar/promptar predictor con haiku (NO fine-tuning — solo prompt engineering con ejemplos).
4. Medir acceptance rate: % de tool calls predichas correctamente en orden y argumentos.
5. **GO/NO-GO**:
   - ≥60% acceptance rate → continuar con Slice 1.
   - 40-60% → DEFERRED, recopilar más datos.
   - <40% → ABORT, cerrar spec como REJECTED con lecciones.

Output: informe de feasibility en directorio output con métricas + decisión.

#### Slice 1 — Tool call predictor + read-only whitelist (4h)

`scripts/speculative/tool-predictor.sh`:

```bash
# Input: contexto del turno actual + últimas 3 acciones
# Output: JSON con top-3 tool calls predichas + score de confianza
# Modelo: claude-haiku (cloud) o qwen2.5:3b (local)
```

`scripts/speculative/safe-tools-whitelist.json`:

```json
{
  "safe_for_speculation": [
    "wiql queries",
    "capacity reads",
    "git log",
    "git status",
    "git diff --stat",
    "cat",
    "grep",
    "find",
    "ls"
  ],
  "never_speculate": [
    "work item updates",
    "git push",
    "git commit",
    "pr create",
    "rm",
    "mv",
    "Write",
    "Edit"
  ]
}
```

#### Slice 2 — Async pre-execution wrapper (5h)

`scripts/speculative/speculative-runner.sh`:

```
1. Recibe predicción del predictor (top-3 con confianza ≥0.7)
2. Filtra contra whitelist (descarta non-idempotentes)
3. Lanza ejecuciones en background con bash & + flock
4. Almacena resultados en /tmp/speculative-cache/<turn-id>/
5. Cuando el orquestador real emite la tool call, hook check si está cacheada
6. Si hit: devuelve resultado cacheado, registra speculative-hit
7. Si miss: ejecuta normal, registra speculative-miss + descarta caché
```

Telemetría obligatoria en log JSONL append-only:
```json
{"ts":"...", "turn_id":"...", "predicted":["..."], "actual":["..."], "hit_count":2, "miss_count":1, "latency_saved_ms":850}
```

#### Slice 3 — Speculative skill pre-loading (3h)

Aplicar el mismo patrón a **carga de skills**:

1. Hook `pre-skill-resolve.sh` consulta predictor sobre el prompt actual.
2. Si predictor sugiere skill X con confianza ≥0.8, pre-lee `SKILL.md` y lo deja en `/tmp/skill-precache/`.
3. Si el resolver oficial coincide → cache hit, evita re-lectura del filesystem.
4. Si no coincide → descarta.

Coste: skills son archivos pequeños (~100 líneas), pre-carga es barata.

#### Slice 4 — Telemetry dashboard + GO/CONTINUE/KILL (3h)

`scripts/speculative/measure.sh`:

- Calcula sobre últimas 7 días:
  - acceptance_rate (predicted ∩ actual / predicted)
  - latency_p50_saved
  - latency_p95_saved
  - false_positive_rate (descartes / predicciones)
  - cost: tokens haiku consumidos / tokens sonnet ahorrados

Decisión semanal:
- acceptance ≥70% y latency_p50 ≥500ms → **CONTINUE/EXPAND** (añadir más tools al whitelist)
- acceptance 50-70% → **TUNE** (mejorar prompt del predictor)
- acceptance <50% durante 2 semanas → **KILL** (mantener slice 0 lecciones, eliminar slices 1-4)

### Out of scope explícito

- **NO** speculative execution de tools con side effects (write, push, create).
- **NO** intentar emular speculative decoding sobre Claude API (decoder opaco).
- **NO** integrar EAGLE-3 / Medusa en savia-dual (ROI bajo, scope creep).
- **NO** modificar el court orchestrator ni tribunal — ya tienen paralelización pura.
- **NO** fine-tuning del predictor (solo prompt engineering).

## Acceptance criteria (pre-comprometidos, falsifiables)

- **AC-0** Slice 0 feasibility-probe ejecutado, output documentado, decisión GO/DEFERRED/ABORT registrada antes de Slice 1.
- **AC-1** `tool-predictor.sh` con bats tests: ≥10 tests verificando JSON schema, top-3 con scores, timeout 2s, exit codes 0/2.
- **AC-2** Whitelist parseable, hook valida que ninguna tool con side-effect entra en pre-execution. Test bats que intenta inyectar tool peligrosa y verifica que falla.
- **AC-3** `speculative-runner.sh` ejecuta en background con flock, no bloquea al orquestador, descarta resultados >30s antiguos. 15 tests bats.
- **AC-4** Telemetría JSONL append-only, sin pérdida de datos en concurrencia (test con 10 procesos paralelos).
- **AC-5** Skill pre-loading reduce p50 de "skill load + first read" en ≥30% medido sobre 20 invocaciones de `/sprint-status`.
- **AC-6** Dashboard `measure.sh` produce métricas en <2s sobre 7 días de logs. Acceptance rate calculado correctamente (verificado contra dataset etiquetado de 50 turnos).
- **AC-7** Sin regresión: tests existentes de comandos afectados (`/sprint-status`, `/pbi-decompose`, `/security-review`) siguen verdes.

## Verification method

```bash
# Slice 0 (feasibility)
bash scripts/speculative/feasibility-probe.sh --command /sprint-status --runs 20

# Slices 1-4
bats tests/speculative/test-tool-predictor.bats
bats tests/speculative/test-whitelist.bats
bats tests/speculative/test-runner.bats
bats tests/speculative/test-skill-preload.bats
bash scripts/speculative/measure.sh --days 7 --format markdown
```

## Riesgos identificados

| R | Riesgo | Mitigación |
|---|---|---|
| R1 | Predictor con alucinaciones genera tool calls peligrosas | Whitelist hardcodeada en Slice 1. Hook que falla si predictor emite tool no-listada. |
| R2 | Coste de haiku predictor > ahorro de tiempo en sonnet | Telemetría obligatoria de tokens-in vs tokens-saved. KILL automático si ratio <1.0. |
| R3 | Race conditions en speculative cache | flock + path con turn-id único + TTL 30s |
| R4 | Acceptance rate <60% en feasibility | ABORT explícito en Slice 0, no continuar |
| R5 | Drift entre prompt del predictor y comportamiento real del orquestador | Re-feasibility cada 60 días o tras cambio de modelo |
| R6 | Falsa sensación de speedup por confirmation bias | Mediciones contra baseline real con `hyperfine`, NO contra estimación |

## Diseño técnico (mínimo viable)

```
┌─────────────────────────────────────────────────────────────┐
│  Turno t: usuario pide "/sprint-status"                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
       ┌─────────────────────────────┐
       │ Orquestador principal        │
       │ (claude-sonnet/opus)         │
       │ Latencia: ~2s think          │
       └──────┬───────────────────────┘
              │ async fork
              ▼
       ┌─────────────────────────────┐
       │ tool-predictor.sh            │
       │ (claude-haiku, ~300ms)       │
       │ Predice: [wiql, capacity]    │
       └──────┬───────────────────────┘
              │
              ▼
       ┌─────────────────────────────┐
       │ Whitelist filter             │
       │ ✓ wiql safe                  │
       │ ✓ capacity safe              │
       └──────┬───────────────────────┘
              │
              ▼
       ┌─────────────────────────────┐
       │ speculative-runner.sh        │
       │ Ejecuta en background        │
       │ Resultados → /tmp/spec-cache │
       └──────┬───────────────────────┘
              │ (paralelo al orquestador)
              ▼
       Orquestador emite real tool call
              │
              ▼
       hook check spec-cache
       Hit → return cached (saved ~800ms)
       Miss → ejecuta normal (no penalty)
```

## Decisión de adopción

**MERGE si TODOS**:
- AC-0 verde con acceptance rate ≥60%
- AC-1, AC-2, AC-3, AC-4 verdes
- AC-7 sin regresión
- Telemetría real (no estimada) demuestra latency_p50 ahorrada ≥400ms en /sprint-status
- Code review humano (Rule #8)

**DO NOT MERGE si**:
- Slice 0 ABORT (acceptance <40%)
- Tokens haiku consumidos > tokens sonnet ahorrados (coste neto positivo)
- Falsos positivos ejecutan tools con side effects (cualquier ocurrencia = STOP)
- Tests rojos

**KILL post-merge si** (4 semanas observación):
- acceptance_rate <50% sostenido
- cost ratio >1.0 sostenido

## Cross-references

- `output/research/speculative-decoding-20260620.md` — investigación completa, matriz V×U/E
- `docs/propuestas/SPEC-154-priorizacion-vue.md` — fórmula aplicada
- `docs/propuestas/SE-202-agent-hooks.md` — base conceptual del hook semántico
- `docs/propuestas/SE-217-autoresearch-patterns.md` — time-budget pattern (Slice 3)
- `docs/rules/domain/prompt-caching.md` — speculative funcional ya en producción
- `docs/rules/domain/autonomous-safety.md` — Rule #8, gates innegociables
- `docs/learning/biomimetic-investigation-protocol.md` — disciplina pre-flight (aplica aquí)

## Notas honestas

1. **No es speculative decoding clásico**. Es el principio draft+verify aplicado a otra capa. Llamarlo "speculative" puede confundir; alternativa: "predictive tool prefetch".
2. **Coste no nulo**: cada predictor call cuesta tokens haiku. Si acceptance es bajo, perdemos dinero acelerando.
3. **No sustituye a la paralelización pura** (court, tribunal). Es complementario.
4. **No aplica a comandos cortos**: si el flow total son 2 tool calls, no hay margen para speculative.
5. Mejor candidato: comandos largos y predecibles (`/sprint-status`, `/weekly-report`, `/executive-reporting`, `/project-update`).
