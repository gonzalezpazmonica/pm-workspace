# Savia OTel — Observabilidad de flujos agénticos vía OpenTelemetry

> **Opt-in.** Sin `SAVIA_OTEL_ENABLED=true`, el sistema funciona exactamente igual que antes. El JSONL local sigue siendo la fuente de verdad.

## Qué es esto

El motor AFG (Agentic Flow Graph) produce trazas JSONL en `output/flows/{run-id}/trace.jsonl`. Este exporter convierte esas trazas en spans OpenTelemetry que puedes visualizar en Jaeger, Grafana Tempo, SigNoz o cualquier stack compatible con OTLP.

## Por qué OpenTelemetry

- **Vendor-neutral**: sin lock-in a ningún SaaS de observabilidad LLM.
- **Self-hosted completo**: Jaeger, Tempo, SigNoz funcionan en tu infra.
- **Estándar de industria**: correlación con el resto de tu stack si ya usas OTel.
- **Compliance**: auditoría estandarizada de decisiones de IA en sectores regulados.

## Configuración rápida

```bash
# Variables mínimas para activar el exporter
export SAVIA_OTEL_ENABLED=true
export OTEL_EXPORTER_OTLP_ENDPOINT="https://collector.tu-org.internal/v1/traces"

# Opcional: auth
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer <tu-token>"

# Opcional: atributos de servicio
export OTEL_RESOURCE_ATTRIBUTES="service.name=savia,deployment.environment=prod"

# Opcional: umbral de confidencialidad (default: N2)
# Flujos con nivel > SAVIA_OTEL_MAX_CONFIDENTIALITY NO se exportan
export SAVIA_OTEL_MAX_CONFIDENTIALITY=N2
```

## Validar la configuración antes de usar

```bash
bash scripts/flow-otel-test.sh
```

Debe mostrar algo como:

```
=== Savia OTel Configuration Test ===

OK Endpoint: https://collector.tu-org.internal/v1/traces
OK Auth header presente: Authorization
OK Confidentiality threshold: N2

Enviando span de prueba...
OK Test span enviado (trace_id: a1b2c3d4...)

CONFIGURACION OTel VALIDA.
```

## Exportar una traza manualmente

```bash
export SAVIA_OTEL_ENABLED=true
bash scripts/flow-otel-exporter.sh output/flows/my-run-id/trace.jsonl
```

## Modo dry-run (sin enviar al collector)

```bash
export SAVIA_OTEL_ENABLED=true
export SAVIA_OTEL_DRYRUN=true
bash scripts/flow-otel-exporter.sh output/flows/my-run-id/trace.jsonl
```

Imprime los spans serializados a stdout. Útil para debuggear el mapeo JSONL → spans.

## Instalar dependencias Python

Las dependencias OTel son opt-in (no se instalan por defecto):

```bash
source .venv/bin/activate
pip install -r scripts/lib/requirements-otel.txt
```

## Mapeo de eventos a spans

| Evento JSONL | Span OTel | Atributos |
|---|---|---|
| `flow.start` | Root span | `savia.flow.id`, `savia.flow.version`, `savia.profile`, `savia.confidentiality` |
| `node.start` / `node.end` | Child span | `savia.node.id`, `savia.node.kind`, `savia.tier_final`, `savia.tier_source` |
| `node.error` | Child span con status ERROR | `error.type`, `error.message` |
| `flow.end` | Cierra root span | `savia.verdict`, `savia.duration_ms` |
| `profile.resolved` | Atributo del root span | `savia.profile_resolution` |

**Importante:** Los prompts y outputs de los modelos NUNCA se incluyen como atributos de span.

## Gate de confidencialidad

Un flujo con `confidentiality: N3` con `SAVIA_OTEL_MAX_CONFIDENTIALITY=N2` se salta silenciosamente y añade un evento `otel.skipped` al JSONL local:

```json
{"event": "otel.skipped", "ts": 1715000005.0, "reason": "confidentiality_above_threshold: N3 > N2"}
```

Niveles en orden ascendente de restricción: `N1 < N2 < N3 < N4 < N4b`.

## MCP server

El exporter también está disponible como MCP server para frontends compatibles:

```bash
python3 scripts/lib/otel_exporter_mcp.py
```

Tools disponibles:
- `export_trace(trace_path, endpoint, headers)` — exporta una traza
- `validate_trace(trace_path)` — valida schema sin necesitar collector

Registro en `opencode.json`:

```json
{
  "mcpServers": {
    "savia-otel-exporter": {
      "command": "python3",
      "args": ["scripts/lib/otel_exporter_mcp.py"]
    }
  }
}
```

## Guías por stack

- Jaeger local: `docs/savia-otel-jaeger.md`
- Grafana Tempo: `docs/savia-otel-tempo.md`
- SigNoz: `docs/savia-otel-signoz.md`

## Variables de entorno — referencia completa

| Variable | Default | Descripción |
|---|---|---|
| `SAVIA_OTEL_ENABLED` | `false` | Activa el exporter. Sin esto, sin OTel. |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | — | URL del collector OTLP (HTTPS obligatorio). |
| `OTEL_EXPORTER_OTLP_HEADERS` | — | Headers en formato `Key=Value,Key2=Value2`. |
| `OTEL_RESOURCE_ATTRIBUTES` | — | Atributos del recurso: `service.name=savia,...`. |
| `SAVIA_OTEL_MAX_CONFIDENTIALITY` | `N2` | Nivel máximo exportable. Flujos por encima se saltan. |
| `SAVIA_OTEL_DRYRUN` | `false` | Imprime spans a stdout en lugar de enviarlos. |

## Fallo silencioso

Si el collector no está disponible, el exporter falla silenciosamente: el flujo continúa, el JSONL local está intacto, y se registra un warning en stderr. El collector nunca bloquea Savia.
