# Spec: Flow Observability — Trazabilidad agéntica vía OpenTelemetry

**Task ID:**        WORKSPACE
**PBI padre:**      Era próxima — Observabilidad de flujos agénticos
**Sprint:**         2026-30
**Fecha creación:** 2026-05-09
**Creado por:**     Mónica

**Developer Type:** agent-team
**Asignado a:**     claude-agent-team
**Estimación:**     6h (un slice extendido)
**Estado:**         Pendiente

**Depende de:**     SPEC-AGENTIC-FLOW-GRAPH (Slices 1-2 en main), Rule #26 Language Boundaries
**Inspirado por:**  open-gitagent/gitagent (OpenTelemetry para LLM calls, tool execution y agent sessions). Concepto adoptado, código no.

**Contexto de ejecución:** Savia opera dentro de OpenCode. El comando `/flow-otel-test` es un fichero markdown en `.opencode/commands/` interpretado como prompt. El exporter se dispara automáticamente al final de cada `/flow-run` si el flag `SAVIA_OTEL_ENABLED=true` está activo en el entorno. La cadena: usuario → OpenCode → modelo → tool Bash → wrapper bash → subprocess Python → SDK OTel → endpoint OTLP del usuario.

**Decisión arquitectónica registrada:**
- (D-1) OTel exporter es OPCIONAL y opt-in. Por defecto, AFG sigue produciendo solo JSONL local.
- (D-2) NO se adopta LangSmith, Langfuse cloud, ni ningún SaaS de observabilidad LLM. El exporter envía a un endpoint OTLP configurable que el usuario elige (collector self-hosted, Jaeger, Tempo, SigNoz).
- (D-3) El JSONL local sigue siendo la fuente de verdad. OTel es un canal adicional, no un sustituto.
- (D-4) Las trazas OTel respetan la confidencialidad declarada en el flujo. Un flujo N4 NUNCA exporta a OTel.
- (D-5) Implementación en Python para construcción del payload OTLP, validación de schema y serialización. Bash solo envoltorio. Conforme a Rule #26.
- (D-6) **El exporter se expone también como MCP server** (`savia-otel-exporter`). Cualquier frontend compatible con MCP puede invocarlo sobre cualquier traza JSONL conforme al schema de AFG. Reutilización futura sin reescribir.
- (D-7) Dependencias Python: `opentelemetry-api`, `opentelemetry-sdk`, `opentelemetry-exporter-otlp-proto-http`. Versiones pineadas. Instalación opt-in.

---

## 1. Contexto y Objetivo

### 1.1 Problema

El SPEC-AGENTIC-FLOW-GRAPH produce trazas JSONL en `output/flows/{run-id}/trace.jsonl`. Cubre el caso del desarrollador inspeccionando un flujo concreto, pero queda corto para tres escenarios:

1. **Flujos en producción a escala.** Cuando 50 instancias de Savia ejecutan flujos simultáneamente en una organización, los JSONL viven dispersos en máquinas individuales. Correlacionar incidentes ("¿por qué los code reviews tardaron x3 ayer?") es manual y lento.
2. **Métricas agregadas.** No hay forma estándar de responder "coste medio por flujo en los últimos 30 días", "p99 latencia de code-review-court", "tasa de fallo de aggregate node". Cada análisis requiere scripts ad-hoc.
3. **Compliance enterprise.** Algunos sectores regulados exigen trazabilidad estandarizada de decisiones de IA. JSONL local no cumple.

La industria converge en OpenTelemetry como estándar abierto para observabilidad. Es vendor-neutral, soporta self-hosting completo (Jaeger, Tempo, SigNoz, Grafana Stack) y no implica enviar nada a SaaS propietarios. open-gitagent/gitagent lo adoptó el 27 de abril.

### 1.2 Objetivo

Añadir un exporter OTel opcional al motor AFG que emita los eventos de la traza JSONL como spans OpenTelemetry vía OTLP/HTTP a un endpoint configurable.

```bash
# Por defecto: solo JSONL local
/flow-run code-review-court

# Con exporter activo (env vars en el entorno donde corre OpenCode)
export SAVIA_OTEL_ENABLED=true
export OTEL_EXPORTER_OTLP_ENDPOINT="https://otel-collector.internal/v1/traces"
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer xxxxx"
/flow-run code-review-court
```

### 1.3 No-Goals

- ❌ NO se reemplaza el JSONL local.
- ❌ NO se incluye un collector OTel ni dashboard. El usuario elige su stack.
- ❌ NO se exportan métricas (solo trazas en este slice).
- ❌ NO se exportan logs OTel.
- ❌ NO se cubren llamadas LLM individuales fuera del contexto AFG.
- ❌ NO se introduce sampling complejo. En este slice: todo o nada por flujo.
- ❌ NO se construye payload OTLP a mano.

---

## 2. Requisitos Funcionales

### 2.1 Mapeo eventos AFG → spans OTel

| Evento JSONL | Span OTel | Atributos clave |
|---|---|---|
| `flow.start` | Root span | `savia.flow.id`, `savia.flow.version`, `savia.profile`, `savia.confidentiality` |
| `node.start` / `node.end` | Child span | `savia.node.id`, `savia.node.kind`, `savia.tier_final`, `savia.tier_source` |
| `node.error` | Span con status ERROR | `error.type`, `error.message` |
| `flow.end` | Cierra root span | `savia.verdict`, `savia.duration_ms` |
| `profile.resolved` | Atributo del root span | `savia.profile_resolution` (JSON serializado) |

Convención de naming: prefijo `savia.*` para atributos custom. Atributos de modelo IA siguen `gen_ai.*` cuando aplique.

**Importante:** los atributos `savia.tier_final` registran el tier que Savia resolvió, NO el modelo concreto. Si el operador quiere registrar también el modelo, esa información la añade el frontend (OpenCode) en sus propias trazas, no Savia.

### 2.2 Configuración

```bash
SAVIA_OTEL_ENABLED=true                              # opt-in explícito
OTEL_EXPORTER_OTLP_ENDPOINT="https://collector/..."  # estándar OTel, honrado por SDK
OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer xxx"
OTEL_RESOURCE_ATTRIBUTES="service.name=savia,deployment.environment=prod"

SAVIA_OTEL_MAX_CONFIDENTIALITY=N2                    # gate de confidencialidad
SAVIA_OTEL_DRYRUN=false                              # imprimir payload sin enviar
```

El SDK oficial OTel honra automáticamente las variables `OTEL_*` estándar.

### 2.3 Gate de confidencialidad

Un flujo declarado con `confidentiality: N3` se ejecuta normalmente, JSONL local se escribe, pero el exporter OTel se salta silenciosamente y registra un evento `otel.skipped` en el JSONL con razón `confidentiality_above_threshold`. Comparación de niveles (N1 < N2 < N3 < N4 < N4b) implementada en Python con orden total documentado.

### 2.4 Arquitectura

Conforme a Rule #26 y al contexto OpenCode:

**Comando slash — `.opencode/commands/flow-otel-test.md`** (markdown, no código):
- Describe al modelo cómo invocar el script de prueba.
- Instruye a presentar resultados claramente formateados.

**Wrapper bash — `scripts/flow-otel-exporter.sh`** (≤ 20 líneas):
- Lee `SAVIA_OTEL_ENABLED`. Si no está `true`, sale con exit 0 silenciosamente.
- Localiza el JSONL del run actual.
- Invoca `python3 scripts/lib/otel_exporter.py --trace-file <path>` como subprocess.
- Captura stdout/stderr y propaga código de salida.

**Lógica Python — `scripts/lib/otel_exporter.py`:**
- Parsea JSONL con `json.loads` línea a línea.
- Usa `opentelemetry.sdk.trace` para construir spans.
- Usa `OTLPSpanExporter` oficial para envío.
- Aplica gate de confidencialidad antes de exportar.
- Maneja timeout, retry y fallos de red sin interrumpir el flujo.
- Modo dry-run imprime los spans serializados a stdout.

**MCP server — `scripts/lib/otel_exporter_mcp.py`:**
- Expone la misma lógica como MCP server.
- Tools: `export_trace(trace_path, endpoint, headers)`, `validate_trace(trace_path) → diagnostics`.
- Permite que cualquier frontend compatible con MCP exporte trazas conformes al schema AFG sin pasar por la tool Bash de OpenCode.

**Hook de OpenCode:**
- Hook que se dispara al final de un comando `/flow-run` si `SAVIA_OTEL_ENABLED=true`.
- El hook invoca el wrapper bash. Convención de nombres alineada con SPEC-127 portabilidad.

### 2.5 Comando slash `/flow-otel-test`

Verifica que la configuración es válida enviando un span de prueba:

```
/flow-otel-test
✓ Endpoint reachable: https://collector.internal/v1/traces
✓ Auth header valid
✓ Test span sent and acknowledged (trace_id: abc123)
✓ Confidentiality threshold: N2
```

Implementación: `scripts/lib/otel_test.py` ejecutado por wrapper bash mínimo, invocado a través de la tool Bash de OpenCode.

### 2.6 Modo dry-run

```bash
SAVIA_OTEL_DRYRUN=true /flow-run code-review-court
```

Exporter ejecuta pero imprime el payload OTLP serializado a stdout en lugar de enviarlo.

### 2.7 Documentación end-to-end

Guía paso a paso para tres stacks: Jaeger local con docker-compose, Grafana Tempo + Grafana self-hosted, SigNoz self-hosted. Sin SaaS externos.

### 2.8 Dependencias Python declaradas

```
# scripts/lib/requirements-otel.txt
opentelemetry-api==1.27.0
opentelemetry-sdk==1.27.0
opentelemetry-exporter-otlp-proto-http==1.27.0
```

Instalación opt-in. Documentado en `docs/savia-otel.md`.

---

## 3. No se modifica

- Formato del JSONL local.
- Schema de `.flow.yaml`.
- Motor de ejecución de AFG (el exporter es post-flow).
- Configuración tier→modelo de OpenCode.
- Cualquier comportamiento por defecto. Sin variables de entorno → sin cambios.

---

## 4. Criterios de Aceptación

- [ ] Lógica de exportación en Python usando SDK oficial OTel. Bash limita su rol a invocar Python (≤ 20 líneas por wrapper).
- [ ] Por defecto inactivo. Activación explícita vía `SAVIA_OTEL_ENABLED=true`.
- [ ] `/flow-otel-test` valida configuración y envía span de prueba.
- [ ] Demo end-to-end con Jaeger local: ejecutar `code-review-court`, ver spans con jerarquía correcta.
- [ ] Gate de confidencialidad funcional: flujo `confidentiality: N3` con umbral N2 NO exporta y registra skip.
- [ ] Fallo del collector NO interrumpe el flujo. Test que lo demuestra.
- [ ] MCP server `savia-otel-exporter` funcional, registrable en frontends compatibles.
- [ ] Tests pytest: 12 casos.
- [ ] Tests bats: 3 casos cubriendo invocación del wrapper.
- [ ] Documentación: `docs/savia-otel.md` con guías Jaeger + Tempo + SigNoz.
- [ ] `requirements-otel.txt` con versiones pineadas.

---

## 5. Ficheros a Crear/Modificar

**Crear (Python — lógica):**
- `scripts/lib/otel_exporter.py`
- `scripts/lib/otel_test.py`
- `scripts/lib/otel_exporter_mcp.py`
- `scripts/lib/savia_confidentiality.py` (orden total entre niveles, reutilizable)
- `scripts/lib/requirements-otel.txt`
- `tests/python/test_otel_exporter.py`
- `tests/python/test_savia_confidentiality.py`
- `tests/python/fixtures/sample-trace.jsonl`

**Crear (Bash — envoltorios):**
- `scripts/flow-otel-exporter.sh` (≤ 20 líneas)
- `tests/flow-otel-wrapper.bats`

**Crear (markdown OpenCode — prompts):**
- `.opencode/commands/flow-otel-test.md`

**Crear (hooks OpenCode):**
- `.opencode/hooks/flow-otel-post.{sh,ts}` según convención SPEC-127

**Crear (docs):**
- `docs/savia-otel.md`
- `docs/savia-otel-jaeger.md`
- `docs/savia-otel-tempo.md`
- `docs/savia-otel-signoz.md`

**Modificar:**
- `scripts/flow-run.sh`: invocar wrapper post-flow si está activado.
- `docs/agentic-flow-graph.md`: sección "Observabilidad".
- `CHANGELOG.md`.

---

## 6. Dependencias y Riesgos

**Dependencias:**
- Sistema: `python3` (≥ 3.10), `pip`. Ya presentes.
- Python: `opentelemetry-api`, `opentelemetry-sdk`, `opentelemetry-exporter-otlp-proto-http`, MCP SDK Python. Instalación opcional.
- Spec previo: SPEC-AGENTIC-FLOW-GRAPH Slices 1-2 en main.
- Regla: Rule #26 Language Boundaries.

**Riesgos:**

| Riesgo | Mitigación |
|---|---|
| **Dependencia Python opcional rompe la idea de "sin dependencias".** | Opt-in. Sin `SAVIA_OTEL_ENABLED=true` no se ejecuta y `pip install` no es necesario. |
| **El SDK OTel evoluciona.** | Versiones pineadas. Test de regresión con golden spans. Actualización vía PR único. |
| **Fuga de información sensible vía atributos.** Un span incluye accidentalmente contenido del prompt. | Whitelist explícita en `otel_exporter.py`. Solo atributos de la sección 2.1. Prompts y outputs NUNCA son atributos OTel. Test pytest que lo verifica. |
| **Latencia añadida al final del flujo.** | Timeout 10s en SDK. Fallo no bloquea. Slice futuro: BatchSpanProcessor en background. |
| **Configuración mal hecha envía a endpoint público accidentalmente.** | Opt-in fuerte. Endpoint sin HTTPS rechazado en Python. `flow-otel-test` antes del primer uso. |
| **Volumen de spans desmesurado.** | Sampling configurable como Slice futuro. Por ahora todo o nada por flujo. |
| **Python no presente en el entorno donde corre OpenCode.** | Wrapper bash detecta ausencia con `command -v python3` y emite mensaje claro. Sin Python, exporter desactivado graciosamente. |

---

## 7. Impacto en Roadmap

- **Habilita Savia en entornos enterprise regulados.** Compliance estandarizado sin SaaS propietario.
- **Análisis cross-flow.** Queries estándar OTel sobre p99, coste por flujo, tasas de fallo.
- **Correlación con resto del stack.** Si la organización ya usa OTel, los flujos Savia aparecen en el mismo dashboard.
- **Compatible con SPEC-AFG-COMPOSE.** Las trazas incluyen `tier_source` y `profile`, permitiendo análisis de coste por profile.
- **MCP server reutilizable.** El exporter está disponible para cualquier frontend MCP-compatible, no solo OpenCode.
- **Refuerza Rule #26 con un caso emblemático.** Primer spec post-regla que la aplica.
- **Slices futuros opcionales:** métricas OTel, logs OTel, sampling, BatchSpanProcessor.
