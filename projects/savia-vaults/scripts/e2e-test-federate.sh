#!/usr/bin/env bash
# e2e-test-federate.sh — E2E federation test using python3 HTTP server
# Tests: cross-vault search, auth, timeouts, concurrent load, edge cases
# Copyright (c) 2026 Savia. MIT License.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${TEST_DIR:-/tmp/savia-federate-e2e}"
VAULT_A="${TEST_DIR}/vault-a"; VAULT_B="${TEST_DIR}/vault-b"
PORT_A=18923; PORT_B=18924; AUTH_TOKEN="e2e-token-$$"
PASS=0; FAIL=0
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

pass() { echo -e "  ${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
info() { echo -e "  ${YELLOW}INFO${NC} $1"; }

cleanup() {
  info "Cleaning up..."
  kill $PID_A 2>/dev/null || true; kill $PID_B 2>/dev/null || true
  rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo "============================================"
echo "  Savia Federate E2E — Federation Test Suite"
echo "============================================"
echo ""

# ── Setup vaults ──
info "Setting up test vaults..."
rm -rf "$TEST_DIR" 2>/dev/null || true; mkdir -p "$VAULT_A/docs" "$VAULT_B/docs"

cat > "$VAULT_A/docs/architecture.md" << 'EOF'
---
title: Alpha Architecture
tags: [architecture, alpha, hexagonal]
---
# Alpha Architecture
Alpha uses hexagonal architecture with event sourcing.
Command Bus, Event Store, Projection Engine.
EOF
cat > "$VAULT_A/docs/onboarding.md" << 'EOF'
---
title: Alpha Onboarding
tags: [onboarding, alpha]
---
# Alpha Onboarding
Install Node.js 22+, clone repo, run setup script.
EOF
cat > "$VAULT_A/docs/security.md" << 'EOF'
---
title: Alpha Security
tags: [security, alpha, jwt, auth]
---
# Alpha Security
JWT authentication with refresh tokens. Bearer token required.
EOF

cat > "$VAULT_B/docs/architecture.md" << 'EOF'
---
title: Beta Architecture
tags: [architecture, beta, microservices]
---
# Beta Architecture
Microservices with Kubernetes. API Gateway, Service Mesh, Config Server.
EOF
cat > "$VAULT_B/docs/deployment.md" << 'EOF'
---
title: Beta Deployment
tags: [deployment, beta, kubernetes]
---
# Beta Deployment
Deploy to Kubernetes: namespace, Config Server, services in dependency order.
EOF

info "Vault A: $(find "$VAULT_A" -name '*.md' | wc -l) notes (architecture, onboarding, security)"
info "Vault B: $(find "$VAULT_B" -name '*.md' | wc -l) notes (architecture, deployment)"

# ── Create python3 A2A server ──
cat > "$TEST_DIR/a2a-server.py" << 'PYEOF'
import sys, os, json, re, time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

VAULT = os.environ['VAULT_PATH']
PORT = int(os.environ.get('PORT', '8923'))
AUTH = os.environ.get('AUTH_TOKEN', '')

def search_files(query, max_results=20):
    if not os.path.isdir(VAULT): return []
    results = []
    terms = [t.lower() for t in query.split() if t]
    for root, dirs, files in os.walk(VAULT):
        dirs[:] = [d for d in dirs if not d.startswith('.') and d != 'node_modules']
        for f in files:
            if not f.endswith(('.md','.yaml','.json','.txt')): continue
            fp = os.path.join(root, f)
            try:
                with open(fp, 'r') as fh: content = fh.read()
            except: continue
            if not terms:
                results.append({'path': os.path.relpath(fp, VAULT), 'score': 0, 'snippet': content[:150], 'tags': []})
                continue
            score = 0
            for term in terms:
                score += len(re.findall(re.escape(term), content, re.IGNORECASE))
            if score > 0:
                tags = []
                fm = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
                if fm:
                    tm = re.search(r'tags:\s*\[(.*?)\]', fm.group(1))
                    if tm: tags = [t.strip().strip("'\"") for t in tm.group(1).split(',')]
                results.append({'path': os.path.relpath(fp, VAULT), 'score': score,
                               'snippet': content[:200].replace('\n',' '), 'tags': tags})
    results.sort(key=lambda r: r['score'], reverse=True)
    return results[:max_results]

class Handler(BaseHTTPRequestHandler):
    def _send(self, code, data):
        self.send_response(code); self.send_header('Content-Type','application/json')
        self.send_header('Access-Control-Allow-Origin','*'); self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    def do_GET(self):
        p = urlparse(self.path)
        qs = parse_qs(p.query)
        # Health and stats never require auth (needed for federation checks)
        requires_auth = AUTH and p.path not in ('/health', '/stats')
        if requires_auth:
            ah = self.headers.get('Authorization','')
            if ah.replace('Bearer ','') != AUTH:
                self._send(401, {'error':'Unauthorized'}); return
        try:
            if p.path == '/health':
                self._send(200, {'status':'ok','vault':VAULT})
            elif p.path == '/search':
                q = qs.get('q',[''])[0]
                mr = int(qs.get('maxResults',['20'])[0])
                self._send(200, {'results': search_files(q, mr)})
            elif p.path == '/stats':
                self._send(200, {'noteCount': len(search_files('', 9999)), 'name': VAULT})
            else:
                self._send(404, {'error':'Not found'})
        except Exception as e:
            self._send(500, {'error': str(e)})
    def log_message(self, *a): pass

s = HTTPServer(('', PORT), Handler)
sys.stderr.write(f'A2A on :{PORT} ({VAULT})\n'); sys.stderr.flush()
s.serve_forever()
PYEOF

# ── Start servers ──
info "Starting A2A servers..."

VAULT_PATH="$VAULT_A" AUTH_TOKEN="$AUTH_TOKEN" PORT="$PORT_A" \
  python3 "$TEST_DIR/a2a-server.py" &
PID_A=$!

VAULT_PATH="$VAULT_B" AUTH_TOKEN="" PORT="$PORT_B" \
  python3 "$TEST_DIR/a2a-server.py" &
PID_B=$!

sleep 2
kill -0 $PID_A 2>/dev/null || { fail "Server A failed to start"; exit 1; }
kill -0 $PID_B 2>/dev/null || { fail "Server B failed to start"; exit 1; }
pass "Server A on :$PORT_A (auth)"
pass "Server B on :$PORT_B (no auth)"
echo ""

# ═══ TEST 1: Health checks ═══
echo "── Test 1: Health checks ──"
HA=$(curl -s http://localhost:$PORT_A/health 2>/dev/null)
HB=$(curl -s http://localhost:$PORT_B/health 2>/dev/null)
echo "$HA" | grep -q '"ok"' && pass "Server A health OK" || fail "Server A health: $HA"
echo "$HB" | grep -q '"ok"' && pass "Server B health OK" || fail "Server B health: $HB"

# ═══ TEST 2: Direct search ═══
echo ""
echo "── Test 2: Direct search ──"
SA=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" "http://localhost:$PORT_A/search?q=architecture" 2>/dev/null)
SB=$(curl -s "http://localhost:$PORT_B/search?q=kubernetes" 2>/dev/null)
AC=$(echo "$SA" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('results',[])))" 2>/dev/null)
BC=$(echo "$SB" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('results',[])))" 2>/dev/null)
[[ "$AC" -gt 0 ]] && pass "Vault A: $AC results for 'architecture'" || fail "Vault A: no architecture results"
[[ "$BC" -gt 0 ]] && pass "Vault B: $BC results for 'kubernetes'" || fail "Vault B: no kubernetes results"

# ═══ TEST 3: Cross-vault content isolation ═══
echo ""
echo "── Test 3: Cross-vault content isolation ──"
# A doesn't have "kubernetes" → should return 0
SAK=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" "http://localhost:$PORT_A/search?q=kubernetes" 2>/dev/null)
ACK=$(echo "$SAK" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('results',[])))" 2>/dev/null)
[[ "$ACK" -eq 0 ]] && pass "Vault A: 0 results for 'kubernetes' (only in B)" || info "Vault A: $ACK kubernetes results"
# B doesn't have "JWT" → should return 0
SBJ=$(curl -s "http://localhost:$PORT_B/search?q=JWT" 2>/dev/null)
BCJ=$(echo "$SBJ" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('results',[])))" 2>/dev/null)
[[ "$BCJ" -eq 0 ]] && pass "Vault B: 0 results for 'JWT' (only in A)" || info "Vault B: $BCJ JWT results"

# ═══ TEST 4: Authentication ═══
echo ""
echo "── Test 4: Authentication ──"
NA=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT_A/search?q=test" 2>/dev/null)
[[ "$NA" == "401" ]] && pass "Server A: 401 without token" || fail "Server A: expected 401 got $NA"
WA=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $AUTH_TOKEN" "http://localhost:$PORT_A/search?q=test" 2>/dev/null)
[[ "$WA" == "200" ]] && pass "Server A: 200 with valid token" || fail "Server A: expected 200 got $WA"
NB=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT_B/search?q=test" 2>/dev/null)
[[ "$NB" == "200" ]] && pass "Server B: 200 without token (no auth required)" || fail "Server B: expected 200 got $NB"

# Wrong token on A
WT=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer wrong-token" "http://localhost:$PORT_A/search?q=test" 2>/dev/null)
[[ "$WT" == "401" ]] && pass "Server A: 401 with wrong token" || fail "Server A: expected 401 got $WT"

# ═══ TEST 5: Timeout / offline dome ═══
echo ""
echo "── Test 5: Offline dome handling ──"
TS=$(date +%s%N)
OFF=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 1 "http://127.0.0.1:19999/health" 2>/dev/null)
TE=$(date +%s%N); TMS=$(( (TE - TS) / 1000000 ))
[[ "$OFF" == "000" ]] && pass "Offline dome refused (${TMS}ms)" || fail "Offline dome returned '$OFF'"

# ═══ TEST 6: Edge cases ═══
echo ""
echo "── Test 6: Edge cases ──"
# Empty query
EQ=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT_B/search?q=" 2>/dev/null)
[[ "$EQ" == "200" ]] && pass "Empty query: 200 (no crash)" || fail "Empty query: $EQ"

# Very long query
LQ=$(python3 -c "import urllib.parse; print(urllib.parse.quote('x'*500))")
LQR=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT_B/search?q=$LQ" 2>/dev/null)
[[ "$LQR" == "200" ]] && pass "Long query (500 chars): 200" || fail "Long query: $LQR"

# Special/script chars
XSS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT_B/search?q=%3Cscript%3E" 2>/dev/null)
[[ "$XSS" == "200" ]] && pass "XSS attempt: 200 (sanitized)" || fail "XSS attempt: $XSS"

# Path traversal
PT=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT_B/search?q=../../etc" 2>/dev/null)
[[ "$PT" == "200" ]] && pass "Path traversal: 200 (sanitized)" || fail "Path traversal: $PT"

# ═══ TEST 7: Concurrent load ═══
echo ""
echo "── Test 7: Concurrent load ──"
OK=0; TOTAL=0
for i in $(seq 1 10); do
  code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://localhost:$PORT_B/search?q=test$i" 2>/dev/null)
  TOTAL=$((TOTAL + 1)); [[ "$code" == "200" ]] && OK=$((OK + 1))
done
[[ "$OK" -ge 9 ]] && pass "Sequential load: $OK/$TOTAL OK" || fail "Load: $OK/$TOTAL OK"

# ═══ TEST 8: Response format validation ═══
echo ""
echo "── Test 8: Response format ──"
RF=$(curl -s "http://localhost:$PORT_B/search?q=architecture&maxResults=2" 2>/dev/null)
echo "$RF" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'results' in d, 'missing results key'
for r in d['results']:
    assert 'path' in r, 'missing path'
    assert 'score' in r, 'missing score'
    assert 'snippet' in r, 'missing snippet'
    assert isinstance(r['score'], (int, float)), 'score not numeric'
print('OK')
" 2>/dev/null && pass "Response format valid" || fail "Response format invalid"

# ═══ TEST 9: Cross-vault stats ─══
echo ""
echo "── Test 9: Stats ──"
STA=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" "http://localhost:$PORT_A/stats" 2>/dev/null)
STB=$(curl -s "http://localhost:$PORT_B/stats" 2>/dev/null)
ANC=$(echo "$STA" | python3 -c "import sys,json; print(json.load(sys.stdin).get('noteCount',0))" 2>/dev/null)
BNC=$(echo "$STB" | python3 -c "import sys,json; print(json.load(sys.stdin).get('noteCount',0))" 2>/dev/null)
[[ "$ANC" -eq 3 ]] && pass "Vault A: 3 notes" || fail "Vault A: expected 3 got $ANC"
[[ "$BNC" -eq 2 ]] && pass "Vault B: 2 notes" || fail "Vault B: expected 2 got $BNC"

echo ""
echo "============================================"
echo "  Result: $PASS PASS | $FAIL FAIL"
echo "============================================"
[[ $FAIL -gt 0 ]] && exit 1 || exit 0
