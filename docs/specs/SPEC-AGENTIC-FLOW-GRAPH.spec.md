# Spec: Agentic Flow Graph — Orquestación de agentes como grafo declarativo de estado

**Task ID:**        WORKSPACE (no Azure DevOps task — workspace-level feature)
**PBI padre:**      N/A — Era próxima: Agentic Flow Graph
**Sprint:**         2026-28 (próximo)
**Fecha creación:** 2026-05-09
**Creado por:**     Mónica (sesión interactiva con Savia)

**Developer Type:** agent-team
**Asignado a:**     claude-agent-team (architect + implementer + reviewer)
**Estimación:**     18h (4 slices × 4h + 2h por AMENDMENT-01 en Slices 1-2)
**Estado:**         Pendiente

**Inspirado por:**  Concepto de LangGraph (modelar flujos agénticos como grafos de estado), NO vendorizado. Ver sección 1.4.

**Refinamientos integrados:** AMENDMENT-01 (CEL + state namespacing, inspirado por achetronic/magec decisión #28). Aplicado 2026-05-10.

**Decisión arquitectónica registrada:**
- (D-1) Implementación nativa en Savia. NO se adopta `langchain` ni `langgraph` como dependencia. Inspiración conceptual sí, código upstream no.
- (D-2) Los flujos agénticos se declaran en YAML/Markdown versionado dentro del repo (Context-as-Code), no en código imperativo disperso por hooks.
- (D-3) ~~El motor de ejecución es bash + jq + ficheros de estado en `.scm/flows/`.~~ **Superado por D-6 (AMENDMENT-01)**: motor en Python con `celpy`, sin runtime persistente, sin daemon. Estado en JSON sigue siendo texto plano legible.
- (D-4) Cada nodo del grafo es un agente, una skill, un comando o un hook ya existente en pm-workspace. La spec NO crea nuevos agentes, solo el lenguaje para orquestarlos.
- (D-5) El grafo es trazable: cada ejecución produce un log JSONL en `output/flows/YYYYMMDD-{flow-id}/` con el camino real recorrido, las decisiones tomadas y los inputs/outputs de cada nodo.
- (D-6) **El motor de ejecución es Python** (no bash + jq). Razón: las condiciones se evalúan con CEL (D-7) y el state requiere namespacing transaccional (D-8); ambos son inviables en bash puro y la Rule #26 (Language Boundaries) los empuja a Python. El comando `/flow-run` es un wrapper bash mínimo sobre `scripts/flow_runner.py`. Los ficheros de estado JSON/JSONL siguen siendo legibles en texto plano.
- (D-7) **CEL como motor de evaluación de condiciones**. Las expresiones `when` (en aristas) y `exit_when` (en guards de bucle) son CEL, no jq. Implementación Python: librería `celpy`. Compilación al cargar el flujo (rechazo temprano), evaluación tras cada nodo. Expresiones que no compilen a tipo `bool` son rechazadas en compile-time. Aplicado de AMENDMENT-01.
- (D-8) **Namespacing del state compartido**. Tres namespaces internos: `flow:` (declarado en `state:`, escribible por nodos), `runtime:` (reservado al motor para trazas, profile, summaries de ContextGuard), `meta:` (reservado para extensiones futuras). Los prefijos son transparentes para los nodos: solo ven y escriben claves planas del namespace `flow:`. El motor rechaza intentos de escritura cruzada con error explícito. Aplicado de AMENDMENT-01.

---

## 1. Contexto y Objetivo

### 1.1 Problema

El stack actual de pm-workspace orquesta agentes de tres formas heterogéneas y poco trazables:

1. **Cadenas imperativas en bash** — scripts en `scripts/` que llaman a comandos `/spec-generate`, `/pr-review`, etc. en orden fijo. El flujo está enterrado en `if/elif`, no se puede inspeccionar sin leer el script entero, y modificarlo significa reescribir lógica.
2. **Hooks deterministas** — los 65+ hooks en `.opencode/hooks/` reaccionan a eventos individuales, pero no componen. Un hook que se dispara tras `Edit` no sabe nada de un hook que se dispara tras `Bash`. La coordinación entre ellos es implícita.
3. **Subagentes ad hoc** — algunos agentes lanzan otros agentes vía `Task`, pero la decisión de qué subagente lanzar y con qué prompt está hardcodeada en el agente padre. No hay forma de auditar el árbol de invocaciones a posteriori sin reconstruirlo a mano desde los logs.

El resultado es que **flujos agénticos no triviales** (sprint nocturno, mejora de código, investigación técnica, code review en paralelo con 5 jueces) se construyen en cada caso reinventando el patrón, con bucles, ramas y handoffs implícitos. No hay un lenguaje común para describirlos, no hay un motor común para ejecutarlos, y no hay una traza común para auditarlos.

### 1.2 Objetivo

Construir el sistema **Agentic Flow Graph (AFG)**: un lenguaje declarativo y un motor de ejecución para componer agentes, skills, comandos y hooks como grafos de estado.

1. **Lenguaje de grafo** — sintaxis YAML que declara nodos (agente / skill / comando / hook), aristas (transiciones condicionadas), estado compartido (variables del flujo) y puntos de decisión.
2. **Motor de ejecución** — `/flow-run {flow-id}` (wrapper bash → `scripts/flow_runner.py`) que lee el grafo, recorre los nodos en orden topológico (con bucles y ramas permitidos), pasa el estado entre ellos, evalúa CEL y registra la traza completa.
3. **Catálogo de flujos** — `.scm/flows/*.flow.yaml` versionados en el repo, uno por flujo agéntico no trivial existente (sprint-nocturno, code-review-court, debt-analyze, etc.).
4. **Comando `/flow-run`** — invoca el motor desde Savia con argumentos.
5. **Comando `/flow-trace`** — muestra la última traza de un flujo, con tiempos y decisiones.
6. **Comando `/flow-validate`** — valida que un grafo es ejecutable (no hay nodos huérfanos, todas las aristas tienen origen y destino, no hay bucles infinitos sin guard).
7. **Hook `flow-state-gate.sh`** — bloquea escrituras al estado del flujo desde fuera del motor.

**Principio SDD:** Esta spec define QUÉ debe existir. Decisiones de implementación clave (motor Python, CEL, namespacing) están registradas en D-6/D-7/D-8.

### 1.3 No-Goals (explícito)

- ❌ NO se adopta LangGraph, LangChain ni ninguna librería Python/JS de orquestación de agentes. Ni como dependencia ni como vendor.
- ❌ NO se construye un runtime persistente (daemon, servicio, base de datos). El motor es process-per-invocation.
- ❌ NO se inventa un DSL nuevo más allá del YAML. Si una transición necesita lógica compleja, se delega a un hook bash existente.
- ❌ NO se mueven los agentes/skills/comandos actuales. AFG los compone, no los reemplaza.
- ❌ NO se construye UI visual de grafos en este slice. La metacúpula Obsidian renderizará los `.flow.yaml` como notas con backlinks en una iteración posterior (ver sección 5).
- ❌ NO se garantiza compatibilidad con frontends fuera del eje provider-agnostic ya implementado (Claude Code, OpenCode, GitHub Copilot Enterprise).

### 1.4 Por qué NO LangGraph

LangGraph resuelve un problema parecido en el ecosistema Python: declarar agentes como grafos de estado con nodos y transiciones. Su modelo conceptual (StateGraph, nodes, edges, conditional edges, checkpointing) es coherente y está validado en producción.

Pero adoptarlo como dependencia de Savia choca con cuatro principios fundacionales:

1. **Sin vendor lock-in** — LangGraph forma parte del stack LangChain, cuya API ha roto compatibilidad varias veces y cuyo modelo de negocio pasa por LangSmith (cloud propietario).
2. **Texto plano es la verdad** — el estado de LangGraph vive en checkpoints binarios o en Postgres. AFG lo mantiene en JSONL legible.
3. **Privacidad absoluta** — la observabilidad de LangChain pasa naturalmente por LangSmith (envío de trazas a cloud externo). Incompatible con N4.
4. **Provider-agnostic** — LangGraph asume que el LLM se invoca a través de su SDK. Savia ya tiene tier-based resolution; reintroducir un wrapper de proveedor sería un retroceso.

Lo que se conserva de LangGraph es **la idea**: un flujo agéntico es un grafo declarativo de estado, no una cadena imperativa. La implementación es propia.

---

## 2. Contrato Técnico

### 2.1 Estructura canónica de un flujo

```
.scm/flows/{flow-id}.flow.yaml          # declaración del grafo
output/flows/{YYYYMMDD-flow-id}/         # trazas de ejecución
  ├── trace.jsonl                        # log evento-por-evento
  ├── state-final.json                   # estado al terminar
  └── nodes/                             # outputs por nodo
      ├── {node-id}-input.json
      └── {node-id}-output.json
```

### 2.2 Esquema YAML del grafo

```yaml
# .scm/flows/code-review-court.flow.yaml
flow_id: code-review-court
version: 1
description: Revisión paralela por 5 jueces especializados con scoring 0-100.
confidentiality: N1                      # nivel del flujo (N1-N4b)
inputs:
  - name: pr_number
    type: integer
    required: true
  - name: target_branch
    type: string
    default: main

state:
  scores: {}                              # diccionario juez → score
  verdict: null                           # final: approve | request-changes | reject

nodes:
  - id: fetch-diff
    kind: command
    invoke: /pr-fetch-diff
    args: { pr: "${inputs.pr_number}" }
    outputs: [diff_path]

  - id: judge-correctness
    kind: agent
    invoke: code-judge-correctness
    args: { diff: "${nodes.fetch-diff.diff_path}" }
    outputs: [score, rationale]
    parallel_group: judges

  - id: judge-architecture
    kind: agent
    invoke: code-judge-architecture
    parallel_group: judges
    # ... mismo patrón

  - id: aggregate
    kind: skill
    invoke: score-aggregator
    depends_on: [judge-correctness, judge-architecture, judge-security, judge-cognitive, judge-spec]
    outputs: [verdict, weighted_score]

edges:
  - from: fetch-diff
    to: [judge-correctness, judge-architecture, judge-security, judge-cognitive, judge-spec]
  - from: aggregate
    to: END
    when: "state.verdict == 'approve' && state.weighted_score > 70"
  - from: aggregate
    to: human-review
    when: "state.verdict != 'approve' || size(state.findings) > 5"

guards:
  - max_iterations: 1                     # no permitir bucles
  - max_duration_minutes: 30
  - max_cost_usd: 5.00                    # opcional, integra con quota guard

on_failure:
  - log: output/flows/${run_id}/error.json
  - notify: stderr
```

### 2.3 Tipos de nodo soportados

| `kind`     | Invoca                                          | Estado pasa por |
|------------|-------------------------------------------------|-----------------|
| `command`  | Slash command Savia (`/pr-fetch-diff`)          | stdout JSON     |
| `agent`    | Agente especializado (`code-judge-correctness`) | Task tool       |
| `skill`    | Skill (`score-aggregator`)                      | función directa |
| `hook`     | Hook bash de `.opencode/hooks/`                 | env vars        |
| `subflow`  | Otro `.flow.yaml`                               | recursión limitada profundidad 3 |

### 2.4 Reglas del motor

1. **Orden topológico con paralelismo opcional**. Nodos con mismo `parallel_group` se ejecutan concurrentemente vía `xargs -P` o equivalente.
2. **Estado compartido inmutable por nodo**. Cada nodo recibe una copia del estado, devuelve un patch JSON que el motor aplica antes de pasar al siguiente.
3. **Aristas condicionadas evaluadas al terminar el nodo origen**. La condición `when` es una expresión **CEL** (Common Expression Language) que recibe en su contexto `state` (mapa con el estado compartido del flujo, namespace `flow:` aplanado) y `nodes` (mapa nodo_id → outputs). El motor compila la expresión una vez al cargar el flujo (vía `celpy`) y la evalúa tras cada terminación de nodo. Una expresión que no compile a tipo `bool` en compile-time hace fallar la carga del flujo (rechazo temprano, no en runtime). Operadores soportados: `==`, `!=`, `<`, `>`, `&&`, `||`, `!`, `has()`, `size()`, `.contains()`.
4. **Guards obligatorios**. Todo flujo declara `max_iterations`, `max_duration_minutes` y opcionalmente `max_cost_usd`. Sin guards el flujo es rechazado por `/flow-validate`.
5. **Confidencialidad declarada**. Un flujo con `confidentiality: N4` no puede invocar nodos de `confidentiality: N1` con datos del estado (hook `flow-state-gate.sh` lo bloquea).
6. **Idempotencia recomendada**. El motor cachea outputs por hash de inputs cuando `idempotent: true` está declarado en el nodo. Reduce coste en re-ejecuciones.
7. **Namespacing del state**. El state compartido tiene tres namespaces internos: `flow:` (declarado en `state:` del flow.yaml, escribible por nodos), `runtime:` (reservado al motor para trazas, profile, summaries), `meta:` (reservado para extensiones futuras). Los nodos solo ven y escriben el namespace `flow:`, sin prefijo. Cualquier intento de escritura a `runtime:` o `meta:` desde un nodo es bloqueado por el motor con error explícito. Los hooks que validan el state pueden inspeccionar todos los namespaces; los nodos NO.

### 2.5 Comando `/flow-run`

```
/flow-run {flow-id} [--input key=value] [--dry-run] [--resume {run-id}]
```

- Sin args, lista flujos disponibles.
- `--dry-run` muestra el orden topológico sin ejecutar.
- `--resume` retoma desde el último nodo completado de una ejecución previa.

### 2.6 Comando `/flow-trace`

```
/flow-trace {flow-id} [--run {run-id}] [--node {node-id}]
```

- Sin args, muestra la última traza completa del flujo.
- Output: árbol de nodos con tiempos, decisiones y outputs resumidos.

### 2.7 Comando `/flow-validate`

```
/flow-validate {flow-id|all}
```

- Verifica: schema YAML, nodos referenciados existen, aristas tienen origen y destino, no hay ciclos sin guard, confidencialidad coherente.
- **Adicional (AMENDMENT-01)**: toda expresión CEL en `when` y `exit_when` compila correctamente vía `celpy`, y devuelve tipo `bool`. Compile-time errors hacen fallar la validación.
- Integrable como gate de CI: `flow-validate all` en pre-commit.

### 2.8 Hook `flow-state-gate.sh`

- Pre-write hook que se dispara cuando un nodo intenta escribir al estado.
- Bloquea: violaciones de confidencialidad, escrituras a campos no declarados en `state:`, escrituras desde procesos que no son el motor.
- **Adicional (AMENDMENT-01)**: bloquea escrituras a los namespaces `runtime:` y `meta:` desde cualquier nodo (solo el motor puede escribir ahí).

---

## 3. Slices de Implementación

### Slice 1 — Lenguaje + validador (4h + 1h por AMENDMENT-01)

- Schema YAML del grafo (`schemas/flow.schema.json`).
- `/flow-validate` implementado como wrapper bash → `scripts/flow_validate.py` (Rule #26).
- Dependencia añadida: `celpy` (CEL compiler/evaluator) en `requirements.txt`.
- Compilación CEL de toda expresión `when`/`exit_when` al cargar el flujo. Tipo `bool` exigido en compile-time.
- 1 flujo de prueba: `hello-world.flow.yaml` (un nodo `command` que ejecuta `/help`).
- Tests BATS: 10 casos de validación (válido, sin guards, ciclo, nodo huérfano, confidencialidad inconsistente).
- Tests Python (pytest): casos de compile-time CEL (expresión inválida, tipo no-bool, namespace incorrecto).

### Slice 2 — Motor de ejecución secuencial (4h + 1h por AMENDMENT-01)

- `scripts/flow_runner.py` (Python) para nodos `kind: command` y `kind: skill`. `/flow-run` es un wrapper bash mínimo.
- Estado compartido en JSON, mutaciones controladas por motor con namespacing (`flow:` / `runtime:` / `meta:`).
- Evaluador CEL (`celpy`) decide aristas tras cada nodo.
- Traza JSONL en `output/flows/{run-id}/trace.jsonl`.
- `/flow-run` y `/flow-trace`.
- Test integración: `hello-world` se ejecuta, namespace `runtime:` invisible para nodos, traza correcta.

### Slice 3 — Paralelismo + nodos `agent` y `hook` (4h)

- Soporte `parallel_group` con `xargs -P`.
- Soporte `kind: agent` (vía Task tool) y `kind: hook` (vía exec directo).
- Migrar `code-review-court` actual a `.flow.yaml` como prueba de fuego.
- Comparativa: tiempo y trazabilidad antes/después.

### Slice 4 — Subflows + idempotencia + integración Obsidian (4h)

- Soporte `kind: subflow` con límite de profundidad 3.
- Caché idempotente por hash de inputs.
- Generador `flow-to-obsidian.sh`: cada `.flow.yaml` se renderiza como nota Obsidian con backlinks a sus nodos. La metacúpula visualiza el grafo nativamente.
- Migrar 3 flujos más: `sprint-nocturno`, `debt-analyze`, `pr-plan`.

---

## 4. Riesgos y Mitigaciones

| Riesgo | Mitigación |
|---|---|
| **Reinventar LangGraph mal**. AFG acaba siendo una versión peor de LangGraph con menos features. | Limitar el alcance: AFG no compite en features, compite en encaje con el contrato Savia (texto plano, sin runtime, soberanía). Documentar explícitamente qué NO hace. |
| ~~**Bash + jq insuficiente para grafos complejos**~~. **Mitigado en compile-time por D-6**: motor en Python desde Slice 1. Riesgo residual: complejidad accidental en Python. | Mantener el motor pequeño (orden topológico + ejecución de nodos + evaluación CEL). NO añadir features no necesarias por ningún flujo real. NO migrar a LangGraph. |
| **Estado JSON crece sin control**. Flujos largos acumulan estado hasta hacer ilegible la traza. | `state:` declara explícitamente los campos esperados. Campos no declarados son rechazados por el hook. Compactación opcional al final del flujo. |
| ~~**Aristas condicionadas con `jq` difíciles de leer**~~. **Superado por D-7**: CEL es schema-aware y C-like. Riesgo residual: condiciones CEL complejas. | Si una condición necesita lógica no expresable en CEL natural, se delega a una skill `kind: skill` que devuelve un booleano y se referencia desde la condición CEL. |
| **Adopción lenta**. Los flujos actuales en bash funcionan; reescribirlos como YAML cuesta. | NO migrar todo. Migrar solo flujos donde la trazabilidad o la composición aportan valor real. Bash sigue siendo válido para scripts triviales. |
| **Curva de aprendizaje de CEL** (AMENDMENT-01). Quien escribe flows debe aprender un mini-lenguaje nuevo. | CEL tiene documentación oficial extensa (Google y Kubernetes). Cheat-sheet de 1 página en `docs/agentic-flow-graph.md`. Sintaxis C-like, familiar. |
| **Confusión sobre namespaces** (AMENDMENT-01). Autor de flow se confunde entre `flow:`, `runtime:`, `meta:`. | Nodos solo ven `flow:` (sin prefijo). El resto es invisible desde la declaración. Documentación explícita. Errores del motor mencionan el namespace y el motivo. |

---

## 5. Conexión con la metacúpula

Cada `.flow.yaml` es Context-as-Code: vive en el repo, se versiona, se revisa en pull request. El generador `flow-to-obsidian.sh` (Slice 4) lo renderiza como nota Obsidian con:

- Frontmatter con `entity_type: flow`, `confidentiality`, `flow_id`.
- Sección "Nodos" con un wikilink por cada nodo (que apunta al agente/skill/comando referenciado).
- Sección "Aristas" como tabla.
- Backlink desde cada agente/skill/comando referenciado al flujo que lo usa.

Cuando la metacúpula (vault de vaults) abra el workspace completo, los flujos aparecen como un cluster propio en el grafo de Obsidian, con conexiones explícitas a los nodos que componen. Por primera vez, la orquestación agéntica es visible como topología, no como código enterrado.

---

## 6. Criterios de Iteración y Cierre

- [ ] Slice 1: `flow-validate hello-world` pasa, 10 tests BATS verdes, tests Python CEL verdes.
- [ ] Slice 2: `flow-run hello-world` produce traza correcta.
- [ ] Slice 3: `code-review-court` migrado y ejecutándose en paralelo con tiempo ≤ 90% del actual.
- [ ] Slice 4: 3 flujos más migrados, vista Obsidian generada para los 5.
- [ ] Documentación: `docs/agentic-flow-graph.md` con ejemplo end-to-end.
- [ ] Decisión registrada en `docs/decisions/`: por qué AFG y no LangGraph.
- [ ] CHANGELOG actualizado.
- [ ] Gate CI: `flow-validate all` integrado en pre-commit.

---

## 7. Pregunta abierta para Mónica

Antes de aprobar la spec, dos decisiones que requieren tu input:

1. **Alcance Slice 4**: ¿la integración con la metacúpula Obsidian entra ya en este spec o se separa en spec hijo (SPEC-AFG-OBSIDIAN)? Argumento para separar: SPEC-128 todavía está en Slice 1 a Slice 3 según su estado; depender de él añade riesgo de bloqueo.

2. **Nodo `kind: subflow`**: ¿permitir desde Slice 1 o esperar a que haya 3-4 flujos reales en producción para ver si la composición se necesita? Argumento para esperar: YAGNI. La composición es la feature más fácil de añadir tarde y la más fácil de sobrediseñar pronto.
