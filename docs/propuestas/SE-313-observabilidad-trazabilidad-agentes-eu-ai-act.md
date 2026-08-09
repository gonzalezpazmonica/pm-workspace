---
id: SE-313
title: "SE-313 — Observabilidad y trazabilidad de flujos agénticos (OTel GenAI + EU AI Act)"
status: IMPLEMENTED
priority: media
---

# SE-313 — Observabilidad y trazabilidad de flujos agénticos (OTel GenAI + EU AI Act)

**Status:** IMPLEMENTED
**Fecha:** 2026-08-08
**Area:** Observability / Governance / Compliance
**Branch sugerida:** `agent/se313-observabilidad-trazabilidad`
**Estimacion total:** ~90h (8 slices)
**Inspiracion:** OpenTelemetry GenAI Semantic Conventions, AgentOps taxonomy (arXiv:2411.05285), OTel Agent SDK (Microsoft Agent Framework), SPEC-191 (aprobada, bloqueada), SE-275 (propuesta de audit trail), SPEC-058 (archivada), Reglamento (UE) 2024/1689 (EU AI Act)

---

## 0. Diagnóstico de contexto: gap de tiers (detonante de este spec)

Durante la sesión de análisis de este spec, la invocación del subagente `explore`
falló con `Model not found: deepseek-v4-pro/.`. Trabajamos con tiers
(heavy/mid/fast), y este fallo **no debería ocurrir ni pasar desapercibido**.

### Causa raíz verificada (2026-08-08, código leído)

1. `~/.savia/preferences.yaml` declara IDs **sin prefijo de provider**:
   ```yaml
   provider: deepseek
   model_heavy: deepseek-v4-pro
   model_mid:   deepseek-v4-pro
   model_fast:  deepseek-v4-flash
   ```

2. El plugin TS `savia-foundation.ts` (línea ~149) resuelve tiers → modelo
   SOLO cuando `agentDef.model` coincide con una **clave de tier**
   (`heavy|mid|fast`):
   ```ts
   if (agentDef?.model && tierMap[agentDef.model]) {
     agentDef.model = tierMap[agentDef.model];
   }
   ```

3. `opencode.json` hardcodea `"model": "deepseek-v4-pro"` en 70+ subagentes.
   Ese valor **no es una clave de tier**, por lo que el plugin **no lo traduce**
   y pasa roto (sin prefijo) al runtime. El registry del runtime (`opencode models`)
   solo contiene IDs prefijados: `deepseek/deepseek-v4-pro`, `deepseek/deepseek-v4-flash`.

4. El agente built-in `explore` (no definido en opencode.json) heredó la
   resolución rota y falló igual. El error `deepseek-v4-pro/.` (con `/` final)
   indica que el runtime intentó tratar el ID como `provider/model` y el modelo
   quedó vacío.

5. **Ninguno de los dos fallos dejó rastro** en telemetría:
   `lifecycle.jsonl` (3 líneas, `"agent":"unknown"`), `agent-traces.jsonl`
   (directorio inexistente), `telemetry-events.jsonl`/`otel-emit.sh` (no existen).

### Lección

El sistema de tiers existe (SPEC-127) y el plugin ya lo traduce, pero hay un
**desajuste de config**: `opencode.json` usa IDs rotos en vez de tier names, y
`preferences.yaml` guarda IDs sin prefijo. Además, el dispatch de subagentes no
está instrumentado. El **Slice 7** corrige los tres frentes.

**Regla derivada (se añade a `docs/rules/domain/model-alias-schema.md`)**: los
IDs en `preferences.yaml` DEBEN llevar prefijo de provider
(`deepseek/deepseek-v4-pro`); `opencode.json` DEBE usar tier names
(`"model": "mid"`) para que el plugin las traduzca; y todo dispatch de
subagente DEBE emitir un evento de telemetría.

---

## 1. Objetivo

Añadir observabilidad y trazabilidad de **primera clase** a todo el ecosistema
agéntico de Savia (agentes, hooks, tribunals, memoria, digestión, ciclo SDD),
usando el estándar emergente **OpenTelemetry GenAI Semantic Conventions** para
flujos agénticos, con **sampling tail-based** para control de coste/volumen, y
alineando el registro de eventos con los requisitos de **record-keeping del
Reglamento (UE) 2024/1689 (EU AI Act)**.

**Objetivo de negocio medible**:
- Tiempo medio de diagnóstico de fallos de agente: **>15 min → <3 min**
  (SPEC-191, retomado).
- 100% de los flujos de decisión de tribunal y fases SDD emiten evento
  estandarizado con `trace_id` (hoy: 0%).
- Cero fallos silenciosos de dispatch de subagentes (hoy: 2 observados en este
  análisis, sin registro).
- Trazabilidad EU AI Act Art. 12/26: todo evento relevante con modelo, versión,
  timestamp y resultado, retenido ≥ 6 meses, exportable a autoridad.

**Trade-off explícito**: la instrumentación es **local-first** (JSONL + OTLP
opt-in). Nada sale del workspace sin `SAVIA_OTLP_ENDPOINT` configurado (cero
telemetría externa por defecto — coherente con `README.md`: "MIT, no telemetry").

**Restricción de frontend (importante)**: en OpenCode nativo los hooks `.sh`
de `.claude/settings.json` NO se ejecutan — la instrumentación en tiempo real
se hace desde el plugin TS (`tool.execute.before/after`). Los hooks bash se
preservan para Claude Code y para scripts. El spec diseña ambas capas.

---

## 2. Estado actual (inventario verificado 2026-08-08)

| # | Activo | Tipo | Qué registra | Destino | Estado |
|---|--------|------|--------------|---------|--------|
| 1 | `agent-trace-log.sh` | Hook PostToolUse Task | agent, tokens (estimados char/4), duration, outcome | `projects/{proj}/traces/agent-traces.jsonl` | **No operativo** (directorio nunca creado) |
| 2 | `cognitive-debt-telemetry.sh` | Hook PostToolUse | tool, duration_ms, session | `~/.savia/cognitive-load/{user}.jsonl` | Dormant (opt-in) |
| 3 | `decision-trace-capture.sh` | Hook PostToolUse Task | decisiones por keyword | `output/decision-traces/` | Opt-in (`SAVIA_DECISION_TRACE=off`) |
| 4 | `subagent-lifecycle.sh` | Hook SubagentStart/Stop | start/stop, agent, id | `output/agent-lifecycle/lifecycle.jsonl` | Operativo pero degradado (3 líneas, agent=unknown) |
| 5 | `task-lifecycle.sh` | Hook TaskCreated/Completed | task events | `output/agent-lifecycle/lifecycle.jsonl` | Operativo |
| 6 | `anti-adulation-telemetry.jsonl` | Output | scores capa 1 | `output/` | Operativo |
| 7 | `judge-calibration.jsonl` | Output | hallazgos aceptados | `output/` | Operativo |
| 8 | `kokoro-telemetry.jsonl` | Output | TTS | `output/` | Operativo |
| 9 | `agent-budget-usage.jsonl` | Output | decisiones de coste | `data/` | Operativo |
| 10 | `_digest-log.md` por proyecto | Regla | idempotencia digestión | `projects/{proj}/` | Operativo (traza **fuente**, no decisión) |
| 11 | `spec-lifecycle.sh` | Script | estados de specs | scripts | Operativo |
| 12 | `trace-pattern-extractor.sh`, `trace-analyze`, `trace-optimize`, `trace-search` | Scripts/comandos | análisis de trazas | scripts/commands | Operativo (sobre datos existentes) |
| 13 | `scope-trace-gate.sh` (SE-079) | Gate PR | ficheros↔AC | scripts | **IMPLEMENTADO** |
| 14 | `decision-trace-writer.py` | Script | escritura decision traces | scripts | Opt-in |
| 15 | `savia-resolve-model` (SPEC-127) | Función bash | tier→model | `savia-env.sh` | Operativo, **gap de prefijo** |
| 16 | `savia-foundation.ts` (SPEC-127 S2b) | Plugin TS | traduce tier→model en config | `.opencode/plugins/` | Operativo, **gap de validación** |
| 17 | `native-delegation.yaml` | Config | permite `explore`/`general` | `config/` | Operativo (explore falló igual) |

### Formato actual de datos

- **JSONL** heterogéneo: cada hook define su propio schema. No hay `trace_id`,
  `span_id`, `parent_span_id` en ningún evento.
- **Sin jerarquía de spans**: una sesión dev con 5 slices produce líneas planas,
  no un árbol.
- **Sin modelo real**: `lifecycle.jsonl` no captura el modelo del LLM.
- **Tokens estimados** (char/4), no reales.
- **Dos capas de instrumentación incomunicadas**: hooks bash (Claude Code) y
  plugin TS (OpenCode nativo) no comparten schema ni destino.

---

## 3. Gaps (análisis)

### G1 — Sin contexto distribuido de traza
Ningún evento lleva `trace_id`/`span_id`/`parent_span_id`. Imposible reconstruir
`request usuario → orquestador → agente → tool → LLM` como un solo árbol.

### G2 — Sin jerarquía de spans agénticos
No existe el concepto de `invoke_agent` → `chat` → `execute_tool` (GenAI semconv).
Un agente que llama a otro agente produce líneas desconectadas.

### G3 — Sin captura de atributos GenAI
No se registra `gen_ai.system`, `gen_ai.request.model`, `gen_ai.response.model`,
`gen_ai.usage.*`, `gen_ai.agent.*`. Imposible: coste por agente, drift de modelo,
detección de tool-loops.

### G4 — Fallos silenciosos de orquestación
El dispatch de subagentes no está instrumentado. Los fallos
`Model not found` de este análisis **no dejaron rastro**. No hay gate que valide
que el tier→modelo resuelve en el runtime (ver Slice 7).

### G5 — Telemetría fragmentada y no estandarizada
~12 formatos JSONL propios, sin schema común, sin correlación entre señales
(logs↔traces↔métricas). `otel-emit.sh` (diseñado en SPEC-191) no existe.

### G6 — Sin sampling ni retención
No hay política de retención (salvo `_digest-log`), ni sampling, ni rotación.
Los JSONL crecen sin límite (SPEC-191 riesgo #5 ya lo señalaba).

### G7 — Sin alineación EU AI Act
Ningún evento registra: versión de modelo, timestamp de uso, resultado de
decisión, identificación de supervisión humana (Art. 14), o retención de logs
(Art. 26(6) ≥ 6 meses). No existe "registro de usos" exportable a autoridad.

### G8 — Sin audit-trail criptográfico
SE-275 (hash-chained audit trail) está PROPOSED, no implementado. No hay forma de
verificar que un veredicto de tribunal no fue alterado, ni cadena spec→merge.

### G9 — Instrumentación rota o degradada
- `agent-trace-log.sh` escribe a `projects/{proj}/traces/` que no existe (0 ficheros).
- `lifecycle.jsonl` captura `agent: "unknown"` (el hook lee `agent_type`, que no
  llega poblado desde el runtime).
- `telemetry-events.jsonl` y `otel-emit.sh` no existen.
- SPEC-191 (dashboard /telemetry) APPROVED pero **BLOCKED** en savia-web.

### G10 — Sin correlación con herramientas externas
Azure DevOps (WIQL, work items), memory-store, vaults y MCP no emiten eventos
telemetry. No se puede trazar "qué PBI tocó qué agente con qué modelo".

### G11 — Desajuste de config de tiers (causa raíz de G4)
`opencode.json` usa IDs sin prefijo en vez de tier names; `preferences.yaml`
guarda IDs sin prefijo; el plugin solo traduce tier names. Resultado: subagentes
con modelos irresolubles y fallos silenciosos.

---

## 4. Estado del arte (investigación 2026-08-08)

### 4.1 OpenTelemetry GenAI Semantic Conventions (convergencia de industria)
SIG activa desde abril 2024; repositorio `open-telemetry/semantic-conventions-genai`.
Cubre: LLM client spans, **agent spans**, events, metrics. Vendors (Datadog,
Honeycomb, New Relic) ya los soportan nativamente.

**Spans claves para Savia**:
- `invoke_agent {gen_ai.agent.name}` — span raíz de ejecución de agente.
  `gen_ai.operation.name=invoke_agent`, `gen_ai.agent.name/id/description`.
- `chat {system}` — llamada LLM: `gen_ai.system`, `gen_ai.request.model`,
  `gen_ai.response.model`, `gen_ai.usage.input_tokens/output_tokens`.
- `execute_tool {name}` — ejecución de tool: `gen_ai.tool.name`, `call.id`.
- Contenido de prompt/completions como **span events** (`gen_ai.content.prompt`)
  desactivables por privacidad.

**Métricas**: `gen_ai.client.token.usage`, `gen_ai.client.operation.duration`.

**Propagación**: W3C TraceContext (`traceparent`/`tracestate`) para trazas
distribuidas multi-agente.

### 4.2 OTel Agent SDK y Microsoft Agent Framework
El Agent Framework de Microsoft emite traces/logs/metrics según GenAI semconv y
se integra con OTel. Confirma que la dirección `invoke_agent`→`chat`→`execute_tool`
es la que la industria está adoptando para flujos agénticos.

### 4.3 AgentOps taxonomy (arXiv:2411.05285)
Taxonomía de artefactos y datos a trazar durante el ciclo de vida del agente:
configuración, razonamiento, acciones/herramientas, memoria, resultados.
Referencia para decidir QUÉ capturar, no solo CÓMO.

### 4.4 Sampling tail-based (recomendado para agentes)
Mantener 100% de trazas con error, >5s, o >20 spans (complejidad); muestrear
routine successes al 5-10%. Directamente aplicable (y barato) para agentes.

### 4.5 Backends OSS self-hosted
Jaeger, Grafana Tempo, OpenSearch, Langfuse (self-hosted), Arize Phoenix.
Compatibles con OTLP; permiten cumplir soberanía de datos (sin vendor cloud).

### 4.6 Marco legal: Reglamento (UE) 2024/1689 (EU AI Act)

Timeline clave (aplicabilidad): prohibiciones 2-feb-2025; GPAI 2-ago-2025;
**high-risk (Cap. III) 2-ago-2026**; resto 2-ago-2027.

| Artículo | Requisito | Impacto en Savia |
|---|---|---|
| **Art. 12 Record-keeping** | Sistemas high-risk deben permitir registro automático de eventos (logs) durante su vida útil; logs para identificar situaciones de riesgo, post-market monitoring y supervisión. | Savia NO es high-risk hoy (assistant de productividad), pero diseñar logging desde ahora evita retrofits. |
| **Art. 26(6) Obligaciones deployer** | Conservar logs generados automáticamente **≥ 6 meses** | Política de retención de telemetría ≥ 6 meses. |
| **Art. 14 Human oversight** | Supervisión humana: detectar anomalías, evitar automation bias, override/interrupción. | Los tribunals y gates deben registrar quién/cuándo se supervisó. |
| **Art. 50 Transparencia** | Informar que se interactúa con IA; marcar outputs generados como IA. | Los informes/outputs de agentes deben poder marcarse como generados por IA. |
| **Art. 53 GPAI providers** | Documentación técnica del modelo, capacidades/limitaciones, resumen de training data. | Registrar `gen_ai.response.model` en cada evento → auditable. |
| **Art. 86 Right to explanation** | Explicación clara del rol de la IA en decisiones que afecten a personas. | La cadena de decisión (spec→implementación→review) debe ser reconstruible. |

**Postura de Savia**: aunque hoy opera como sistema de productividad interna de
bajo riesgo, la alineación con Art. 12/26/50 es **defensa en profundidad** y
habilita adopción enterprise / SaaS. El spec adopta record-keeping como diseño,
no como respuesta a una sanción.

---

## 5. Diseño propuesto

### 5.1 Evento estándar `savia.event` (JSONL + schema)

Schema mínimo unificado (W3C traceparent + GenAI semconv subset):

```json
{
  "schema": "savia.event/1.0",
  "ts": "2026-08-08T21:30:00Z",
  "trace_id": "hex-32",
  "span_id": "hex-16",
  "parent_span_id": "hex-16",
  "event": "agent.completed",
  "session_id": "mon-1234",
  "kind": "invoke_agent|chat|execute_tool|tribunal|hook|memory|digest|sdd|dispatch",
  "status": "ok|error|partial",
  "agent": {"name": "dotnet-developer", "tier": "mid", "id": "..."},
  "gen_ai": {
    "system": "deepseek|anthropic|...",
    "request_model": "deepseek/deepseek-v4-pro",
    "response_model": "deepseek/deepseek-v4-pro",
    "usage": {"input_tokens": 4200, "output_tokens": 2100},
    "agent": {"name": "dotnet-developer", "operation": "invoke_agent"}
  },
  "tool": {"name": "Edit", "target": "src/UserService.cs", "call_id": "..."},
  "task": {"spec_ref": "AB#1234", "slice": 1},
  "duration_ms": 45230,
  "outcome": "success|failure|partial",
  "error_summary": "opcional, redactado",
  "retention_days": 180
}
```

Reglas de redacción (heredadas de SPEC-191 riesgo #6 + context-placement):
- `session_id` truncado a 8 chars.
- Paths absolutos → `{project}`.
- `SAVIA_TELEMETRY_REDACT=1` → solo `ts` + `event`.
- Contenido de prompts SIEMPRE como evento aparte opt-in, nunca en span attrs.

### 5.2 Jerarquía de spans (referencia)

```
Trace: /dev-session AB#1234
  └─ Span: invoke_agent dev-orchestrator
     ├─ Span: execute_tool Task → dotnet-developer
     │  └─ Span: invoke_agent dotnet-developer
     │     ├─ Span: chat deepseek  (gen_ai.usage, model)
     │     └─ Span: execute_tool Edit (src/UserService.cs)
     ├─ Span: invoke_agent test-engineer
     └─ Span: invoke_agent code-reviewer  (tribunal verdict)
```

### 5.3 Pipeline local-first (dos capas)

```
CAPA A — OpenCode nativo (plugin TS):
  tool.execute.before/after ──► guard dispatch-trace ──► output/telemetry-events.jsonl

CAPA B — Claude Code / scripts (bash):
  hooks (.claude/hooks/*.sh) ──► scripts/otel-emit.sh ──► output/telemetry-events.jsonl

Ambas capas ──► tail-sampling (rotate + retain ≥180d) ──► opt-in OTLP collector
```

Schema y destino compartidos: cualquier capa puede escribir; el sampling y la
redacción se aplican en lectura/rotación.

### 5.4 Componentes

| Nombre | Tipo | Propósito |
|---|---|---|
| `scripts/otel-emit.sh` | Bash | Emite eventos estándar con trace_id auto-generado o heredado |
| `scripts/savia-trace.sh` | Bash | Helper: inicia/cierra spans, propaga traceparent |
| `scripts/telemetry-tail-sample.sh` | Bash | Aplica políticas de sampling + rotación + retención |
| `config/telemetry-schema.json` | JSON | Schema validable de `savia.event` |
| `config/telemetry-policies.yaml` | YAML | Sampling %, retención, redacción |
| `scripts/trace-export-otlp.sh` | Bash | Convierte JSONL → OTLP (opt-in) |
| `.opencode/plugins/guards/dispatch-trace.ts` | Plugin guard | Instrumenta dispatch de subagentes en OpenCode nativo |
| `/telemetry` (savia-server) | Endpoint | Retoma SPEC-191 (depende de savia-web) |

---

## 6. Slices de implementación

### S1 — Schema + `otel-emit.sh` + hooks base (16h)
- Definir `config/telemetry-schema.json` (schema 1.0).
- Escribir `scripts/otel-emit.sh` (SPLIT de SPEC-191 Slice 3, ahora agnóstico de savia-web).
- Corregir `agent-trace-log.sh`: escribir a `output/agent-traces.jsonl` (destino
  real), campos estándar, `|| true` nunca bloquea.
- Integrar en 3 hooks existentes (subagent-lifecycle, task-lifecycle, agent-trace-log).
- BATS tests ≥ 80.
- AC: `otel-emit.sh agent.completed ...` produce JSON válido; `jq empty` exit 0.

### S2 — Contexto distribuido de traza (14h)
- `scripts/savia-trace.sh`: genera trace_id/span_id (W3C), hereda de `traceparent`.
- Hook SessionStart emite `session.started` con trace_id raíz.
- Hook PostToolUse Task propaga trace_id al subagente (env `SAVIA_TRACEPARENT`).
- En OpenCode: `dispatch-trace` guard inyecta `SAVIA_TRACEPARENT` en el input
  del Task tool y registra el span padre.
- AC: una sesión con 2 agentes produce un único trace_id compartido.

### S3 — Atributos GenAI + modelo real (12h)
- Capturar `gen_ai.system/request_model/response_model/usage` en eventos de agente.
- Resolver el modelo real del tier vía `savia_resolve_model` (corrige "unknown").
- AC: `lifecycle.jsonl` deja de emitir `agent:"unknown"`.

### S4 — Sampling + retención + rotación (10h)
- `config/telemetry-policies.yaml`: retención ≥ 180 días (Art. 26(6)), rotación a los 10k líneas, sampling tail (errores 100%, slow >5s 100%, >20 spans 100%, routine 5%).
- AC: archivo >10k líneas se rota; política exportable.

### S5 — Redacción + clasificación N1-N4b (8h)
- Aplicar redacción (session truncado, paths→{project}, `SAVIA_TELEMETRY_REDACT`).
- Validación de que span attrs nunca contienen PII (reutilizar block-credential-leak).
- AC: `SAVIA_TELEMETRY_REDACT=1` emite solo `ts`+`event`.

### S6 — Audit trail + cadena spec→merge (14h)
- Implementar SE-275 S1 (hash-chained audit trail) para tribunals + fases SDD.
- Envelope estandar (SE-275 S3) en los 3 orchestrators.
- AC: verificar integridad de cadena con `audit-chain-verify.sh`.

### S7 — **Dispatch de subagentes: corrección de tiers + telemetría** (10h) ← gap de modelos
Tres frentes (resuelve G4 + G11):

**7a. Corregir `preferences.yaml`** → IDs con prefijo de provider:
```yaml
model_heavy: deepseek/deepseek-v4-pro
model_mid:   deepseek/deepseek-v4-pro
model_fast:  deepseek/deepseek-v4-flash
```
El plugin TS y `savia_resolve_model` leen el mismo fichero → ambos corregidos.

**7b. Normalizar `opencode.json`** → usar tier names (`heavy|mid|fast`), no IDs:
```json
"dotnet-developer": { "model": "mid", "mode": "subagent", ... }
```
El plugin las traduce a los IDs prefijados del preferences (PV-06: sin vendor
names hardcodeados). Para agentes sin tier claro se usa el del catálogo
(`docs/rules/domain/agents-catalog.md`).

**7c. Gate + telemetría de dispatch**:
- Nuevo guard `dispatch-trace` (plugin TS) + `scripts/subagent-dispatch-gate.sh`
  (bash): ANTES del Task tool resuelve `tier→model` vía `savia_resolve_model`,
  verifica que el ID existe en el runtime (cache de `opencode models` en
  `config/model-registry.json`), y registra `dispatch.resolved` o
  `dispatch.failed` con `requested_model`/`resolved_model`/`error` + trace_id.
- El plugin guard aplica en OpenCode nativo; el script bash en Claude Code y CI.
- `savia_resolve_model`: si el ID devuelto no lleva `provider/`, se prefija con
  `provider:` del preferences (defensa ante futuros valores sin prefijo).

**AC-S7**:
- [x] AC-7.1: `savia_resolve_model mid` devuelve `deepseek/deepseek-v4-pro` (con prefijo).
- [x] AC-7.2: `subagent-dispatch-gate.sh` detecta un ID no resolubible y emite
  `dispatch.failed` con error claro (no `Model not found` opaco).
- [x] AC-7.3: un fallo de dispatch aparece en `output/telemetry-events.jsonl` con
  trace_id de la sesión (cero fallos silenciosos).
- [x] AC-7.4: `opencode.json` no contiene IDs hardcodeados sin prefijo (solo tier names).
- [x] AC-7.5: `config/model-registry.json` cachea `opencode models` y el gate lo usa.
- [x] AC-7.6: reproducción del escenario original (invocar `explore`/subagente con
  modelo roto) → `dispatch.failed` registrado, no silencioso.
- [x] AC-7.7: built-in agents (`explore`, `general`) también pasan por el gate.

### S8 — Endpoint `/telemetry` + dashboard (retoma SPEC-191) (16h)
- Solo si savia-web está disponible; si no, slice se degrada a informe estático
  (`output/telemetry-report-{date}.md`).
- AC: mismo bloque de SPEC-191.

---

## 7. Dependencias

- **S2 → S1**: trace context necesita schema.
- **S3 → S2**: atributos GenAI se registran en spans existentes.
- **S6 → S2**: el audit trail referencia trace_id.
- **S7 → S3**: el gate de dispatch alimenta `gen_ai.request_model`.
- **S7 → SPEC-127**: corrige el gap de prefijo en `savia_resolve_model` y en el plugin.
- **S7 → `opencode.json`/`preferences.yaml`**: cambios de config requieren
  reinicio de opencode (no se recarga en caliente).
- **S8 → SPEC-191**: retoma dashboard; depende de savia-web.
- **No requiere**: nuevos agentes, ni dependencias runtime (bash + jq + python3).

---

## 8. Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Overhead de I/O en hooks (append JSONL) | Alta | Bajo | Append O(1); <10ms en bash; async donde sea posible |
| JSONL crece sin límite | Media | Medio | Rotación automática + policies (S4) |
| Fallo silencioso del propio otel-emit | Media | Medio | Exit codes + `|| true` nunca bloquean; error visible en hook threshold |
| PII en telemetría | Media | Alto | Redacción (S5) + reuso de block-credential-leak; N1-N4b |
| Cambiar `opencode.json` rompe dispatch existente | Media | Alto | S7 usa tier names que el plugin traduce; validación `opencode models`; probar con 1 agente antes de masivo |
| `opencode.json` con tier names no traducidos si el plugin falla | Baja | Alto | Fallback: `savia_resolve_model` en el gate; el gate WARN visible antes de dispatch |
| Sampling pierde trazas raras pero críticas | Baja | Medio | Tail sampling: errores y slow siempre 100% |
| Reinicio de opencode olvidado tras S7 | Media | Medio | El gate detecta modelos no resueltos y advierte; recordatorio en el AC |

---

## 9. Criterios de aceptación (resumen)

- [x] **AC-S1**: `otel-emit.sh` existe, validado por BATS, integrado en ≥3 hooks.
- [x] **AC-S2**: `trace_id` compartido en cadena sesión→agente→tool; `traceparent` propagado.
- [x] **AC-S3**: eventos con `gen_ai.request_model`/`response_model` reales; fin de `agent:"unknown"`.
- [x] **AC-S4**: retención ≥180d configurada y rotación operativa.
- [x] **AC-S5**: redacción validada; `SAVIA_TELEMETRY_REDACT=1` degrada a mínimo.
- [x] **AC-S6**: 3/3 tribunales emiten hash-chained entries (SE-275 S1); `audit-chain-verify.sh` pasa.
- [x] **AC-S7**: dispatch gate + telemetría operativos; ningún `Model not found` silencioso (AC-7.1..7.7).
- [x] **AC-S8**: `/telemetry` o informe estático generado.
- [ ] **AC-EU**: informe de alineación con Art. 12/26(6)/14/50/86 en
      `docs/rules/domain/eu-ai-act-traceability.md`.

---

## 10. Métrica de éxito

- **S1-S5**: ≥80% de los eventos de agentes/tribunals/hooks tienen trace_id válido.
- **S7**: 0 fallos silenciosos de dispatch en 4 semanas de uso normal.
- **EU**: inventario de alineación Art. 12/26(6) documentado y exportable.
- Tiempo de diagnóstico de fallo: **>15min → <3min** medido sobre 5 incidentes.

---

## 11. OpenCode Implementation Plan

### Clasificación
- **Type**: Scripts bash + plugin TS + config + (opcional) frontend.
- **Autonomy**: L1-L2 por slice; S7 y S8 requieren revisión humana (config del
  runtime del frontend / savia-web).
- **Reversibility**: Alta — todos los componentes son additive; el pipeline
  funciona sin S8.

### Bindings
| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| `scripts/otel-emit.sh` | Bash | idéntico |
| `scripts/savia-trace.sh` | Bash | idéntico |
| `config/telemetry-*.json/yaml` | cualquier motor | idéntico |
| `subagent-dispatch-gate.sh` | bash hook | idéntico (script) |
| `dispatch-trace` guard | — | plugin TS (`tool.execute.before/after`) |
| hooks | `.claude/hooks/*.sh` | plugin TS `hook_event` |
| `opencode.json`/`preferences.yaml` (S7) | humano | idéntico |
| `/telemetry` (S8) | HUMAN-SUPERVISED | idéntico |

### Portability
- [x] **DUAL_BINDING**: scripts bash y config agnósticos de frontend; S7 depende
      de `opencode models` (OpenCode) — se provee fallback a `preferences.yaml`.

---

## 12. Referencias

- OTel GenAI Semantic Conventions: https://github.com/open-telemetry/semantic-conventions-genai
- AgentOps taxonomy: https://arxiv.org/abs/2411.05285
- Microsoft Agent Framework observability (OTel Agent SDK):
  https://learn.microsoft.com/en-us/agent-framework/agents/observability
- OTel Agent observability guide (Zylos, 2026): https://zylos.ai/research/2026-02-28-opentelemetry-ai-agent-observability/
- SPEC-191 (dashboard /telemetry, retomado en S8): `docs/propuestas/SPEC-191-savia-telemetry.md`
- SE-275 (audit trail hash-chained, implementado en S6): `docs/propuestas/SE-275-trust-gated-audit-trail.md`
- SPEC-058 (archivado, superseded): `docs/propuestas/SPEC-058-opentelemetry-agent-tracing.md`
- EU AI Act (Reglamento UE 2024/1689) — Art. 12, 26(6), 14, 50, 53, 86: https://ai-act-law.eu/
- SPEC-127 (tier-based model resolution): `scripts/savia-env.sh` línea ~147 + `.opencode/plugins/savia-foundation.ts`
