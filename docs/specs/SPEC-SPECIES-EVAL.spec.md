# SPEC-SPECIES-EVAL — Binary Checklist + LLM-as-Judge para todas las specs Savia

> **Spec nueva** — Aplica el patron `species/eval/` de Emilio Carrion (product-blueprints) como quality gate universal post-implementacion en el pipeline SDD de Savia.
>
> Inspirada por: `SPEC-PROJECT-UPDATE` ($11 testing), Emilio Carrion "DNA of Software" (LinkedIn 2026-05-06),
> `EmilioCarrion/product-blueprints` (MIT), PageIndex/VectifyAI (reasoning-based verification).

**Task ID:**          SPEC-SPECIES-EVAL
**PBI padre:**        Savia SDD Quality — verificacion post-implementacion de specs
**Sprint:**           2026-19 (start) — 1 sprint estimado
**Fecha creacion:**   2026-05-07
**Confidencialidad:** N1 publico (codenames-only)
**Creado por:**       Savia (sesion interactiva con la PM activa, inspirado por analisis cross-source)

**Developer Type:**   agent-team (python-developer + test-architect)
**Asignado a:**       claude-agent-team
**Estado:**           Pendiente

**Effort Estimation (Dual Model):**

| Dimension       | Value |
|-----------------|-------|
| Agent effort    | ~14 h |
| Human effort    | ~4 h (review + calibracion de prompts) |
| Review effort   | ~2 h |
| Context risk    | low (no toca confidencialidad, solo tooling de testing) |
| Agent-capable   | yes |
| Fallback        | Humano necesita ~1 sprint desde cero |

**Decisiones arquitectonicas registradas:**

- (D-1) **Tres capas de evaluacion** por spec: `must-have.yaml` (binario), `judge-prompts.md` (LLM cualitativo), `thresholds.yaml` (metricas numericas). Inspirado en `species/eval/` de product-blueprints.
- (D-2) **Integracion con Code Review Court**: `.review.crc` existente absorbe los resultados de las 3 capas como evidencia adicional. No reemplaza el Court, lo enriquece.
- (D-3) **Templates generables**: `scripts/spec-eval-init.py {spec_id}` genera el scaffold `eval/` para una spec existente.
- (D-4) **Ejecucion dual**: `scripts/spec-eval-run.sh {spec_id}` corre must-have (determinista, rapido) + judge-prompts (LLM, lento). Thresholds via tooling nativo (pytest, coverage, bash).
- (D-5) **No vendor**: NO instalamos herramientas externas. must-have.yaml es un parser YAML propio (~60 LOC). judge-prompts usa el LLM del runtime actual.
- (D-6) **Opt-in por spec**: No se exige `eval/` para todas las specs desde el principio. Se añade incrementalmente. Specs nuevas lo requieren desde su creacion (template en sdd-spec-writer).

---

## 1. Contexto y Objetivo

### 1.1 Problema

El pipeline SDD de Savia tiene 3 capas de verificacion:
1. **Tests unitarios/integracion** (test-runner, test-engineer)
2. **Code Review Court** (6 jueces, `.review.crc`)
3. **E2E + BATS** (test_project_update_full.sh, etc.)

Pero hay un **gap**: ninguna capa verifica sistematicamente que la implementacion cumple los **criterios de aceptacion de la spec** de forma binaria y trazable. El Court juzga codigo (arquitectura, seguridad, naming), no "la spec dice AC-1.3 y eso esta implementado si/no".

Ademas, hay cualidades que no son mecanicamente verificables:
- "El MOC debe ser navegable en < 30 segundos"
- "Los digests generados deben mantener la voz del proyecto"
- "La sintesis ejecutiva no debe sonar a template generico"

Estas cualidades requieren juicio humano... o LLM-as-a-judge.

### 1.2 Inspiracion externa

**Emilio Carrion** (Staff Engineer @ Mercadona Tech, 2026-05-06) publico el concepto de "DNA de software" en 24 archivos. Su `species/eval/` tiene 3 capas:

| Capa | Formato | Ejecucion | Coste |
|------|---------|-----------|-------|
| `must-have.yaml` | Binary checklist (pass/fail) | Automatica, determinista | Bajo |
| `judge-prompts.md` | LLM-as-a-judge cualitativo | LLM con screenshots/inputs | Medio |
| `lighthouse-thresholds.yaml` | Metricas numericas | Tooling estandar | Bajo |

Carrion verifico esto regenerando un sitio web completo (Mos) con Codex CLI + GPT-5. El patron demostro que:
- Cada gap en el ADN detectado en `dna-gaps.md` mejora TODAS las regeneraciones futuras (leverage acumulable)
- Los atajos del agente (navbar invisible, mapa degradado) se detectan en `must-have.yaml`, no en tests unitarios
- LLM-as-a-judge captura cualidades que ningun test automatizado puede

**PageIndex** (VectifyAI, 29K stars) aporta el concepto complementario de **verificacion basada en razonamiento** sobre estructura jerarquica. Aunque PageIndex es un sistema RAG, su approach de "reasoning-based verification" sobre un arbol de documentos es aplicable a como evaluamos la integridad estructural de outputs generados (digests, MOCs, grafos).

### 1.3 Objetivo

Añadir **3 capas de evaluacion post-implementacion** a TODA spec Savia, ejecutables automaticamente y con resultados integrados en el `.review.crc`:

1. **Binary checklist** (`eval/must-have.yaml`): pass/fail por item. Corre en < 5s. Cero LLM.
2. **LLM-as-a-judge** (`eval/judge-prompts.md`): evaluacion cualitativa con scoring 1-10. Corre async, ~30s por prompt.
3. **Measurable thresholds** (`eval/thresholds.yaml`): metricas numericas contra umbrales (coverage, performance, linting, frontmatter compliance).

Resultado: el `.review.crc` incluye una seccion nueva `## Species Eval Results` con:
- Must-have: X/Y passed (Z failed)
- Judge score: N.N/10 composite
- Thresholds: M/N within bounds

### 1.4 No-goals (explicito)

- NO reemplaza el Code Review Court (`.review.crc`). Lo complementa.
- NO reemplaza los tests unitarios/integracion. Añade verificacion contra acceptance criteria.
- NO exige eval/ para specs existentes retroactivamente. Solo para specs nuevas y las que voluntariamente adopten.
- NO instala dependencias externas (Lighthouse, Pa11y,etc). Thresholds usan tooling ya presente (pytest, coverage, shell).
- NO ejecuta LLM-as-a-judge en CI (coste). Solo bajo demanda (`--with-judge`) o en pre-release.

### 1.5 Criterios de Aceptacion globales

- [ ] AC-G1: `scripts/spec-eval-init.py SPEC-XXX` genera scaffold `eval/` con must-have.yaml, judge-prompts.md, thresholds.yaml.
- [ ] AC-G2: `scripts/spec-eval-run.sh SPEC-XXX` ejecuta must-have (siempre) y reporta pass/fail por item.
- [ ] AC-G3: `scripts/spec-eval-run.sh SPEC-XXX --with-judge` ejecuta must-have + judge-prompts (LLM) y reporta scoring.
- [ ] AC-G4: Resultados integrados en `.review.crc` bajo seccion `## Species Eval Results`.
- [ ] AC-G5: Specs nuevas creadas por `sdd-spec-writer` incluyen `eval/` scaffold vacio con placeholder generico.
- [ ] AC-G6: SPEC-PROJECT-UPDATE adopta eval/ como spec piloto (Fase 1 tras implementacion).
- [ ] AC-G7: must-have.yaml parser es < 80 LOC Python puro (sin deps externas).
- [ ] AC-G8: Cero hardcode de nombres reales (Rule #20). Cero referencias a proyectos privados (Rule zero-project-leakage).
- [ ] AC-G9: Confidentiality scan pasa tras commit.

---

## 2. Diseno de las 3 capas

### 2.1 Capa 1: Binary Checklist (`eval/must-have.yaml`)

#### 2.1.1 Schema

```yaml
# eval/must-have.yaml — Binary acceptance criteria
# Cada item es pass o fail. Ejecucion determinista, < 5s.
version: 1

spec: SPEC-SPECIES-EVAL        # spec_id
spec_version: v1.0              # version de la spec evaluada

groups:
  - id: vault-layout            # identificador unico
    label: "Vault & Frontmatter" # etiqueta humana
    section: "3"                # seccion de la spec que se verifica
    items:
      - id: vault-init-creates-10-folders
        ac_ref: AC-1.1          # referencia al AC en la spec
        check: "vault-init.py crea las 10 carpetas canonicas"
        verify:
          type: shell           # shell | python | file-exists | json-query
          command: "test -d projects/test_main/test-monica/vault/00-Index && test -d projects/test_main/test-monica/vault/10-PBIs && test -d projects/test_main/test-monica/vault/20-Decisions && test -d projects/test_main/test-monica/vault/30-Sprints && test -d projects/test_main/test-monica/vault/40-Stakeholders && test -d projects/test_main/test-monica/vault/50-Digests && test -d projects/test_main/test-monica/vault/60-Risks && test -d projects/test_main/test-monica/vault/70-Specs && test -d projects/test_main/test-monica/vault/80-Sessions && test -d projects/test_main/test-monica/vault/99-Inbox"
          expected_rc: 0

      - id: vault-init-idempotent
        ac_ref: AC-1.2
        check: "Re-ejecutar vault-init.py es no-op"
        verify:
          type: python
          function: "tests.spec_eval.test_vault_init_idempotent"

      - id: frontmatter-hook-blocks-invalid
        ac_ref: AC-1.3
        check: "Hook bloquea write sin frontmatter en vault/*.md"
        verify:
          type: shell
          command: "bash tests/bats/test_vault_frontmatter_gate.bats --filter 'missing frontmatter'"
          expected_rc: 0

      - id: frontmatter-hook-blocks-n4-leak
        ac_ref: AC-1.4
        check: "Hook bloquea write con confidentiality:N4 en path no-N4"
        verify:
          type: shell
          command: "bash tests/bats/test_vault_frontmatter_gate.bats --filter 'N4 leak'"
          expected_rc: 0

      - id: templates-validate
        ac_ref: AC-1.10
        check: "Todas las plantillas validan contra vault-validate.py"
        verify:
          type: shell
          command: "python scripts/vault-validate.py --check-templates"
          expected_rc: 0
```

#### 2.1.2 Tipos de `verify`

| Type | Descripcion | Ejemplo |
|------|-------------|---------|
| `shell` | Comando bash, rc esperado | `test -d path/` |
| `python` | Funcion Python importable | `tests.spec_eval.test_X` |
| `file-exists` | Existe fichero(s) con glob | `vault/50-Digests/*.md` |
| `json-query` | jq query sobre output JSON | `.status == "created"` |
| `http-check` | HTTP request + status code | `curl -s -o /dev/null -w "%{http_code}"` |

#### 2.1.3 Comportamiento del runner

```
$ bash scripts/spec-eval-run.sh SPEC-PROJECT-UPDATE
== SPEC-PROJECT-UPDATE — Must-Have Checklist ==

[vault-layout] Vault & Frontmatter
  PASS  vault-init-creates-10-folders    (AC-1.1)
  PASS  vault-init-idempotent             (AC-1.2)
  PASS  frontmatter-hook-blocks-invalid   (AC-1.3)
  PASS  frontmatter-hook-blocks-n4-leak  (AC-1.4)
  PASS  templates-validate                (AC-1.10)

[capture] Captura conversaciones IA
  PASS  session-capture-creates-note      (AC-3.1)
  FAIL  session-capture-personal-vault    (AC-3.2)
        rc=1 expected=0 — personal vault path no existe
  PASS  session-capture-frontmatter-ok    (AC-3.3)

RESULTS: 7/8 passed (1 failed)
```

- Exit code: 0 si todos pasan, 1 si algun fallo.
- `--ci` mode output JSON para CI: `{"passed":7,"failed":1,"total":8,"failures":["session-capture-personal-vault"]}`

### 2.2 Capa 2: LLM-as-Judge (`eval/judge-prompts.md`)

#### 2.2.1 Estructura

```markdown
# Judge Prompts — SPEC-PROJECT-UPDATE

Evaluacion cualitativa post-implementacion. Cada prompt se ejecuta con
un LLM (mid-tier, ~$0.05/prompt). Inputs al juez:

- Vault completo (estructura + frontmatter de cada nota)
- MOC generado (00-Index/MOC-{slug}.md)
- digests de ejemplo (2-3 de cada fuente)
- grafo Mermaid (del MOC)
- dni-gaps.md (si existe)

El juez devuelve: score (1-10), reasoning, top-3 issues, top-3 strengths.
Scores < 7 generan flag en .review.crc. NO se itera automaticamente.

---

## Prompt 1: Vault Navigability

> Eres un PM evaluando si el vault Obsidian generado es navegable y util.
>
> Se te proporciona la estructura completa del vault (arbol de carpetas
> y frontmatter de cada nota).
>
> Score 1-10 sobre:
> - **Descubribilidad**: puede un PM nuevo encontrar un PBI, una decision,
>   o un digest de reunion en < 30s sin conocer la estructura exacta?
> - **MOC utilidad**: el MOC sirve como punto de entrada o es un placeholder?
> - **Wikilinks**: los enlaces `[[...]]` son utiles y no apuntan a notas
>   inexistentes?
> - **Densidad**: hay suficiente contexto por nota sin ser un muro de texto?
>
> Penaliza: MOC placeholder sin contenido real (-3), wikilinks rotos > 10%
> del total (-3 por cada 10%), carpetas vacias sin indicacion de que se
> llenaran en fases posteriores (-1 por carpeta).
>
> Da 3 strengths y 3 issues concretos con paths de notas como evidencia.

## Prompt 2: Digest Quality

> Eres un PM evaluando la calidad de los digests auto-generados.
>
> Se te proporcionan 3 digests de ejemplo (1 meeting, 1 email, 1 chat Teams).
>
> Score 1-10 sobre:
> - **Completitud**: captura el tema principal, decisiones, y action items?
> - **Concision**: es accionable o es un resumen generico?
> - **Voz**: mantiene el tono del proyecto o suena a template?
> - **Wikilinks**: referencia entidades conocidas (PBIs, personas, specs)?
>
> Penaliza: action items sin owner (-2), resumen tipo "se discutio X"
> sin detalles concretos (-2), cero wikilinks cuando el texto menciona
> entidades conocidas (-3).
>
> Da 3 strengths y 3 issues con fragmentos del digest como evidencia.

## Prompt 3: Cross-Source Coherence

> Eres un PM evaluando si los digests de distintas fuentes forman una
> narrativa coherente o son silos aislados.
>
> Se te proporciona: MOC completo, 3 digests de fuentes distintas,
> grafo Mermaid, action items consolidados.
>
> Score 1-10 sobre:
> - **Deduplicacion**: action items repetidos entre fuentes?
> - **Cruce**: decisiones de una reunion aparecen referenciadas en el
>   digest del mail de seguimiento?
> - **Contradicciones**: hay informacion contradictoria entre fuentes
>   que no se marca como conflicto?
>
> Penaliza: mismo action item en 3+ digests sin consolidar (-3),
> decision en reunion ignorada en el resto de fuentes (-2),
> timelines inconsistentes (mismo hecho con fechas distintas) (-3).

## Prompt 4: Synthesis Quality (MOC)

> Eres un PM evaluando la sintesis ejecutiva en el MOC.
>
> Se te proporciona el MOC completo (`00-Index/MOC-{slug}.md`).
>
> Score 1-10 sobre:
> - **Accionabilidad**: un PM leyendo solo el MOC sabe que hacer hoy?
> - **Priorizacion**: riesgos, decisiones, y action items estan priorizados
>   o son listas planas?
> - **Actualidad**: la sintesis refleja el estado real o es generica?
> - **Concision**: < 400 palabras la seccion de sintesis ejecutiva?
>
> Penaliza: sintesis que podria aplicar a cualquier proyecto (-3),
> action items sin deadline/owner (-2), lista de riesgos sin severity (-2),
> secciones auto-managed vacias o con placeholder (-3).

## Aggregation

El reporte incluye score por prompt y composite (promedio simple). El
composite score aparece en `.review.crc` junto con el contador de must-have
failures.
```

#### 2.2.2 Ejecucion

```bash
# Solo must-have (rapido, CI-safe)
scripts/spec-eval-run.sh SPEC-PROJECT-UPDATE

# must-have + judge-prompts (completo, pre-release)
scripts/spec-eval-run.sh SPEC-PROJECT-UPDATE --with-judge

# Solo judge-prompts (re-calibracion)
scripts/spec-eval-run.sh SPEC-PROJECT-UPDATE --only-judge
```

El runner:
1. Lee `eval/judge-prompts.md`
2. Para cada prompt, recolecta los inputs declarados
3. Invoca LLM con el prompt + inputs como contexto
4. Extrae score (1-10) del JSON de respuesta
5. Agrega en `.review.crc`

### 2.3 Capa 3: Measurable Thresholds (`eval/thresholds.yaml`)

#### 2.3.1 Schema

```yaml
# eval/thresholds.yaml — Measurable thresholds
# Metricas numericas contra umbrales. Usa tooling nativo del workspace.
version: 1

spec: SPEC-PROJECT-UPDATE
spec_version: v1.0

groups:
  - id: test-coverage
    label: "Test Coverage"
    items:
      - metric: vault_validate_coverage
        tool: coverage
        command: "pytest tests/scripts/test_vault_validate.py --cov=scripts/vault_validate.py --cov-report=json --quiet 2>&1"
        extract: ".totals.percent_covered"
        threshold: 80
        operator: gte
        unit: "%"

  - id: frontmatter-compliance
    label: "Frontmatter Compliance"
    items:
      - metric: all_templates_valid
        tool: vault-validate
        command: "python scripts/vault-validate.py --check-templates 2>&1"
        extract: "count_valid_templates"
        threshold: 8          # una plantilla por entity_type
        operator: gte
        unit: "templates"

  - id: idempotency
    label: "Idempotency"
    items:
      - metric: vault_init_idempotent
        tool: shell
        command: "python scripts/vault-init.py test 2>&1 | python -c 'import sys,json; print(json.load(sys.stdin)[\"status\"])'"
        extract: "stdout"
        threshold: "exists"
        operator: eq
        unit: "status"

  - id: llm-token-budget
    label: "LLM Token Budget (F2 enrich)"
    items:
      - metric: meeting_digest_avg_tokens
        tool: shell
        command: "bash scripts/measure-digest-tokens.sh meeting"
        extract: "avg_tokens"
        threshold: 8000
        operator: lte
        unit: "tokens"
```

#### 2.3.2 Operadores

| Operator | Significado |
|----------|-------------|
| `gte` | >= threshold |
| `lte` | <= threshold |
| `eq` | == threshold |
| `gt` | > threshold |
| `lt` | < threshold |
| `between` | threshold es `[min, max]` |

---

## 3. Integracion con Code Review Court

### 3.1 Nueva seccion en `.review.crc`

```markdown
## Species Eval Results

**Spec:** SPEC-PROJECT-UPDATE v1.0
**Eval run:** 2026-05-07T14:30:00+02:00
**Runner:** spec-eval-run.sh v1.0

### Must-Have Checklist
- Passed: 7/8
- Failed: 1 (session-capture-personal-vault — rc=1 expected=0)
- Skipped: 0

### Judge Scores (prompts: 4)
| Prompt | Score | Flag |
|--------|-------|------|
| Vault Navigability | 8/10 | — |
| Digest Quality | 6/10 | REVIEW |
| Cross-Source Coherence | 7/10 | — |
| Synthesis Quality (MOC) | 5/10 | REVIEW |
| **Composite** | **6.5/10** | REVIEW |

### Thresholds
| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| vault_validate_coverage | 92% | >= 80% | PASS |
| all_templates_valid | 8/8 | >= 8 | PASS |
| vault_init_idempotent | exists | == exists | PASS |
| meeting_digest_avg_tokens | 7200 | <= 8000 | PASS |

### Verdict
- Must-have: 1 failure (non-blocking for v1)
- Judge composite: 6.5/10 (2 prompts below 7 — human review recommended)
- Thresholds: 4/4 passed
```

### 3.2 Comportamiento del Court

- Los jueces del Court (`spec-judge`, `correctness-judge`, `architecture-judge`, etc.) reciben esta seccion como **evidencia adicional**.
- El `spec-judge` es el principal consumidor: compara must-have failures contra acceptance criteria.
- Un composite score < 5 genera flag `BLOCKED` en el Court.
- Un composite score 5-6.9 genera flag `WARNING — human review recommended`.

---

## 4. Tooling

### 4.1 `scripts/spec-eval-init.py {spec_id}`

```bash
$ python scripts/spec-eval-init.py SPEC-PROJECT-UPDATE
Created: docs/specs/SPEC-PROJECT-UPDATE/eval/must-have.yaml (placeholder)
Created: docs/specs/SPEC-PROJECT-UPDATE/eval/judge-prompts.md (placeholder)
Created: docs/specs/SPEC-PROJECT-UPDATE/eval/thresholds.yaml (placeholder)

Next: edita los 3 ficheros con los criterios especificos de tu spec.
      Usa los placeholders como guia.
```

- Busca la spec en `docs/specs/{spec_id}.spec.md`
- Extrae acceptance criteria (AC-G*, AC-1.*, etc.) para pre-rellenar must-have.yaml
- Genera placeholders con comentarios guia
- Si `eval/` ya existe, aborta (no sobrescribe)

### 4.2 `scripts/spec-eval-run.sh {spec_id} [flags]`

```
Flags:
  --ci              Output JSON (para CI)
  --with-judge      Ejecuta tambien judge-prompts (LLM)
  --only-judge      Solo judge-prompts (sin must-have)
  --output FILE     Path para el reporte (.review.crc seccion)
```

- Busca `eval/` en el directorio de la spec
- Si no existe `eval/`, exit 0 con mensaje "spec no tiene eval/ configurado"
- must-have: parsea YAML, ejecuta cada `verify`, reporta pass/fail
- judge-prompts: si `--with-judge`, invoca LLM (mid tier) por cada prompt
- thresholds: ejecuta cada `command`, extrae valor, compara contra `threshold`

### 4.3 Integracion en `sdd-spec-writer`

Al crear una spec nueva, `sdd-spec-writer` genera `eval/` scaffold con:
- `must-have.yaml` placeholder (grupos por cada seccion de AC de la spec)
- `judge-prompts.md` placeholder (prompt generico "Implementation Quality")
- `thresholds.yaml` placeholder (test coverage >= 80%)

Esto asegura que toda spec nueva nazca con eval/ preparado.

### 4.4 Template de `must-have.yaml` (placeholder)

```yaml
# eval/must-have.yaml — Binary acceptance criteria
# DOCUMENTACION: docs/specs/SPEC-SPECIES-EVAL.spec.md
version: 1
spec: {SPEC_ID}
spec_version: v1.0

groups:
  # EDITAR: un grupo por cada seccion de AC de la spec
  # - id: feature-group
  #   label: "Feature Group Name"
  #   section: "3"
  #   items:
  #     - id: descriptive-id
  #       ac_ref: AC-1.1
  #       check: "Descripcion verificable en lenguaje natural"
  #       verify:
  #         type: shell
  #         command: "your-test-command"
  #         expected_rc: 0
```

---

## 5. Mapping con SPEC-PROJECT-UPDATE (spec piloto)

SPEC-PROJECT-UPDATE adopta eval/ como spec piloto. Mapping con sus AC:

### 5.1 must-have.yaml (mapeo directo)

| AC | must-have check | verify type |
|----|-----------------|-------------|
| AC-1.1 | vault-init.py crea estructura completa | shell (test -d x10) |
| AC-1.2 | Re-ejecutar es no-op | python (funcion de test) |
| AC-1.3 | Hook bloquea sin frontmatter | shell (bats) |
| AC-1.4 | Hook bloquea N4 leak | shell (bats) |
| AC-2.1 | Digests en vault/50-Digests/ | file-exists |
| AC-3.1 | Sesion crea nota en vault | shell |
| AC-3.2 | Sesion sin slug -> personal vault | shell |
| AC-4.4 | enrich < 30 min | shell (time) |
| AC-1.10 | Plantillas validan | shell (vault-validate) |

### 5.2 judge-prompts.md

- **Prompt 1: Vault Navigability** — cubre AC-G4 (vault navegable en Obsidian)
- **Prompt 2: Digest Quality** — cubre AC-4.1, AC-4.2 (digests con frontmatter + wikilinks)
- **Prompt 3: Cross-Source Coherence** — cubre AC-2.3, AC-5.3 (wikilinks + queries)
- **Prompt 4: Synthesis Quality** — cubre AC-6.2, AC-6.3 (sintesis ejecutiva en MOC)

### 5.3 thresholds.yaml

| Metrica | Umbral | Tool |
|---------|--------|------|
| vault_validate.py coverage | >= 80% | pytest --cov |
| All templates valid | == 8/8 | vault-validate --check-templates |
| vault-init idempotent | exists | vault-init.py 2x |
| F1 time-box | <= 900s | time |
| Action items dedup rate | >= 80% | shell (jq) |

---

## 6. Aprendizajes de PageIndex aplicados

PageIndex (VectifyAI) verifica la integridad de su arbol de indices con:
- `verify_toc()` — muestreo aleatorio de nodos + verificacion LLM de que cada titulo aparece en la pagina correcta
- `fix_incorrect_toc_with_retries()` — reparacion automatica de nodos mal indexados
- `check_title_appearance_in_start_concurrent()` — verificacion concurrente de posicion de titulos

Estos patrones de verificacion son aplicables a la evaluacion de specs:

1. **Muestreo aleatorio**: En lugar de verificar todas las notas del vault, must-have.yaml puede muestrear N aleatorias para verificaciones caras (ej: validar frontmatter de 20 notas aleatorias, no 500).
2. **Verificacion concurrente**: Los checks de must-have se ejecutan en paralelo (shell commands independientes).
3. **Reparacion vs reporte**: must-have.yaml no repara — solo reporta. El agente `fix-assigner` (ya existente) toma los fallos y los asigna.

---

## 7. Estructura de archivos creados

```
docs/specs/SPEC-SPECIES-EVAL.spec.md              (esta spec)

scripts/spec-eval-init.py                          (scaffolder)
scripts/spec-eval-run.sh                           (runner)
scripts/spec-eval-musthave.py                      (parser must-have.yaml)
scripts/spec-eval-judge.py                         (runner judge-prompts)
scripts/spec-eval-thresholds.py                    (runner thresholds)

tests/scripts/test_spec_eval_musthave.py           (unit tests)
tests/scripts/test_spec_eval_thresholds.py         (unit tests)

docs/specs/SPEC-PROJECT-UPDATE/eval/              (spec piloto — creado por spec-eval-init)
  must-have.yaml
  judge-prompts.md
  thresholds.yaml

docs/rules/domain/species-eval.md                  (regla canonica — como usar eval/)
```

### Modificados

```
.sdd-spec-writer: template incluye eval/ scaffold vacio
.review.crc: nueva seccion "## Species Eval Results"
AGENTS.md / SKILLS.md: auto-regen si procede
```

---

## 8. Plan de testing

### 8.1 Unit tests

- `test_spec_eval_musthave.py`: parse must-have.yaml, ejecutar verify types (shell, python, file-exists, json-query), reporte pass/fail, CI JSON output.
- `test_spec_eval_thresholds.py`: ejecutar commands, extraer valores, comparar contra thresholds con todos los operadores.

### 8.2 Integracion

- `tests/e2e/test_spec_eval_full.sh`: spec-eval-init SPEC-TEST -> spec-eval-run SPEC-TEST -> assert output -> spec-eval-run --ci SPEC-TEST -> assert JSON.

### 8.3 Spec piloto

- SPEC-PROJECT-UPDATE/eval/ se testea como parte de la Fase 1 de PROJECT-UPDATE.

---

## 9. OpenCode Implementation Plan (Rule spec-opencode-implementation-plan)

### 9.1 Classification

`runtime: dual` — Funciona en Claude Code Y OpenCode.

### 9.2 Diferencias por runtime

| Aspecto | Claude Code | OpenCode |
|---------|-------------|----------|
| Shell scripts | nativos | nativos |
| Python scripts | nativos | nativos |
| LLM invocation (judge) | Task tool | Task tool |
| YAML parsing | pyyaml | pyyaml |
| .review.crc integracion | append a seccion | mismo |

### 9.3 Tests por runtime

- Unit tests Python: corren igual.
- Shell runner: corren igual (bash).
- LLM judge: mismo prompt, mismo modelo.

---

## 10. Riesgos y mitigaciones

| ID | Riesgo | Severidad | Mitigacion |
|----|--------|-----------|------------|
| R-1 | LLM-as-judge inconsistente entre runs | medium | Mismo modelo, temperatura 0.0. Scores se interpretan como orientativos, no bloqueantes. |
| R-2 | must-have.yaml se desincroniza de la spec | medium | Cada item referencia `ac_ref`. spec-eval-init re-genera desde AC actuales. |
| R-3 | Sobrecarga de falsos positivos en must-have | low | Verify type `shell` permite comandos precisos. Si un check es fragil, se migra a `python`. |
| R-4 | Resistencia a adoptar eval/ (friccion) | medium | Opt-in. Specs existentes no requieren eval/. Nuevas specs lo incluyen por defecto. |
| R-5 | Coste de judge-prompts (~$0.20/spec) | low | Solo bajo demanda (`--with-judge`). No en CI. |
| R-6 | Conflictos con tool-healing en OpenCode | low | Python scripts no usan write/read directo. Shell heredoc como fallback. |

---

## 11. Dependencias

### 11.1 Internas

- `scripts/savia-env.sh` — resolver paths, runtime.
- `sdd-spec-writer` — template para specs nuevas.
- `code-reviewer` + Court — integracion `.review.crc`.
- `fix-assigner` — asignar must-have failures a agentes.

### 11.2 Externas

- Python 3.10+, `pyyaml`.
- LLM access (mid tier) para judge-prompts.

### 11.3 Sin dependencia de

- Herramientas externas de testing (Lighthouse, Pa11y, etc.).
- APIs de terceros.
- Plugins o vendors externos.

---

## 12. Glosario

- **Species**: termino de Carrion para "lo que define el genero de producto". En Savia: "lo que la spec define como invariante".
- **must-have.yaml**: binary checklist, pass/fail por item, ejecucion determinista < 5s.
- **judge-prompts.md**: prompts LLM-as-a-judge para evaluacion cualitativa con scoring 1-10.
- **thresholds.yaml**: metricas numericas contra umbrales.
- **DNA gaps**: ambiguedades en la spec que el agente tuvo que resolver sin guia. Concepto de Carrion, aplicable a reporte de gaps en Savia.
- **Composite score**: promedio simple de los scores de judge-prompts.
