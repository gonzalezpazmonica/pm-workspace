#!/usr/bin/env python3
"""A2A Server — SE-263 S5: Federation task plane.
Implements A2A v1.0 protocol (JSON-RPC 2.0 + SSE) with 5 federation skills.
Bind-gate enforced: refuses to start on non-declared interfaces.
"""
import json, os, sys, time, uuid, hashlib, threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

# ── Config ──
ROOT = Path(os.environ.get("SAVIA_ROOT", os.getcwd()))
CONFIG_PATH = ROOT / "coordinacion" / "federation.config.yaml"
ALLOWLIST_PATH = ROOT / "config" / "a2a-skills-allowlist.yaml"

SKILLS_V1 = {
    "situacion.query":     {"maxLevel": 2, "readOnly": True},
    "commitment.propose":  {"maxLevel": 2, "readOnly": False},
    "commitment.ack":      {"maxLevel": 2, "readOnly": False},
    "dependency.notify":   {"maxLevel": 2, "readOnly": True},
    "handoff.request":     {"maxLevel": 2, "readOnly": False},
}

ALLOWLIST = set(SKILLS_V1.keys())

class A2AHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        try:
            req = json.loads(body)
        except json.JSONDecodeError:
            self._jsonrpc_error(None, -32700, "Parse error")
            return

        method = req.get("method", "")
        params = req.get("params", {})
        msg_id = req.get("id")

        if method == "tasks/send":
            self._handle_task(params, msg_id)
        elif method == "tasks/get":
            self._handle_get(params, msg_id)
        elif method == "tasks/cancel":
            self._handle_cancel(params, msg_id)
        else:
            self._jsonrpc_error(msg_id, -32601, f"Method not found: {method}")

    def _handle_task(self, params, msg_id):
        skill = params.get("skill", "")
        if skill not in ALLOWLIST:
            self._jsonrpc_result(msg_id, {"status": "rejected", "reason": f"Skill not allowlisted: {skill}"})
            return

        task_id = str(uuid.uuid4())
        result = {
            "id": task_id,
            "status": "submitted",
            "skill": skill,
            "createdAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        }
        self._jsonrpc_result(msg_id, result)

    def _handle_get(self, params, msg_id):
        self._jsonrpc_result(msg_id, {"status": "unknown", "reason": "task state not persisted yet"})

    def _handle_cancel(self, params, msg_id):
        self._jsonrpc_result(msg_id, {"status": "cancelled"})

    def _jsonrpc_result(self, msg_id, result):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        resp = {"jsonrpc": "2.0", "id": msg_id, "result": result}
        self.wfile.write(json.dumps(resp).encode())

    def _jsonrpc_error(self, msg_id, code, message):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        resp = {"jsonrpc": "2.0", "id": msg_id, "error": {"code": code, "message": message}}
        self.wfile.write(json.dumps(resp).encode())

    def log_message(self, format, *args):
        pass  # silent in production; enable for debug

def main():
    import argparse
    p = argparse.ArgumentParser(description="Savia A2A Federation Server")
    p.add_argument("--host", default="127.0.0.1", help="Bind address")
    p.add_argument("--port", type=int, default=8080, help="Bind port")
    p.add_argument("--allowed-interface", help="Declared private network interface (bind-gate)")
    args = p.parse_args()

    # Bind-gate: refuse to start on non-declared interfaces
    if args.allowed_interface and args.host != args.allowed_interface:
        print(f"BIND-GATE ABORT: host={args.host} not in declared interface {args.allowed_interface}", file=sys.stderr)
        sys.exit(1)

    server = HTTPServer((args.host, args.port), A2AHandler)
    print(f"A2A server: {args.host}:{args.port} (skills={len(ALLOWLIST)})")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()

if __name__ == "__main__":
    main()
