# Grafana Tempo + Grafana — Guía de integración

> Stack recomendado para producción self-hosted con dashboards Grafana.

## Componentes necesarios

- **Grafana Tempo**: almacenamiento de trazas compatible con OTLP.
- **OpenTelemetry Collector**: recibe spans y los reenvía a Tempo.
- **Grafana**: visualización.

## docker-compose mínimo

```yaml
# docker-compose.otel-tempo.yml
version: "3.8"
services:
  tempo:
    image: grafana/tempo:2.4.1
    command: ["-config.file=/etc/tempo.yaml"]
    volumes:
      - ./tempo.yaml:/etc/tempo.yaml
    ports:
      - "3200:3200"   # HTTP API

  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.100.0
    command: ["--config=/etc/otel-collector-config.yaml"]
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml
    ports:
      - "4318:4318"   # OTLP HTTP

  grafana:
    image: grafana/grafana:10.4.2
    ports:
      - "3000:3000"
```

## Configurar Savia

```bash
export SAVIA_OTEL_ENABLED=true
export OTEL_EXPORTER_OTLP_ENDPOINT="https://otel-collector.tu-org/v1/traces"
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer <token>"
export SAVIA_OTEL_MAX_CONFIDENTIALITY=N2
export OTEL_RESOURCE_ATTRIBUTES="service.name=savia,deployment.environment=prod"
```

## Datasource en Grafana

1. Grafana → Configuration → Data Sources → Add data source → Tempo.
2. URL: `http://tempo:3200`.
3. Save & Test.

## Explorar trazas

Grafana → Explore → Tempo datasource → busca `service.name = savia`.
