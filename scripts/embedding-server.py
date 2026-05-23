#!/usr/bin/env python3
"""embedding-server.py — In-process HTTP server for sentence_transformers embeddings.

Keeps the model resident in memory so recall/search avoid the 15-30s cold-start
on every call. Launched lazily by memory-store.sh on first vector/hybrid search.

Port:  $SAVIA_EMBED_PORT  (default 7331)
Model: $SAVIA_EMBED_MODEL (default all-MiniLM-L6-v2)

Endpoints:
  GET  /health  → {"status": "ok", "model": "<name>"}
  POST /embed   → body {"text": "..."}  → {"embedding": [...]}

Windows launch (no nohup): memory-store.sh uses cmd.exe /c "start /b python3 ..."
Linux/macOS launch:         memory-store.sh uses nohup python3 ... &
"""

import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("SAVIA_EMBED_PORT", "7331"))
MODEL_NAME = os.environ.get("SAVIA_EMBED_MODEL", "all-MiniLM-L6-v2")

_model = None


def _get_model():
    global _model
    if _model is None:
        try:
            from sentence_transformers import SentenceTransformer
        except ImportError:
            print("[embedding-server] ERROR: sentence-transformers not installed.", flush=True)
            print("[embedding-server] Run: pip install sentence-transformers", flush=True)
            sys.exit(1)
        _model = SentenceTransformer(MODEL_NAME)
    return _model


class _Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # suppress access log
        pass

    def do_GET(self):
        if self.path == "/health":
            self._send(200, {"status": "ok", "model": MODEL_NAME})
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/embed":
            self._send(404, {"error": "not found"})
            return
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        try:
            data = json.loads(body)
        except ValueError:
            self._send(400, {"error": "invalid JSON"})
            return
        text = data.get("text", "")
        if not text:
            self._send(400, {"error": "missing 'text' field"})
            return
        try:
            embedding = _get_model().encode(text).tolist()
            self._send(200, {"embedding": embedding})
        except Exception as exc:
            self._send(500, {"error": str(exc)})

    def _send(self, code, data):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    print(f"[embedding-server] Loading model {MODEL_NAME}…", flush=True)
    _get_model()  # pre-warm to fail fast if not installed
    server = HTTPServer(("127.0.0.1", PORT), _Handler)
    print(f"[embedding-server] Ready → http://127.0.0.1:{PORT}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
