---
spec_id: SPEC-154
title: Fórmula canónica de priorización (V×U/E) — 4 campos persistidos en specs, PBIs, ToDos y debt
status: PROPOSED
origin: Conversación 2026-05-23. La filosofía "Prioridad = (Valor × Urgencia) / Esfuerzo" debe ser la función pura, auditable y contrafactual que gobierna toda decisión de priorización en Savia (humanos + agentes). Hoy `/backlog-prioritize` usa RICE/WSJF, `/debt-prioritize` usa scoring ad-hoc, el ROADMAP cita la fórmula sin definirla, y otros 30+ comandos inventan su propia escala. **Decisión 2026-05-23**: persistir los 4 campos (value, urgency, effort, priority_score) en TODO work item de Savia — specs, PBIs, Tasks, ToDos, debt. Sin persistencia, la fórmula colapsa entre sesiones.
severity: Alta — sin formula canónica + persistencia, los agentes alucinan su propia escala. Y sin los 4 campos visibles en frontmatter/work item, la decisión NO es auditable (Rule #24).
effort: ~24h (L) — librería scoring (3h) + adapters (2h) + extensión frontmatter (2h) + backfill specs (3h) + Azure DevOps fields (3h) + ToDos+debt persistence (2h) + 3 comandos piloto (3h) + tests (3h) + docs (3h).
priority: P3 — fundacional. Habilita confianza en cualquier output de agente que tenga que elegir entre N tareas.
value: 85
urgency: 60
effort_score: 65
priority_score: 78.5
confidence: alta — la fórmula ya está validada por la usuaria como filosofía operativa; la implementación es ingeniería estándar (función pura + JSON contract + adapters + frontmatter extension).
bucket: Q2 2026
related_specs:
  - SPEC-128 (Obsidian Context-as-Code — V/U/E necesitan contexto compartido)
  - SPEC-125 (Spec lifecycle — el frontmatter `priority`+`effort` se extiende a 4 campos)
  - SE-092 (PM-BACKEND — el bridge a Azure DevOps debe emitir V/U/E desde work items)
  - SPEC-147 (decision-trees — algunos árboles ya delegan en "qué es más prioritario", ahora con contrato)
  - SE-013 (dual estimation — agent-actuals.jsonl alimenta refinamiento de effort)
---

# SPEC-154 — Fórmula canónica V×U/E + persistencia 4-campos

## Why

Hay una contradicción operativa en Savia hoy:

- El **ROADMAP.md** (reescrito 2026-05-23) afirma en §3 que las specs van "ordenadas por valor × urgencia / esfuerzo" — pero **no define** cómo se compone cada variable, ni dónde se guardan los valores.
- **`/backlog-prioritize`** computa RICE o WSJF y emite un score que **se pierde tras la sesión**. La próxima invocación re-estima desde cero.
- Los **agentes** toman decisiones de tipo "qué hacer primero" sin contrato compartido. Cuando un agente devuelve "te recomiendo empezar por X", no hay traza de **por qué X y no Y** ni continuidad entre sesiones.
- **72 specs** en el ROADMAP están en `needs-triage` precisamente porque carecen de `priority` + `effort`. La fórmula amplía esto a 4 campos requeridos.

Aplicar la filosofía declarada exige tres cosas concretas:

1. **Una función pura** — input: `{value, urgency, effort, context}` con escalas explícitas; output: score + decision trail. Mismo input ⇒ mismo output.
2. **Persistencia de los 4 campos** en TODO artefacto de trabajo de Savia (specs, PBIs, Tasks, ToDos, debt). Sin persistencia, la fórmula colapsa entre sesiones.
3. **DECISION trail obligatorio**: cada comando que prioriza N items emite `(value, urgency, effort, priority_score)` + razón. Esto cumple Rule #24: la usuaria puede preguntar "¿por qué X antes que Y?" y obtener evidencia.

Subestimar esfuerzo es el sesgo más común (lo dice la filosofía). Por eso `effort` debe incluir **coste humano de revisión**, no solo tiempo de implementación.

## Scope

### IN-Scope (6 slices)

#### Slice 1 — Función pura + contrato JSON (3h)

`scripts/priority/score.py`:

```python
def score(item: PriorityInput) -> PriorityOutput:
    """
    Prioridad canónica V×U/E.
    Args:
        item.value:   1-100 (impacto absoluto, escala en priority-canonical-formula.md)
        item.urgency: 1-100 (pendiente de degradación temporal, NO ansiedad)
        item.effort:  PriorityEffort {
            tokens: int,
            human_review_hours: float,
            regression_risk: 1-5,
            cognitive_complexity: 1-5
        }
    Returns:
        PriorityOutput {
            priority_score: float,       # = (value * urgency) / effort_normalized
            value: 1-100,
            urgency: 1-100,
            effort_normalized: 1-100,    # composición ponderada de los 4 sub-factores
            decision_trail: str,         # 1-3 frases en lenguaje natural
            counterfactual: str          # qué tarea reemplaza si se elige ésta
        }
    """
```

Schema JSON en `docs/schemas/priority-v1.json`. Versionado.

#### Slice 2 — Extensión de frontmatter de specs + backfill (5h)

**Nueva regla**: todo fichero en `docs/propuestas/SPEC-*.md` y `SE-*.md` debe llevar en frontmatter **4 campos obligatorios** además de los existentes:

```yaml
value: 78           # 1-100 — impacto absoluto
urgency: 92         # 1-100 — pendiente de degradación temporal
effort_score: 35    # 1-100 — esfuerzo normalizado (de los 4 sub-factores)
priority_score: 205.4   # = (value * urgency) / effort_score — calculado, no manual
```

- **Compatibilidad**: los campos `priority` (P0..P13/alta/media/baja) y `effort` (~Nh / S/M/L) actuales se **mantienen** como narrativa legible. Los 4 nuevos son numéricos y los consume la fórmula.
- **Validación**: hook + script `scripts/validate-spec-frontmatter.sh` falla si una spec tiene los 4 campos inconsistentes (priority_score ≠ value×urgency/effort_score con tolerancia ±5%).
- **Backfill (3h del slice)**: script `scripts/priority/backfill-specs.py` que:
  1. Lee los 32 specs con `priority` + `effort` actuales y mapea a `value`, `urgency`, `effort_score` con heurística declarada (no inventa — usa tabla en `priority-canonical-formula.md`).
  2. Marca como `needs-triage: true` las 72 specs sin metadata (no inventa números).
  3. Para las 78 IMPLEMENTED, marca `archived: true` (no participan en ranking activo).
  4. Genera reporte `output/priority-backfill-{fecha}.md` con qué specs se mapearon, cuáles quedaron pendientes y por qué.

#### Slice 3 — Adapters RICE / WSJF / ad-hoc (3h)

`scripts/priority/adapters/`:

- `rice_to_vue.py`: `(reach, impact, confidence) → value`; `effort_pbi → effort.human_review_hours + tokens`.
- `wsjf_to_vue.py`: `(business_value, time_criticality, risk) → value + urgency`; `job_size → effort`.
- `adhoc_to_vue.py`: heurística para high/medium/low + warning si confidence < 0.6.

`/backlog-prioritize` sigue funcionando igual; internamente llama al adapter y emite además los 4 campos V/U/E/score como columnas adicionales.

#### Slice 4 — Persistencia en Azure DevOps + ToDos + debt (5h)

**Azure DevOps (3h)**:

- Configurar 4 custom fields en el process template:
  - `Custom.SaviaValue` (Integer 1-100)
  - `Custom.SaviaUrgency` (Integer 1-100)
  - `Custom.SaviaEffortScore` (Integer 1-100)
  - `Custom.SaviaPriorityScore` (Double, calculado)
- `Custom.SaviaPriorityScore` es read-only para humanos — solo lo escribe `scripts/priority/score.py` vía API.
- Script `scripts/priority/sync-ado.py` que para cada work item activo: lee V/U/E del frontmatter o de la PR linkada, computa score, escribe los 4 campos en ADO.
- **Fallback** si custom fields no están disponibles: usar campos estándar (Priority + Effort + tag `urgency:N`) con warning explícito.

**ToDos (1h)**:

- `TodoWrite` tool acepta opcionalmente `value`, `urgency`, `effort` por item. Si presentes, computa `priority_score` y lo añade al objeto.
- Si ausentes, el item queda como "ad-hoc" sin score — auditable.

**Debt items (1h)**:

- `/debt-track` y `/debt-prioritize` usan los 4 campos. Backfill de debt items existentes con valores por defecto (`value=50, urgency=30`) + warning visible "estos son placeholders".

#### Slice 5 — 3 comandos piloto + ROADMAP (3h)

1. **`/backlog-prioritize`** — columna "Decision Trail" + counterfactual + 4 columnas V/U/E/score.
2. **`scripts/roadmap-rebuild.sh`** — lee frontmatter de todas las specs vivas, llama `score.py`, ordena §3 del ROADMAP por `priority_score` descendente, emite trail por spec.
3. **`/debt-prioritize`** — sustituye scoring ad-hoc por V/U/E. Output JSON en `output/priority-decisions/debt-prioritize-{fecha}.json`.

#### Slice 6 — Tests + docs + regla canónica (5h)

- **BATS suite** `tests/test-priority-formula.bats`:
  - Función pura: mismo input ⇒ mismo output (idempotencia).
  - Counterfactual: cambiar effort de 1 item ⇒ recomputar score y trail.
  - Adapter RICE vs V/U/E directo: correlación Spearman > 0.8 en backlog real.
  - Frontmatter validation: spec con `priority_score` inconsistente falla validación.
  - Backfill idempotente: ejecutar 2 veces no cambia outputs.
  - AC-07: items sin V/U/E declarados emiten `BLOCKED: missing {field}` y NO se rankean.
- **`docs/rules/domain/priority-canonical-formula.md`** (≤150L, Rule #11):
  - Escalas explícitas value 1-100 con ejemplos (qué es 50, qué es 95).
  - Escala urgency con árbol de decisión (no es ansiedad).
  - Componentes de effort (los 4 sub-factores con peso).
  - Cuándo NO usar la fórmula.
  - Anti-patterns: alucinación de escala, gaming (inflar value).
- **`docs/rules/domain/priority-persistence.md`** (≤150L):
  - Contrato de los 4 campos en frontmatter, ADO, ToDos, debt.
  - Política de backfill (qué inventar, qué dejar como needs-triage).
- **Actualizar ROADMAP.md** §3.1: columna `priority_score` calculado, no inferido.

### OUT-of-scope (declarado explícitamente)

- **NO** migrar los 30+ comandos en una sola spec. Slice 6 documenta la regla; cada comando se migra cuando se toque por otra razón.
- **NO** reemplazar RICE/WSJF — son adapters, no sustitutos.
- **NO** resolver "subestimar effort" — eso es SE-013 (dual estimation).
- **NO** sincronización bidireccional ADO ⇄ frontmatter en esta spec (futura SPEC).
- **NO** integración con Obsidian/Context-as-Code (eso es SPEC-128).

## Acceptance Criteria

- **AC-01** `scripts/priority/score.py` es función pura: 100 invocaciones con mismo input ⇒ mismo score.
- **AC-02** Toda spec en `docs/propuestas/` con `status: PROPOSED|ACCEPTED|APPROVED|DRAFT|IN_PROGRESS` tiene los 4 campos `value`/`urgency`/`effort_score`/`priority_score` en frontmatter O un flag `needs-triage: true`. **No hay tercer estado** (sin metadata + sin needs-triage = error de CI).
- **AC-03** `priority_score` en frontmatter SIEMPRE = `(value * urgency) / effort_score` con tolerancia ±5% (validado por hook + CI).
- **AC-04** Adapter RICE: ranking RICE vs V/U/E tiene correlación Spearman > 0.8.
- **AC-05** Cada output de los 3 comandos piloto incluye `decision_trail` no vacío para CADA item priorizado.
- **AC-06** Cada output incluye `counterfactual` para el top-3.
- **AC-07** Items sin V/U/E declarados emiten `BLOCKED: missing {field}` y se excluyen del ranking — NO se inventan valores. Radical Honesty.
- **AC-08** ROADMAP §3 muestra columna `priority_score` explícita por spec.
- **AC-09** Azure DevOps custom fields configurados (o fallback documentado) y `sync-ado.py` ejecuta sin errores en un work item de prueba.
- **AC-10** `TodoWrite` acepta los 4 campos opcionales; si presentes, computa score; si ausentes, marca "ad-hoc".
- **AC-11** Backfill script genera reporte que clasifica las 154 specs vivas (78 archived + 32 mapeadas + 72 needs-triage + las nuevas IN_PROGRESS) sin inventar números.
- **AC-12** Regla canónica `priority-canonical-formula.md` ≤150 líneas, define escalas con ejemplos concretos.

## Risks & Mitigations

| Riesgo | Mitigación |
|---|---|
| **Gaming**: inflar `value` para que tareas suban | Decision trail obligatorio + counterfactual hacen visible la inflación. Code review humano detecta. AC-07 bloquea items sin justificación. |
| **Backfill inventa números** para las 72 needs-triage | AC-11 + AC-07: backfill NUNCA inventa. Marca como needs-triage explícito. Honest > complete. |
| **Drift entre frontmatter y ADO** custom fields | Slice 4 declara fuente de verdad por tipo de artefacto: specs → frontmatter, work items → ADO. `sync-ado.py` propaga frontmatter → ADO, NO al revés (en esta spec). |
| **Sub-estimación de effort** | `effort` no es un número, son 4 sub-factores. Imposible olvidar `human_review_hours` porque es campo requerido (AC-03). |
| **Sobrecarga cognitiva**: pedir V/U/E a humanos | Adapter `adhoc_to_vue.py` acepta high/medium/low y los mapea con confidence < 1.0 + warning. ToDos casuales no requieren los 4 campos. |
| **Custom fields ADO** pueden no estar disponibles | Fallback documentado: campos estándar Priority+Effort + tag `urgency:N`. Warning explícito al usuario. |
| **Migración de 30+ comandos** queda colgando | Declarado OUT-of-scope. Migración incremental. |
| **Ranking RICE vs V/U/E diverge >30%** | AC-04 establece umbral Spearman > 0.8. Stop condition. |
| **Backfill rompe specs existentes** | Backfill SOLO añade campos, nunca modifica los existentes (`priority`, `effort` narrativos se preservan). |

## Implementation Plan

### Files to create

```
scripts/priority/
├── score.py                          # función pura (Slice 1)
├── backfill-specs.py                 # Slice 2 — backfill frontmatter
├── sync-ado.py                       # Slice 4 — Azure DevOps custom fields
├── validate-spec-frontmatter.sh      # Slice 2 — validador CI
├── adapters/
│   ├── rice_to_vue.py                # Slice 3
│   ├── wsjf_to_vue.py                # Slice 3
│   └── adhoc_to_vue.py               # Slice 3
└── __init__.py

docs/schemas/priority-v1.json         # Slice 1
docs/rules/domain/priority-canonical-formula.md  # Slice 6 — ≤150L
docs/rules/domain/priority-persistence.md         # Slice 6 — ≤150L
tests/test-priority-formula.bats      # Slice 6
output/priority-decisions/.gitkeep    # Slice 5
output/priority-backfill-{fecha}.md   # Slice 2 — generado por backfill
scripts/roadmap-rebuild.sh            # Slice 5 — nuevo (o evolución del actual)
```

### Files to modify

```
.claude/commands/backlog-prioritize.md   # Slice 5 — output V/U/E/score
.opencode/commands/backlog-prioritize.md # idem (mirror)
.claude/commands/debt-prioritize.md      # Slice 5 — sustituye scoring ad-hoc
.opencode/commands/debt-prioritize.md    # idem
docs/propuestas/ROADMAP.md               # Slice 5 — §3 con priority_score
docs/propuestas/SPEC-*.md                # Slice 2 — backfill frontmatter (154 ficheros, automático)
docs/propuestas/SE-*.md                  # Slice 2 — idem
```

### Stop conditions (Radical Honesty)

- Si en Slice 3 el adapter RICE→V/U/E **no logra correlación > 0.7** en muestra de backlog real, **STOP** y recalibrar escalas o abandonar (REJECTED honesto > IMPLEMENTED inservible).
- Si en Slice 2 el backfill no consigue mapear ≥80% de las 32 specs con `priority`+`effort` actuales (las que tienen metadata declarada), **STOP** — significa que la heurística es mala.
- Si Slice 4 detecta que ADO no permite los 4 custom fields y el fallback no es viable, declarar Slice 4 parcial (ADO=opt-in, ToDos+debt OK) y documentar.

## Open Questions

- **OQ-1** ¿`effort.tokens` se mide en tokens reales (post-implementación) o estimados (pre)? Propuesta: estimado en pre, real en post para `data/agent-actuals.jsonl` (SE-013).
- **OQ-2** ¿La fórmula respeta `priority: P0/CRITICAL` o lo reconvierte a V/U/E? Propuesta: P0/CRITICAL pin a `value=100, urgency=100` automáticamente.
- **OQ-3** Adaptar también `/sprint-plan` en Slice 5? Es el comando con más impacto operativo. Decidir en planning.
- **OQ-4** ¿Los 78 specs IMPLEMENTED necesitan los 4 campos retroactivos para analítica histórica? Propuesta: NO en esta spec — marcar `archived: true` y no participan en ranking activo. Análisis histórico requiere SPEC separada.
- **OQ-5** ¿Qué hacer con specs sin frontmatter (algunos `investigacion-*.md`)? Propuesta: excluirlas del scope (no son work items priorizables).
- **OQ-6** ¿Los ToDos efímeros de sesión (TodoWrite) deben persistir score post-sesión? Propuesta: NO — son efímeros por diseño. Si se promueven a Task/PBI, ahí sí se persiste.

## Definition of Done

- AC-01..AC-12 verdes en CI.
- ROADMAP §3 visualmente mejorado con `priority_score` explícito por spec.
- 154 specs vivas clasificadas en {scored, archived, needs-triage} sin inventos.
- 3 comandos piloto emiten DECISION trail con los 4 campos.
- Azure DevOps custom fields operativos (o fallback documentado).
- Documentos canónicos publicados en `docs/rules/domain/` (formula + persistence).
- Working session real (≥1 sprint planning) usa la fórmula y produce decisión trazable.
- PR pendiente de revisión humana (autonomous-safety): SIEMPRE Draft, AUTONOMOUS_REVIEWER asignado.

## Self-Application

Esta spec **se aplica a sí misma**: su frontmatter incluye los 4 campos:

- `value: 85` — habilita auditabilidad de TODA decisión de priorización en Savia, fundacional.
- `urgency: 60` — no es deadline-driven; la deuda crece linealmente con cada sesión sin formula canónica, pero no hay degradación catastrófica.
- `effort_score: 65` — L (~24h), 6 slices, riesgo bajo-medio (función pura + frontmatter extension son ingeniería estándar; ADO custom fields es lo más arriesgado por dependencia externa).
- `priority_score: 78.5` — `(85 * 60) / 65 = 78.46`. Top-tier pero no #1 (SE-092 PM-BACKEND y SE-093 ZERO-LEAK probablemente la superan).

Esto es la prueba de honestidad: si la spec dijera `priority_score: 95` sin justificación, sería gaming. Los 4 campos hacen imposible esconder.

## References

- ROADMAP.md §3 (orden actual implícito V×U/E sin definición)
- `.claude/commands/backlog-prioritize.md` (RICE/WSJF actual)
- `.claude/commands/debt-prioritize.md` (scoring ad-hoc actual)
- `docs/rules/domain/radical-honesty.md` (Rule #24 — decisión auditable)
- `data/agent-actuals.jsonl` (SE-013 — actuals para refinar effort)
- Filosofía canónica: conversación 2026-05-23 con usuaria (registrada como `origin`).
