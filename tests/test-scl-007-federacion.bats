#!/usr/bin/env bats
# SCL-007 — Federación cross-dome real (lecciones entre instancias vía A2A)
# Ref: docs/specs/SCL-007-federacion-crossdome.spec.md

set -uo pipefail

setup_file() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  export REPO_ROOT
}

start_remote() {
  # Arranca un servidor A2A real simulando otra instancia. Imprime "PORT:PID".
  local REMOTE="$1"
  mkdir -p "$REMOTE/learning"
  local PORT=$(( (RANDOM % 2000) + 9000 ))
  export PATH="$HOME/.nvm/versions/node/v22.23.2/bin:$PATH"
  (cd "$REPO_ROOT/projects/savia-vaults" && exec node dist/cli/index.js serve --transport a2a --port "$PORT" --host 127.0.0.1 --path "$REMOTE" >/dev/null 2>&1) &
  local PID=$!
  sleep 2
  echo "${PORT}:${PID}"
}

# parse: "PORT:PID" → PORT y PID separados por ':'
parse_remote() {
  PORT="${1%%:*}"
  PID="${1#*:}"
}

stop_remote() {
  local PID="$1"
  [ -n "$PID" ] && kill "$PID" 2>/dev/null || true
}

setup() {
  FED="$REPO_ROOT/scripts/learning-federate.sh"
  PROP="$REPO_ROOT/scripts/learning-proposal.sh"
  PERSIST="$REPO_ROOT/scripts/learning-persist.sh"
  TMPD="$(mktemp -d -t scl-s7-XXXXXX)"
  mkdir -p "$TMPD/vault/learning" "$TMPD/proposals"
  export SCL_VAULT_DIR="$TMPD/vault"
  export SCL_PROPOSALS_DIR="$TMPD/proposals"
  echo "ev" > "$TMPD/ev.txt"
  bash "$PROP" --origin "leccion federable cross-dome" --evidence "$TMPD/ev.txt" \
    --diagnosis "d" --change "c" --target criterio --trigger ledger \
    --output-dir "$TMPD/proposals" --graph-index "$TMPD/g.jsonl" >/dev/null
  bash "$PERSIST" --file "$(ls "$TMPD/proposals/"*.md)" >/dev/null 2>&1
  SERVER_PID=""
}

teardown() {
  [ -n "${SERVER_PID:-}" ] && kill "$SERVER_PID" 2>/dev/null || true
  [ -n "${TMPD:-}" ] && rm -rf "$TMPD"
}

@test "AC-1: --share envia la leccion a un dome remoto via /share (A2A)" {
  parse_remote "$(start_remote "$TMPD/remote/vault")"
  SERVER_PID="$PID"
  id=$(basename "$(ls "$TMPD/vault/learning/"*.md | head -1)" .md)
  run bash "$FED" --share "$id" --to "http://127.0.0.1:$PORT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SHARED"* ]]
  [ -f "$TMPD/remote/vault/learning/${id}.md" ]
}

@test "AC-2: --search-remote consulta /search de un dome remoto y lista lecciones" {
  # Mock HTTP: simula la respuesta /search de un dome remoto (JSON A2A)
  MOCK="$TMPD/mock-server.py"
  PORT=$(( (RANDOM % 2000) + 9000 ))
  cat > "$MOCK" <<PY
import http.server, json, sys
PORT = int(sys.argv[1])
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/search'):
            body = json.dumps({"results": [
                {"path": "learning/LP-REMOta-01.md", "score": 3.2, "snippet": "leccion federable cross-dome"},
                {"path": "docs/otro.md", "score": 1.1, "snippet": "no es leccion"}
            ]})
            self.send_response(200); self.send_header('Content-Type','application/json'); self.end_headers()
            self.wfile.write(body.encode())
        else:
            self.send_response(404); self.end_headers()
    def log_message(self, *a): pass
http.server.HTTPServer(('127.0.0.1', PORT), H).serve_forever()
PY
  python3 "$MOCK" "$PORT" &
  SERVER_PID=$!
  sleep 1
  run bash "$FED" --search-remote --url "http://127.0.0.1:$PORT" --query "leccion"
  [ "$status" -eq 0 ]
  [[ "$output" == *"LP-REMOta-01"* ]]
  echo "$output" | grep -qi "lecciones del dome remoto"
}

@test "AC-3: la leccion compartida se importa como INFERRED (shadow, sin efecto)" {
  id=$(basename "$(ls "$TMPD/vault/learning/"*.md | head -1)" .md)
  run bash "$FED" --import "$id" --output-dir "$TMPD/imported"
  [ "$status" -eq 0 ]
  [ -f "$TMPD/imported/${id}.md" ]
  grep -q "^provenance: INFERRED" "$TMPD/imported/${id}.md"
  grep -q "^lifecycle: proposed" "$TMPD/imported/${id}.md"
  grep -q "^federated: true" "$TMPD/imported/${id}.md"
}

@test "AC-4: importar la misma leccion dos veces no duplica (idempotente)" {
  id=$(basename "$(ls "$TMPD/vault/learning/"*.md | head -1)" .md)
  bash "$FED" --import "$id" --output-dir "$TMPD/imported" >/dev/null 2>&1
  run bash "$FED" --import "$id" --output-dir "$TMPD/imported"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ALREADY"* ]]
  count=$(find "$TMPD/imported" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" = "1" ]
}

@test "AC-5: --share sin --to es error de uso" {
  id=$(basename "$(ls "$TMPD/vault/learning/"*.md | head -1)" .md)
  run bash "$FED" --share "$id"
  [ "$status" -eq 2 ]
}

@test "AC-6: --search-remote requiere --url y --query" {
  run bash "$FED" --search-remote
  [ "$status" -eq 2 ]
}
