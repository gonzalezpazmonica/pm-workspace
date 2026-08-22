#!/usr/bin/env bats
# SCL-009 — auto-descubrimiento de instancias federadas
# Spec: docs/specs/SCL-009-autodiscover.spec.md
# Los tests usan registry y pool temporales; nunca tocan .savia-vault real.
# Nota: los mocks HTTP corren como procesos `timeout` standalone (se
# auto-terminan) para no colgar bats con background heredocs.

SCRIPT="scripts/federation-discover.sh"

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
  FIXDIR=$(mktemp -d)
  export SCL_FEDERATION_REGISTRY="$FIXDIR/federation.json"
  export SCL_FEDERATION_POOL="$FIXDIR/pool.txt"
  export SCL_FEDERATION_TIMEOUT="2"
}

teardown() {
  rm -rf "$FIXDIR"
  pkill -f "mock-health-9911.py" 2>/dev/null || true
}

@test "AC-01: --add registra instancia y aparece en --list" {
  run bash "$SCRIPT" --add inst-a http://127.0.0.1:9900
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "REGISTERED inst-a"
  run bash "$SCRIPT" --list
  echo "$output" | grep -q "inst-a"
  echo "$output" | grep -q "127.0.0.1:9900"
}

@test "AC-02: --check marca healthy una instancia con /health ok" {
  # mock standalone en fichero, con timeout 15s (se auto-termina)
  local port
  port=$(python3 -c "import socket; s=socket.socket(); s.bind(('127.0.0.1',0)); print(s.getsockname()[1]); s.close()")
  cat > "$FIXDIR/mock-health.py" << PY
import http.server, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            b = b'{"status":"ok"}'
            self.send_response(200); self.send_header('Content-Length',str(len(b))); self.end_headers(); self.wfile.write(b)
        else: self.send_response(404); self.end_headers()
    def log_message(self,*a): pass
http.server.HTTPServer(('127.0.0.1', $port), H).serve_forever()
PY
  timeout 20 python3 "$FIXDIR/mock-health.py" &
  # espera activa a que escuche
  for i in $(seq 1 10); do
    (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && break
    sleep 0.3
  done
  bash "$SCRIPT" --add inst-ok "http://127.0.0.1:${port}" >/dev/null
  run bash "$SCRIPT" --check
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "inst-ok: healthy"
  # el timeout 20 auto-mata el mock; el teardown pkill es red de seguridad
  pkill -f "mock-health.py" 2>/dev/null || true
}

@test "AC-03: --check marca unhealthy una instancia caida (timeout)" {
  bash "$SCRIPT" --add inst-down http://127.0.0.1:9999 >/dev/null
  run bash "$SCRIPT" --check
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "inst-down: unhealthy"
}

@test "AC-04 + AC-05: learning-federate sin --url usa healthy del registry; sin healthy exit 2" {
  run bash scripts/learning-federate.sh --search-remote --query "test" \
    --from-vault "$FIXDIR" --output-dir "$FIXDIR"
  [[ "$status" -eq 2 ]]
  echo "$output" | grep -q "registry"
}

@test "RN-02: instancia unhealthy NO se usa como destino por defecto" {
  bash "$SCRIPT" --add inst-x http://127.0.0.1:9999 >/dev/null
  python3 -c "
import json
d = json.load(open('$SCL_FEDERATION_REGISTRY'))
d[0]['status'] = 'unhealthy'
json.dump(d, open('$SCL_FEDERATION_REGISTRY','w'))"
  run bash scripts/learning-federate.sh --search-remote --query "q" \
    --from-vault "$FIXDIR" --output-dir "$FIXDIR"
  [[ "$status" -eq 2 ]]
}

@test "AC-06: hashes de CRITERIO.md y CONSTITUCION.md invariantes" {
  local h1 h2
  h1=$(sha256sum CRITERIO.md | cut -d' ' -f1)
  h2=$(sha256sum .claude/CONSTITUCION.md | cut -d' ' -f1)
  bash "$SCRIPT" --add inst-h http://127.0.0.1:9998 >/dev/null
  bash "$SCRIPT" --check >/dev/null
  [[ "$(sha256sum CRITERIO.md | cut -d' ' -f1)" == "$h1" ]]
  [[ "$(sha256sum .claude/CONSTITUCION.md | cut -d' ' -f1)" == "$h2" ]]
}

@test "RN-04/AC-07: bash -n, sin vendor names, sin LLM" {
  bash -n "$SCRIPT"
  bash -n scripts/learning-federate.sh
  run grep -niE "openai|anthropic|gpt-|gemini|qwen|deepseek" "$SCRIPT"
  [[ "$status" -ne 0 ]]
}

@test "input inválido → exit 2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 2 ]]
  run bash "$SCRIPT" --add solo-un-arg
  [[ "$status" -eq 2 ]]
}

@test "RN-05: pool con token nunca se persiste en repo (config local)" {
  echo "inst-secreta,http://127.0.0.1:9997,TOKENSECRETO123" > "$SCL_FEDERATION_POOL"
  run bash "$SCRIPT" --check
  [[ "$status" -eq 0 ]]
  ! grep -q "TOKENSECRETO123" "$SCL_FEDERATION_REGISTRY" || true
}