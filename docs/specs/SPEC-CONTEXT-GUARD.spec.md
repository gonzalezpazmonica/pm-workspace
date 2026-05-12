# Spec: Context Guard — Summarization automática del contexto agéntico

**Task ID:**        WORKSPACE
**PBI padre:**      Era próxima — Gestión automática de ventana de contexto
**Sprint:**         2026-31
**Fecha creación:** 2026-05-09
**Creado por:**     Mónica

**Developer Type:** agent-team
**Asignado a:**     claude-agent-team
**Estimación:**     8h (2 slices × 4h)
**Estado:**         Pendiente

**Depende de:**     Rule #26 Language Boundaries
**Inspirado por:**  achetronic/magec — capacidad nativa "Context guard: automatic context window management with LLM-powered summarization". Concepto adoptado, código no.

**Contexto de ejecución:** Savia opera dentro de OpenCode. OpenCode gestiona la ventana de contexto del modelo a su nivel (truncamiento, compactación), pero esa gestión es opaca al ecosistema de agentes Savia y no está alineada con sus convenciones de memoria, niveles de confidencialidad ni reglas SDD. ContextGuard introduce una capa de gestión propia de Savia que opera ANTES de que OpenCode tenga que truncar nada: cuando un agente o flow se acerca a un umbral configurable, Savia genera un summary estructurado del contexto pasado y lo sustituye por la versión summarizada, conservando los inputs/outputs recientes intactos.

**Decisión arquitectónica registrada:**
- (D-1) ContextGuard es OPCIONAL y declarativo. Se activa por agente o por flow vía frontmatter; sin declaración, no se aplica.
- (D-2) ContextGuard NO compite con la gestión de OpenCode. Opera ANTES, en una capa de Savia, con criterios alineados a las convenciones del repo.
- (D-3) El umbral se expresa en porcentaje del context window del tier en uso, NO en tokens absolutos. Esto sobrevive cambios de modelo.
- (D-4) La summarization la realiza un agente especializado (`context-summarizer`), invocable vía tier `fast` por defecto. El operador puede elevar a `mid` o `heavy` para summaries críticos.
- (D-5) **El summary preserva metadata estructurada** (turn count, decisiones tomadas, artifacts producidos, errores) además de la prosa. Recuperable vía API.
- (D-6) Implementación en Python. Bash solo envoltorio. Conforme a Rule #26.
- (D-7) **Expone MCP server** (`savia-context-guard`) con tools para invocar summarization sobre cualquier conversación, no solo en el contexto de un flow.
- (D-8) Respeta la confidencialidad. Un summary de un flow N4 es N4. Nunca se exfiltra summary a niveles inferiores.

---

## 1. Contexto y Objetivo

### 1.1 Problema

Cuando un agente o flow acumula contexto largo (conversación extensa con el usuario, output voluminoso de tools, iteraciones de loop con muchos resultados intermedios), pasan tres cosas indeseables:

1. **El modelo pierde atención sobre instrucciones tempranas.** Lo que dijo el system prompt o el primer mensaje del usuario queda sepultado.
2. **El coste por token sube linealmente con el contexto acumulado.** Un flow de 20 nodos donde cada nodo añade 2K tokens al contexto consume 40K extra en el último nodo respecto al primero, en cada llamada al modelo.
3. **OpenCode acaba truncando.** Cuando se choca con el límite del modelo, OpenCode aplica su propia heurística de truncamiento, que es ajena a las convenciones de Savia (niveles de confidencialidad, decisiones SDD registradas, artifacts producidos, etc.). El truncamiento es opaco y a veces destruye contexto crítico que Savia habría preservado.

Magec lo resuelve con un componente nativo llamado ContextGuard: cuando el contexto se acerca al umbral, lanza una summarization vía LLM, sustituye el bloque temprano por el summary y deja los turnos recientes intactos. El operador configura por agente: umbral de activación, agente de summarization, política de retención de turnos recientes.

### 1.2 Objetivo

Construir Context Guard de Savia: un componente que se acopla al ciclo de vida de los agentes y flows, monitoriza el tamaño del contexto, y antes de chocar con el límite genera un summary estructurado y compacta el contexto manteniendo intactos los turnos más recientes.

Tras esta spec:

1. Un agente declara `context_guard: { enabled: true, threshold_pct: 75, recent_turns: 5 }` en su frontmatter y la summarization se activa automáticamente.
2. Un flow declara la misma configuración a nivel de root y todos sus nodos la heredan (overridable por nodo).
3. Cuando se dispara la summarization, queda registrada en la traza JSONL como evento `context.summarized` con metadata.
4. El summary es accesible programáticamente: cualquier agente puede consultar "¿qué pasó en los turnos summarizados?" sin tener que reconstruirlo.

### 1.3 No-Goals

- ❌ NO se reemplaza la gestión de contexto de OpenCode. ContextGuard opera ANTES; si aún así se choca, OpenCode hace lo suyo.
- ❌ NO se introduce streaming de summarization (incremental durante la ejecución). En este slice: summarization invocada en puntos discretos.
- ❌ NO se sumariza nunca el system prompt, las reglas activas ni el frontmatter. Solo turnos de conversación.
- ❌ NO se cuenta tokens manualmente. Se delega a una librería tokenizer mantenida (`tiktoken` para Anthropic/OpenAI; equivalente para DeepSeek si está disponible).
- ❌ NO se cubren llamadas LLM individuales fuera del contexto agéntico de Savia.

---

## 2. Requisitos Funcionales

### 2.1 Configuración por agente o flow

```yaml
# .opencode/agents/long-running-researcher.md (frontmatter)
---
name: long-running-researcher
context_guard:
  enabled: true
  threshold_pct: 75            # disparar summarization al 75% del context window
  recent_turns: 5              # preservar últimos 5 turnos sin tocar
  summarizer_tier: fast        # fast | mid | heavy
  preserve_artifacts: true     # NO summarizar bloques marcados como artifact
---
```

```yaml
# .scm/flows/long-research-flow.flow.yaml
flow_id: long-research-flow
context_guard:
  enabled: true
  threshold_pct: 70
  recent_turns: 3
  summarizer_tier: fast
nodes:
  - id: deep-search
    kind: agent
    invoke: researcher
    context_guard: { recent_turns: 10 }   # override por nodo
```

### 2.2 Disparo

El motor de Savia (al ejecutar agentes o flows) consulta el `tokenizer` apropiado para el modelo en uso (resuelto por OpenCode según tier) y mide el tamaño actual del contexto antes de cada llamada. Si supera `threshold_pct * context_window`, dispara el summarizer:

1. Aparta los últimos `recent_turns` turnos.
2. Pasa todo lo anterior al `context-summarizer` (un agente especializado).
3. Sustituye el bloque por el summary devuelto.
4. Registra en la traza JSONL: evento `context.summarized` con `tokens_before`, `tokens_after`, `summarizer_tier`, `summary_id`.

### 2.3 Agente `context-summarizer`

Agente especializado nuevo, invocable vía tool. Su prompt fija una plantilla estricta para el output:

```yaml
summary_v1:
  turn_count: <int>
  time_span:
    first_turn_at: <ISO-8601>
    last_turn_at: <ISO-8601>
  key_decisions:
    - <string>
  artifacts_produced:
    - { id, kind, location }
  errors_encountered:
    - { type, message }
  tools_invoked:
    - { name, count }
  prose_summary: |
    <markdown>
```

Esta estructura es CRÍTICA: el summary no es solo prosa. Es metadata recuperable. Otros agentes pueden consultar "¿qué decisiones se tomaron antes?" o "¿qué artifacts hay disponibles?" sin tener que parsear la prosa.

### 2.4 Almacenamiento del summary

El summary se persiste en `output/context-guard/{run_id}/summary-{N}.yaml` (donde N es el número de summary, ya que un flow largo puede generar varios). Y se registra en el state del agente/flow bajo el namespace `runtime:` (siguiendo SPEC-AGENTIC-FLOW-GRAPH AMENDMENT-01):

```yaml
runtime:
  context_guard:
    summaries_count: 2
    last_summary_id: "summary-002"
    last_summary_at: "2026-05-09T14:30:00Z"
```

### 2.5 Tool `recall_summary`

Skill nueva accesible para cualquier agente que necesite mirar atrás:

```
recall_summary(run_id, summary_id?) → SummaryV1
```

Si `summary_id` se omite, devuelve el último. Permite que un agente consulte "qué pasó antes" sin reinflar el contexto entero.

### 2.6 Arquitectura

Conforme a Rule #26 y al contexto OpenCode:

**Markdown OpenCode (prompts):**
- `.opencode/agents/context-summarizer.md` — agente con prompt estricto que produce summary_v1.
- `.opencode/skills/context-guard-recall/SKILL.md` — guía para usar `recall_summary`.

**Lógica Python — `scripts/lib/context_guard/`:**
- `__init__.py`
- `monitor.py` — mide tamaño de contexto, decide cuándo disparar.
- `tokenizer.py` — wrapper sobre `tiktoken` y equivalentes; mapea tier→tokenizer.
- `summarizer.py` — invoca al agente `context-summarizer` vía API, recibe summary_v1, valida estructura.
- `store.py` — persistencia de summaries en `output/context-guard/`.
- `mcp_server.py` — expone `summarize(turns)`, `recall_summary(run_id, summary_id)`.
- `cli.py` — punto de entrada.
- `requirements.txt` — `tiktoken`, `pydantic`, `pyyaml`, MCP SDK.

**Wrappers bash (≤ 15 líneas cada uno):**
- `scripts/context-guard-recall.sh` — invoca `python3 -m context_guard recall ...`.

**Hook OpenCode:**
- `.opencode/hooks/context-guard-monitor.{sh,ts}` — se dispara antes de cada llamada al modelo en agentes/flows con `context_guard.enabled: true`. Convención SPEC-127 portabilidad.

### 2.7 Validación de la plantilla summary_v1

El parser de summary rechaza outputs que no cumplan la estructura. Si el `context-summarizer` devuelve algo malformado, se reintenta una vez (con tier elevado si el original era `fast`). Si vuelve a fallar: fallo explícito con error en stderr y traza, NO summarization silenciosa rota.

### 2.8 Confidencialidad

El summary hereda el nivel de confidencialidad del agente o flow que lo originó. Si un flow declara `confidentiality: N4`, los summaries quedan bajo `output/context-guard/N4/{run_id}/...` y los hooks de confidencialidad existentes los protegen. Nunca se exporta un summary a un nivel inferior.

---

## 3. No se modifica

- Gestión de contexto interna de OpenCode.
- Ningún agente existente.
- SPEC-AGENTIC-FLOW-GRAPH (ContextGuard se acopla por hook, no requiere cambios al motor).
- Convenciones de memoria L0-L3 existentes.
- Niveles de confidencialidad N1-N4b.

---

## 4. Criterios de Aceptación

**Slice 1 — Monitor + summarizer básico:**
- [ ] `context_guard` declarable en frontmatter de agente.
- [ ] Monitor mide tokens correctamente para tiers heavy/mid/fast (al menos 3 modelos validados).
- [ ] Disparo automático al superar `threshold_pct` confirmado en test integración.
- [ ] Agente `context-summarizer` funcional con plantilla summary_v1.
- [ ] Summary persistido en `output/context-guard/{run_id}/`.
- [ ] Evento `context.summarized` en traza JSONL.
- [ ] Tests pytest: 18 casos.

**Slice 2 — Integración con flows + recall + MCP:**
- [ ] `context_guard` declarable a nivel de flow root y por nodo (override).
- [ ] Skill `context-guard-recall` accesible desde otros agentes.
- [ ] MCP server `savia-context-guard` funcional.
- [ ] Confidencialidad respetada: summary de flow N3 NO accesible desde N1.
- [ ] Test E2E: flow de 15 nodos con outputs voluminosos NO choca con context limit.
- [ ] Tests pytest: 12 casos adicionales.
- [ ] Documentación: `docs/context-guard.md`.

---

## 5. Ficheros a Crear/Modificar

**Crear (Python — lógica):**
- `scripts/lib/context_guard/__init__.py`
- `scripts/lib/context_guard/monitor.py`
- `scripts/lib/context_guard/tokenizer.py`
- `scripts/lib/context_guard/summarizer.py`
- `scripts/lib/context_guard/store.py`
- `scripts/lib/context_guard/mcp_server.py`
- `scripts/lib/context_guard/cli.py`
- `scripts/lib/context_guard/requirements.txt`
- `tests/python/test_context_guard_monitor.py`
- `tests/python/test_context_guard_tokenizer.py`
- `tests/python/test_context_guard_summarizer.py`
- `tests/python/test_context_guard_store.py`
- `tests/python/fixtures/context-guard/`

**Crear (Bash — envoltorios):**
- `scripts/context-guard-recall.sh` (≤ 15 líneas)
- `tests/context-guard-wrapper.bats`

**Crear (markdown OpenCode — prompts):**
- `.opencode/agents/context-summarizer.md`
- `.opencode/skills/context-guard-recall/SKILL.md`

**Crear (hooks OpenCode):**
- `.opencode/hooks/context-guard-monitor.{sh,ts}` (convención SPEC-127)

**Crear (schemas y docs):**
- `schemas/summary-v1.schema.json`
- `docs/context-guard.md`

**Modificar:**
- `docs/rules/domain/agents-catalog.md`: añadir entrada `context-summarizer`.
- `CHANGELOG.md`.

---

## 6. Dependencias y Riesgos

**Dependencias:** Python ≥ 3.10, `tiktoken` (Anthropic/OpenAI tokenization), `pydantic`, `pyyaml`, MCP SDK Python. Sin dependencias del lado del servidor.

**Riesgos:**

| Riesgo | Mitigación |
|---|---|
| **Coste de la summarization en flows muy largos.** Cada disparo invoca un LLM, lo que añade coste. | Tier `fast` por defecto. Monitorización: si `summaries_count > 5` en un flow, registrar warning en traza para que el operador revise el diseño del flow (probablemente está mal descompuesto). |
| **Summary mal generado destruye contexto crítico.** El summarizer omite información que después era necesaria. | Plantilla estricta `summary_v1` exige metadata estructurada (decisiones, artifacts, errores). El summary preserva los hechos accionables, no solo prosa. Recall API permite consultar metadata sin re-inflar. |
| **Tokenizer mal mapeado.** Un modelo nuevo no tiene tokenizer disponible y el monitor mide mal. | `tokenizer.py` mapea tier→modelo→tokenizer con fallback explícito. Si no hay tokenizer disponible, ContextGuard se desactiva para ese modelo concreto y emite warning, NO falla silenciosamente. |
| **Loops infinitos de summarization.** Si el threshold es muy bajo, cada turno dispara summarize. | Validador rechaza `threshold_pct < 50`. Hard floor en 50%. |
| **Latencia añadida.** La summarization añade segundos. | Documentado. Trade-off explícito: latencia vs preservación de contexto. Operador decide vía `enabled: true/false`. |
| **El agente `context-summarizer` se vuelve un monolito** (irónico, justo el problema que resuelve SPEC-AGENT-ARCHITECT). | Prompt corto y enfocado. Plantilla estricta de output. Tests cubren que el prompt cabe en <100 líneas. Auto-evaluable con `agent-architect`. |

---

## 7. Impacto en Roadmap

- **Habilita flows largos sin context overflow.** Sin ContextGuard, AFG está limitado a flows pequeños o a OpenCode truncando opacamente.
- **Integración natural con SPEC-AGENTIC-FLOW-GRAPH.** Las trazas con `context.summarized` permiten análisis de qué flows necesitaron compactación. Conecta también con SPEC-FLOW-OBSERVABILITY: span OTel `savia.context.summarized` exportable.
- **Beneficia conversaciones largas con el usuario**, no solo flows. Cualquier agente con `context_guard.enabled: true` lo aprovecha.
- **Sienta la base para un módulo A2A futuro.** Magec expone agentes vía A2A; cuando Savia explore esa interoperabilidad, los summaries son la pieza que permite handoff entre agentes (un agente Savia pasa su summary a un agente externo en lugar de su contexto entero, preservando privacidad).
- **Slices futuros opcionales:**
  - Streaming de summarization (incremental durante la ejecución).
  - Summary diff: detectar cambios entre summaries sucesivos.
  - Auto-tuning de `threshold_pct` basado en histórico.
