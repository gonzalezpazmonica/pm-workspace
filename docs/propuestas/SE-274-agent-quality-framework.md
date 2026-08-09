# SE-274 — Agent & Skill Quality Framework: rubricado adversario + eval golden sets + verify.sh por agente

**Status:** PROPOSED
**Fecha:** 2026-07-30
**Area:** Agent governance / Skill quality / Eval infrastructure
**Branch:** agent/se274-agent-quality
**Estimacion total:** ~40h (5 slices)
**Inspiracion:** `ericrisco/rsc-harness` (skill-rubric.md, agent-eval, verify.sh) + `Shubhamsaboo/awesome-llm-apps` (RAG Failure Diagnostics Clinic P01-P12, Trust-Gated Agent Team)

---

## Origen

Savia tiene 81 agentes y 119+ skills. Creceran. Hoy no existe un estandar
de calidad medible para ellos: un agente nuevo se aprueba si pasa los gates
de pr-plan (G0-G15), que verifican formato, confidencialidad, CHANGELOG y
scope-trace — pero **no verifican calidad semantica**: ¿dispara
correctamente vs su sibling mas cercano? ¿respeta sus limites de permiso?
¿sus cross-references resuelven? ¿tiene cobertura minima de evals?

Dos fuentes externas ofrecen patrones maduros para resolverlo:

1. **rsc-harness** (`ericrisco/rsc`): 257 skills con un rubric de 7
   dimensiones ponderadas + 7 gates deterministas + scoring >= 8.5 para
   publicar. Pipeline de eval: golden sets JSONL (50-200 casos por modo de
   fallo), scorer mix (60% deterministico / 30% LLM-judge / 10% humano),
   regression gate con bootstrap CI. Per-skill `verify.sh` que ejecuta
   lint + type + test + coverage + audit.

2. **awesome-llm-apps**: RAG Failure Diagnostics Clinic con 12 patrones de
   fallo reutilizables (P01-P12) que clasifican bugs en un patron primario
   y sugieren un fix estructural minimo, no un tweak de prompt. Modelo
   Trust-Gated Agent Team con scoring 0-100 y tiered gold/silver/bronze.

**El hueco.** Savia tiene tribunales que evaluan outputs (Truth, Code
Review, Recommendation) pero **no tiene un tribunal ni una metrica para
evaluar a los propios agentes y skills**. La calidad se asume; no se mide.

timeline:
  - from: "2026-08-09"
    learned: "2026-08-09"
    value: "IMPLEMENTED"
    source: "SE-274 S2 completado: golden sets de tribunales (PR #953)"
---

## Objetivo

Crear un framework de calidad medible para agentes y skills de Savia:
rubric ponderado con gates deterministicos (S1), pipeline de eval con
golden sets para los tres tribunales (S2), `verify.sh` por agente de alto
riesgo (S3), lint de cobertura minima de evals en CI (S4), y clinic de
diagnostico de fallos RAG para el sistema de memoria (S5).

---

## Out of scope explicito

- NO evaluar los 81 agentes de una vez. Se priorizan los 15 de mayor riesgo
  (tribunales + guardians + orchestrators + sdd-spec-writer + developers).
- NO sustituir los gates G0-G15 existentes. El rubric es una capa adicional
  de calidad semantica, no un reemplazo de los gates de formato.
- NO implementar el pipeline completo de auto-mejora (Executor/Analyst/
  Mutator loop). Eso es SE-xxx futuro. Aqui solo el scoring y la deteccion.
- NO tocar agentes que no estan en la lista de high-risk.

---

## Diseno

### S1 — Rubric de calidad adversario para agentes y skills

7 dimensiones ponderadas, adaptadas al dominio de Savia:

| # | Dimension | Peso | Que mide |
|---|---|---|---|
| D1 | Discriminacion de disparo | 0.15 | ¿Un configurator podria elegir este agente/skill sobre su sibling mas cercano solo por la description? |
| D2 | Disciplina de frontera | 0.20 | ¿Respeta su nivel L0-L4? ¿Nunca hace merge/push-force/write-fuera-de-scope? |
| D3 | Correccion y frescura | 0.20 | ¿Cada claim load-bearing cita fuente con fecha? ¿Paths y comandos existen en el repo? |
| D4 | Accionabilidad | 0.15 | ¿Numeros, paths, comandos y reglas de decision concretos? ¿Zero adjetivos sin sustancia? |
| D5 | Cobertura de evals | 0.10 | ¿>=5 should_trigger, >=4 should_not_trigger (con route_to a sibling real), >=1 capability? |
| D6 | Integridad de cross-references | 0.10 | ¿Todo `recommends`, `uses`, `routes_to` resuelve a un agente/skill real del catalogo? |
| D7 | Originalidad y seguridad | 0.10 | ¿Voz Savia, no clon? ¿Cumple autonomous-safety.md? ¿CONSTITUCION.md ART-01 a ART-20? |

**Scoring**: cada dimension 0-10. Puntuacion ponderada minima para publicar:
**8.0** (equivalente a 8.5 de rsc, ajustado porque Savia tiene menos
skills y el ecosistema es mas joven).

**Gates deterministicos** (bloquean publicacion independientemente del score):

| Gate | Que verifica |
|---|---|
| G-A1 | `name` en frontmatter coincide con directorio; `origin: savia` presente |
| G-A2 | Frontmatter valida contra JSON schema de agente/skill |
| G-A3 | Todo `recommends` / `route_to` / `uses` resuelve a un id real del catalogo |
| G-A4 | `eval-lint.sh` reporta PASS (>=5 trigger / >=4 not-trigger / >=1 capability) |
| G-A5 | Toda cross-reference `../<sibling>/SKILL.md` o `../<sibling>/AGENT.md` resuelve |
| G-A6 | Nivel de permiso declarado en frontmatter (L0-L4) coincide con acciones documentadas |
| G-A7 | Si `verify.sh` existe, es ejecutable, solo-lectura, y sale 0 en target limpio/vacio |

**Anti-cheat del reviewer** (hereda de rsc-harness):
- Pass independiente: revisar el artefacto como esta escrito, no como se intenciona
- Evidencia, no vibes: citar char counts, source titles con fechas, line counts
- Longitud es coste, nunca credito: rutas mas cortas puntuan mas alto que verbose
- Frescura obligatoria: dimension D3 cap a 6 si claims son plausiblemente obsoletos
- Fix loop: hasta 2 rondas; luego registrar score real y flag (nunca redondear hacia arriba)

**Artefacto**: `docs/rules/domain/agent-skill-rubric.md` — documento vivo,
versionado, aplicable por cualquier reviewer humano o agente.

### S2 — Pipeline de eval con golden sets para tribunales

Pipeline de 5 fases (dataset → runner → scorers → metrics → gate):

```
dataset (JSONL golden set)
  → runner (ejecuta agente contra cada caso)
    → scorers (deterministico / LLM-judge / humano)
      → metrics (bootstrap CI)
        → gate (PASS/FAIL exit code)
```

**Golden sets por tribunal** (50-200 casos hand-labeled por modo de fallo):

| Tribunal | Casos target | Modos de fallo a cubrir |
|---|---|---|
| Code Review Court | 80 (40 bugs reales, 40 clean) | False positive (marcar clean como bug), false negative (no detectar bug real), severity inflation |
| Truth Tribunal | 100 (reports con errores plantados) | Factual error no detectado, hallucination no detectada, incoherence pasada por alto, completeness sobre-estimada |
| Recommendation Tribunal | 100 (drafts con adulacion/sesgo plantado) | Sycophancy no detectada, concession no detectada, framing no detectado, authority-claim no verificada |

**Scorer mix** (60/30/10):
- ~60% deterministico: exact match, regex, JSON schema, latency threshold
- ~30% LLM-as-judge: donde correctness es semantica (Claude >= modelo bajo test)
- ~10% human-in-the-loop: casos genuinamente ambiguos

**Reglas del LLM-judge**:
- Judge model >= system under test
- Rubric fuerza rationale escrito antes del score
- Pairwise beats pointwise para estabilidad
- Swap positions y average (cancelar position bias)
- Calibrar contra human gold y reportar agreement antes de gatear

**Regression gate**: bloquear en regresion vs baseline commiteado, no en
umbral absoluto. Bootstrap CI para que el ruido del judge solo no tire el
build.

**Artefactos**: `tests/evals/code-review-court/cases.jsonl`,
`tests/evals/truth-tribunal/cases.jsonl`,
`tests/evals/recommendation-tribunal/cases.jsonl`,
`scripts/agent-eval-runner.sh`.

### S3 — verify.sh por agente de alto riesgo

Cada uno de los 15 agentes de mayor riesgo recibe un `scripts/verify-<agent>.sh`:

| Agente | Que verifica |
|---|---|
| `commit-guardian` | Staged changes cumplen reglas del workspace deterministicamente |
| `security-guardian` | Secret scan (gitleaks), dependency audit (Trivy), PII scan en diff |
| `code-reviewer` | Output format cumple schema de report, todos los findings tienen severity + location + fix |
| `configurator` | Dispatch decisions resuelven a skills/agents/rules reales del catalogo |
| `drift-auditor` | Diff entre docs, config y codigo: todas las referencias cruzadas resuelven |
| `sdd-spec-writer` | Spec generada valida contra schema, todos los AC son testables, plan OpenCode presente |
| `truth-tribunal-orchestrator` | Veredicto contiene scores de los 7 judges, vetos aplicados, aggregation correcta |
| `recommendation-tribunal-orchestrator` | Veredicto contiene scores de los 10 judges, vetos aplicados, mutation aplicada |
| `court-orchestrator` | `.review.crc` contiene findings de los 6 judges, fix cycles documentados |
| `dotnet-developer` | `dotnet build` + `dotnet test` + `dotnet format --verify-no-changes` |
| `typescript-developer` | `tsc --noEmit` + `npm test` + `npm run lint` |
| `python-developer` | `mypy` + `pytest` + `ruff check` |
| `frontend-developer` | `ng lint` / `eslint` + `npm test` + `npm run build` |
| `terraform-developer` | `terraform fmt -check` + `terraform validate` + `tflint` |
| `infrastructure-agent` | `terraform plan` es solo lectura, nunca `apply` |

**Reglas comunes**:
- Skip tools no instalados (amarillo SKIP) en vez de fallar — pero SKIP es
  "no verificado", no "pass"
- Non-zero exit de una tool que SI corrio es hard FAIL
- Debe correrse desde el directorio que el agente documenta

### S4 — eval-lint.sh: cobertura minima de evals en CI

Script `scripts/agent-eval-lint.sh` que verifica en CI:

1. Todo directorio de agente en `.opencode/agents/` tiene `evals/cases.yaml`
   con >=5 should_trigger, >=4 should_not_trigger, >=1 capability
2. Todo directorio de skill en `.opencode/skills/` tiene `evals/cases.yaml`
   con >=3 should_trigger, >=2 should_not_trigger
3. Todo `route_to` en should_not_trigger referencia un agente/skill real
4. Reporta PASS/FAIL por agente/skill; exit no-zero en cualquier FAIL

**Integracion**: nuevo gate G16 en `pr-plan-gates.sh` que corre
`agent-eval-lint.sh` solo sobre agentes/skills modificados en el PR.

### S5 — RAG Failure Diagnostics Clinic para el sistema de memoria

Adaptacion de los 12 patrones de fallo (P01-P12) del RAG Failure
Diagnostics Clinic al sistema de memoria de Savia:

| Patron | Nombre | Manifestacion en Savia |
|---|---|---|
| P01 | Retrieval hallucination / grounding drift | Memoria devuelve contexto incorrecto que el agente asume como verdad |
| P02 | Chunk boundary split | Entidad partida entre dos fragments de memoria; contexto incompleto |
| P03 | Embedding drift / stale index | Indice de memoria desactualizado; resultados irrelevantes |
| P04 | Query-document mismatch | Query del agente no matchea el encoding de la entrada de memoria |
| P05 | Query rewriting / router misalignment | Configurator enruta a skill/agente equivocado por mala interpretacion |
| P06 | Context window overflow | Demasiados resultados; el agente solo ve los primeros N |
| P07 | Redundant / near-duplicate retrieval | Multiples entradas dicen lo mismo; el agente las trata como evidencia independiente |
| P08 | Session memory leak / missing context | Contexto perdido entre handoffs de agentes |
| P09 | Temporal staleness | Entrada de memoria vigente cuando se escribio, obsoleta ahora |
| P10 | Authority / provenance confusion | Memoria no distingue entre "hecho verificado" y "suposicion del agente" |
| P11 | Multi-tenant interference | Entradas de un proyecto contaminan respuestas de otro |
| P12 | Format / encoding corruption | Entrada de memoria corrupta por encoding, truncado, o caracteres especiales |

**Script**: `scripts/memory-failure-diagnostics.sh` que:
1. Recibe un query + respuesta que el usuario marco como incorrecta
2. Clasifica el fallo en uno de los 12 patrones (con LLM)
3. Sugiere un fix estructural (no un tweak de prompt): reindexar, ajustar
   chunk size, purgar entradas stale, añadir filtro de provenance, etc.
4. Registra en `output/memory-failure-patterns.jsonl` para analisis de
   tendencias

---

## Slices de implementacion

### S1 — Rubric + scoring manual de los 15 agentes top (12h)
- Escribir `docs/rules/domain/agent-skill-rubric.md` (4h)
- Escribir JSON schema de validacion de frontmatter para agentes y skills (2h)
- Scorings manuales de los 15 agentes high-risk usando el rubric (4h)
- Documentar gaps encontrados en `output/se274-rubric-gaps.md` (2h)

### S2 — Golden sets para los 3 tribunales (12h)
- Crear `tests/evals/code-review-court/cases.jsonl` con 80 casos hand-labeled (4h)
- Crear `tests/evals/truth-tribunal/cases.jsonl` con 100 casos (4h)
- Crear `tests/evals/recommendation-tribunal/cases.jsonl` con 100 casos (4h)

### S3 — verify.sh para los 15 agentes high-risk (8h)
- Escribir `scripts/verify-<agent>.sh` para cada uno de los 15 (4h)
- Integrar en CI: nuevo job que corre verify.sh sobre agentes modificados (2h)
- Documentar SKIP vs FAIL vs PASS en `docs/rules/domain/agent-verify-policy.md` (2h)

### S4 — eval-lint.sh + G16 en pr-plan (4h)
- Escribir `scripts/agent-eval-lint.sh` (2h)
- Añadir gate G16 a `scripts/pr-plan-gates.sh` (1h)
- Actualizar `docs/rules/domain/pr-plan-gates.md` con G16 (1h)

### S5 — RAG Failure Diagnostics Clinic para memoria (4h)
- Escribir `scripts/memory-failure-diagnostics.sh` (2h)
- Documentar los 12 patrones en `docs/rules/domain/memory-failure-patterns.md` (1h)
- Añadir `output/memory-failure-patterns.jsonl` al sistema de logging (1h)

---

## Dependencias

- **S1 → S2**: El rubric define que dimensiones medir en los golden sets
- **S3 → S1**: verify.sh usa los gates deterministicos del rubric (G-A1 a G-A7)
- **S4 → S1, S3**: eval-lint.sh verifica cobertura minima; verify.sh verifica ejecucion
- **S5 independiente**: No depende de S1-S4
- **Requiere**: acceso a los 3 tribunales existentes para extraer casos reales
- **No requiere**: nuevos agentes, nuevos hooks, cambios en CONSTITUCION.md

---

## Riesgos

| Riesgo | Prob | Impacto | Mitigacion |
|---|---|---|---|
| Crear golden sets es mas trabajo del estimado (hand-labeling) | Media | Medio | Priorizar 50 casos por tribunal en S2; el resto en S2b futuro |
| Resistencia a scores bajos en agentes existentes | Baja | Bajo | El rubric es herramienta de mejora, no de castigo; los gaps generan tasks, no bloqueos |
| verify.sh requiere tools no instaladas en CI | Media | Bajo | Patron SKIP amarillo: tool no instalada = no verificada, no fallida |
| Los 12 patrones RAG no cubren todos los fallos de memoria de Savia | Baja | Bajo | Los patrones son punto de partida; el clinic crece con cada fallo nuevo detectado |
| G16 enlentece CI para PRs que tocan muchos agentes | Baja | Medio | G16 solo corre sobre agentes/skills modificados en el PR, no full catalog |

---

## Criterios de aceptacion

### AC-S1: Rubric publicado y aplicado
- [ ] AC-S1.1: `docs/rules/domain/agent-skill-rubric.md` existe con las 7 dimensiones y 7 gates
- [ ] AC-S1.2: JSON schema de frontmatter valida 100% de los 81 agentes existentes (PASS o FAIL documentado)
- [ ] AC-S1.3: 15 agentes high-risk tienen score documentado en `output/se274-rubric-gaps.md`
- [ ] AC-S1.4: Todo agente nuevo creado post-S1 debe pasar el rubric antes de merge

### AC-S2: Golden sets operativos
- [x] AC-S2.1: `tests/evals/code-review-court/cases.jsonl` existe con >=50 casos
- [x] AC-S2.2: `tests/evals/truth-tribunal/cases.jsonl` existe con >=50 casos
- [x] AC-S2.3: `tests/evals/recommendation-tribunal/cases.jsonl` existe con >=50 casos
- [ ] AC-S2.4: `scripts/agent-eval-runner.sh` ejecuta los 3 golden sets y produce `eval-report.json`

### AC-S3: verify.sh por agente
- [ ] AC-S3.1: 15 scripts `scripts/verify-<agent>.sh` existen y son ejecutables
- [ ] AC-S3.2: Cada verify.sh sale 0 en el caso feliz (target limpio/vacio)
- [ ] AC-S3.3: verify.sh del agente modificado corre en CI en el PR

### AC-S4: Lint de cobertura en CI
- [ ] AC-S4.1: `scripts/agent-eval-lint.sh` existe y reporta PASS/FAIL por agente/skill
- [ ] AC-S4.2: G16 corre en `pr-plan.sh` sobre agentes/skills modificados en el PR
- [ ] AC-S4.3: PR que añade un agente sin `evals/cases.yaml` es bloqueado por G16

### AC-S5: Clinic de diagnostico RAG
- [ ] AC-S5.1: `scripts/memory-failure-diagnostics.sh` existe y clasifica en 12 patrones
- [ ] AC-S5.2: `docs/rules/domain/memory-failure-patterns.md` documenta los 12 patrones con ejemplos
- [ ] AC-S5.3: `output/memory-failure-patterns.jsonl` recibe entradas del clinic

---

## Metrica de exito

- **S1**: 15/15 agentes high-risk con score documentado y gaps accionables
- **S2**: 3/3 golden sets con >=50 casos cada uno, regression gate funcional
- **S3**: 15/15 verify.sh scripts ejecutandose en CI sobre PRs que tocan su agente
- **S4**: G16 bloquea efectivamente PRs sin cobertura minima de evals
- **S5**: 12/12 patrones documentados; clinic clasifica fallos reales de memoria
