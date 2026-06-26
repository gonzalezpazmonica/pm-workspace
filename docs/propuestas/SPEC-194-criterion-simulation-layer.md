---
status: IMPLEMENTED
implemented_at: "2026-06-24"
resource: internal://docs/propuestas/SPEC-194-criterion-simulation-layer.md
timeline:
  - from: "2026-06-24"
    learned: "2026-06-24"
    value: "IMPLEMENTED"
    source: "session:2026-06-24"
---
# SPEC-194 — Criterion Simulation Layer

> **Priority:** P0 · **Estimate (human):** 5-7d · **Estimate (agent):** 6-9h · **Category:** novel · **Type:** governance-infrastructure

> **Dual estimate**: 5-7 dias humano end-to-end (definicion del modelo de operator state, heuristicas de trigger, juez meta-reflexivo, integracion con tribunales existentes, tests, validacion empirica). 6-9h agente con pipeline supervisado. Categoria novel: no hay patron previo que copiar; el componente meta-reflexivo es nuevo en la arquitectura.

## Objective

Existe un limite estructural en cualquier sistema agentico actual: el agente puede ejecutar el ciclo idea -> aplicacion -> revision, pero NO puede dudar del frame de la idea. Solo evalua si la aplicacion fue correcta DADA la idea. La revision es otra aplicacion del criterio preexistente, no una reflexion sobre si el criterio mismo es correcto.

> Cita textual de la usuaria (2026-06-13):
> "Un humano, en la fase de revision, puede concluir que el problema no estaba en la ejecucion sino en la idea original. Puede dudar de la pregunta, no solo de la respuesta. Un agente, sin ese meta-nivel disenado, revisara la aplicacion pero no cuestionara la idea. Optimizara dentro del marco. No transformara el marco. Se delega la ejecucion, no el criterio. Cuando el humano no mantiene el suyo, el sistema no cierra el loop. Lo simula."

Esta spec acepta esa limitacion y la aborda **explicitamente como simulacion**, no como sustituto de criterio humano. Anade una capa que se activa cuando el riesgo de criterio humano relajado es alto y, antes de aplicar la idea, ejecuta cuatro preguntas meta-reflexivas que el humano se haria si tuviera energia y distancia para hacerlo. El output es un challenge visible al humano que NO bloquea automatico — fuerza al humano a reafirmar el frame conscientemente.

Trade-off honesto: esto NO es criterio real. Un LLM no tiene criterio. Es heuristica de pausa. Mas caro en tokens. No siempre acierta. Tiene falsos positivos sobre tareas legitimas. La spec declara esto desde el primer parrafo del banner que emite: "soy una simulacion de meta-reflexion, no tu criterio".

## Principles affected

- **#3 Humans decide** — La capa NO bloquea. Emite challenge. La decision final sigue siendo del humano. Lo que cambia: el humano se ve forzado a reafirmar conscientemente.
- **#5 Truth as common good** — Reconocer la limitacion (no es criterio real, es simulacion) es parte de la verdad sobre el sistema.
- **#9 Disarm words** — El banner usa lenguaje plano sin promesas exageradas: "esta idea podria estar mal planteada" no "esta idea esta mal".
- **Linea Roja L4** (autonomia destructiva) — Nunca bloquea autonoma; solo interpela.
- **Genesis B9 GOAL STEWARD + B8 ATTENTION ANCHOR** — Esta spec es la implementacion mas directa de B9 (cuestionar el proposito, no solo ejecutarlo).

NO contradice `radical-honesty.md` (Rule #24): la honestidad sobre la limitacion es parte del diseno. NO contradice `autonomous-safety.md`: no hay autonomia destructiva, solo interrupcion del flujo.

## Design

### Overview

```
[task arrives: spec, PR plan, code change request]
     |
     v
[trigger evaluator: should criterion-simulation activate?]
     | high-impact task? recent revert pattern? operator-state signals?
     | yes -> proceed; no -> bypass (telemetry only)
     v
[criterion-simulation-judge: 4 meta-questions]
     | Q1 frame challenge: la idea responde al problema real?
     | Q2 historical priors: tareas similares fracasaron por frame?
     | Q3 operator state: fatiga / presion / hora atipica / overrides?
     | Q4 alternative reframing: existe tarea mas simple que resuelva igual?
     v
[verdict: FRAME_OK | FRAME_DOUBT | FRAME_REJECT]
     | FRAME_OK: continua silencioso, telemetria.
     | FRAME_DOUBT: emite challenge banner. NO bloquea.
     | FRAME_REJECT: emite challenge mas fuerte. NO bloquea.
     v
[human decides: confirma frame o lo redefine]
     | si confirma: registra reaffirmation con timestamp + razon (>=20 chars)
     | si redefine: registra reframe + diff de tarea
     v
[task ejecuta con frame confirmado/redefinido]
```

### Components

| # | Name | Kind | Purpose |
|---|------|------|---------|
| 1 | `scripts/criterion-simulation/trigger-evaluator.py` | py script | Decide si activar la capa basado en operator-state signals |
| 2 | `scripts/criterion-simulation/operator-state-signals.py` | py script | Calcula score de operator state (fatigue, pressure, time, override-rate) |
| 3 | `.opencode/agents/criterion-simulation-judge.md` | LLM judge (heavy model) | Ejecuta las 4 meta-preguntas. Output: verdict + razonamiento. |
| 4 | `.opencode/hooks/criterion-simulation-challenge.sh` | hook (pre-task / pre-spec-implement) | Activa el judge si trigger; emite challenge banner si verdict != FRAME_OK |
| 5 | `scripts/criterion-simulation/historical-priors.py` | py script | Busca en KG y memory tareas similares revertidas o fracasadas |
| 6 | `scripts/criterion-simulation/reaffirmation-log.py` | py script | Registra confirmaciones humanas con timestamp + razon |
| 7 | `output/criterion-simulation/` | dir | Logs de challenges + reaffirmations + reframes |
| 8 | `docs/rules/domain/criterion-simulation-honesty.md` | rule | Declara explicitamente que NO es criterio real, es simulacion |
| 9 | `.opencode/skills/meta-reflection/SKILL.md` | skill | Protocolo que el LLM carga para ejecutar las 4 meta-preguntas |
| 10 | `.opencode/skills/meta-reflection/DOMAIN.md` | skill domain | Knowledge: como diferenciar evaluacion vs reflexion |
| 11 | KG schema extension | sql | Anade tabla `frame_reaffirmations` (task_id, ts, operator, reason, verdict_before) |

### Contracts

#### Trigger evaluator

```python
# trigger-evaluator.py
def should_activate(task_context: dict) -> dict:
    """Returns {activate: bool, reason: str, score: int 0-100}.

    Activates if score >= TRIGGER_THRESHOLD (default 50).
    """
    score = 0
    reasons = []

    # High-impact signals
    if task_context.get("touches_production"):       score += 25; reasons.append("production")
    if task_context.get("touches_security"):         score += 30; reasons.append("security")
    if task_context.get("touches_human_safety"):     score += 50; reasons.append("safety")
    if task_context.get("estimated_hours") > 16:     score += 15; reasons.append("large")

    # Operator state signals (from operator-state-signals.py)
    state = compute_operator_state(task_context["operator"])
    score += state["fatigue_score"] * 0.3       # 0-30
    score += state["pressure_score"] * 0.2      # 0-20
    score += state["override_rate"] * 0.2       # 0-20

    # Historical priors
    priors = recent_failed_frames(task_context, lookback_days=90)
    if priors["count"] >= 2: score += 20; reasons.append(f"{priors['count']} similar reverts")

    return {
        "activate": score >= TRIGGER_THRESHOLD,
        "score": min(100, score),
        "reasons": reasons,
        "operator_state": state,
        "priors": priors,
    }
```

#### Operator state signals

```python
# operator-state-signals.py
def compute_operator_state(operator_id: str) -> dict:
    """Computes operator-state signals from local data.

    Reads:
    - Last N commits by operator (timestamps, frequency, gaps)
    - Last N reviews / approvals (override-rate)
    - Current time of day (fatigue heuristic by hour band)
    - Calendar pressure if available (~/.savia/preferences.yaml deadline_proximity)

    Privacy: all data is local. NO external service queried.

    Returns {fatigue_score, pressure_score, override_rate, time_band}.
    """
```

Honesto: estas heuristicas son groseras. Hora del dia no es prueba de fatiga real. Tasa de override puede ser legitimamente alta. La capa puede dispararse por motivos malos. Eso esta documentado en la regla de honestidad asociada.

#### Criterion simulation judge

```yaml
# criterion-simulation-judge.md
input:
  task_context: { spec_path, pr_url, problem_statement, proposed_solution }
  operator_state: { fatigue, pressure, override_rate, time_band }
  historical_priors: { similar_failed_frames: [...] }

output:
  verdict: FRAME_OK | FRAME_DOUBT | FRAME_REJECT
  meta_questions:
    Q1_frame_challenge: { passed: bool, reasoning: str }
    Q2_historical_priors: { passed: bool, reasoning: str, cited_priors: [str] }
    Q3_operator_state: { passed: bool, reasoning: str, mitigation: str }
    Q4_alternative_reframing: { proposed_reframe: str | null, would_solve: bool }
  banner_text: str   # what to show the human
  confidence: 0.0-1.0
  is_simulation_disclaimer: "I am a meta-reflection simulation, not your judgment."
```

Las 4 meta-preguntas operacionalmente:

**Q1 frame challenge**: dado el problem_statement, leer la spec/PR y verificar si la solucion propuesta responde al problema declarado o a uno parecido pero distinto. Tipica falla: spec resuelve "como X" cuando el problema real es "deberiamos X?".

**Q2 historical priors**: buscar en KG / memory tareas etiquetadas con label similar (touches mismos modulos, mismas categorias de cambio). Si hay >=2 reverts en 90d, citar los IDs y resumir por que se revirtieron. NO bloquea, informa.

**Q3 operator state**: si el operador tiene fatigue alto / hora atipica / override-rate alto, mencionarlo. Banner: "tu firmaste 5 specs en las ultimas 2 horas. Esta es la sexta. Las dos anteriores fueron revertidas por @X. Quieres reafirmar el frame de esta?".

**Q4 alternative reframing**: el modelo propone (cuando puede) una formulacion alternativa: "el problema declarado es A. Una alternativa seria B, que requiere menos cambio y resuelve el subproblema critico. Quieres considerarla?".

Confidence calibration: el modelo NO tiene criterio. La confidence es una estimacion de cuan robusto es su analisis (cuantas senales convergen, cuanta evidencia historica), no de cuan correcto es. Documentado.

#### Hook integration

```bash
# criterion-simulation-challenge.sh — pre-task / pre-spec-implement
INPUT=$(cat)
TASK_CTX=$(extract_task_context "$INPUT")

TRIGGER=$(python3 scripts/criterion-simulation/trigger-evaluator.py --task "$TASK_CTX")
ACTIVATE=$(echo "$TRIGGER" | jq -r '.activate')

if [[ "$ACTIVATE" != "true" ]]; then
  log_telemetry "BYPASS_LOW_SCORE"
  exit 0
fi

# Run judge
VERDICT=$(invoke_agent criterion-simulation-judge --task "$TASK_CTX" --operator-state "$TRIGGER")
DECISION=$(echo "$VERDICT" | jq -r '.verdict')

case "$DECISION" in
  FRAME_OK)
    log_telemetry "FRAME_OK_PASS"
    exit 0
    ;;
  FRAME_DOUBT|FRAME_REJECT)
    log_telemetry "$DECISION"
    cat >&2 <<EOF

[criterion-simulation SPEC-194]
DISCLAIMER: I am a meta-reflection simulation, not your judgment.
This is a heuristic interruption when operator-state signals are high.

$(echo "$VERDICT" | jq -r '.banner_text')

ACTION: reaffirm the frame consciously OR redefine the task.
  bash scripts/criterion-simulation/reaffirmation-log.py reaffirm \
       --task <id> --reason "<>=20 chars why this frame is correct>"
  bash scripts/criterion-simulation/reaffirmation-log.py reframe \
       --task <id> --new-statement "<new problem statement>"

Bypass: SAVIA_CRITERION_SIMULATION=off
EOF
    # NO blocking. Just visible challenge.
    exit 0
    ;;
esac
```

Crucial: **exit 0 siempre**. La capa nunca bloquea. Solo interrumpe visualmente.

### Configuration

```bash
# Master switch
SAVIA_CRITERION_SIMULATION=on|off                    # default off (opt-in inicial)

# Trigger
SAVIA_CS_TRIGGER_THRESHOLD=50                        # 0-100; menor = mas activaciones
SAVIA_CS_LOOKBACK_DAYS=90                            # ventana para historical priors

# Judge model
SAVIA_CS_JUDGE_MODEL=heavy                           # heavy por default; meta-reflexion es costosa

# Operator state
SAVIA_CS_OPERATOR_DATA=local                         # local | none (privacidad)
SAVIA_CS_FATIGUE_HOUR_BAND="22:00-06:00"             # horas consideradas atipicas

# Telemetria
SAVIA_CS_LOG=output/criterion-simulation/events.jsonl

# Modes individuales
SAVIA_CS_MODE=shadow|advise|interrupt                # default advise
# shadow: telemetria solamente
# advise: emite banner pero sin bloquear ni requerir reaffirmation
# interrupt: emite banner Y registra reaffirmation requerida (NO bloquea ejecucion, pero el log queda)
```

### Lo que NO hace esta spec (importante)

- **NO genera criterio**. Solo activa heuristicas que un humano competente con tiempo activaria solo.
- **NO bloquea ejecucion**. Es visualmente intrusivo pero el humano sigue decidiendo.
- **NO sustituye revision humana de PRs**. Es ANTERIOR: cuestiona el frame antes de la aplicacion.
- **NO juzga personas**. operator-state es signal del momento, no del operador en general.
- **NO se activa en tareas normales**. Trigger threshold conservador. Bypass facil.

### Limitaciones honestas

1. **No es criterio real, es heuristica**. El sistema no piensa. La spec lo declara desde el primer mensaje al humano.
2. **Falsos positivos esperados**. Tareas legitimas con score alto activaran la capa. El coste: ~30 segundos del humano confirmando. El beneficio: 1 de cada N veces, el humano se da cuenta de que efectivamente no estaba pensando.
3. **Operator-state heuristicas son crudas**. Hora del dia, frecuencia de commits, override-rate son proxies. No miden cansancio real. La calibracion solo sera buena con telemetria de meses.
4. **Coste en tokens significativo**. Heavy model + 4 meta-preguntas + busqueda en KG. ~15-25K tokens por activacion. Por eso threshold conservador.
5. **Privacy concerns sobre operator-state**. La spec exige `SAVIA_CS_OPERATOR_DATA=local` por defecto. No se envia a ningun lugar externo. Datos eliminables.
6. **Tipologia de problemas que NO atrapa**: errores ejecutivos (eso lo cubre el tribunal). Problemas de timing puro. Politica organizacional. La capa SOLO ataca el slot "frame de la idea".

## Acceptance criteria

1. **Disclaimer visible siempre**: cualquier challenge banner contiene la frase "simulacion de meta-reflexion, no tu criterio". Verificado por bats.
2. **Exit 0 siempre**: en los 3 verdicts (FRAME_OK, FRAME_DOUBT, FRAME_REJECT), el hook devuelve exit 0 — nunca bloquea. Verificado por bats.
3. **Trigger conservador**: en 50 task-contexts sinteticos representativos del workspace, el activador dispara en <= 20%. Verificado por pytest con dataset.
4. **Trigger detecta high-impact**: en 10 task-contexts con `touches_security=true` o `touches_human_safety=true`, dispara en >= 8/10. Verificado por pytest.
5. **Operator-state signals son locales**: `operator-state-signals.py` no realiza llamadas de red. Verificado por test que mocka socket y falla si se usa.
6. **Q2 historical priors funciona**: dado un KG con 3 reverts etiquetados similar, el judge cita >= 2 en el output. Verificado por pytest sintetico con KG temporal.
7. **Reaffirmation se registra con razon obligatoria >= 20 chars**: `reaffirmation-log.py reaffirm --reason "x"` (3 chars) -> rechazo + exit 2. Verificado por bats.
8. **Reframe se registra con new-statement obligatorio**: similar al anterior, --new-statement requerido. Verificado por bats.
9. **Telemetria JSONL valida**: cada activacion escribe linea con campos `ts, task_id, verdict, score, reasons, operator_state_summary, banner_emitted`. Verificado por bats.
10. **Modo `shadow` no emite banner**: con `SAVIA_CS_MODE=shadow`, los 3 verdicts solo loguean; no escriben a stderr. Verificado por bats.
11. **Modo `advise` emite banner pero no requiere reaffirmation**: el flujo continua. Verificado por bats.
12. **Modo `interrupt` emite banner Y registra reaffirmation pending**: el log incluye `reaffirmation_required: true`. Verificado por bats.
13. **Master switch off**: con `SAVIA_CRITERION_SIMULATION=off`, ningun componente se activa. Verificado por bats.
14. **KG migration idempotente**: ejecutar `kg-schema-migrate-cs.py` 2 veces no duplica tabla. Verificado por pytest.
15. **Skill `meta-reflection` cargable**: tiene SKILL.md y DOMAIN.md. Verificado por bats (test-skills-no-orphans).
16. **Regla `criterion-simulation-honesty.md`**: declara que la capa NO es criterio real. Verificado por grep.
17. **Latencia con judge heavy**: p95 < 30s desde trigger hasta verdict. Verificado por benchmark.
18. **No falsos positivos en outputs historicos**: ejecutar trigger contra ultimos 20 commits hechos en horario atipico -> activaciones <= 4 (20%). Verificado manualmente + script.
19. **Documentacion del mecanismo de revision**: la regla declara la limitacion conceptual (revision != reflexion) explicitamente para que el equipo no tome la capa por mas de lo que es. Verificado por grep de la cita.
20. **Coste documentado**: el output del judge incluye `tokens_used` para que el coste sea visible. Verificado por bats.

## Out of scope

- **Generar criterio real**. Imposible con LLM.
- **Sustituir revision humana de PR**. Es complementaria, no sustitutiva.
- **Bloquear ejecucion automaticamente**. La capa interrumpe; el humano decide.
- **Modelo predictivo de operator burnout**. Heuristicas crudas son suficientes; no construimos un modelo psicometrico.
- **Integracion con Outlook/calendar para fatigue**. Solo si la usuaria tiene archivo local explicito; no se conecta a servicios externos.
- **Auto-escalado a otro humano**. La capa interpela al operador actual. Si esta cansado, debe reconocerlo y delegar manualmente.

## Dependencies

- Blocked by: ninguna spec activa.
- Blocks: ninguna spec actualmente.
- Related:
  - SPEC-188 Root-Cause Investigation Architecture: la capa usa la memoria de fallos como input para Q2 historical priors.
  - SPEC-125 Recommendation Tribunal: ortogonal — el tribunal evalua el output, esta spec cuestiona el frame antes de generar el output.
  - SPEC-192 Anti-adulation: ortogonal — anti-adulation cubre patrones de output, esta spec cubre el frame de la entrada.
  - SE-072 verified-source-required: la capa usa fuentes verificadas para Q2.
  - `radical-honesty.md` Rule #24: la honestidad sobre la limitacion (es simulacion, no criterio) es obligatoria.

## Migration path

Despliegue gradual extra-conservador (la capa interrumpe trabajo humano, errar caro):

| Semana | Cambio | Modo |
|---|---|---|
| 1 | Componentes 1-3 + telemetria | `shadow` global; threshold 80 (alto, dispara poco) |
| 2 | Revisar telemetria. Calibrar thresholds. Reducir falsos positivos. | `shadow` |
| 3-4 | Componentes 4-7. Habilitar `advise` en tareas TIER touches_security solamente | `advise` parcial |
| 5-8 | Si advise tiene <= 30% falsos positivos a juicio de la usuaria, ampliar a touches_production | `advise` ampliado |
| 9+ | Modo `interrupt` solo si la usuaria lo activa explicitamente | opt-in |

Reverse: `SAVIA_CRITERION_SIMULATION=off` desactiva. Borrar agente/hook/scripts/skill remueve el codigo. KG migration es additiva.

## Reference code

Esqueleto del judge prompt:

```
Eres una capa de simulacion de meta-reflexion. NO eres criterio real.
NO eres juicio humano. Eres una heuristica de pausa que activa preguntas
que un senior con energia y distancia se haria.

Recibes:
- Problem statement (la tarea original)
- Proposed solution (la spec / PR)
- Operator state (fatigue, pressure, hora, override-rate)
- Historical priors (tareas similares revertidas, si las hay)

Para cada una de las 4 preguntas:

Q1 FRAME CHALLENGE: la solucion propuesta responde al problema real, o
   responde a un problema parecido pero distinto? Cita evidencia textual.

Q2 HISTORICAL PRIORS: existen tareas similares que fracasaron por frame
   (no por ejecucion) en los ultimos 90 dias? Cita IDs y resume por que.

Q3 OPERATOR STATE: dado el estado del operador (fatigue/pressure/...),
   hay riesgo elevado de criterio relajado? Si si, mencionalo sin juzgar.

Q4 ALTERNATIVE REFRAMING: existe una formulacion mas simple del problema
   que resolveria el caso critico con menos cambio? Si si, propon en 1-2
   frases.

Output:
- verdict: FRAME_OK si las 4 preguntas pasan
- FRAME_DOUBT si 1-2 fallan
- FRAME_REJECT si 3-4 fallan o si Q1 falla solo (frame challenge directo)
- banner_text: maximo 6 lineas, lenguaje plano, SIN promesas exageradas
- IMPORTANTE: incluir SIEMPRE la frase "soy simulacion de meta-reflexion,
  no tu criterio. Tu decides".
```

## Impact statement

Cierra (parcialmente, con honestidad) el limite estructural identificado por la usuaria: los sistemas agenticos ejecutan, evaluan, pero no reflexionan sobre el frame. Esta spec NO da criterio al sistema; activa heuristicas de pausa cuando el humano puede haber soltado el suyo. El beneficio esperado es modesto: 1 de cada N tareas, el humano reconoce que no estaba pensando y reformula. El coste es real (tokens, ~30s de interrupcion). La spec es opt-in, conservadora en triggers y empieza en modo shadow para validar antes de molestar.

Honestidad final: si esta capa no detecta NADA en 30 dias de uso, es senal de que la usuaria si mantiene su criterio. Si detecta mucho, es senal de que el flujo organizacional esta empujando a errar el frame. Ambas senales son utiles. La capa no fracasa silenciosamente: cada activacion deja log auditable.

## OpenCode Implementation Plan

> Required post-2026-04-26.

**Classification**: Tier 2. Anade infraestructura nueva (1 agent + 1 hook + 5 scripts + 1 skill + 1 regla + KG schema), modifica nada del flujo existente, defaults extra-conservadores.

### Phase 1 — Trigger evaluator + operator-state signals (semana 1)

1. Crear `scripts/criterion-simulation/operator-state-signals.py` (stdlib + sqlite local).
2. Crear `scripts/criterion-simulation/trigger-evaluator.py`.
3. Crear `scripts/criterion-simulation/historical-priors.py` (consume KG SE-162).
4. Tests pytest `tests/scripts/test_criterion_simulation_trigger.py` (50 sinteticos + 10 high-impact).
5. KG schema: anadir tabla `frame_reaffirmations` via `kg-schema-migrate-cs.py` idempotente.

### Phase 2 — Judge + skill (semana 2)

6. Crear `.opencode/agents/criterion-simulation-judge.md` con prompt + esquema.
7. Crear `.opencode/skills/meta-reflection/SKILL.md` con protocolo de las 4 preguntas.
8. Crear `.opencode/skills/meta-reflection/DOMAIN.md` (reflexion vs evaluacion).
9. Tests pytest sinteticos del judge (Q1-Q4 cada uno con positivos y negativos).

### Phase 3 — Hook + reaffirmation (semana 3)

10. Crear `.opencode/hooks/criterion-simulation-challenge.sh`.
11. Crear `scripts/criterion-simulation/reaffirmation-log.py` con --reaffirm y --reframe.
12. Registrar hook en `.claude/settings.json` matcher pre-Task / pre-Edit con guard de high-impact.
13. Tests bats `tests/test-criterion-simulation-hook.bats` (3 modos, telemetria, exit 0 siempre).

### Phase 4 — Regla y honestidad (semana 4)

14. Crear `docs/rules/domain/criterion-simulation-honesty.md` con la cita explicita.
15. Tests grep que la regla cita la limitacion (revision != reflexion).
16. Actualizar `radical-honesty.md` con seccion sobre simulacion-no-es-criterio.

### Phase 5 — Validacion empirica (semanas 5-8)

17. Modo shadow durante 4 semanas en el workspace.
18. Recopilar telemetria: cuantos triggers, cuantos verdicts != FRAME_OK, cuantos llevarian a reframe segun la usuaria.
19. Calibrar thresholds. Documentar en CHANGELOG.
20. Decidir promocion a `advise` si los datos lo justifican.

### Acceptance criteria checklist (mapping)

| AC | Phase | Verifier |
|---|---|---|
| 1, 2, 9, 10, 11, 12, 13 | 3 | bats |
| 3, 4, 5, 6, 17, 18, 20 | 1+2+5 | pytest + benchmark |
| 7, 8 | 3 | bats |
| 14 | 1 | pytest |
| 15 | 2 | bats (test-skills-no-orphans) |
| 16, 19 | 4 | grep |

### Risks

- **Falsos positivos altos en early modo `advise`**: amenaza adopcion. Mitigacion: empezar en `shadow` 4 semanas, solo activar high-impact + signals fuertes.
- **Operator-state heuristicas mal calibradas**: hora del dia / frecuencia de commits son crudas. Mitigacion: estado parameterizable; usuaria puede ajustar `SAVIA_CS_FATIGUE_HOUR_BAND` y override rates aceptables.
- **Coste en tokens significativo**: ~15-25K por activacion. Mitigacion: trigger conservador. Threshold default 50 produce <= 20% activacion en tasks normales.
- **Privacy creep**: operator-state podria expandirse a tracking. Mitigacion: regla explicita `SAVIA_CS_OPERATOR_DATA=local` y NO conexion externa; test que falla si hay socket.
- **La capa se vuelve adulatoria**: el judge podria suavizar challenges para no molestar. Mitigacion: SPEC-192 anti-adulation cubre los outputs del judge tambien.
- **El humano la ignora siempre**: se vuelve ruido. Mitigacion: si telemetria muestra >70% reaffirmation sin reflexion (operator confirma siempre con razon < 30 chars), threshold sube automaticamente.

## Notes

Origen del diseno: reflexion textual de la usuaria 2026-06-13.

Esta spec es conscientemente honesta sobre lo que NO es: NO genera criterio, NO sustituye juicio humano, NO bloquea autonoma. Es heuristica de pausa con disclaimer explicito. Mas valiosa que silenciosa. Menos valiosa que un buen senior dudando del frame.

La regla acompañante (`criterion-simulation-honesty.md`) cita textualmente:
"Un agente que no puede dudar de su propia idea no cierra el loop. Lo simula. Esta spec es esa simulacion, declarada como tal."

Hermana operacional de SPEC-192 (anti-adulation) y SPEC-193 (injection hardening): las tres atacan limites de los sistemas agenticos sin pretender resolverlos del todo, con honestidad sobre el alcance.
