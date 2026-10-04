#!/usr/bin/env bats
# test-lightpanda-browser.bats — calibracion SE-376 de la skill lightpanda-browser.
# La skill (deprecated, sustituida por obscura-browser) delega el fallback en
# scripts/scrapling-fetch.sh. Estos tests ejercitan ese wrapper contra un
# servidor HTTP sintetico en 127.0.0.1: nunca se sale a internet.
# Ref: docs/rules/domain/research-stack.md
# Ref: docs/propuestas/SE-061-scrapling-research-backend.md
# Skill: .claude/skills/lightpanda-browser/SKILL.md

SCRIPT="scripts/scrapling-fetch.sh"

setup_file() {
  export SRV_DIR
  SRV_DIR="$(mktemp -d)"
  cat > "$SRV_DIR/srv.py" <<'PY'
import http.server
import sys
import time


class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, body, ctype="text/html; charset=utf-8", extra=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _redirect(self, location):
        self.send_response(302)
        self.send_header("Location", location)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        p = self.path
        if p == "/ok":
            self._send(200, b"<html><head><title>Hola\n mundo</title></head><body><script>\nvar secreto=1;\n</script><p>Texto &amp; m\xc3\xa1s</p></body></html>")
        elif p in ("/403", "/503", "/404"):
            self._send(int(p[1:]), b"<html><title>Fallo</title><p>cuerpo de error</p></html>")
        elif p == "/latin1":
            self._send(200, "<html><title>Canción</title><p>año</p></html>".encode("latin-1"), "text/html; charset=iso-8859-1")
        elif p == "/metalatin1":
            self._send(200, b'<html><head><meta charset="iso-8859-1"><title>x</title></head><p>ni\xf1o</p></html>', "text/html")
        elif p == "/empty":
            self._send(200, b"")
        elif p == "/medium":
            self._send(200, b"<html><title>m</title><p>" + b"palabra " * 40000 + b"</p></html>")
        elif p == "/big":
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            chunk = b"A" * 1024 * 1024
            try:
                for _ in range(40):
                    self.wfile.write(chunk)
            except (BrokenPipeError, ConnectionResetError):
                print("cliente corto la conexion (esperado en /big)", file=sys.stderr)
        elif p == "/slow":
            time.sleep(6)
            self._send(200, b"<title>tarde</title>")
        elif p == "/loop":
            self._redirect("/loop")
        elif p == "/rel":
            self._redirect("/ok")
        elif p.startswith("/redir?to="):
            self._redirect(p.split("=", 1)[1])
        else:
            self._send(404, b"nada")


srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), H)
with open(sys.argv[1], "w") as fh:
    fh.write(str(srv.server_address[1]))
srv.serve_forever()
PY
  python3 "$SRV_DIR/srv.py" "$SRV_DIR/port" 2>/dev/null &
  echo $! > "$SRV_DIR/pid"
  # Par para DNS rebinding: PUBLIC en 127.0.0.2:P (el sitecustomize de los tests lo
  # trata como IP global) e INTERNAL en 127.0.0.1:P, que cuenta cada peticion.
  cat > "$SRV_DIR/pair.py" <<'PY'
import http.server
import sys
import threading

out_dir = sys.argv[1]


def handler(label):
    class H(http.server.BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def do_GET(self):
            with open("%s/%s.hits" % (out_dir, label), "a") as fh:
                fh.write(self.path + "\n")
            if self.path.startswith("/redir?to="):
                self.send_response(302)
                self.send_header("Location", self.path.split("=", 1)[1])
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
            body = ("<html><title>%s</title><p>body-%s</p></html>" % (label, label)).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
    return H


for _ in range(50):
    pub = http.server.ThreadingHTTPServer(("127.0.0.2", 0), handler("PUBLIC"))
    port = pub.server_address[1]
    try:
        internal = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler("INTERNAL"))
        break
    except OSError as e:
        print("puerto %d ocupado en 127.0.0.1 (%s), se reintenta" % (port, e), file=sys.stderr)
        pub.server_close()
else:
    sys.exit("sin puerto libre comun en 127.0.0.1/127.0.0.2")
threading.Thread(target=pub.serve_forever, daemon=True).start()
with open("%s/rport" % out_dir, "w") as fh:
    fh.write(str(port))
internal.serve_forever()
PY
  python3 "$SRV_DIR/pair.py" "$SRV_DIR" 2>/dev/null &
  echo $! > "$SRV_DIR/pairpid"
  local i
  for i in $(seq 1 50); do
    [[ -s "$SRV_DIR/port" && -s "$SRV_DIR/rport" ]] && break
    sleep 0.1
  done
}

teardown_file() {
  local f
  for f in pid pairpid; do
    if [[ -s "$SRV_DIR/$f" ]]; then
      kill "$(cat "$SRV_DIR/$f")" 2>/dev/null || true
    fi
  done
  rm -rf "$SRV_DIR"
}

setup() {
  cd "$BATS_TEST_DIRNAME/.." || return 1
  TMPDIR_T="$(mktemp -d)"
  BASE="http://127.0.0.1:$(cat "$SRV_DIR/port")"
}

teardown() {
  # servidor IPv6 de un solo uso: si el test falla antes de usarlo, no debe quedar vivo
  if [[ -s "$TMPDIR_T/v6pid" ]]; then
    kill "$(cat "$TMPDIR_T/v6pid")" 2>/dev/null || true
  fi
  rm -rf "$TMPDIR_T"
}

# Lee un campo del JSON (ultima linea: run mezcla stderr, donde van ERROR/WARN).
jget() {
  python3 -c 'import json,sys; d=json.loads(sys.stdin.read().strip().splitlines()[-1]); v=d.get(sys.argv[1]); print("" if v is None else v)' "$1"
}

# Peticiones que ha recibido el servidor INTERNAL del par de rebinding.
internal_hits() {
  if [[ -f "$SRV_DIR/INTERNAL.hits" ]]; then wc -l < "$SRV_DIR/INTERNAL.hits"; else echo 0; fi
}

# sitecustomize: para Python, `localhost` resuelve a 127.0.0.2 y esa IP es global.
# curl sigue resolviendo `localhost` con el sistema (127.0.0.1, el servidor INTERNAL).
# REBIND_MODE=alternate: TTL 0 hostil, publica en las llamadas impares e interna en las pares.
rebind_site() {
  mkdir -p "$TMPDIR_T/py"
  cat > "$TMPDIR_T/py/sitecustomize.py" <<'PY'
import ipaddress
import os
import socket

_MODE = os.environ.get("REBIND_MODE")
if _MODE:
    _PUB, _INT = "127.0.0.2", "127.0.0.1"
    _CNT = os.environ["REBIND_COUNTER"]
    _orig_ga = socket.getaddrinfo

    def _ga(host, port, *a, **k):
        h = host.decode() if isinstance(host, bytes) else host
        if h and h.lower() == "localhost":
            ip = _PUB
            if _MODE == "alternate":
                n = 1
                if os.path.exists(_CNT):
                    with open(_CNT) as fh:
                        n = int(fh.read() or 0) + 1
                with open(_CNT, "w") as fh:
                    fh.write(str(n))
                ip = _PUB if n % 2 else _INT
            return _orig_ga(ip, port, *a, **k)
        return _orig_ga(host, port, *a, **k)

    socket.getaddrinfo = _ga
    _orig_global = ipaddress.IPv4Address.is_global
    ipaddress.IPv4Address.is_global = property(lambda s: str(s) == _PUB or _orig_global.fget(s))
PY
  export PYTHONPATH="$TMPDIR_T/py" REBIND_MODE="$1" REBIND_COUNTER="$TMPDIR_T/rebind.count"
  RBASE="http://localhost:$(cat "$SRV_DIR/rport")"
  : > "$SRV_DIR/INTERNAL.hits"
}

# Scrapling simulado: Selector parsea HTML; Fetcher descarga por su cuenta (urllib,
# resolviendo el nombre otra vez) como la libreria real y anota cada llamada.
scrapling_stub() {
  mkdir -p "$TMPDIR_T/py/scrapling"
  cat > "$TMPDIR_T/py/scrapling/__init__.py" <<'PY'
import os
import re
import urllib.request


class _Node:
    def __init__(self, text):
        self.text = text


class Selector:
    def __init__(self, content=None, url=None, **kw):
        self._doc = content or ""
        self.url = url
        self.status = 0

    def css_first(self, sel):
        found = self.css(sel)
        return found[0] if found else None

    def css(self, sel):
        return [_Node(t) for t in re.findall(r"<%s[^>]*>(.*?)</%s>" % (sel, sel), self._doc, re.S | re.I)]

    def get_all_text(self, strip=True):
        return "stub:" + " ".join(re.sub(r"<[^>]+>", " ", self._doc).split())


class Fetcher:
    @staticmethod
    def get(url, timeout=20, **kw):
        with open(os.environ["STUB_FETCH_LOG"], "a") as fh:
            fh.write(url + "\n")
        with urllib.request.urlopen(url, timeout=timeout) as r:
            page = Selector(r.read().decode("utf-8", "replace"), url=r.geturl())
            page.status = r.status
        return page
PY
  export PYTHONPATH="$TMPDIR_T/py" STUB_FETCH_LOG="$TMPDIR_T/fetcher.log"
}

# --- Positivos ---

@test "positive: 200 page exits 0 with JSON status, backend and null error" {
  run bash "$SCRIPT" "$BASE/ok" --json --allow-private
  [ "$status" -eq 0 ]
  [ "$(jget status <<<"$output")" = "200" ]
  [ "$(jget backend <<<"$output")" = "curl" ]
  [ -z "$(jget error <<<"$output")" ]
}

@test "positive: multi-line title extracted, script body excluded, entities decoded" {
  run bash "$SCRIPT" "$BASE/ok" --json --allow-private
  [ "$status" -eq 0 ]
  [ "$(jget title <<<"$output")" = "Hola mundo" ]
  [[ "$(jget text <<<"$output")" == *"Texto & más"* ]]
  [[ "$(jget text <<<"$output")" != *"secreto"* ]]
}

@test "positive: latin-1 charset header decoded instead of crashing" {
  run bash "$SCRIPT" "$BASE/latin1" --json --allow-private
  [ "$status" -eq 0 ]
  [ "$(jget title <<<"$output")" = "Canción" ]
  [[ "$(jget text <<<"$output")" == *"año"* ]]
}

@test "positive: meta charset sniffed when header has no charset" {
  run bash "$SCRIPT" "$BASE/metalatin1" --json --allow-private
  [ "$status" -eq 0 ]
  [[ "$(jget text <<<"$output")" == *"niño"* ]]
}

@test "positive: relative redirect followed to final URL" {
  run bash "$SCRIPT" "$BASE/rel" --json --allow-private
  [ "$status" -eq 0 ]
  [ "$(jget url_final <<<"$output")" = "$BASE/ok" ]
  [ "$(jget title <<<"$output")" = "Hola mundo" ]
}

@test "positive: text mode prints STATUS and BACKEND headers" {
  run bash "$SCRIPT" "$BASE/ok" --allow-private
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATUS: 200"* ]]
  [[ "$output" == *"BACKEND: curl"* ]]
}

# --- Errores HTTP: no se presentan como exito ---

@test "error: 403 fails with exit 1 instead of success" {
  run bash "$SCRIPT" "$BASE/403" --json --allow-private
  [ "$status" -eq 1 ]
  [ "$(jget status <<<"$output")" = "403" ]
  [[ "$(jget error <<<"$output")" == *"HTTP 403"* ]]
}

@test "error: 503 fails with exit 1 instead of success" {
  run bash "$SCRIPT" "$BASE/503" --json --allow-private
  [ "$status" -eq 1 ]
  [ "$(jget status <<<"$output")" = "503" ]
}

@test "error: 404 fails with exit 1" {
  run bash "$SCRIPT" "$BASE/404" --allow-private
  [ "$status" -eq 1 ]
  [[ "$output" == *"STATUS: 404"* ]]
}

@test "error: connection refused gives exit 1, error text and clean url_final" {
  run bash "$SCRIPT" "http://127.0.0.1:1/x" --json --allow-private
  [ "$status" -eq 1 ]
  [ "$(jget url_final <<<"$output")" = "http://127.0.0.1:1/x" ]
  [ -n "$(jget error <<<"$output")" ]
}

@test "error: redirect loop beyond limit fails with exit 1" {
  run bash "$SCRIPT" "$BASE/loop" --json --allow-private
  [ "$status" -eq 1 ]
  [[ "$(jget error <<<"$output")" == *"redirecciones"* ]]
}

# --- SSRF: destinos bloqueados (exit 3) ---

@test "block: loopback URL rejected by default without --allow-private" {
  run bash "$SCRIPT" "$BASE/ok" --json
  [ "$status" -eq 3 ]
  [[ "$output" == *"--allow-private"* ]]
}

@test "block: localhost hostname rejected by default" {
  run bash "$SCRIPT" "http://localhost:1/x"
  [ "$status" -eq 3 ]
}

@test "block: redirect to cloud metadata 169.254.169.254 blocked even with --allow-private" {
  run timeout 10 bash "$SCRIPT" "$BASE/redir?to=http://169.254.169.254/latest/" --json --allow-private
  [ "$status" -eq 3 ]
  [[ "$(jget error <<<"$output")" == *"169.254.169.254"* ]]
}

@test "block: decimal-encoded metadata IP rejected" {
  run bash "$SCRIPT" "http://2852039166/latest/" --allow-private
  [ "$status" -eq 3 ]
}

@test "block: IPv4-mapped IPv6 metadata literal rejected" {
  run bash "$SCRIPT" "http://[::ffff:169.254.169.254]/" --allow-private
  [ "$status" -eq 3 ]
}

@test "block: redirect to file:// rejected and not reported as success" {
  run bash "$SCRIPT" "$BASE/redir?to=file:///etc/hostname" --json --allow-private
  [ "$status" -eq 3 ]
  [[ "$(jget error <<<"$output")" == *"esquema"* ]]
}

@test "block: file:// as initial URL is a usage error" {
  run bash "$SCRIPT" "file:///etc/passwd"
  [ "$status" -eq 2 ]
}

# --- Limites: tamano, tiempo y argumentos ---

@test "boundary: response larger than --max-bytes aborts with exit 1" {
  run timeout 20 bash "$SCRIPT" "$BASE/big" --json --allow-private --max-bytes 1048576
  [ "$status" -eq 1 ]
  [[ "$(jget error <<<"$output")" == *"max-bytes"* ]]
}

@test "boundary: large page over 128KB of text no longer crashes" {
  run bash "$SCRIPT" "$BASE/medium" --json --allow-private
  [ "$status" -eq 0 ]
  local n
  n=$(jget text <<<"$output" | wc -c)
  [ "$n" -gt 300000 ]
}

@test "boundary: empty 200 body returns exit 0 and empty text" {
  run bash "$SCRIPT" "$BASE/empty" --json --allow-private
  [ "$status" -eq 0 ]
  [ -z "$(jget text <<<"$output")" ]
}

@test "boundary: --timeout 1 on slow endpoint fails fast with exit 1" {
  local t0=$SECONDS
  run timeout 15 bash "$SCRIPT" "$BASE/slow" --json --allow-private --timeout 1
  [ "$status" -eq 1 ]
  [ $((SECONDS - t0)) -le 4 ]
  [[ "$(jget error <<<"$output")" == *"timeout"* ]]
}

@test "invalid: --timeout 0 rejected because curl treats 0 as no limit" {
  run bash "$SCRIPT" "$BASE/ok" --timeout 0
  [ "$status" -eq 2 ]
}

@test "invalid: --timeout without value exits 2 instead of hanging" {
  run timeout 5 bash "$SCRIPT" "$BASE/ok" --timeout
  [ "$status" -eq 2 ]
}

@test "invalid: --selector without value exits 2 instead of hanging" {
  run timeout 5 bash "$SCRIPT" "$BASE/ok" --selector
  [ "$status" -eq 2 ]
}

@test "invalid: --max-bytes non-numeric or zero rejected" {
  run bash "$SCRIPT" "$BASE/ok" --max-bytes abc
  [ "$status" -eq 2 ]
  run bash "$SCRIPT" "$BASE/ok" --max-bytes 0
  [ "$status" -eq 2 ]
}

# --- Honestidad del backend ---

@test "honesty: --selector with curl backend warns that it is ignored" {
  run bash "$SCRIPT" "$BASE/ok" --json --allow-private --selector "p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"*"selector"* ]]
}

@test "honesty: broken scrapling install falls back and reports backend curl" {
  mkdir -p "$TMPDIR_T/py/scrapling"
  echo "# sin Fetcher" > "$TMPDIR_T/py/scrapling/__init__.py"
  PYTHONPATH="$TMPDIR_T/py" run bash "$SCRIPT" "$BASE/ok" --json --allow-private
  [ "$status" -eq 0 ]
  [[ "$output" == *'"backend": "curl"'* ]]
}

@test "honesty: scrapling installed parses the curl download; 503 still fails with backend scrapling" {
  scrapling_stub
  run bash "$SCRIPT" "$BASE/ok" --json --allow-private --selector p
  [ "$status" -eq 0 ]
  [[ "$output" == *'"backend": "scrapling"'* ]]
  [[ "$output" == *'"fetcher": "curl"'* ]]
  # --selector p lo aplica el parser de Scrapling (el extractor propio daria todo el texto)
  [[ "$(echo "$output" | jget text)" == "Texto "* ]]
  run bash "$SCRIPT" "$BASE/503" --json --allow-private
  [ "$status" -eq 1 ]
  [[ "$output" == *'"backend": "scrapling"'* ]]
  [[ "$output" == *'"status": 503'* ]]
  run bash "$SCRIPT" "$BASE/redir?to=http://169.254.169.254/latest/" --json --allow-private
  [ "$status" -eq 3 ]
  [[ "$output" != *"stub:"* ]]
  # la libreria nunca descarga: no puede seguir redirecciones ni resolver por su cuenta
  [ ! -e "$STUB_FETCH_LOG" ]
}

@test "block: DNS rebinding (TTL 0) with scrapling installed never returns internal content" {
  rebind_site alternate
  scrapling_stub
  run bash "$SCRIPT" "$RBASE/" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *"PUBLIC"* ]]
  [[ "$output" != *"INTERNAL"* ]]
  [ "$(internal_hits)" -eq 0 ]
  # una sola resolucion: la que se valida es la que se usa
  [ "$(cat "$REBIND_COUNTER")" -eq 1 ]
}

@test "block: redirect to internal with scrapling installed sends no request to the internal server" {
  rebind_site fixed
  scrapling_stub
  run bash "$SCRIPT" "$RBASE/redir?to=http://127.0.0.1:$(cat "$SRV_DIR/rport")/secreto" --json
  [ "$status" -eq 3 ]
  [ "$(internal_hits)" -eq 0 ]
  [ "$(echo "$output" | jget url_final)" = "http://127.0.0.1:$(cat "$SRV_DIR/rport")/secreto" ]
}

@test "block: curl pins the validated IP (--resolve), so the system resolver cannot redirect it to an internal host" {
  rebind_site fixed
  run bash "$SCRIPT" "$RBASE/" --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jget title)" = "PUBLIC" ]
  [ "$(internal_hits)" -eq 0 ]
}

@test "block: --allow-private never reaches cloud metadata (AWS IPv6, Alibaba, Azure wireserver, Oracle)" {
  local u
  for u in "http://[fd00:ec2::254]/latest/" "http://100.100.100.200/latest/meta-data/" \
           "http://168.63.129.16/machine" "http://192.0.0.192/latest/"; do
    run bash "$SCRIPT" "$u" --json --allow-private --timeout 2
    [ "$status" -eq 3 ]
    [[ "$output" == *"metadatos"* ]]
  done
}

@test "positive: IPv6 literal [::1] with --allow-private is fetched; without it, blocked as internal" {
  python3 - "$TMPDIR_T/v6port" <<'PY' >/dev/null 2>&1 3>&- &
import http.server
import socket
import sys


class S(http.server.HTTPServer):
    address_family = socket.AF_INET6


class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        body = b"<html><title>v6</title><p>seis</p></html>"
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


srv = S(("::1", 0), H)
with open(sys.argv[1], "w") as fh:
    fh.write(str(srv.server_address[1]))
srv.handle_request()
PY
  echo $! > "$TMPDIR_T/v6pid"
  local i
  for i in $(seq 1 50); do [[ -s "$TMPDIR_T/v6port" ]] && break; sleep 0.1; done
  [[ -s "$TMPDIR_T/v6port" ]] || skip "sin IPv6 en loopback"
  run bash "$SCRIPT" "http://[::1]:$(cat "$TMPDIR_T/v6port")/" --json
  [ "$status" -eq 3 ]
  [[ "$output" == *"red interna"* ]]
  run bash "$SCRIPT" "http://[::1]:$(cat "$TMPDIR_T/v6port")/" --json --allow-private
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jget title)" = "v6" ]
}

@test "honesty: --stealth warns that it has no effect because curl always downloads" {
  run bash "$SCRIPT" "$BASE/ok" --json --allow-private --stealth
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"*"stealth"* ]]
}

@test "honesty: no curl and no scrapling reports missing backend with exit 1" {
  mkdir -p "$TMPDIR_T/bin"
  local c
  for c in bash python3 mktemp rm; do
    ln -s "$(command -v "$c")" "$TMPDIR_T/bin/$c"
  done
  PATH="$TMPDIR_T/bin" run "$TMPDIR_T/bin/bash" "$SCRIPT" "$BASE/ok" --json --allow-private
  [ "$status" -eq 1 ]
  [[ "$output" == *"curl"* ]]
}

# --- Coherencia de la skill con la realidad ---

@test "doc: every scripts/ path cited by the skill exists" {
  local p missing=0
  for p in $(grep -oE 'scripts/[A-Za-z0-9_.-]+' .claude/skills/lightpanda-browser/SKILL.md | sort -u); do
    [[ -e "$p" ]] || { echo "falta: $p"; missing=1; }
  done
  [ "$missing" -eq 0 ]
}

@test "doc: --wait-until values in the skill are accepted by lightpanda" {
  command -v lightpanda >/dev/null 2>&1 || skip "lightpanda no instalado"
  local allowed
  allowed=$(LIGHTPANDA_DISABLE_TELEMETRY=true timeout 5 lightpanda help fetch 2>&1 | grep -A1 'Allowed values: "load"')
  local v bad=0
  for v in $(grep -oE -- '--wait-until [a-z0-9]+' .claude/skills/lightpanda-browser/SKILL.md | awk '{print $2}' | sort -u); do
    [[ "$allowed" == *"\"$v\""* ]] || { echo "valor no valido: $v"; bad=1; }
  done
  [ "$bad" -eq 0 ]
}

@test "safety: target script runs set -uo pipefail before parsing arguments" {
  run bash -x "$SCRIPT" --help
  [ "$status" -eq 0 ]
  local trace; trace=$(printf '%s\n' "$output" | grep -nE '^\+ (set -uo pipefail|URL=)' | head -2)
  [[ "$trace" == *"+ set -uo pipefail"*"+ URL="* ]]
}
