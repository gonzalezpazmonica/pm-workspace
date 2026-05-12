"""
ephemeral_server.py — Servidor HTTP mínimo de referencia para URLs efímeras.

**NO es para producción.** Para producción: poner detrás de nginx/caddy
o integrar el handler en OpenCode.

Decisión D-5 de SPEC-AGENT-ARTIFACTS:
  Sirve /api/v1/ephemeral/artifacts/{token} verificando el token HMAC.
  Stdlib puro (http.server, urllib.parse). Sin dependencias externas.

Uso:
  python3 -m scripts.lib.artifacts.ephemeral_server          # puerto 8765
  python3 -m scripts.lib.artifacts.ephemeral_server --port 9000
  SAVIA_ARTIFACT_SECRET=mysecret python3 -m ... --artifacts-dir output/artifacts

Rule #26: Python para lógica HTTP, bash solo wrappers.
"""
from __future__ import annotations

import argparse
import http.server
import json
import mimetypes
import os
import urllib.parse
from pathlib import Path
from typing import Any

from scripts.lib.artifacts.ephemeral import TokenExpiredError, TokenInvalidError, validate_token
from scripts.lib.artifacts.store import ArtifactStore


# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------

DEFAULT_PORT = 8765
ROUTE_PREFIX = "/api/v1/ephemeral/artifacts/"


# ---------------------------------------------------------------------------
# Handler HTTP
# ---------------------------------------------------------------------------

class EphemeralArtifactHandler(http.server.BaseHTTPRequestHandler):
    """
    Maneja peticiones GET /api/v1/ephemeral/artifacts/{token}.

    Configurado desde el servidor via ``server.artifact_store`` y
    ``server.hmac_secret`` (bytes o None para leer de env).
    """

    server: "EphemeralArtifactServer"  # typing override

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        """Silencia el log por defecto de BaseHTTPRequestHandler."""
        pass

    def do_GET(self) -> None:  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/health":
            self._send_json(200, {"status": "ok", "server": "savia-artifacts-ephemeral"})
            return

        if not path.startswith(ROUTE_PREFIX):
            self._send_json(404, {"error": "Not found"})
            return

        token = path[len(ROUTE_PREFIX):]
        if not token:
            self._send_json(400, {"error": "Token vacío"})
            return

        self._serve_artifact(token)

    def _serve_artifact(self, token: str) -> None:
        """Valida el token y sirve el artifact."""
        secret = self.server.hmac_secret  # bytes | None

        try:
            et = validate_token(token, secret=secret)
        except TokenExpiredError as exc:
            self._send_json(410, {"error": "Token expirado", "detail": str(exc)})
            return
        except TokenInvalidError as exc:
            self._send_json(401, {"error": "Token inválido", "detail": str(exc)})
            return

        store: ArtifactStore = self.server.artifact_store
        try:
            content, meta = store.load_content(et.artifact_id)
        except FileNotFoundError:
            self._send_json(404, {"error": f"Artifact '{et.artifact_id}' no encontrado"})
            return

        # Determinar content-type para la respuesta
        content_type = meta.mime_type or "application/octet-stream"

        # Filename para Content-Disposition
        safe_name = urllib.parse.quote(meta.name)

        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(content)))
        self.send_header(
            "Content-Disposition",
            f'attachment; filename="{safe_name}"',
        )
        # Seguridad: no cachear URLs efímeras
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.end_headers()
        self.wfile.write(content)

    def _send_json(self, status: int, data: dict[str, Any]) -> None:
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


# ---------------------------------------------------------------------------
# Servidor con atributos extra (store + secret)
# ---------------------------------------------------------------------------

class EphemeralArtifactServer(http.server.HTTPServer):
    """HTTPServer decorado con artifact_store y hmac_secret."""

    def __init__(
        self,
        host: str,
        port: int,
        artifact_store: ArtifactStore,
        hmac_secret: bytes | None = None,
    ) -> None:
        super().__init__((host, port), EphemeralArtifactHandler)
        self.artifact_store = artifact_store
        self.hmac_secret = hmac_secret


# ---------------------------------------------------------------------------
# Factory pública (usada en tests)
# ---------------------------------------------------------------------------

def make_server(
    host: str = "127.0.0.1",
    port: int = DEFAULT_PORT,
    artifacts_dir: Path | None = None,
    hmac_secret: bytes | None = None,
) -> EphemeralArtifactServer:
    """
    Crea un EphemeralArtifactServer listo para arrancar.

    Parameters
    ----------
    host:
        Dirección de escucha. Default ``127.0.0.1``.
    port:
        Puerto. Default 8765.
    artifacts_dir:
        Directorio raíz de artifacts. Si None, usa SAVIA_ARTIFACTS_DIR o
        ``output/artifacts``.
    hmac_secret:
        Clave HMAC. Si None, se lee de SAVIA_ARTIFACT_SECRET en runtime.
    """
    effective_dir = artifacts_dir or Path(
        os.environ.get("SAVIA_ARTIFACTS_DIR", "output/artifacts")
    )
    store = ArtifactStore(effective_dir)
    return EphemeralArtifactServer(
        host=host,
        port=port,
        artifact_store=store,
        hmac_secret=hmac_secret,
    )


# ---------------------------------------------------------------------------
# Entrypoint CLI
# ---------------------------------------------------------------------------

def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Servidor de referencia para URLs efímeras de artifacts (solo desarrollo)."
    )
    parser.add_argument("--host", default="127.0.0.1", help="Dirección de escucha")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Puerto TCP")
    parser.add_argument(
        "--artifacts-dir",
        default=None,
        help="Directorio raíz de artifacts (default: SAVIA_ARTIFACTS_DIR o output/artifacts)",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    artifacts_dir = Path(args.artifacts_dir) if args.artifacts_dir else None
    server = make_server(host=args.host, port=args.port, artifacts_dir=artifacts_dir)
    print(
        f"[savia-artifacts] Servidor de referencia escuchando en "
        f"http://{args.host}:{args.port}{ROUTE_PREFIX}{{token}}"
    )
    print("[savia-artifacts] SOLO PARA DESARROLLO. No usar en producción.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[savia-artifacts] Detenido.")


if __name__ == "__main__":
    main()
