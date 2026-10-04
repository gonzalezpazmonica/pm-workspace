#!/usr/bin/env bash
# scrapling-fetch.sh — SE-061 Slice 2 adaptive fetch wrapper.
#
# Descarga SIEMPRE con curl (validacion anti-SSRF + IP fijada) y, si Scrapling
# esta instalado, lo usa solo como parser del HTML descargado (--selector).
# Sin Scrapling, extractor HTML propio.
#
# Usage:
#   scrapling-fetch.sh URL [SELECTOR]
#   scrapling-fetch.sh URL --json
#   scrapling-fetch.sh URL --stealth
#   scrapling-fetch.sh URL --timeout 30
#   scrapling-fetch.sh URL --selector "article.content"
#   scrapling-fetch.sh URL --max-bytes 1048576
#   scrapling-fetch.sh http://127.0.0.1:8080/ --allow-private
#
# Output (default):
#   TITLE: ...
#   STATUS: 200
#   URL_FINAL: https://...
#   BACKEND: scrapling|curl   (parser; la descarga es siempre curl)
#   [ERROR: ...]            (solo si falla)
#   ---
#   <extracted text>
#
# Output (--json), tambien en errores de red, HTTP o politica:
#   {"status":200,"title":"...","url_final":"...","text":"...",
#    "text_truncated":false,"error":null,"backend":"scrapling|curl",
#    "fetcher":"curl"}
#
# Exit codes:
#   0 — OK (respuesta 2xx)
#   1 — fetch error (red, timeout, 3xx sin destino, 4xx, 5xx, > --max-bytes,
#       demasiadas redirecciones, sin backend disponible)
#   2 — usage error
#   3 — destino bloqueado por la politica anti-SSRF (ver abajo)
#
# Politica de destinos (SE-376, calibracion lightpanda-browser):
#   - Solo http/https, tambien en cada salto de redireccion.
#   - Metadatos cloud: link-local (169.254.0.0/16, fe80::/10), fd00:ec2::254
#     (AWS IPv6), 100.100.100.200 (Alibaba), 168.63.129.16 (Azure wireserver)
#     y 192.0.0.192 (Oracle); ademas multicast, reservadas y 0.0.0.0:
#     bloqueadas SIEMPRE, tambien con --allow-private.
#   - Loopback (127/8, ::1), redes privadas y demas no globales: bloqueadas
#     salvo --allow-private.
#   - Cada salto (URL inicial y cada redireccion) se resuelve UNA vez, se
#     valida y curl conecta a esa IP (--resolve): un DNS rebinding no puede
#     cambiarla entre la validacion y la conexion. Las redirecciones las
#     sigue el script, nunca curl ni Scrapling.
#   - Scrapling no descarga nada (su Fetcher resolveria y redirigiria por su
#     cuenta): --stealth no tiene efecto y lo avisa por stderr.
#
# Ref: SE-061, docs/propuestas/SE-061-scrapling-research-backend.md
# Safety: set -uo pipefail. Egress limitado a URL del usuario.

set -uo pipefail

URL=""
SELECTOR=""
JSON=0
STEALTH=0
TIMEOUT=20
MAX_BYTES=5242880
ALLOW_PRIVATE=0
MAX_REDIRS=5
BACKEND=""

usage() {
  cat <<EOF
Usage:
  $0 URL [--selector CSS] [--json] [--stealth] [--timeout SEC]
         [--max-bytes N] [--allow-private]

Fetch URL with curl (validated, IP-pinned hops); parse with Scrapling if
installed, else with the built-in HTML extractor.

Arguments:
  URL                    Required. Must be http(s)://
  --selector CSS         Extract only matching nodes (needs scrapling as
                         parser; without it, ignored with a warning)
  --json                 Machine-readable JSON output
  --stealth              No effect: downloads always use curl with the
                         validated IP (anti-SSRF); warns on stderr
  --timeout SEC          Max total fetch time in seconds, >= 1 (default 20)
  --max-bytes N          Abort if the body exceeds N bytes (default 5242880)
  --allow-private        Allow loopback/private destinations (never cloud
                         metadata endpoints)

Exit codes: 0 OK (2xx) | 1 fetch/HTTP error | 2 usage | 3 blocked destination
Ref: SE-061 Slice 2.
EOF
}

need_value() {
  if [[ $# -lt 2 || -z "$2" ]]; then
    echo "ERROR: $1 requiere un valor" >&2
    exit 2
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --selector) need_value "$@"; SELECTOR="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    --stealth) STEALTH=1; shift ;;
    --timeout) need_value "$@"; TIMEOUT="$2"; shift 2 ;;
    --max-bytes) need_value "$@"; MAX_BYTES="$2"; shift 2 ;;
    --allow-private) ALLOW_PRIVATE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --*) echo "ERROR: unknown flag '$1'" >&2; exit 2 ;;
    *)
      if [[ -z "$URL" ]]; then URL="$1"
      elif [[ -z "$SELECTOR" ]]; then SELECTOR="$1"
      else echo "ERROR: unexpected arg '$1'" >&2; exit 2
      fi
      shift ;;
  esac
done

if [[ -z "$URL" ]]; then
  echo "ERROR: URL required" >&2
  usage >&2
  exit 2
fi

if [[ ! "$URL" =~ ^https?:// ]]; then
  echo "ERROR: URL must start with http:// or https://" >&2
  exit 2
fi

# 0 no es valido: curl lo interpreta como "sin limite".
if ! [[ "$TIMEOUT" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: --timeout must be a positive integer (>= 1)" >&2
  exit 2
fi

if ! [[ "$MAX_BYTES" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: --max-bytes must be a positive integer" >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 requerido (validacion de destino y salida JSON)" >&2
  exit 1
fi

# La descarga exige curl (unica via con IP fijada). Parser: scrapling si esta, si no el propio.
if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl requerido: es el unico backend que descarga con la IP validada (scrapling solo parsea)" >&2
  exit 1
fi
if python3 -c "import scrapling" 2>/dev/null; then
  BACKEND="scrapling"
else
  BACKEND="curl"
fi

WORK=$(mktemp -d 2>/dev/null) || { echo "ERROR: mktemp failed" >&2; exit 1; }
trap 'rm -rf "$WORK"' EXIT
RESULT="$WORK/result.json"

# Helper Python: validacion de destino, extraccion HTML y salida.
# El cuerpo viaja por ficheros, nunca por argv (limite de 128 KB por argumento).
read -r -d '' PY_HELPER <<'PY' || true  # read -d '' devuelve 1 al llegar a EOF
import codecs, ipaddress, json, os, re, socket, sys, urllib.parse
from html.parser import HTMLParser

TEXT_MAX = 500000
BLOCKED = "destino bloqueado"
# Endpoints de metadatos cloud fuera de link-local: bloqueados incluso con --allow-private.
METADATA = [ipaddress.ip_network(n) for n in (
    "169.254.0.0/16", "fe80::/10", "fd00:ec2::254/128", "100.100.100.200/32",
    "168.63.129.16/32", "192.0.0.192/32")]


def check(url, allow_private):
    """Imprime 'host port ip' o sale con 3 (bloqueado) / 1 (no resuelve)."""
    p = urllib.parse.urlsplit(url)
    if p.scheme not in ("http", "https"):
        print("%s: esquema no permitido '%s' en %s" % (BLOCKED, p.scheme, url), file=sys.stderr)
        sys.exit(3)
    host = p.hostname
    if not host:
        print("%s: URL sin host: %s" % (BLOCKED, url), file=sys.stderr)
        sys.exit(3)
    try:
        port = p.port or (443 if p.scheme == "https" else 80)
    except ValueError:
        print("%s: puerto invalido en %s" % (BLOCKED, url), file=sys.stderr)
        sys.exit(3)
    try:
        infos = socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)
    except (socket.gaierror, UnicodeError) as e:
        print("no se pudo resolver %s: %s" % (host, e), file=sys.stderr)
        sys.exit(1)
    first = None
    for info in infos:
        raw = info[4][0]
        ip = ipaddress.ip_address(raw.split("%")[0])
        if ip.version == 6 and ip.ipv4_mapped:
            ip = ip.ipv4_mapped
        if any(ip in net for net in METADATA if net.version == ip.version):
            print("%s: %s resuelve a %s (metadatos cloud / link-local)" % (BLOCKED, host, ip), file=sys.stderr)
            sys.exit(3)
        # ::1 cae en ::/8 (reservada): se trata como 127.0.0.1, interna con --allow-private.
        if not ip.is_loopback and (ip.is_multicast or ip.is_unspecified or ip.is_reserved):
            print("%s: %s resuelve a %s (multicast, reservada o sin especificar)" % (BLOCKED, host, ip), file=sys.stderr)
            sys.exit(3)
        if not ip.is_global and not allow_private:
            print("%s: %s resuelve a %s (red interna); usa --allow-private si es intencionado" % (BLOCKED, host, ip), file=sys.stderr)
            sys.exit(3)
        if first is None:
            first = raw
    print(host, port, first)


class _Extractor(HTMLParser):
    SKIP = {"script", "style", "noscript", "template"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.skip = 0
        self.in_title = False
        self.title = []
        self.parts = []

    def handle_starttag(self, tag, attrs):
        if tag in self.SKIP:
            self.skip += 1
        elif tag == "title":
            self.in_title = True

    def handle_endtag(self, tag):
        if tag in self.SKIP and self.skip:
            self.skip -= 1
        elif tag == "title":
            self.in_title = False

    def handle_data(self, data):
        if self.in_title:
            self.title.append(data)
        elif not self.skip:
            chunk = " ".join(data.split())
            if chunk:
                self.parts.append(chunk)


def _charset(ctype, raw):
    cands = []
    m = re.search(r"charset=([\w.:-]+)", ctype or "", re.I)
    if m:
        cands.append(m.group(1))
    m = re.search(rb"<meta[^>]+charset=[\"']?([\w.:-]+)", raw[:4096], re.I)
    if m:
        cands.append(m.group(1).decode("ascii", "replace"))
    for c in cands:
        try:
            return codecs.lookup(c).name
        except LookupError:
            print("WARN: charset desconocido '%s', se prueba el siguiente" % c, file=sys.stderr)
    return "utf-8"


def extract(body_file, ctype, status, url_final, out):
    with open(body_file, "rb") as fh:
        raw = fh.read()
    doc = raw.decode(_charset(ctype, raw), errors="replace")
    title, text = "", doc
    if "html" in (ctype or "").lower() or re.search(r"<(html|title|body|p)\b", doc[:4096], re.I):
        ex = _Extractor()
        ex.feed(doc)
        ex.close()
        title = " ".join("".join(ex.title).split())
        text = "\n".join(ex.parts)
    res = {"status": int(status or 0), "title": title[:200], "url_final": url_final, "text": text}
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(res, fh, ensure_ascii=False)


def _first(page, sel):
    f = getattr(page, "css_first", None)  # Scrapling 0.2 (Adaptor)
    if f is not None:
        return f(sel)
    found = page.css(sel)  # Scrapling 0.3 (Selector): lista con .first
    return getattr(found, "first", None) if hasattr(found, "first") else (found[0] if found else None)


def scrape(body_file, ctype, status, url_final, selector, out):
    """Parsea con Scrapling el cuerpo YA descargado por curl. Exit 4: sin parser."""
    try:
        from scrapling import Selector as Parser
    except ImportError:
        try:
            from scrapling import Adaptor as Parser
        except ImportError as e:
            print("scrapling sin parser utilizable (Selector/Adaptor): %s" % e, file=sys.stderr)
            sys.exit(4)
    with open(body_file, "rb") as fh:
        raw = fh.read()
    doc = raw.decode(_charset(ctype, raw), errors="replace")
    try:
        page = Parser(doc, url=url_final)
        node = _first(page, "title")
        title = " ".join((node.text or "").split()) if node is not None else ""
        if selector:
            text = "\n".join(n.text.strip() for n in page.css(selector) if n.text)
        else:
            text = page.get_all_text(strip=True)
    except Exception as e:  # API de la libreria variable entre versiones: degradar al extractor propio
        print("scrapling no pudo parsear (%s: %s)" % (type(e).__name__, e), file=sys.stderr)
        sys.exit(4)
    res = {"status": int(status or 0), "title": title[:200], "url_final": url_final, "text": text or ""}
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(res, fh, ensure_ascii=False)


def emit(result_file, backend, error, as_json, url, status):
    d = {"status": int(status or 0), "title": "", "url_final": url, "text": ""}
    if os.path.exists(result_file) and os.path.getsize(result_file) > 0:
        with open(result_file, encoding="utf-8") as fh:
            d.update(json.load(fh))
    if error.startswith(BLOCKED):
        d["title"], d["text"] = "", ""
    text = d.get("text") or ""
    d["text_truncated"] = len(text) > TEXT_MAX
    d["text"] = text[:TEXT_MAX]
    d["error"] = error or None
    d["backend"] = backend
    d["fetcher"] = "curl"
    if as_json == "1":
        print(json.dumps(d, ensure_ascii=False))
        return
    print("TITLE: %s" % d["title"])
    print("STATUS: %s" % d["status"])
    print("URL_FINAL: %s" % d["url_final"])
    print("BACKEND: %s" % backend)
    if error:
        print("ERROR: %s" % error)
    print("---")
    print(d["text"])


cmd = sys.argv[1]
if cmd == "check":
    check(sys.argv[2], sys.argv[3] == "1")
elif cmd == "extract":
    extract(*sys.argv[2:7])
elif cmd == "scrape":
    scrape(*sys.argv[2:8])
elif cmd == "emit":
    emit(*sys.argv[2:8])
PY

py() { python3 -c "$PY_HELPER" "$@"; }

FETCH_ERROR=""
STATUS=0
URL_FINAL="$URL"
CHECK_OUT=""

# Valida un destino; deja "host port ip" en CHECK_OUT o el motivo en FETCH_ERROR.
check_target() {
  local rc
  CHECK_OUT=$(py check "$1" "$ALLOW_PRIVATE" 2>"$WORK/check.err"); rc=$?
  if [[ $rc -ne 0 ]]; then
    FETCH_ERROR=$(<"$WORK/check.err")
    [[ -n "$FETCH_ERROR" ]] || FETCH_ERROR="validacion de destino fallida para $1"
  fi
  return $rc
}

# Parsea con Scrapling el cuerpo descargado. Exit 4: Scrapling sin parser usable.
parse_with_scrapling() {
  local rc
  py scrape "$WORK/body" "$CTYPE" "$STATUS" "$URL_FINAL" "$SELECTOR" "$RESULT" 2>"$WORK/scrape.err"; rc=$?
  [[ $rc -ne 0 ]] && FETCH_ERROR=$(<"$WORK/scrape.err")
  return $rc
}

fetch_with_curl() {
  local cur="$URL" hops=0 start=$SECONDS remaining meta rc host port ip
  local body="$WORK/body" redirect="" pin=()
  while :; do
    # Una sola resolucion por salto: la IP validada es la que usa curl.
    check_target "$cur" || { rc=$?; URL_FINAL="$cur"; return $rc; }
    read -r host port ip <<<"$CHECK_OUT"
    # Un literal IP no se resuelve (no hay rebinding posible) y curl no admite un
    # host IPv6 en --resolve: solo se fija la IP cuando el host es un nombre.
    pin=()
    if [[ "$host" != "$ip" ]]; then
      [[ "$ip" == *:* ]] && ip="[$ip]"
      pin=(--resolve "$host:$port:$ip")
    fi
    remaining=$(( TIMEOUT - (SECONDS - start) ))
    if [[ $remaining -lt 1 ]]; then
      FETCH_ERROR="timeout: se agotaron ${TIMEOUT}s"
      return 1
    fi
    : > "$body"
    meta=$(curl -sS --proto '=http,https' --max-redirs 0 \
      --max-time "$remaining" --max-filesize "$MAX_BYTES" \
      "${pin[@]}" \
      -A 'Mozilla/5.0 (compatible; SaviaResearch/1.0)' \
      -o "$body" -w '%{http_code}\n%{content_type}\n%{redirect_url}' \
      "$cur" 2>"$WORK/curl.err"); rc=$?
    URL_FINAL="$cur"
    STATUS="${meta%%$'\n'*}"
    [[ "$STATUS" =~ ^[0-9]+$ ]] || STATUS=0
    case $rc in
      0) ;;
      28) FETCH_ERROR="timeout: sin respuesta completa en ${TIMEOUT}s"; return 1 ;;
      63) FETCH_ERROR="la respuesta supera --max-bytes ($MAX_BYTES bytes)"; return 1 ;;
      *) FETCH_ERROR="curl ($rc): $(<"$WORK/curl.err")"; return 1 ;;
    esac
    meta="${meta#*$'\n'}"
    CTYPE="${meta%%$'\n'*}"
    redirect="${meta#*$'\n'}"
    if [[ "$STATUS" =~ ^3 && -n "$redirect" ]]; then
      hops=$((hops + 1))
      if [[ $hops -gt $MAX_REDIRS ]]; then
        FETCH_ERROR="demasiadas redirecciones (> $MAX_REDIRS)"
        return 1
      fi
      cur="$redirect"
      continue
    fi
    break
  done
}

CTYPE=""
if [[ $STEALTH -eq 1 ]]; then
  echo "WARN: --stealth sin efecto: la descarga la hace siempre curl contra la IP validada (anti-SSRF)" >&2
fi
if [[ -n "$SELECTOR" && "$BACKEND" == "curl" ]]; then
  echo "WARN: --selector ignorado sin scrapling (el extractor propio no aplica selectores)" >&2
fi

EXIT_CODE=0
fetch_with_curl || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
  if [[ "$BACKEND" == "scrapling" ]]; then
    parse_with_scrapling || EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
      echo "WARN: ${FETCH_ERROR:-scrapling fallo}; se usa el extractor propio" >&2
      BACKEND="curl"
      FETCH_ERROR=""
      EXIT_CODE=0
    fi
  fi
  if [[ "$BACKEND" == "curl" ]]; then
    py extract "$WORK/body" "$CTYPE" "$STATUS" "$URL_FINAL" "$RESULT" || EXIT_CODE=1
  fi
fi

if [[ $EXIT_CODE -eq 0 && ! "$STATUS" =~ ^2[0-9][0-9]$ ]]; then
  FETCH_ERROR="HTTP $STATUS"
  EXIT_CODE=1
fi
if [[ $EXIT_CODE -ne 0 && -z "$FETCH_ERROR" ]]; then
  FETCH_ERROR="fetch fallido (codigo $EXIT_CODE)"
fi
[[ $EXIT_CODE -ne 0 ]] && echo "ERROR: $FETCH_ERROR" >&2

py emit "$RESULT" "$BACKEND" "$FETCH_ERROR" "$JSON" "$URL_FINAL" "$STATUS"

exit $EXIT_CODE
