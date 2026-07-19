#!/usr/bin/env bash
# compile-criterio-vetos.sh — SE-268 S1: CRITERIO.md line_roja → veto bus.
# Compiles all linea_roja entries and publishes them to the veto bus.
# Usage: compile-criterio-vetos.sh [--criterio CRITERIO.md] [--socket PATH | --host H --port P]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
CRITERIO="${1:-$ROOT/CRITERIO.md}"
SOCKET="${VETO_BUS_SOCKET:-/tmp/savia-veto.sock}"
HOST="${VETO_BUS_HOST:-}"
PORT="${VETO_BUS_PORT:-9090}"

shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --criterio) CRITERIO="$2"; shift 2 ;;
    --socket) SOCKET="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Use Python to compile and publish all linea_roja vetos
python3 -c "
import sys, json, subprocess, urllib.request, urllib.parse

sys.path.insert(0, '$SCRIPT_DIR')
exec(open('$SCRIPT_DIR/veto-bus.py').read().split('if __name__')[0])

vetos = compile_criterio(__import__('pathlib').Path('$CRITERIO'))
print(f'Compiled {len(vetos)} linea_roja vetos', file=sys.stderr)

# Publish each veto via HTTP to the bus
base = 'http://localhost/veto'
sock = '$SOCKET'
host = '$HOST'
port = '$PORT'

import http.client
import socket as sockmod

for v in vetos:
    body = json.dumps(v).encode()
    try:
        if host:
            conn = http.client.HTTPConnection(host, int(port), timeout=2)
        else:
            conn = http.client.HTTPConnection('localhost', timeout=2)
            conn.sock = sockmod.socket(sockmod.AF_UNIX, sockmod.SOCK_STREAM)
            conn.sock.connect(sock)
        conn.request('POST', '/veto', body, {'Content-Type': 'application/json'})
        resp = conn.getresponse()
        result = json.loads(resp.read())
        conn.close()
        status = result.get('status', 'unknown')
        print(f'  {v[\"id\"]}: {status}', file=sys.stderr)
    except Exception as e:
        print(f'  {v[\"id\"]}: ERROR - {e}', file=sys.stderr)
        sys.exit(1)

print(f'Published {len(vetos)} vetos to bus')
" 2>&1
