# SigNoz self-hosted — Guía de integración

> Alternativa open-source a Datadog/NewRelic con soporte nativo OTLP.

## Instalación rápida

```bash
git clone -b main https://github.com/SigNoz/signoz.git
cd signoz/deploy
./install.sh
```

SigNoz expone el collector OTLP en el puerto 4318 por defecto.

## Configurar Savia

```bash
export SAVIA_OTEL_ENABLED=true
export OTEL_EXPORTER_OTLP_ENDPOINT="https://signoz.tu-org.internal:4318/v1/traces"
export OTEL_EXPORTER_OTLP_HEADERS="signoz-ingestion-key=<tu-clave>"
export SAVIA_OTEL_MAX_CONFIDENTIALITY=N2
export OTEL_RESOURCE_ATTRIBUTES="service.name=savia,deployment.environment=prod"
```

## Validar

```bash
bash scripts/flow-otel-test.sh
```

## Ver trazas

Abre la UI de SigNoz → Services → `savia` → Traces.

Puedes filtrar por `savia.flow.id`, `savia.verdict` o `savia.node.kind` directamente desde la UI.

## Alertas

SigNoz permite crear alertas sobre métricas derivadas de trazas. Por ejemplo:
- Latencia p99 del span `flow/code-review-court` > 30s → alerta.
- Tasa de spans con status ERROR > 5% → alerta.
