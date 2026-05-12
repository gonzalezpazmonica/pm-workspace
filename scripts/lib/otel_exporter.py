"""
otel_exporter.py — Exporta trazas AFG (JSONL) como spans OpenTelemetry vía OTLP/HTTP.

Arquitectura (SPEC-FLOW-OBSERVABILITY §2.4, D-5):
- Python gestiona toda la lógica OTel. Bash es solo involtorio (≤20 líneas).
- El JSONL local sigue siendo la fuente de verdad (D-3). OTel es canal adicional.
- Exporter OPT-IN: sin SAVIA_OTEL_ENABLED=true, este módulo no se activa (D-1).
- Gate de confidencialidad: flujos por encima del umbral se saltan silenciosamente (D-4).

Mapeo JSONL → spans (§2.1):
  flow.start        → Root span
  node.start/end    → Child spans
  node.error        → Child span con status ERROR
  flow.end          → Cierra root span
  profile.resolved  → Atributo del root span

Uso CLI:
  python3 scripts/lib/otel_exporter.py --trace-file output/flows/<run-id>/trace.jsonl
  python3 scripts/lib/otel_exporter.py --trace-file ... --dry-run
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import sys
import time
from pathlib import Path
from typing import Any

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import (
    BatchSpanProcessor,
    ConsoleSpanExporter,
    SimpleSpanProcessor,
)
from opentelemetry.trace import SpanKind, StatusCode

from savia_confidentiality import (
    ConfidentialityLevel,
    is_exportable,
    parse_level,
)

logger = logging.getLogger(__name__)

# Atributos permitidos en spans (whitelist para evitar fugas de PII/prompts).
# Prompts y outputs NUNCA se incluyen como atributos OTel.
_ALLOWED_ROOT_ATTRS: frozenset[str] = frozenset({
    "savia.flow.id",
    "savia.flow.version",
    "savia.profile",
    "savia.confidentiality",
    "savia.verdict",
    "savia.duration_ms",
    "savia.profile_resolution",
})

_ALLOWED_NODE_ATTRS: frozenset[str] = frozenset({
    "savia.node.id",
    "savia.node.kind",
    "savia.tier_final",
    "savia.tier_source",
    "error.type",
    "error.message",
})

_SKIP_EVENT_NAME = "otel.skipped"
_DEFAULT_TIMEOUT_S = 10


class OtelExporterConfig:
    """Configuración del exporter leída desde variables de entorno."""

    def __init__(self) -> None:
        self.enabled: bool = os.environ.get("SAVIA_OTEL_ENABLED", "").lower() == "true"
        self.endpoint: str = os.environ.get(
            "OTEL_EXPORTER_OTLP_ENDPOINT", ""
        )
        self.headers_raw: str = os.environ.get("OTEL_EXPORTER_OTLP_HEADERS", "")
        self.resource_attrs: str = os.environ.get("OTEL_RESOURCE_ATTRIBUTES", "")
        self.dry_run: bool = os.environ.get("SAVIA_OTEL_DRYRUN", "").lower() == "true"
        self.max_confidentiality_raw: str = os.environ.get(
            "SAVIA_OTEL_MAX_CONFIDENTIALITY", "N2"
        )

    @property
    def max_confidentiality(self) -> ConfidentialityLevel:
        return parse_level(self.max_confidentiality_raw)

    @property
    def headers(self) -> dict[str, str]:
        """Parsea 'Key=Value,Key2=Value2' → dict."""
        result: dict[str, str] = {}
        for part in self.headers_raw.split(","):
            part = part.strip()
            if "=" in part:
                k, _, v = part.partition("=")
                result[k.strip()] = v.strip()
        return result

    @property
    def resource_attributes(self) -> dict[str, str]:
        """Parsea 'key=value,key2=value2' → dict."""
        result: dict[str, str] = {}
        for part in self.resource_attrs.split(","):
            part = part.strip()
            if "=" in part:
                k, _, v = part.partition("=")
                result[k.strip()] = v.strip()
        return result


def _safe_attr(value: Any) -> str | int | float | bool:
    """Convierte un valor a tipo aceptado por OTel (no envía objetos complejos)."""
    if isinstance(value, (str, int, float, bool)):
        return value
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


_EVENT_NAME_NORMALIZE: dict[str, str] = {
    # Normaliza convención underscore (flow_runner.py actual) a punto (spec §2.1)
    "flow_start": "flow.start",
    "flow_end": "flow.end",
    "node_start": "node.start",
    "node_end": "node.end",
}


def _normalize_event(event: dict[str, Any]) -> dict[str, Any]:
    """Normaliza nombres de eventos (underscore→punto) para compatibilidad con flow_runner."""
    ev_name = event.get("event", "")
    normalized = _EVENT_NAME_NORMALIZE.get(ev_name, ev_name)
    if normalized != ev_name:
        event = {**event, "event": normalized}
        # flow_runner usa "node" para el id, spec usa "node_id"
        if normalized in ("node.start", "node.end") and "node" in event and "node_id" not in event:
            event = {**event, "node_id": event["node"]}
    return event


def _parse_trace_jsonl(trace_path: Path) -> list[dict[str, Any]]:
    """Parsea JSONL línea a línea. Ignora líneas vacías y malformadas.

    Normaliza nombres de eventos entre convención underscore (flow_runner)
    y convención punto (spec §2.1) para compatibilidad total.
    """
    events: list[dict[str, Any]] = []
    with trace_path.open(encoding="utf-8") as f:
        for lineno, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                events.append(_normalize_event(json.loads(line)))
            except json.JSONDecodeError as exc:
                logger.warning("Línea %d malformada en traza, ignorando: %s", lineno, exc)
    return events


def _detect_confidentiality(events: list[dict[str, Any]]) -> ConfidentialityLevel:
    """Extrae el nivel de confidencialidad del evento flow.start."""
    for event in events:
        if event.get("event") == "flow.start":
            raw = event.get("confidentiality", "N1")
            try:
                return parse_level(str(raw))
            except ValueError:
                logger.warning(
                    "Nivel de confidencialidad desconocido %r, asumiendo N4 (restrictivo)",
                    raw,
                )
                return ConfidentialityLevel.N4
    return ConfidentialityLevel.N4  # Conservador si no hay flow.start


def _write_skip_event(trace_path: Path, reason: str) -> None:
    """Añade un evento otel.skipped al JSONL local."""
    skip_record = json.dumps({
        "event": _SKIP_EVENT_NAME,
        "ts": time.time(),
        "reason": reason,
    })
    with trace_path.open("a", encoding="utf-8") as f:
        f.write(skip_record + "\n")
    logger.info("OTel export saltado: %s", reason)


def _build_resource(config: OtelExporterConfig) -> Resource:
    attrs = {"service.name": "savia", "service.version": "1.0"}
    attrs.update(config.resource_attributes)
    return Resource.create(attrs)


def _build_exporter(config: OtelExporterConfig) -> OTLPSpanExporter | ConsoleSpanExporter:
    if config.dry_run:
        return ConsoleSpanExporter()

    # Rechazar endpoints sin HTTPS (§6 Riesgos)
    if config.endpoint and not config.endpoint.startswith("https://"):
        raise ValueError(
            f"El endpoint OTLP debe usar HTTPS. Recibido: {config.endpoint!r}. "
            "Configura OTEL_EXPORTER_OTLP_ENDPOINT=https://..."
        )

    return OTLPSpanExporter(
        endpoint=config.endpoint or None,
        headers=config.headers or None,
        timeout=_DEFAULT_TIMEOUT_S,
    )


def export_trace(
    trace_path: Path,
    config: OtelExporterConfig | None = None,
) -> bool:
    """Exporta una traza AFG como spans OTel.

    Args:
        trace_path: Path al fichero JSONL de la traza.
        config: Configuración OTel. Si None, usa variables de entorno.

    Returns:
        True si se exportó (o dry-run), False si se saltó.

    Raises:
        FileNotFoundError: Si trace_path no existe.
        ValueError: Si el endpoint es inválido (no HTTPS).
    """
    if config is None:
        config = OtelExporterConfig()

    if not config.enabled:
        logger.debug("SAVIA_OTEL_ENABLED no está activo. Sin exportación.")
        return False

    if not trace_path.exists():
        raise FileNotFoundError(f"Traza no encontrada: {trace_path}")

    events = _parse_trace_jsonl(trace_path)
    if not events:
        logger.warning("Traza vacía: %s", trace_path)
        return False

    # Gate de confidencialidad (D-4)
    flow_level = _detect_confidentiality(events)
    if not is_exportable(flow_level, config.max_confidentiality):
        _write_skip_event(
            trace_path,
            f"confidentiality_above_threshold: {flow_level.value} > {config.max_confidentiality.value}",
        )
        return False

    resource = _build_resource(config)
    exporter = _build_exporter(config)

    provider = TracerProvider(resource=resource)
    if config.dry_run:
        provider.add_span_processor(SimpleSpanProcessor(exporter))
    else:
        provider.add_span_processor(BatchSpanProcessor(exporter))

    tracer = provider.get_tracer("savia.flow-observability", "1.0")

    # Construir spans a partir de eventos
    root_span_ctx: Any = None
    child_spans: dict[str, Any] = {}

    flow_id = ""
    start_ts_ns: int = 0

    for event in events:
        event_type = event.get("event", "")
        ts_ns = int(event.get("ts", time.time()) * 1e9)

        if event_type == "flow.start":
            flow_id = str(event.get("flow_id", "unknown"))
            start_ts_ns = ts_ns
            root_attrs = {
                "savia.flow.id": flow_id,
                "savia.flow.version": _safe_attr(event.get("version", "")),
                "savia.profile": _safe_attr(event.get("profile", "")),
                "savia.confidentiality": flow_level.value,
            }
            root_span_ctx = tracer.start_span(
                name=f"flow/{flow_id}",
                kind=SpanKind.INTERNAL,
                start_time=ts_ns,
                attributes={k: v for k, v in root_attrs.items() if k in _ALLOWED_ROOT_ATTRS},
            )

        elif event_type == "profile.resolved" and root_span_ctx is not None:
            resolution = event.get("resolution", {})
            root_span_ctx.set_attribute(
                "savia.profile_resolution",
                _safe_attr(resolution),
            )

        elif event_type == "node.start" and root_span_ctx is not None:
            node_id = str(event.get("node_id", "unknown"))
            ctx = trace.use_span(root_span_ctx, end_on_exit=False)
            node_attrs = {
                "savia.node.id": node_id,
                "savia.node.kind": _safe_attr(event.get("kind", "")),
                "savia.tier_final": _safe_attr(event.get("tier_final", "")),
                "savia.tier_source": _safe_attr(event.get("tier_source", "")),
            }
            with ctx:
                child_span = tracer.start_span(
                    name=f"node/{node_id}",
                    kind=SpanKind.INTERNAL,
                    start_time=ts_ns,
                    attributes={k: v for k, v in node_attrs.items() if k in _ALLOWED_NODE_ATTRS},
                )
            child_spans[node_id] = child_span

        elif event_type == "node.error":
            node_id = str(event.get("node_id", "unknown"))
            span = child_spans.get(node_id)
            if span:
                span.set_status(StatusCode.ERROR, event.get("error_message", ""))
                span.set_attribute("error.type", _safe_attr(event.get("error_type", "unknown")))
                span.set_attribute("error.message", _safe_attr(event.get("error_message", "")))

        elif event_type == "node.end":
            node_id = str(event.get("node_id", "unknown"))
            span = child_spans.pop(node_id, None)
            if span:
                span.end(end_time=ts_ns)

        elif event_type == "flow.end" and root_span_ctx is not None:
            verdict = str(event.get("verdict", ""))
            duration_ms = event.get("duration_ms", 0)
            root_span_ctx.set_attribute("savia.verdict", verdict)
            root_span_ctx.set_attribute("savia.duration_ms", _safe_attr(duration_ms))

    # Cerrar spans huérfanos (node.start sin node.end)
    for orphan_span in child_spans.values():
        orphan_span.end()

    # Cerrar root span
    if root_span_ctx is not None:
        root_span_ctx.end()

    # Forzar flush (no bloquea más de timeout_s)
    try:
        provider.force_flush(timeout_millis=_DEFAULT_TIMEOUT_S * 1000)
    except Exception as exc:  # noqa: BLE001
        # Fallo del collector NO interrumpe el flujo (§4, §6)
        logger.warning("Flush OTel falló (no crítico): %s", exc)

    provider.shutdown()
    return True


def main() -> int:
    """Entrypoint CLI."""
    parser = argparse.ArgumentParser(
        description="Exporta una traza AFG JSONL como spans OpenTelemetry."
    )
    parser.add_argument(
        "--trace-file",
        required=True,
        type=Path,
        help="Path al fichero trace.jsonl generado por AFG.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Imprime spans a stdout sin enviar al endpoint.",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(levelname)s %(name)s: %(message)s",
    )

    config = OtelExporterConfig()
    if args.dry_run:
        config.dry_run = True

    if not config.enabled and not args.dry_run:
        print("SAVIA_OTEL_ENABLED no está activo. Sin exportación. Saliendo.", file=sys.stderr)
        return 0

    try:
        exported = export_trace(args.trace_file, config)
        if exported:
            print(f"✓ Traza exportada: {args.trace_file}")
        else:
            print(f"⊘ Traza saltada (confidencialidad o desactivado): {args.trace_file}")
        return 0
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except ValueError as exc:
        print(f"ERROR de configuración: {exc}", file=sys.stderr)
        return 2
    except Exception as exc:  # noqa: BLE001
        # Fallo del collector no interrumpe. Salida limpia.
        logger.error("Error al exportar traza (no crítico): %s", exc, exc_info=True)
        return 0


if __name__ == "__main__":
    sys.exit(main())
