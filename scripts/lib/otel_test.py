"""
otel_test.py — Valida la configuración OTel enviando un span de prueba.

Invocado por el wrapper bash desde el comando /flow-otel-test.
Verifica endpoint, autenticación y umbral de confidencialidad.
"""
from __future__ import annotations

import os
import sys
import time
from pathlib import Path

from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.trace import SpanKind

from savia_confidentiality import parse_level

_DEFAULT_TIMEOUT_S = 10


def run_connectivity_test() -> int:
    """Envía un span de prueba y reporta el resultado.

    Returns:
        0 si OK, 1 si fallo de configuración, 2 si fallo de red.
    """
    endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "")
    headers_raw = os.environ.get("OTEL_EXPORTER_OTLP_HEADERS", "")
    max_conf_raw = os.environ.get("SAVIA_OTEL_MAX_CONFIDENTIALITY", "N2")
    dry_run = os.environ.get("SAVIA_OTEL_DRYRUN", "").lower() == "true"

    print("=== Savia OTel Configuration Test ===\n")

    # 1. Endpoint
    if not endpoint and not dry_run:
        print("✗ OTEL_EXPORTER_OTLP_ENDPOINT no configurado.")
        print("  Configura: export OTEL_EXPORTER_OTLP_ENDPOINT=https://collector/v1/traces")
        return 1

    if endpoint and not endpoint.startswith("https://") and not dry_run:
        print(f"✗ Endpoint debe usar HTTPS. Recibido: {endpoint!r}")
        return 1

    if dry_run:
        print("✓ Modo dry-run activo (no se envía al endpoint)")
    else:
        print(f"✓ Endpoint: {endpoint}")

    # 2. Auth header (opcional)
    if headers_raw:
        # No imprimimos el valor, solo que está presente
        keys = [part.split("=")[0].strip() for part in headers_raw.split(",") if "=" in part]
        print(f"✓ Auth header(s) presentes: {', '.join(keys)}")
    else:
        print("⚠ OTEL_EXPORTER_OTLP_HEADERS no configurado (puede fallar si el endpoint requiere auth)")

    # 3. Umbral de confidencialidad
    try:
        max_level = parse_level(max_conf_raw)
        print(f"✓ Confidentiality threshold: {max_level.value}")
    except ValueError as exc:
        print(f"✗ SAVIA_OTEL_MAX_CONFIDENTIALITY inválido: {exc}")
        return 1

    # 4. Enviar span de prueba
    print("\nEnviando span de prueba...")
    try:
        resource = Resource.create({"service.name": "savia", "savia.test": "true"})
        provider = TracerProvider(resource=resource)

        if dry_run:
            from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor
            provider.add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter()))
        else:
            headers: dict[str, str] = {}
            for part in headers_raw.split(","):
                part = part.strip()
                if "=" in part:
                    k, _, v = part.partition("=")
                    headers[k.strip()] = v.strip()

            exporter = OTLPSpanExporter(
                endpoint=endpoint,
                headers=headers or None,
                timeout=_DEFAULT_TIMEOUT_S,
            )
            provider.add_span_processor(SimpleSpanProcessor(exporter))

        tracer = provider.get_tracer("savia.otel-test", "1.0")
        with tracer.start_as_current_span(
            "savia.connectivity-test",
            kind=SpanKind.INTERNAL,
        ) as span:
            trace_id = format(span.get_span_context().trace_id, "032x")
            span.set_attribute("savia.test", "true")
            span.set_attribute("savia.ts", str(time.time()))

        provider.force_flush(timeout_millis=_DEFAULT_TIMEOUT_S * 1000)
        provider.shutdown()

        print(f"✓ Test span enviado (trace_id: {trace_id})")
        print("\n✅ Configuración OTel válida.\n")
        return 0

    except Exception as exc:  # noqa: BLE001
        print(f"\n✗ Error al enviar span de prueba: {exc}")
        print("  Verifica que el collector está accesible y el endpoint es correcto.")
        return 2


if __name__ == "__main__":
    sys.exit(run_connectivity_test())
