#!/usr/bin/env python3
"""veto-bus.py — SE-268 S1: Constitutional veto bus (hyperdirect pathway).
Minimal-latency control plane, independent from A2A and git state plane.
Protocol: HTTP/JSON over Unix socket or TCP.
  POST /veto         — publish veto {action, scope, ttl, reason}
  GET  /check?q=X    — check if action X is vetoed
  GET  /vetos         — list active vetos
  DELETE /veto/{id}   — revoke veto
  GET  /health        — liveness
Startup: compiles CRITERIO.md linea_roja → permanent vetos.
Fail-closed: unreachable → treat as blocked.
"""
from __future__ import annotations

import argparse, json, os, re, signal, sys, threading, time, uuid
from datetime import datetime, timezone
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from typing import Optional
from socketserver import UnixStreamServer

ROOT = Path(os.environ.get("SAVIA_ROOT", os.getcwd()))
CRITERIO_PATH = ROOT / "CRITERIO.md"
STATE_FILE = ROOT / "bridge" / "control-plane" / "veto-state.json"

_active: dict[str, dict] = {}
_lock = threading.Lock()

def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def _now_ts() -> float:
    return time.time()

# ── Compile CRITERIO.md linea_roja → permanent vetos ──────────────────────
def compile_criterio(path: Path) -> list[dict]:
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8")
    vetos: list[dict] = []
    cur_section = "global"
    cur_id = cur_dur = cur_amb = cur_prin = cur_enf = cur_section_snap = None

    for line in text.split("\n"):
        sm = re.match(r"^###\s+(\w+)", line)
        if sm:
            cur_section = sm.group(1)
            continue
        m = re.match(r"^(CRIT-\d{3})\b", line)
        if m:
            if cur_id and cur_dur == "linea_roja":
                vetos.append(_build_veto(cur_id, cur_amb or cur_section_snap, cur_prin, cur_enf))
            cur_id = m.group(1)
            cur_section_snap = cur_section
            cur_dur = cur_amb = cur_prin = cur_enf = None
            continue
        if cur_id:
            if "dureza:" in line:
                dm = re.search(r"dureza:\s*(linea_roja|preferencia|estilo)", line)
                if dm: cur_dur = dm.group(1)
            if "ambito:" in line and not cur_amb:
                am = re.search(r"ambito:\s*(\w+)", line)
                if am: cur_amb = am.group(1)
            if "principio:" in line and not cur_prin:
                pm = re.search(r"principio:\s*(.+)", line)
                if pm: cur_prin = pm.group(1).strip()
            if "enforcement:" in line and not cur_enf:
                em = re.search(r"enforcement:\s*(.+)", line)
                if em: cur_enf = em.group(1).strip()

    if cur_id and cur_dur == "linea_roja":
        vetos.append(_build_veto(cur_id, cur_amb or cur_section_snap, cur_prin, cur_enf))
    return vetos

def _build_veto(crit_id: str, ambito, principio, enforcement):
    return {
        "id": f"crit-{crit_id.lower()}",
        "action": crit_id,
        "scope": "domain",
        "ttl": None,
        "reason": f"[CRITERIO] {crit_id}: {principio or 'linea_roja'}",
        "source": "criterio-compiled",
        "domain": ambito or "global",
        "enforcement": enforcement or "",
        "published_at": _now_iso(),
    }

# ── Veto matching ─────────────────────────────────────────────────────────
def _matches(veto: dict, action: str) -> bool:
    scope = veto.get("scope", "global")
    if scope == "global":
        return True
    if scope == "domain":
        dom = veto.get("domain", "")
        return bool(dom and action.startswith(f"domain:{dom}"))
    if scope == "instance":
        inst = veto.get("instance", "")
        return bool(inst and inst in action)
    if scope == "session":
        sess = veto.get("session", "")
        return bool(sess and action.startswith(sess))
    return False

def check(action: str) -> tuple[bool, list[dict]]:
    with _lock:
        now = _now_ts()
        matching = []
        for vid, veto in list(_active.items()):
            expires = veto.get("expires_at")
            if expires is not None and now >= expires:
                del _active[vid]
                continue
            if _matches(veto, action):
                matching.append(veto)
        return (len(matching) > 0, matching)

def publish(action: str, scope="global", ttl=None, reason="",
            domain="", instance="", session="", source="human") -> dict:
    vid = f"veto-{uuid.uuid4().hex[:8]}"
    now = _now_ts()
    veto = {"id": vid, "action": action, "scope": scope, "ttl": ttl,
            "expires_at": (now + ttl) if ttl is not None else None, "reason": reason,
            "source": source, "domain": domain, "instance": instance,
            "session": session, "published_at": _now_iso()}
    with _lock:
        _active[vid] = veto
    _persist()
    return veto

def revoke(vid: str) -> bool:
    with _lock:
        if vid in _active:
            del _active[vid]
            _persist()
            return True
    return False

def list_all() -> list[dict]:
    with _lock:
        return list(_active.values())

# ── Persistence ───────────────────────────────────────────────────────────
def _persist():
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    try:
        STATE_FILE.write_text(json.dumps({
            "vetos": list(_active.values()), "saved_at": _now_iso()
        }, indent=2, ensure_ascii=False))
    except OSError:
        pass

def _load():
    if STATE_FILE.exists():
        try:
            data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
            now = _now_ts()
            with _lock:
                for v in data.get("vetos", []):
                    ttl = v.get("ttl")
                    if ttl is not None and now >= v.get("expires_at", 0):
                        continue
                    _active[v["id"]] = v
        except (json.JSONDecodeError, KeyError):
            pass

# ── TTL expiry ────────────────────────────────────────────────────────────
def _ttl_loop():
    while True:
        time.sleep(10)
        with _lock:
            now = _now_ts()
            stale = [vid for vid, v in _active.items()
                       if v.get("expires_at") is not None and now >= v.get("expires_at", 0)]
            for vid in stale:
                del _active[vid]
            if stale:
                _persist()

# ── HTTP handler ──────────────────────────────────────────────────────────
class VetoHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self._json(200, {"status": "ok", "vetos": len(_active)})
        elif self.path == "/vetos":
            self._json(200, {"vetos": list_all()})
        elif self.path.startswith("/check"):
            q = self._qs().get("q", "")
            if not q:
                self._json(400, {"error": "missing q param"})
                return
            blocked, vetos = check(q)
            self._json(200, {"action": q, "allowed": not blocked, "blocked_by": vetos})
        else:
            self._json(404, {"error": "not found"})

    def do_POST(self):
        if self.path == "/veto":
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length))
            veto = publish(
                action=body.get("action", "*"),
                scope=body.get("scope", "global"),
                ttl=body.get("ttl"),
                reason=body.get("reason", ""),
                domain=body.get("domain", ""),
                instance=body.get("instance", ""),
                session=body.get("session", ""),
                source=body.get("source", "human"),
            )
            self._json(201, {"status": "published", "veto": veto})
        else:
            self._json(404, {"error": "not found"})

    def do_DELETE(self):
        if self.path.startswith("/veto/"):
            vid = self.path.split("/")[-1]
            ok = revoke(vid)
            self._json(200, {"status": "revoked" if ok else "not_found", "id": vid})
        else:
            self._json(404, {"error": "not found"})

    def _json(self, code, data):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode())

    def _qs(self):
        qs = self.path.split("?")[-1] if "?" in self.path else ""
        return {k: v for k, v in (p.split("=", 1) for p in qs.split("&") if "=" in p)}

    def log_message(self, fmt, *args):
        pass

# ── Unix socket server ────────────────────────────────────────────────────
class VetoUnixServer(UnixStreamServer):
    allow_reuse_address = True

def _unix_handler():
    return type("_UnixHandler", (VetoHandler,), {})

# ── Main ──────────────────────────────────────────────────────────────────
def main():
    p = argparse.ArgumentParser(description="SE-268 Veto Bus")
    g = p.add_mutually_exclusive_group()
    g.add_argument("--socket", default="/tmp/savia-veto.sock")
    g.add_argument("--host", default=None)
    p.add_argument("--port", type=int, default=9090)
    p.add_argument("--criterio", default=str(CRITERIO_PATH))
    args = p.parse_args()

    compiled = compile_criterio(Path(args.criterio))
    with _lock:
        for v in compiled:
            _active[v["id"]] = v
    print(f"[veto-bus] {len(compiled)} linea_roja vetos compiled", file=sys.stderr)

    _load()
    threading.Thread(target=_ttl_loop, daemon=True).start()

    if args.host:
        srv = HTTPServer((args.host, args.port), VetoHandler)
        print(f"[veto-bus] TCP {args.host}:{args.port} ({len(_active)} vetos)", file=sys.stderr)
    else:
        sock = args.socket
        if os.path.exists(sock):
            os.unlink(sock)
        srv = VetoUnixServer(sock, _unix_handler())
        os.chmod(sock, 0o600)
        print(f"[veto-bus] unix:{sock} ({len(_active)} vetos)", file=sys.stderr)

    def stop(sig, frame):
        _persist()
        srv.shutdown()
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        if not args.host and os.path.exists(args.socket):
            os.unlink(args.socket)

if __name__ == "__main__":
    main()
