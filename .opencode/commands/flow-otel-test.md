# /flow-otel-test — Valida la configuración OTel y envía span de prueba

Verifica que la configuración OpenTelemetry es válida antes de activar el exporter.

## Qué hace

1. Lee las variables de entorno OTel configuradas.
2. Valida que el endpoint usa HTTPS.
3. Verifica el umbral de confidencialidad.
4. Envía un span de prueba al collector.
5. Reporta el resultado con trace_id.

## Variables de entorno

```bash
export SAVIA_OTEL_ENABLED=true
export OTEL_EXPORTER_OTLP_ENDPOINT="https://collector.internal/v1/traces"
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer <token>"
export SAVIA_OTEL_MAX_CONFIDENTIALITY=N2
export OTEL_RESOURCE_ATTRIBUTES="service.name=savia,deployment.environment=prod"
```

## Dry-run (sin collector real)

```bash
export SAVIA_OTEL_ENABLED=true
export SAVIA_OTEL_DRYRUN=true
```

## Invocación

```bash
bash scripts/flow-otel-test.sh
```

O directamente (venv activado):

```bash
source .venv/bin/activate
python3 scripts/lib/otel_test.py
```

## Salida esperada

```
=== Savia OTel Configuration Test ===

OK Endpoint: https://collector.internal/v1/traces
OK Auth header presente: Authorization
OK Confidentiality threshold: N2

Enviando span de prueba...
OK Test span enviado (trace_id: a1b2c3d4...)

CONFIGURACION OTel VALIDA.
```

## Documentación

Ver docs/savia-otel.md para guías Jaeger, Grafana Tempo y SigNoz.
