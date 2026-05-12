# Jaeger local con docker-compose — Guía rápida

> Para desarrollo y pruebas. Sin auth, sin TLS. No usar en producción.

## Arrancar Jaeger con docker-compose

```yaml
# docker-compose.otel-jaeger.yml
version: "3.8"
services:
  jaeger:
    image: jaegertracing/all-in-one:1.57
    ports:
      - "16686:16686"   # UI
      - "4318:4318"     # OTLP HTTP
    environment:
      - COLLECTOR_OTLP_ENABLED=true
```

```bash
docker compose -f docker-compose.otel-jaeger.yml up -d
```

## Configurar Savia

```bash
export SAVIA_OTEL_ENABLED=true
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318/v1/traces"
export SAVIA_OTEL_MAX_CONFIDENTIALITY=N2
```

> Nota: En local con Jaeger sin TLS, el endpoint HTTP (no HTTPS) está permitido solo en modo dry-run o si deshabilitas la validación HTTPS en otel_exporter.py. Para producción siempre HTTPS.

## Validar

```bash
bash scripts/flow-otel-test.sh
```

## Ver trazas

Abre `http://localhost:16686` → busca servicio `savia` → selecciona un trace.

Verás la jerarquía de spans:
```
flow/code-review-court (root)
  node/validate
  node/security-judge
  node/correctness-judge
  node/aggregate
```
