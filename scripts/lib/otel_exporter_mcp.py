"""
otel_exporter_mcp.py — MCP server que expone el exporter OTel como herramienta.

Implementa el protocolo MCP sobre stdin/stdout (JSON-RPC 2.0).
Tools expuestas:
  - export_trace(trace_path, endpoint, headers)   → exporta una traza AFG
  - validate_trace(trace_path)                    → valida schema y devuelve diagnóstico

Uso:
  python3 scripts/lib/otel_exporter_mcp.py

Registro en opencode.json (ejemplo):
  {
    "mcpServers": {
      "savia-otel-exporter": {
        "command": "python3",
        "args": ["scripts/lib/otel_exporter_mcp.py"]
      }
    }
  }
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

# Asegurar que scripts/lib está en el path
_LIB_DIR = Path(__file__).parent
if str(_LIB_DIR) not in sys.path:
    sys.path.insert(0, str(_LIB_DIR))

from otel_exporter import OtelExporterConfig, export_trace
from savia_confidentiality import parse_level

# ─── Protocolo MCP (JSON-RPC 2.0 sobre stdio) ────────────────────────────────

_MCP_VERSION = "2024-11-05"
_SERVER_INFO = {
    "name": "savia-otel-exporter",
    "version": "1.0.0",
}
_CAPABILITIES: dict[str, Any] = {"tools": {}}


def _send(obj: dict[str, Any]) -> None:
    line = json.dumps(obj, ensure_ascii=False)
    sys.stdout.write(line + "\n")
    sys.stdout.flush()


def _send_result(req_id: Any, result: Any) -> None:
    _send({"jsonrpc": "2.0", "id": req_id, "result": result})


def _send_error(req_id: Any, code: int, message: str) -> None:
    _send({"jsonrpc": "2.0", "id": req_id, "error": {"code": code, "message": message}})


# ─── Handlers de tools ───────────────────────────────────────────────────────

_TOOLS = [
    {
        "name": "export_trace",
        "description": (
            "Exporta una traza AFG (JSONL) como spans OpenTelemetry al endpoint OTLP configurado. "
            "Respeta el gate de confidencialidad. Devuelve {exported: bool, reason: str}."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "trace_path": {
                    "type": "string",
                    "description": "Path absoluto o relativo al fichero trace.jsonl generado por AFG.",
                },
                "endpoint": {
                    "type": "string",
                    "description": "Endpoint OTLP (https://...). Sobreescribe OTEL_EXPORTER_OTLP_ENDPOINT.",
                },
                "headers": {
                    "type": "string",
                    "description": "Headers en formato 'Key=Value,Key2=Value2'. Sobreescribe OTEL_EXPORTER_OTLP_HEADERS.",
                },
                "dry_run": {
                    "type": "boolean",
                    "description": "Si true, imprime spans a stdout sin enviar.",
                },
            },
            "required": ["trace_path"],
        },
    },
    {
        "name": "validate_trace",
        "description": (
            "Valida el schema de una traza AFG JSONL y devuelve diagnósticos. "
            "No requiere conexión al collector. "
            "Devuelve {valid: bool, events: int, issues: list[str]}."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "trace_path": {
                    "type": "string",
                    "description": "Path al fichero trace.jsonl a validar.",
                },
            },
            "required": ["trace_path"],
        },
    },
]


def _handle_export_trace(params: dict[str, Any]) -> dict[str, Any]:
    trace_path = Path(params["trace_path"])
    config = OtelExporterConfig()

    # Sobreescrituras desde parámetros del tool
    if "endpoint" in params and params["endpoint"]:
        os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"] = params["endpoint"]
        config = OtelExporterConfig()
    if "headers" in params and params["headers"]:
        os.environ["OTEL_EXPORTER_OTLP_HEADERS"] = params["headers"]
        config = OtelExporterConfig()
    if params.get("dry_run"):
        config.dry_run = True

    # Forzar habilitado cuando se llama via MCP con endpoint explícito
    if params.get("endpoint"):
        config.enabled = True

    try:
        exported = export_trace(trace_path, config)
        return {
            "exported": exported,
            "reason": "ok" if exported else "skipped_confidentiality_or_disabled",
        }
    except FileNotFoundError as exc:
        return {"exported": False, "reason": f"file_not_found: {exc}"}
    except ValueError as exc:
        return {"exported": False, "reason": f"config_error: {exc}"}
    except Exception as exc:  # noqa: BLE001
        return {"exported": False, "reason": f"export_error: {exc}"}


def _handle_validate_trace(params: dict[str, Any]) -> dict[str, Any]:
    trace_path = Path(params["trace_path"])

    if not trace_path.exists():
        return {"valid": False, "events": 0, "issues": [f"Fichero no encontrado: {trace_path}"]}

    events: list[dict[str, Any]] = []
    issues: list[str] = []
    parse_errors = 0

    with trace_path.open(encoding="utf-8") as f:
        for lineno, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError as exc:
                parse_errors += 1
                issues.append(f"Línea {lineno}: JSON inválido — {exc}")

    if not events:
        issues.append("Traza vacía (0 eventos parseados)")
        return {"valid": False, "events": 0, "issues": issues}

    # Validaciones mínimas de schema
    event_types = {e.get("event") for e in events}

    if "flow.start" not in event_types:
        issues.append("Falta evento flow.start")
    if "flow.end" not in event_types:
        issues.append("Falta evento flow.end")

    # Detectar confidencialidad declarada
    for event in events:
        if event.get("event") == "flow.start":
            conf_raw = event.get("confidentiality", "")
            if conf_raw:
                try:
                    parse_level(str(conf_raw))
                except ValueError:
                    issues.append(f"Nivel de confidencialidad inválido: {conf_raw!r}")
            break

    # node.start sin node.end
    started = {e.get("node_id") for e in events if e.get("event") == "node.start"}
    ended = {e.get("node_id") for e in events if e.get("event") == "node.end"}
    orphans = started - ended
    if orphans:
        issues.append(f"Nodos sin node.end: {sorted(orphans)}")

    valid = parse_errors == 0 and len(issues) == 0
    return {
        "valid": valid,
        "events": len(events),
        "issues": issues,
    }


# ─── Loop principal MCP ──────────────────────────────────────────────────────

def _handle_request(req: dict[str, Any]) -> None:
    req_id = req.get("id")
    method = req.get("method", "")
    params = req.get("params") or {}

    if method == "initialize":
        _send_result(req_id, {
            "protocolVersion": _MCP_VERSION,
            "serverInfo": _SERVER_INFO,
            "capabilities": _CAPABILITIES,
        })

    elif method == "tools/list":
        _send_result(req_id, {"tools": _TOOLS})

    elif method == "tools/call":
        tool_name = params.get("name", "")
        tool_args = params.get("arguments") or {}

        if tool_name == "export_trace":
            result = _handle_export_trace(tool_args)
        elif tool_name == "validate_trace":
            result = _handle_validate_trace(tool_args)
        else:
            _send_error(req_id, -32601, f"Tool desconocido: {tool_name!r}")
            return

        _send_result(req_id, {
            "content": [{"type": "text", "text": json.dumps(result, ensure_ascii=False)}],
        })

    elif method == "notifications/initialized":
        # Notificación sin respuesta
        pass

    else:
        _send_error(req_id, -32601, f"Método desconocido: {method!r}")


def main() -> int:
    """Loop stdin/stdout del servidor MCP."""
    for raw_line in sys.stdin:
        raw_line = raw_line.strip()
        if not raw_line:
            continue
        try:
            req = json.loads(raw_line)
        except json.JSONDecodeError as exc:
            _send_error(None, -32700, f"JSON inválido: {exc}")
            continue

        try:
            _handle_request(req)
        except Exception as exc:  # noqa: BLE001
            req_id = req.get("id")
            _send_error(req_id, -32603, f"Error interno: {exc}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
