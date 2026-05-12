"""
test_otel_exporter.py — Tests unitarios para otel_exporter.py (12 casos requeridos por spec).

Usa dry-run y mocking de exporters para no requerir un collector real.
"""
from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Asegurar que scripts/lib está en el path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts" / "lib"))

from otel_exporter import (
    OtelExporterConfig,
    _detect_confidentiality,
    _normalize_event,
    _parse_trace_jsonl,
    _write_skip_event,
    export_trace,
)
from savia_confidentiality import ConfidentialityLevel

_FIXTURES = Path(__file__).parent / "fixtures"


# ─── Fixtures ────────────────────────────────────────────────────────────────

@pytest.fixture
def sample_trace(tmp_path: Path) -> Path:
    """Traza AFG mínima válida (N1)."""
    trace = tmp_path / "trace.jsonl"
    events = [
        {"event": "flow.start", "flow_id": "run-001", "version": "1.0",
         "profile": "test", "confidentiality": "N1", "ts": time.time()},
        {"event": "node.start", "node_id": "validate", "kind": "validate",
         "tier_final": "fast", "tier_source": "preferences", "ts": time.time()},
        {"event": "node.end", "node_id": "validate", "ts": time.time()},
        {"event": "flow.end", "verdict": "ok", "duration_ms": 100, "ts": time.time()},
    ]
    with trace.open("w") as f:
        for e in events:
            f.write(json.dumps(e) + "\n")
    return trace


@pytest.fixture
def n3_trace(tmp_path: Path) -> Path:
    """Traza con confidencialidad N3 (sobre el umbral N2)."""
    trace = tmp_path / "trace-n3.jsonl"
    events = [
        {"event": "flow.start", "flow_id": "run-n3", "confidentiality": "N3", "ts": time.time()},
        {"event": "flow.end", "verdict": "ok", "duration_ms": 50, "ts": time.time()},
    ]
    with trace.open("w") as f:
        for e in events:
            f.write(json.dumps(e) + "\n")
    return trace


@pytest.fixture
def enabled_config_dryrun() -> OtelExporterConfig:
    """Config con dry-run activo (no requiere endpoint real)."""
    os.environ["SAVIA_OTEL_ENABLED"] = "true"
    os.environ["SAVIA_OTEL_DRYRUN"] = "true"
    os.environ["SAVIA_OTEL_MAX_CONFIDENTIALITY"] = "N2"
    config = OtelExporterConfig()
    yield config
    # Cleanup env vars
    for key in ("SAVIA_OTEL_ENABLED", "SAVIA_OTEL_DRYRUN", "SAVIA_OTEL_MAX_CONFIDENTIALITY"):
        os.environ.pop(key, None)


# ─── Tests ───────────────────────────────────────────────────────────────────

class TestParseTraceJsonl:
    """TC-01: Parseo de JSONL."""

    def test_parses_valid_jsonl(self) -> None:
        fixture = _FIXTURES / "sample-trace.jsonl"
        events = _parse_trace_jsonl(fixture)
        assert len(events) == 7  # 7 eventos en el fixture
        assert events[0]["event"] == "flow.start"

    def test_ignores_blank_lines(self, tmp_path: Path) -> None:
        trace = tmp_path / "blank.jsonl"
        trace.write_text('{"event":"flow.start","ts":1.0}\n\n{"event":"flow.end","ts":2.0}\n')
        events = _parse_trace_jsonl(trace)
        assert len(events) == 2

    def test_ignores_malformed_lines(self, tmp_path: Path) -> None:
        trace = tmp_path / "bad.jsonl"
        trace.write_text('{"event":"flow.start"}\nnot-json\n{"event":"flow.end"}\n')
        events = _parse_trace_jsonl(trace)
        assert len(events) == 2  # La línea malformada se ignora


class TestDetectConfidentiality:
    """TC-02: Detección de nivel de confidencialidad."""

    def test_detects_n1_from_flow_start(self, sample_trace: Path) -> None:
        events = _parse_trace_jsonl(sample_trace)
        level = _detect_confidentiality(events)
        assert level == ConfidentialityLevel.N1

    def test_detects_n3(self, n3_trace: Path) -> None:
        events = _parse_trace_jsonl(n3_trace)
        assert _detect_confidentiality(events) == ConfidentialityLevel.N3

    def test_defaults_to_n4_when_no_flow_start(self, tmp_path: Path) -> None:
        """Sin flow.start, asume N4 (conservador)."""
        trace = tmp_path / "no-start.jsonl"
        trace.write_text('{"event":"node.start","node_id":"x"}\n')
        events = _parse_trace_jsonl(trace)
        assert _detect_confidentiality(events) == ConfidentialityLevel.N4


class TestExportDisabledByDefault:
    """TC-03: Sin SAVIA_OTEL_ENABLED=true, el exporter no hace nada."""

    def test_disabled_by_default(self, sample_trace: Path) -> None:
        os.environ.pop("SAVIA_OTEL_ENABLED", None)
        config = OtelExporterConfig()
        config.enabled = False
        result = export_trace(sample_trace, config)
        assert result is False


class TestConfidentialityGate:
    """TC-04 y TC-05: Gate de confidencialidad."""

    def test_n1_trace_exported_with_n2_threshold(
        self, sample_trace: Path, enabled_config_dryrun: OtelExporterConfig
    ) -> None:
        """Flujo N1 con umbral N2 → debe exportar."""
        result = export_trace(sample_trace, enabled_config_dryrun)
        assert result is True

    def test_n3_trace_skipped_with_n2_threshold(
        self, n3_trace: Path, enabled_config_dryrun: OtelExporterConfig
    ) -> None:
        """Flujo N3 con umbral N2 → NO debe exportar (criterio clave de la spec)."""
        result = export_trace(n3_trace, enabled_config_dryrun)
        assert result is False

    def test_skip_writes_otel_skipped_event(
        self, n3_trace: Path, enabled_config_dryrun: OtelExporterConfig
    ) -> None:
        """Al saltar por confidencialidad, se añade otel.skipped al JSONL."""
        export_trace(n3_trace, enabled_config_dryrun)
        lines = n3_trace.read_text().splitlines()
        skip_events = [json.loads(l) for l in lines if l.strip()]
        skip_found = any(e.get("event") == "otel.skipped" for e in skip_events)
        assert skip_found, "Debe haber un evento otel.skipped en el JSONL"


class TestCollectorFailureDoesNotInterrupt:
    """TC-06: Fallo del collector NO interrumpe el flujo."""

    def test_network_failure_returns_gracefully(self, sample_trace: Path) -> None:
        """Si el exporter falla, export_trace no lanza excepción."""
        os.environ["SAVIA_OTEL_ENABLED"] = "true"
        os.environ["SAVIA_OTEL_DRYRUN"] = "false"
        os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"] = "https://nonexistent-collector.invalid/v1/traces"
        os.environ["SAVIA_OTEL_MAX_CONFIDENTIALITY"] = "N2"
        config = OtelExporterConfig()

        # No debe lanzar excepción aunque el collector no exista
        try:
            export_trace(sample_trace, config)
            assert True  # Llegamos aquí sin excepción
        except Exception as exc:
            pytest.fail(f"export_trace no debe propagar excepciones de red: {exc}")
        finally:
            for key in ("SAVIA_OTEL_ENABLED", "SAVIA_OTEL_DRYRUN",
                        "OTEL_EXPORTER_OTLP_ENDPOINT", "SAVIA_OTEL_MAX_CONFIDENTIALITY"):
                os.environ.pop(key, None)


class TestNoPIILeakage:
    """TC-07: Los prompts y outputs NUNCA se incluyen como atributos OTel."""

    def test_prompt_not_in_span_attributes(self, tmp_path: Path, enabled_config_dryrun: OtelExporterConfig) -> None:
        """Una traza con campo 'prompt' no debe emitir ese campo como atributo OTel."""
        trace = tmp_path / "trace-pii.jsonl"
        events = [
            {"event": "flow.start", "flow_id": "pii-test", "confidentiality": "N1",
             "prompt": "SECRET PROMPT — NUNCA EN OTEL", "ts": time.time()},
            {"event": "flow.end", "verdict": "ok", "duration_ms": 10,
             "output": "SECRET OUTPUT — NUNCA EN OTEL", "ts": time.time()},
        ]
        with trace.open("w") as f:
            for e in events:
                f.write(json.dumps(e) + "\n")

        # Capturar spans emitidos en dry-run usando ConsoleSpanExporter
        import io
        from contextlib import redirect_stdout

        buf = io.StringIO()
        with redirect_stdout(buf):
            export_trace(trace, enabled_config_dryrun)

        output = buf.getvalue()
        assert "SECRET PROMPT" not in output
        assert "SECRET OUTPUT" not in output


class TestFileNotFound:
    """TC-08: FileNotFoundError si la traza no existe."""

    def test_raises_file_not_found(self, enabled_config_dryrun: OtelExporterConfig) -> None:
        with pytest.raises(FileNotFoundError):
            export_trace(Path("/tmp/nonexistent-trace-12345.jsonl"), enabled_config_dryrun)


class TestHttpsRequired:
    """TC-09: Endpoint sin HTTPS es rechazado."""

    def test_http_endpoint_raises_value_error(self, sample_trace: Path) -> None:
        os.environ["SAVIA_OTEL_ENABLED"] = "true"
        os.environ["SAVIA_OTEL_MAX_CONFIDENTIALITY"] = "N2"
        config = OtelExporterConfig()
        config.enabled = True
        config.dry_run = False
        # Simular endpoint HTTP (no HTTPS)
        os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"] = "http://insecure-endpoint/v1/traces"
        config2 = OtelExporterConfig()
        config2.enabled = True
        config2.dry_run = False

        with pytest.raises(ValueError, match="HTTPS"):
            export_trace(sample_trace, config2)

        for key in ("SAVIA_OTEL_ENABLED", "SAVIA_OTEL_MAX_CONFIDENTIALITY",
                    "OTEL_EXPORTER_OTLP_ENDPOINT"):
            os.environ.pop(key, None)


class TestOrphanNodes:
    """TC-10: Nodos sin node.end se cierran limpiamente."""

    def test_orphan_nodes_do_not_crash(
        self, tmp_path: Path, enabled_config_dryrun: OtelExporterConfig
    ) -> None:
        trace = tmp_path / "orphan.jsonl"
        events = [
            {"event": "flow.start", "flow_id": "orphan-test", "confidentiality": "N1", "ts": time.time()},
            {"event": "node.start", "node_id": "orphan-node", "kind": "agent",
             "tier_final": "mid", "tier_source": "preferences", "ts": time.time()},
            # Sin node.end — nodo huérfano
            {"event": "flow.end", "verdict": "ok", "duration_ms": 10, "ts": time.time()},
        ]
        with trace.open("w") as f:
            for e in events:
                f.write(json.dumps(e) + "\n")

        # No debe lanzar excepción
        result = export_trace(trace, enabled_config_dryrun)
        assert result is True


class TestDryRunMode:
    """TC-11: Modo dry-run exporta sin enviar al endpoint."""

    def test_dry_run_does_not_require_endpoint(
        self, sample_trace: Path, enabled_config_dryrun: OtelExporterConfig
    ) -> None:
        """Dry-run activo sin endpoint → debe funcionar igual."""
        os.environ.pop("OTEL_EXPORTER_OTLP_ENDPOINT", None)
        result = export_trace(sample_trace, enabled_config_dryrun)
        assert result is True


class TestWriteSkipEvent:
    """TC-12: _write_skip_event añade el evento correcto al JSONL."""

    def test_skip_event_format(self, tmp_path: Path) -> None:
        trace = tmp_path / "skip-test.jsonl"
        trace.write_text('{"event":"flow.start"}\n')
        _write_skip_event(trace, "confidentiality_above_threshold: N3 > N2")

        lines = trace.read_text().splitlines()
        assert len(lines) == 2
        skip_event = json.loads(lines[1])
        assert skip_event["event"] == "otel.skipped"
        assert "confidentiality_above_threshold" in skip_event["reason"]
        assert "ts" in skip_event


class TestEventNormalization:
    """TC-13 (bonus): Normalización underscore→punto para compatibilidad con flow_runner."""

    def test_flow_start_underscore_normalized(self) -> None:
        ev = _normalize_event({"event": "flow_start", "flow_id": "x", "confidentiality": "N1"})
        assert ev["event"] == "flow.start"

    def test_node_start_underscore_normalized(self) -> None:
        ev = _normalize_event({"event": "node_start", "node": "validate"})
        assert ev["event"] == "node.start"
        assert ev["node_id"] == "validate"

    def test_dot_notation_passthrough(self) -> None:
        ev = _normalize_event({"event": "flow.start", "flow_id": "x"})
        assert ev["event"] == "flow.start"

    def test_runner_format_trace_exportable(
        self, tmp_path: Path, enabled_config_dryrun: OtelExporterConfig
    ) -> None:
        """Una traza en formato flow_runner (underscores) debe exportarse sin error."""
        trace = tmp_path / "runner-trace.jsonl"
        events = [
            {"event": "flow_start", "flow_id": "r-001", "confidentiality": "N1", "ts": time.time()},
            {"event": "node_start", "node": "check", "kind": "validate",
             "tier_final": "fast", "tier_source": "preferences", "ts": time.time()},
            {"event": "node_end", "node": "check", "ts": time.time()},
            {"event": "flow_end", "ok": True, "duration_s": 0.1, "ts": time.time()},
        ]
        with trace.open("w") as f:
            for e in events:
                f.write(json.dumps(e) + "\n")
        result = export_trace(trace, enabled_config_dryrun)
        assert result is True
