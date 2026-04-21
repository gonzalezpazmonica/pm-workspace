#!/usr/bin/env bash
# scrapling-fetch.sh — SE-061 Slice 2 adaptive fetch wrapper.
#
# Wrapper estable sobre Scrapling (parser-only, sin Chromium required).
# Con fallback automatico a curl cuando Scrapling no esta instalado.
#
# Usage:
#   scrapling-fetch.sh URL [SELECTOR]
#   scrapling-fetch.sh URL --json
#   scrapling-fetch.sh URL --stealth
#   scrapling-fetch.sh URL --timeout 30
#   scrapling-fetch.sh URL --selector "article.content"
#
# Output (default):
#   TITLE: ...
#   STATUS: 200
#   URL_FINAL: https://...
#   ---
#   <extracted text>
#
# Output (--json):
#   {"status":200,"title":"...","url_final":"...","text":"...","backend":"scrapling|curl"}
#
# Exit codes:
#   0 — OK (content fetched)
#   1 — fetch error (network, 4xx, 5xx)
#   2 — usage error
#
# Ref: SE-061, docs/propuestas/SE-061-scrapling-research-backend.md
# Safety: set -uo pipefail. Egress limitado a URL del usuario.

set -uo pipefail

URL=""
SELECTOR=""
JSON=0
STEALTH=0
TIMEOUT=20
BACKEND=""

usage() {
  cat <<EOF
Usage:
  $0 URL [--selector CSS] [--json] [--stealth] [--timeout SEC]

Fetch URL with Scrapling (adaptive parser). Falls back to curl if unavailable.

Arguments:
  URL                    Required. Must be http(s)://
  --selector CSS         Extract only matching nodes (CSS selector)
  --json                 Machine-readable JSON output
  --stealth              Request stealth mode (scrapling only, no-op for curl)
  --timeout SEC          Max fetch time in seconds (default 20)

Ref: SE-061 Slice 2.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --selector) SELECTOR="${2:-}"; shift 2 ;;
    --json) JSON=1; shift ;;
    --stealth) STEALTH=1; shift ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
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

if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --timeout must be a positive integer" >&2
  exit 2
fi

# Detect backend: scrapling if installed, else curl
if command -v python3 >/dev/null 2>&1 && python3 -c "import scrapling" 2>/dev/null; then
  BACKEND="scrapling"
elif command -v curl >/dev/null 2>&1; then
  BACKEND="curl"
else
  echo "ERROR: neither scrapling nor curl available" >&2
  exit 1
fi

STATUS=0
TITLE=""
URL_FINAL="$URL"
TEXT=""
EXIT_CODE=0

fetch_with_scrapling() {
  local py_script
  py_script=$(cat <<'PY'
import sys, json, os
url = os.environ.get("FETCH_URL", "")
selector = os.environ.get("FETCH_SELECTOR", "")
stealth = os.environ.get("FETCH_STEALTH", "0") == "1"
timeout = int(os.environ.get("FETCH_TIMEOUT", "20"))
try:
    from scrapling import Fetcher
    f = Fetcher.get(url, timeout=timeout, stealth=stealth) if stealth else Fetcher.get(url, timeout=timeout)
    status = int(getattr(f, "status", 0) or 0)
    url_final = getattr(f, "url", url) or url
    title_sel = f.css_first("title")
    title = title_sel.text.strip() if title_sel else ""
    if selector:
        nodes = f.css(selector)
        text = "\n".join(n.text.strip() for n in nodes if n.text)
    else:
        text = f.get_all_text(strip=True)
    print(json.dumps({"status": status, "title": title, "url_final": url_final, "text": text or ""}, ensure_ascii=False))
    sys.exit(0 if 200 <= status < 400 else 1)
except ImportError:
    print(json.dumps({"error": "scrapling_import_failed"}), file=sys.stderr)
    sys.exit(3)
except (OSError, RuntimeError, ValueError) as e:
    print(json.dumps({"error": str(e)}), file=sys.stderr)
    sys.exit(1)
PY
)
  FETCH_URL="$URL" FETCH_SELECTOR="$SELECTOR" FETCH_STEALTH="$STEALTH" FETCH_TIMEOUT="$TIMEOUT" \
    python3 -c "$py_script"
}

fetch_with_curl() {
  local tmpfile
  tmpfile=$(mktemp 2>/dev/null) || { echo "ERROR: mktemp failed" >&2; return 1; }
  local status_code url_final
  status_code=$(curl -sS -L -o "$tmpfile" -w '%{http_code}|%{url_effective}' \
    --max-time "$TIMEOUT" \
    -A 'Mozilla/5.0 (compatible; SaviaResearch/1.0)' \
    "$URL" 2>/dev/null || echo "0|$URL")
  local http_code="${status_code%%|*}"
  url_final="${status_code#*|}"

  local title=""
  local text=""
  if [[ -s "$tmpfile" ]]; then
    # Simple title extraction
    title=$(grep -oE '<title[^>]*>[^<]*</title>' "$tmpfile" 2>/dev/null | head -1 | sed -E 's/<[^>]+>//g' | head -c 200)
    # Strip HTML tags for text (very basic fallback)
    text=$(sed -E 's/<script[^>]*>.*<\/script>//g; s/<style[^>]*>.*<\/style>//g; s/<[^>]+>//g; s/&nbsp;/ /g; s/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g' "$tmpfile" | tr -s ' \n' ' \n' | head -c 500000)
  fi

  rm -f "$tmpfile"
  python3 -c "import json,sys; print(json.dumps({'status':int('$http_code' or 0),'title':sys.argv[1],'url_final':sys.argv[2],'text':sys.argv[3]}, ensure_ascii=False))" "$title" "$url_final" "$text"
  [[ "$http_code" =~ ^2|3 ]] && return 0 || return 1
}

RESULT_JSON=""
if [[ "$BACKEND" == "scrapling" ]]; then
  RESULT_JSON=$(fetch_with_scrapling) || EXIT_CODE=$?
  # Fallback to curl if scrapling import failed unexpectedly
  if [[ "$EXIT_CODE" -eq 3 ]] && command -v curl >/dev/null 2>&1; then
    BACKEND="curl"
    EXIT_CODE=0
    RESULT_JSON=$(fetch_with_curl) || EXIT_CODE=$?
  fi
else
  RESULT_JSON=$(fetch_with_curl) || EXIT_CODE=$?
fi

if [[ -z "$RESULT_JSON" ]]; then
  echo "ERROR: empty result" >&2
  exit 1
fi

# Parse fields for verbose output
if command -v python3 >/dev/null 2>&1; then
  STATUS=$(echo "$RESULT_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',0))" 2>/dev/null || echo 0)
  TITLE=$(echo "$RESULT_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('title',''))" 2>/dev/null || echo "")
  URL_FINAL=$(echo "$RESULT_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('url_final',''))" 2>/dev/null || echo "$URL")
  TEXT=$(echo "$RESULT_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('text',''))" 2>/dev/null || echo "")
fi

if [[ "$JSON" -eq 1 ]]; then
  # Add backend field
  echo "$RESULT_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); d['backend']=sys.argv[1]; print(json.dumps(d, ensure_ascii=False))" "$BACKEND"
else
  echo "TITLE: $TITLE"
  echo "STATUS: $STATUS"
  echo "URL_FINAL: $URL_FINAL"
  echo "BACKEND: $BACKEND"
  echo "---"
  echo "$TEXT"
fi

exit $EXIT_CODE
