---
spec_id: SPEC-191
title: "Savia Telemetry — OpenTelemetry Observability Dashboard"
status: APPROVED
tier: 1B
effort: TBD
era: 199
origin: user-request-2026-06-06
version_draft: 1
related_specs:
  - SPEC-190 (Application Code Twin — lifecycle.jsonl como fuente de datos compartida)
  - SPEC-186 (Double Opt-in — gates autónomos protegen workflows de agentes)
  - SPEC-162 (Knowledge Graph — entidades trazables desde telemetría)

triage_note: "BLOCKED: depends on savia-web infrastructure"
---

# SPEC-191 — Savia Telemetry
## OpenTelemetry Observability Dashboard

> Estado: PROPOSED · Tier 1B · Era 199
> Origen: petición directa 2026-06-06
> Referencia técnica: [opencode-plugin-otel v1.1.0](https://github.com/DEVtheOPS/opencode-plugin-otel) (MIT)

---

## Objetivo

Añadir observabilidad completa al ecosistema Savia — agentes, skills, hooks,
memoria, workspace y sprint — exponiendo las tres señales OpenTelemetry
(trazas, métricas y logs) a través de una nueva página `/telemetry` en
savia-web.

**Objetivo de negocio medible**: tras el despliegue de SPEC-191, el tiempo
medio de diagnóstico de fallos en ejecuciones de agentes pasa de >15 min
(búsqueda manual en logs) a <3 min (consulta directa al panel). Métrica de
referencia: tiempo transcurrido entre `agent.failed` detectado y causa
identificada, medido sobre los 5 incidentes post-despliegue.

**Trade-off explícito**: la telemetría web-side usa `PerformanceObserver` +
`Date.now()` para latencias de bridge calls — no instrumentación de kernel.
La precisión es ±5 ms, suficiente para p50/p95 operacionales. La colección
de datos de agentes depende de que `output/agent-lifecycle/lifecycle.jsonl`
esté escrito por los hooks de pm-workspace (ya existe, confirmado en
savia-monitor `CLAUDE.md`). Si un hook no llama a `otel-emit.sh`, ese evento
no aparece en telemetría — esto es un scope-limit, no un bug.

---

## Principios afectados

- **#3 Transparencia** — Toda la actividad de agentes y hooks queda visible
  y auditable sin necesidad de leer logs crudos.
- **#5 Humans decide** — El dashboard es de solo lectura. No expone controles
  de ejecución. Los datos son observacionales, no normativos.
- **#9 Supervised execution** — Los hooks que emiten telemetría no cambian su
  comportamiento ni sus side-effects. `otel-emit.sh` solo escribe a un JSONL.
- **#11 Context efficiency** — El polling al bridge es configurable (default
  30 s). El store mantiene máx 50 spans en memoria. Sin SSE permanente.

---

## Diseño

### Visión general — tres capas

```
┌─────────────────────────────────────────────────────────────────────┐
│  CAPA 1: INSTRUMENTACIÓN                                            │
│                                                                     │
│  savia-web (browser)          pm-workspace (bash/shell)             │
│  ┌─────────────────────┐      ┌──────────────────────────────────┐  │
│  │ useBridge.ts        │      │ .opencode/hooks/*.sh             │  │
│  │  → span per request │      │  → llaman otel-emit.sh           │  │
│  │                     │      │                                  │  │
│  │ useSSE.ts           │      │ scripts/memory-store.sh          │  │
│  │  → span per stream  │      │  → llama otel-emit.sh (R/W)      │  │
│  │                     │      │                                  │  │
│  │ useTelemetry.ts     │      │ scripts/otel-emit.sh             │  │
│  │  → in-memory buffer │      │  → append output/telemetry-      │  │
│  │    (≤50 spans)      │      │    events.jsonl                  │  │
│  └─────────────────────┘      └──────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  CAPA 2: TRANSPORTE / AGREGACIÓN                                    │
│                                                                     │
│  savia-server (bridge) — nuevo endpoint GET /telemetry              │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  Lee y agrega:                                              │    │
│  │  • output/agent-lifecycle/lifecycle.jsonl   (agent events)  │    │
│  │  • output/telemetry-events.jsonl            (hook events)   │    │
│  │  • ~/.claude/external-memory/auto/MEMORY.md (memory size)  │    │
│  │  • ~./savia/live.log                        (tool activity) │    │
│  │                                                             │    │
│  │  Produce: TelemetrySnapshot (JSON schema — ver Contratos)   │    │
│  │                                                             │    │
│  │  Opcional: forward a OTLP collector vía HTTP/protobuf       │    │
│  │  (env SAVIA_OTLP_ENDPOINT, desactivado por defecto)         │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  CAPA 3: VISUALIZACIÓN                                              │
│                                                                     │
│  savia-web /telemetry (nueva ruta)                                  │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  useTelemetryStore (Pinia)                                  │    │
│  │    polls /telemetry cada 30 s                               │    │
│  │    calcula p50/p95 client-side                              │    │
│  │                                                             │    │
│  │  TelemetryPage.vue                                          │    │
│  │  ├── AgentPanel.vue      (invocaciones, latencia, tokens)   │    │
│  │  ├── WorkspaceHealthPanel.vue (hooks, drift, CI)            │    │
│  │  ├── MemoryStatePanel.vue     (MEMORY.md size, R/W)         │    │
│  │  ├── SprintPanel.vue          (velocity, blocked)           │    │
│  │  └── SpanFeed.vue             (últimos 50 spans live)       │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  savia-web → OTLP exporter (opcional, gated por VITE_OTLP_ENDPOINT) │
│  • @opentelemetry/sdk-trace-web                                     │
│  • @opentelemetry/exporter-trace-otlp-http                          │
└─────────────────────────────────────────────────────────────────────┘
```

### Stack técnico

| Capa | Dependencia | Versión mínima | Scope |
|---|---|---|---|
| savia-web | `@opentelemetry/api` | 1.9+ | prod |
| savia-web | `@opentelemetry/sdk-trace-web` | 1.30+ | prod |
| savia-web | `@opentelemetry/exporter-trace-otlp-http` | 0.57+ | prod |
| savia-web | `@opentelemetry/context-zone` | 1.30+ | prod |
| savia-web | ECharts 5 + vue-echarts 7 | ya instalado | prod |
| pm-workspace | bash ≥ 5.1 | ya disponible | runtime |
| pm-workspace | `jq` ≥ 1.6 | ya disponible | runtime |
| savia-server | semántica `GET /telemetry` | nuevo endpoint | server |

No se requiere `@opentelemetry/sdk-metrics` en el browser: las métricas
se calculan del lado del bridge a partir de los JSONL.
El exporter HTTP/protobuf es **opt-in**: si `VITE_OTLP_ENDPOINT` no está
definido, el SDK no se inicializa y el overhead es cero.

### Señales OpenTelemetry

#### Métricas (calculadas en bridge, servidas en `/telemetry`)

| Nombre | Tipo OTel | Atributos | Fuente |
|---|---|---|---|
| `savia.agent.invocations` | Counter | `agent_name`, `model`, `exit_code` | lifecycle.jsonl |
| `savia.agent.duration_ms` | Histogram | `agent_name`, `model` | lifecycle.jsonl (ts_start, ts_end) |
| `savia.agent.tokens` | Counter | `agent_name`, `token_type` (input/output) | lifecycle.jsonl |
| `savia.hook.executions` | Counter | `hook_name`, `exit_code` | telemetry-events.jsonl |
| `savia.hook.duration_ms` | Histogram | `hook_name` | telemetry-events.jsonl |
| `savia.memory.size_bytes` | Gauge | `memory_file` | stat MEMORY.md |
| `savia.memory.reads` | Counter | `session_id` | telemetry-events.jsonl |
| `savia.memory.writes` | Counter | `session_id` | telemetry-events.jsonl |
| `savia.workspace.drift_events` | Counter | `project` | telemetry-events.jsonl |
| `savia.bridge.request_duration_ms` | Histogram | `endpoint`, `method` | savia-web spans |
| `savia.bridge.request_errors` | Counter | `endpoint`, `status_code` | savia-web spans |
| `savia.session.count` | Counter | — | chat store (local) |

#### Trazas (spans generados en savia-web)

| Nombre del span | Atributos obligatorios | Creado en |
|---|---|---|
| `savia.bridge.request` | `http.method`, `url.path`, `http.response_status_code`, `duration_ms` | `useBridge.ts` |
| `savia.sse.stream` | `session_id`, `duration_ms`, `message_count` | `useSSE.ts` |
| `savia.chat.session` | `session_id`, `event` (created/idle) | `useChatStore` |
| `savia.page.navigation` | `route.path`, `duration_ms` | `router/index.ts` guard |

Estos spans se almacenan en un circular buffer (`SpanBuffer` en
`useTelemetry.ts`, cap=50) y se envían al OTLP endpoint si está configurado.

#### Eventos de log (emitidos por `otel-emit.sh`, almacenados en JSONL)

| Evento | Payload mínimo |
|---|---|
| `agent.started` | `agent_name`, `model`, `session_id`, `ts` |
| `agent.completed` | `agent_name`, `model`, `exit_code`, `duration_ms`, `ts` |
| `agent.failed` | `agent_name`, `model`, `error_summary`, `ts` |
| `hook.executed` | `hook_name`, `exit_code`, `duration_ms`, `ts` |
| `hook.failed` | `hook_name`, `exit_code`, `error_summary`, `ts` |
| `memory.read` | `session_id`, `bytes_read`, `ts` |
| `memory.write` | `session_id`, `bytes_written`, `ts` |
| `drift.detected` | `project`, `drift_type`, `ts` |
| `ci.failed` | `project`, `pipeline_id`, `ts` |

### Contrato `/telemetry` — TelemetrySnapshot (JSON)

```typescript
interface TelemetrySnapshot {
  generated_at: string                  // ISO 8601
  window_hours: number                  // Por defecto 24h
  agents: {
    invocations: AgentInvocation[]      // Últimas 100 (LIFO)
    summary: {
      total_today: number
      failed_today: number
      p50_duration_ms: number           // -1 si < 5 muestras
      p95_duration_ms: number           // -1 si < 5 muestras
      by_name: Record<string, number>   // agent_name → count_today
    }
  }
  hooks: {
    events: HookEvent[]                 // Últimas 100 (LIFO)
    summary: {
      total_today: number
      failed_today: number
      by_name: Record<string, number>
    }
  }
  memory: {
    size_bytes: number                  // Tamaño actual MEMORY.md
    size_bytes_history: MemoryPoint[]   // Últimas 24h, puntos cada 1h
    reads_today: number
    writes_today: number
  }
  drift: {
    events_today: DriftEvent[]          // Últimas 20
    total_today: number
  }
  spans: SpanRecord[]                   // Últimos 50 spans cross-signal
}

interface AgentInvocation {
  ts: string
  agent_name: string
  model: string           // heavy | mid | fast
  exit_code: number       // 0 = success, 1+ = failure
  duration_ms: number
  session_id: string
  tokens_input?: number
  tokens_output?: number
}

interface HookEvent {
  ts: string
  hook_name: string
  exit_code: number
  duration_ms: number
  project?: string
}

interface MemoryPoint {
  ts: string
  size_bytes: number
}

interface DriftEvent {
  ts: string
  project: string
  drift_type: string
}

interface SpanRecord {
  ts: string
  span_name: string
  kind: 'agent' | 'hook' | 'bridge' | 'memory' | 'session'
  duration_ms: number
  status: 'ok' | 'error'
  attributes: Record<string, string | number>
}
```

### Algoritmo de cálculo p50/p95

Calculado client-side en `useTelemetryStore.ts`:

```
FUNCTION percentile(values: number[], p: number): number
  IF values.length < 5: RETURN -1
  sorted = [...values].sort((a,b) => a-b)
  idx = Math.floor(p / 100 * sorted.length)
  RETURN sorted[Math.min(idx, sorted.length - 1)]
```

p50 = percentile(durations, 50), p95 = percentile(durations, 95).
Fuente de durations: `TelemetrySnapshot.agents.invocations[].duration_ms`
para los últimos 100 registros.

### Diseño del componente `otel-emit.sh`

```bash
#!/usr/bin/env bash
# Usage: otel-emit.sh <event_name> [key=value ...]
# Appends a structured JSON event to output/telemetry-events.jsonl
# Examples:
#   otel-emit.sh agent.started agent_name=drift-auditor model=heavy session_id=mon-1234
#   otel-emit.sh hook.executed hook_name=pre-commit exit_code=0 duration_ms=412
set -euo pipefail

EVENT_NAME="${1:?otel-emit.sh: event_name required}"
shift
OUTPUT_FILE="${SAVIA_TELEMETRY_FILE:-output/telemetry-events.jsonl}"
mkdir -p "$(dirname "$OUTPUT_FILE")"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
JSON="{\"event\":\"${EVENT_NAME}\",\"ts\":\"${TS}\""

for pair in "$@"; do
  KEY="${pair%%=*}"
  VAL="${pair#*=}"
  # Numeric if pure digits or decimal
  if [[ "$VAL" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    JSON="${JSON},\"${KEY}\":${VAL}"
  else
    JSON="${JSON},\"${KEY}\":\"${VAL}\""
  fi
done

JSON="${JSON}}"
echo "$JSON" >> "$OUTPUT_FILE"
```

Integración con hooks existentes: los hooks en `.opencode/hooks/` que ya
registran actividad (pre-commit, post-session, memory-store) añaden al
final una llamada `bash scripts/otel-emit.sh <event> key=val`. Si el
script no existe (entorno sin pm-workspace), el hook falla silenciosamente
con `|| true`.

### Diseño de useTelemetryStore (Pinia)

```typescript
// src/stores/telemetry.ts
export const useTelemetryStore = defineStore('telemetry', () => {
  const snapshot = ref<TelemetrySnapshot | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)
  const spanBuffer = ref<SpanRecord[]>([])    // cap 50 — spans del browser
  let pollTimer: ReturnType<typeof setInterval> | null = null

  // Percentiles computados
  const agentP50 = computed(() => { /* percentile logic */ })
  const agentP95 = computed(() => { /* percentile logic */ })
  const blockedItems = computed(() => {
    // Reutiliza backlog store — sin API call adicional
    const backlog = useBacklogStore()
    return backlog.allPbis.filter(p => p.state === 'Active' && /* blocked heuristic */).length
  })

  async function fetchSnapshot() { /* GET /telemetry */ }
  function addSpan(span: SpanRecord) {
    spanBuffer.value.unshift(span)
    if (spanBuffer.value.length > 50) spanBuffer.value.pop()
  }
  function startPolling(intervalMs = 30_000) { /* setInterval */ }
  function stopPolling() { /* clearInterval */ }

  return { snapshot, loading, error, spanBuffer, agentP50, agentP95,
           blockedItems, fetchSnapshot, addSpan, startPolling, stopPolling }
})
```

### Instrumentación de useBridge.ts

Se envuelven `get()` y `post()` con timing explícito:

```typescript
async function get<T>(path: string): Promise<T | null> {
  const t0 = Date.now()
  try {
    const res = await fetch(`${baseUrl()}${path}`, { headers: headers() })
    const duration = Date.now() - t0
    useTelemetryStore().addSpan({
      ts: new Date().toISOString(), span_name: 'savia.bridge.request',
      kind: 'bridge', duration_ms: duration,
      status: res.ok ? 'ok' : 'error',
      attributes: { 'http.method': 'GET', 'url.path': path,
                    'http.response_status_code': res.status }
    })
    if (!res.ok) return null
    return await res.json() as T
  } catch (err) {
    useTelemetryStore().addSpan({ /* error span */ })
    return null
  }
}
```

La instrumentación es lazy: `useTelemetryStore()` solo se llama si Pinia
está inicializado. En tests, el store se mockea con vitest `vi.mock`.

---

## Componentes

| Nombre | Tipo | Propósito |
|---|---|---|
| `src/pages/TelemetryPage.vue` | Vue page | Página raíz `/telemetry` — layout 2×2 + span feed |
| `src/components/telemetry/AgentPanel.vue` | Vue component | Tabla invocaciones + gráfico latencia p50/p95 (ECharts bar) |
| `src/components/telemetry/WorkspaceHealthPanel.vue` | Vue component | Hooks today, failure rate, drift events lista |
| `src/components/telemetry/MemoryStatePanel.vue` | Vue component | Gauge MEMORY.md + sparkline reads/writes (ECharts line) |
| `src/components/telemetry/SprintPanel.vue` | Vue component | Velocity (reutiliza VelocityChart.vue) + blocked badge from backlog store |
| `src/components/telemetry/SpanFeed.vue` | Vue component | Lista scrollable últimos 50 spans, filtro por kind |
| `src/components/telemetry/TelemetryMetricCard.vue` | Vue component | Tarjeta reutilizable: title + value + delta + unit |
| `src/stores/telemetry.ts` | Pinia store | Estado global telemetría, polling, span buffer, percentiles |
| `src/composables/useTelemetry.ts` | Composable | Inicialización OTel SDK, `TracerProvider`, `SpanBuffer`, OTLP export |
| `src/types/telemetry.ts` | TypeScript types | `TelemetrySnapshot`, `AgentInvocation`, `SpanRecord`, etc. |
| `scripts/otel-emit.sh` | Bash script | Emite eventos estructurados a `output/telemetry-events.jsonl` |
| `savia-server: GET /telemetry` | Bridge endpoint | Agrega JSONL + MEMORY.md → TelemetrySnapshot JSON |
| `savia-server: POST /telemetry/spans` | Bridge endpoint | Recibe spans del browser (opcional, si bridge actúa como OTLP proxy) |
| `tests/unit/stores/telemetry.test.ts` | Unit test | Store: polling, percentiles, span buffer cap, error handling |
| `tests/unit/composables/useTelemetry.test.ts` | Unit test | SDK init, span creation, buffer overflow |
| `e2e/telemetry.spec.ts` | E2E test (Playwright) | /telemetry ruta accesible, paneles visibles, polling activo |
| `tests/bats/test-spec-191-otel-emit.bats` | BATS test | otel-emit.sh: formato JSON válido, campos numéricos, archivo creado |

---

## Acceptance Criteria

- **AC-1**: La ruta `/telemetry` está registrada en `src/router/index.ts` y carga
  `TelemetryPage.vue` con lazy import. Navegando a `/telemetry` desde la sidebar
  (con enlace en `AppSidebar.vue`) el componente se monta sin errores de consola.
  Verificado: `e2e/telemetry.spec.ts` navega a `/telemetry` y aserta que el
  título de página `h1` contiene "Telemetry" (o equivalente i18n).

- **AC-2**: `useTelemetryStore` hace `GET /telemetry` al montarse `TelemetryPage.vue`
  y almacena el resultado en `snapshot`. Si el bridge devuelve 200, `loading` pasa de
  `true` a `false` y `error` queda `null`. Si el bridge devuelve 500 o el fetch falla,
  `error` contiene un string no vacío y `loading` es `false`.
  Verificado: `tests/unit/stores/telemetry.test.ts` con fetch mockeado (200 y error).

- **AC-3**: `useTelemetryStore.startPolling(30_000)` configura un `setInterval` que
  llama a `fetchSnapshot` exactamente cada 30 s. `stopPolling()` cancela el interval
  (verificado con `vi.useFakeTimers()`). Al desmontar `TelemetryPage.vue`,
  `stopPolling()` es llamado (`onUnmounted` hook).
  Verificado: unit test con fake timers — `fetchSnapshot` llamado N veces en N×30 s.

- **AC-4**: `AgentPanel.vue` muestra una tabla con las últimas 20 entradas de
  `snapshot.agents.invocations` (o menos si hay < 20). Cada fila muestra:
  `agent_name`, `model`, `exit_code`, `duration_ms` formateado como `{n} ms`, y `ts`
  formateado como hora local. Las filas con `exit_code ≠ 0` tienen clase CSS
  `row--error`.
  Verificado: `e2e/telemetry.spec.ts` aserta que la tabla tiene al menos 1 fila
  visible cuando el mock de `/telemetry` devuelve ≥ 1 invocación.

- **AC-5**: `AgentPanel.vue` muestra `agentP50` y `agentP95` calculados de
  `snapshot.agents.invocations[].duration_ms` (últimas 100). Si hay menos de 5
  muestras, muestra "N/A" en lugar del valor. Los valores se actualizan al recibir
  un nuevo snapshot.
  Verificado: unit test — fixture con 3 invocaciones → "N/A"; fixture con 10
  invocaciones → valor numérico correcto (tolerancia ±1 ms).

- **AC-6**: `WorkspaceHealthPanel.vue` muestra los contadores
  `snapshot.hooks.summary.total_today` y `snapshot.hooks.summary.failed_today` como
  tarjetas numéricas. La tarjeta `failed_today` aplica color de alerta CSS cuando
  `failed_today > 0`. Muestra los últimos 5 eventos de `snapshot.drift.events_today`
  en una lista ordenada por `ts` descendente.
  Verificado: unit snapshot con `failed_today=2` → clase `card--alert` presente en DOM.

- **AC-7**: `MemoryStatePanel.vue` muestra `snapshot.memory.size_bytes` formateado
  como KB (÷ 1024, 1 decimal). Muestra `reads_today` y `writes_today`. Si
  `size_bytes_history` tiene ≥ 2 puntos, renderiza un gráfico de línea ECharts con
  el historial de las últimas 24 h (eje X: hora, eje Y: KB).
  Verificado: unit test — fixture con `size_bytes=51200` → panel muestra "50.0 KB".

- **AC-8**: `SpanFeed.vue` muestra los spans de `useTelemetryStore.spanBuffer` (browser
  spans) más `snapshot.spans` (bridge spans), fusionados, ordenados por `ts`
  descendente, limitados a 50 entradas. Cada entrada muestra `span_name`, `kind`,
  `duration_ms`, `status`. El botón "Clear" vacía `spanBuffer` (no afecta `snapshot.spans`).
  Verificado: unit test — añadir 60 spans → la lista muestra exactamente 50.

- **AC-9**: `useTelemetry.ts` inicializa `@opentelemetry/sdk-trace-web` con un
  `WebTracerProvider` solo si `import.meta.env.VITE_OTLP_ENDPOINT` es un string
  no vacío. Si la variable no está definida o es vacía, el provider no se registra y
  `trace.getActiveSpan()` retorna `undefined`. El overhead cuando está desactivado
  es zero (no se instancia ningún objeto OTel).
  Verificado: unit test con `import.meta.env` mockeado — con valor vacío, el import de
  `@opentelemetry/sdk-trace-web` no es llamado.

- **AC-10**: La instrumentación de `useBridge.ts` añade un `SpanRecord` a
  `useTelemetryStore().spanBuffer` por cada llamada a `get()` y `post()`, con
  `span_name='savia.bridge.request'`, `duration_ms ≥ 0`, `status='ok'` si
  `res.ok === true`, y `status='error'` si `res.ok === false` o si hay excepción.
  Verificado: unit test `useBridge.test.ts` — mock fetch 200 → 1 span 'ok' en buffer;
  mock fetch 500 → 1 span 'error' en buffer.

- **AC-11**: `scripts/otel-emit.sh agent.completed agent_name=drift-auditor exit_code=0
  duration_ms=1234` escribe exactamente 1 línea JSON válida a `output/telemetry-events.jsonl`
  con campos: `event="agent.completed"`, `agent_name="drift-auditor"`,
  `exit_code=0` (integer, sin comillas), `duration_ms=1234` (integer), `ts` en
  formato ISO 8601 (`YYYY-MM-DDTHH:MM:SSZ`). `jq empty` sobre la línea tiene exit 0.
  Verificado: `tests/bats/test-spec-191-otel-emit.bats` — ejecuta el script y aserta
  cada campo via `jq`.

- **AC-12**: `GET /telemetry` en savia-server devuelve HTTP 200 con `Content-Type:
  application/json` y un body válido según `TelemetrySnapshot`. Si
  `output/agent-lifecycle/lifecycle.jsonl` no existe, `agents.invocations` es `[]` y
  `agents.summary.total_today=0` (no error 500). Si `MEMORY.md` no existe,
  `memory.size_bytes=0`.
  Verificado: E2E test con bridge real — `GET /telemetry` → `jq .generated_at` no vacío.

- **AC-13**: `SprintPanel.vue` muestra `velocity` de `snapshot` (si presente) y
  `blockedItems` de `useTelemetryStore().blockedItems` (computado del backlog store, sin
  llamada adicional al bridge). El componente `VelocityChart.vue` existente es
  reutilizado pasando los datos de sprint como prop.
  Verificado: unit test — backlog store con 2 PBIs en estado 'Active' marcados con
  blocked=true → `blockedItems === 2`.

- **AC-14**: Los 228 tests unitarios existentes (`npm test`) y los ~150 E2E tests
  (`npm run e2e`) pasan sin regresiones tras añadir la instrumentación en
  `useBridge.ts`. La instrumentación usa `try { useTelemetryStore().addSpan(...) }
  catch { /* silent */ }` para garantizar que un fallo en telemetría nunca rompe
  una llamada de bridge.
  Verificado: CI pipeline — `npm test && npm run e2e` exit 0 en el PR de Slice 2.

- **AC-15**: La nueva página `/telemetry` está protegida por autenticación (requiere
  `auth.token` válido — igual que el resto de páginas). Si el usuario no tiene token,
  el router guard redirige a `/`. La ruta no tiene `meta.requiresAdmin`, por lo que
  cualquier usuario autenticado puede acceder.
  Verificado: `e2e/telemetry.spec.ts` — test sin token → redirect a `/`; test con
  token user → página carga; test con token admin → página carga.

---

## Estimación por slice

| # | Slice | Descripción | Horas | Buffer |
|---|-------|-------------|-------|--------|
| 1 | Tipos + OTel setup | `src/types/telemetry.ts`, `useTelemetry.ts` (SDK init, gated), `TelemetryMetricCard.vue` | 3h | +0.5h |
| 2 | Instrumentación useBridge | Wrap `get()`/`post()` con SpanRecord, unit tests sin regresiones | 2h | +0.5h |
| 3 | `otel-emit.sh` + hooks | Script bash, BATS tests, integración en 3 hooks existentes (pre-commit, memory-store, post-session) | 3h | +1h |
| 4 | Bridge endpoint `/telemetry` | `GET /telemetry`: lectura JSONL, cálculo TelemetrySnapshot, edge cases (archivos ausentes) | 5h | +1.5h |
| 5 | Pinia store `telemetry.ts` | Polling, percentiles, span buffer, composición con backlog store, unit tests | 3h | +0.5h |
| 6 | `TelemetryPage` + `AgentPanel` | Layout, ruta router, AgentPanel con ECharts bar chart, i18n keys | 4h | +1h |
| 7 | `WorkspaceHealthPanel` + `MemoryStatePanel` | Hook events list, drift feed, ECharts sparkline, alert styling | 3h | +0.5h |
| 8 | `SprintPanel` + `SpanFeed` | VelocityChart reutilizado, blocked badge, span list con filtro y clear | 2h | +0.5h |
| 9 | Tests E2E + BATS | `e2e/telemetry.spec.ts` (AC-1, AC-4, AC-12, AC-15), BATS otel-emit (AC-11) | 3h | +1h |

**Total estimado**: 28 h + 7 h buffer = **35 h techo**; rango publicado 22-28 h (p50).

> Buffer alto en Slice 4: el bridge endpoint depende de la implementación
> interna de savia-server, que no está especificada en este spec. Si el
> bridge no es modificable por agentes IA (lenguaje desconocido o restricción
> de acceso), Slice 4 pasa a humano y el resto del spec sigue siendo
> implementable (el store puede usar datos mock en modo degradado).

---

## Dependencias

### Bloqueantes

| Dep | Razón |
|---|---|
| savia-web ≥ versión actual | Requiere ECharts ya instalado, VelocityChart.vue existente, useBridge.ts interface estable |
| `output/agent-lifecycle/lifecycle.jsonl` | Fuente de verdad para eventos de agentes. Ya existe (confirmado en savia-monitor `CLAUDE.md`) |

### No bloqueantes (Slice 4 degradado si ausentes)

| Dep | Modo degradado |
|---|---|
| `output/telemetry-events.jsonl` | Si no existe → `hooks.events=[]`, se crea al primer `otel-emit.sh` |
| `~/.savia/live.log` | Si no existe → `drift.events_today=[]` |
| OTLP collector externo | Si `VITE_OTLP_ENDPOINT` vacío → exporter desactivado, todo funciona sin él |

---

## Riesgos

| # | Riesgo | Severidad | Mitigación |
|---|--------|-----------|-----------|
| 1 | Bridge endpoint `/telemetry` inaccesible (savia-server en lenguaje no gestionable por agentes) | Alta | Slice 4 se marca `human-only`. Store usa modo mock con datos vacíos hasta que bridge esté disponible. Paneles muestran "No data available" sin crashear. |
| 2 | CORS bloqueado para OTLP HTTP desde browser | Media | El exporter OTLP es opt-in. El dashboard funciona 100% sin él. Si se activa, el colector debe responder con `Access-Control-Allow-Origin: *`. Documentado en setup guide. |
| 3 | `useBridge.ts` instrumentado causa regresiones en tests existentes | Media | Wrap usa `try/catch` silent. Tests de store mockean `useTelemetryStore` con `vi.mock`. AC-14 gatekeea el merge. |
| 4 | `otel-emit.sh` llamado desde hooks ralentiza el flujo de pre-commit | Baja | Script escribe a disco (append), no hace red. Benchmark: < 10 ms en bash 5.1. Si el archivo JSONL crece >10 MB, se rota automáticamente (> 10.000 líneas → mv a `.jsonl.bak`). |
| 5 | `lifecycle.jsonl` crece sin límite y ralentiza el endpoint `/telemetry` | Media | Bridge lee solo las últimas 1.000 líneas del JSONL (`tail -n 1000` o equivalente). Se documenta en setup que el archivo debe ser rotado periódicamente. |
| 6 | Datos de telemetría contienen información sensible (session_id, paths) | Media | `session_id` se trunca a los primeros 8 caracteres antes de servir en `/telemetry`. Rutas absolutas reemplazadas por `{project}` en eventos de drift. `SAVIA_TELEMETRY_REDACT=1` deshabilita todos los atributos excepto `ts` y `event`. |

---

## Verificación

```bash
# Unit tests nuevos
npx vitest run src/__tests__/stores/telemetry.test.ts
npx vitest run src/__tests__/composables/useTelemetry.test.ts

# Tests existentes — sin regresiones
npm test

# E2E
npx playwright test e2e/telemetry.spec.ts

# BATS
bats tests/bats/test-spec-191-otel-emit.bats

# Bridge endpoint (manual, requiere savia-server activo)
curl -s https://localhost:8922/telemetry \
  -H "Authorization: Bearer $(cat ~/.savia/token)" | jq .generated_at
```

Score target: ≥ 93/100 en scorer de pm-workspace sobre ACs (completeness,
specificity, testability, feasibility).

---

## Out of scope permanente

- Dashboard de costes LLM en euros (scope de SPEC-192 futuro)
- Alertas push / webhooks cuando `failed_today > N` (futuro SPEC-193)
- Instrumentación de savia-monitor (Tauri app — diferente runtime, diferente SPEC)
- Retención histórica de TelemetrySnapshot en base de datos (los JSONL son la fuente;
  la retención es responsabilidad del operador)
- Modo multi-usuario: `/telemetry` sirve el workspace del usuario activo, no agrega
  múltiples usuarios
- Exportación a Prometheus (metrics scraping) — compatible con OTLP pero fuera de
  scope v1

---

## OpenCode Implementation Plan

### Clasificación

- **Type**: Frontend + scripts — nueva página + instrumentación de código existente
- **Autonomy**: L2 (agentes implementan slices 1-3 y 5-9; Slice 4 requiere
  supervisión por dependencia en savia-server; humano revisa cada PR)
- **Reversibility**: Alta — la instrumentación en `useBridge.ts` es un wrapper
  additive; los componentes nuevos son todos additive; `otel-emit.sh` solo escribe
  a un JSONL. Rollback = revert PR del slice.

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| `src/pages/TelemetryPage.vue` | `frontend-developer` agent | Mismo (lee AGENTS.md) |
| `src/stores/telemetry.ts` | `frontend-developer` agent | Mismo |
| `src/composables/useTelemetry.ts` | `typescript-developer` agent | Mismo |
| `scripts/otel-emit.sh` | Bash — cualquier motor | Bash — idem |
| `otel-emit.sh` en hooks | `.opencode/hooks/*.sh` → registrados en settings.json | Plugin TS function `hook_event` (future, cuando OpenCode soporte hooks shell) |
| Bridge endpoint | `dotnet-developer` / `typescript-developer` según impl. | Mismo |

### Agent assignments por slice

| Slice | Agente principal | Agente secundario | Herramientas |
|-------|-----------------|-------------------|--------------|
| 1 | `typescript-developer` | — | Write (tipos, composable), Read (bridge.ts types) |
| 2 | `frontend-developer` | `test-engineer` | Edit (useBridge.ts), Write (test), Bash (npm test) |
| 3 | `python-developer` (bash) | `test-engineer` | Write (otel-emit.sh), Bash (bats) |
| 4 | **HUMAN-SUPERVISED** | `typescript-developer` si Node bridge | Read (savia-server code), Write (endpoint) |
| 5 | `frontend-developer` | `test-engineer` | Write (store), Bash (vitest) |
| 6 | `frontend-developer` | `visual-qa-agent` | Write (page, component), Read (ECharts docs) |
| 7 | `frontend-developer` | `visual-qa-agent` | Write (panels), Edit (AppSidebar.vue para link) |
| 8 | `frontend-developer` | — | Write (SpanFeed, SprintPanel), Edit (VelocityChart props) |
| 9 | `test-engineer` | `frontend-test-runner` | Write (e2e, BATS), Bash (playwright, bats) |

### Gate de calidad por slice

- Slices 1-3: `npm test` exit 0 (sin regresiones) + nuevo test del slice passing
- Slice 4: revisión humana + curl manual del endpoint
- Slices 5-9: `npm test && npm run e2e` exit 0

### Verification protocol

- [ ] Funciona en runtime OpenCode (navegación a `/telemetry` desde OpenCode browser)
- [ ] Tests cubren both paths: `VITE_OTLP_ENDPOINT` definido y no definido
- [ ] Si añade hooks shell: documentados en `otel-emit.sh` y no bloquean commit
- [ ] AC-14 verificado: 228 unit tests + ~150 E2E tests pasan sin cambios

### Portability classification

- [x] **DUAL_BINDING**: instrumentación Vue/TS runs en cualquier frontend que cargue
  savia-web. Scripts bash son agnósticos de motor IA. Slice 4 (bridge) es
  agnóstico de frontend.

---

## Referencias

- `https://github.com/DEVtheOPS/opencode-plugin-otel` — referencia de instrumentación
  OTel para opencode CLI (MIT). Métricas y log events adaptados para Savia.
- `projects/savia-web/src/composables/useBridge.ts` — punto de instrumentación Slice 2
- `projects/savia-web/src/composables/useSSE.ts` — punto de instrumentación spans SSE
- `projects/savia-web/src/stores/backlog.ts` — fuente de `blockedItems` para SprintPanel
- `projects/savia-web/src/router/index.ts` — ruta `/telemetry` a registrar
- `projects/savia-web/vite.config.ts` — `VITE_` env vars disponibles en build
- `projects/savia-monitor/src/stores/activity.ts` — confirma formato `ActivityEntry`
  y existencia de `output/agent-lifecycle/lifecycle.jsonl`
- `projects/savia-monitor/CLAUDE.md` — confirma fuentes de datos (live.log, lifecycle.jsonl)
- `docs/rules/domain/spec-opencode-implementation-plan.md` — sección OpenCode Plan
- `docs/rules/domain/autonomous-safety.md` — L2 supervisión por slice
- `docs/rules/domain/context-placement-confirmation.md` — N1-N4b para datos de telemetría
- `@opentelemetry/sdk-trace-web` — `https://opentelemetry.io/docs/languages/js/`
- `@opentelemetry/exporter-trace-otlp-http` — OTLP/HTTP transport (no gRPC en browser)
