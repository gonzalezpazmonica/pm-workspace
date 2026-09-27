#!/usr/bin/env bats
# Ref: SE-314 — sovereignty-classify.sh: evidence-verified confidential verdicts
# Ref: docs/propuestas/SE-314-sovereignty-classifier-redesign.md
#
# A local 3B model labelled 18/309 public governance rules "confidential" at
# 0.9 (BLOCK in N1). A confidential verdict now needs a verbatim quote of the
# private datum; placeholders and code identifiers do not count. These tests
# use a fake Ollama server so they are deterministic and run in CI.

SCRIPT="scripts/sovereignty-classify.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/ws"
  mkdir -p "$CLAUDE_PROJECT_DIR/config/classifier"
  cp config/classifier/prompt-v3.txt "$CLAUDE_PROJECT_DIR/config/classifier/"
  FAKE_DIR="$BATS_TEST_TMPDIR/fake"
  mkdir -p "$FAKE_DIR"
  PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
  FAKE_DIR="$FAKE_DIR" PORT="$PORT" python3 -c '
import http.server, json, os
d = os.environ["FAKE_DIR"]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, body):
        self.send_response(200); self.send_header("Content-Type", "application/json"); self.end_headers()
        self.wfile.write(json.dumps(body).encode())
    def do_GET(self): self._send({"models": []})
    def do_POST(self):
        req = self.rfile.read(int(self.headers["Content-Length"]))
        open(os.path.join(d, "last-request.json"), "wb").write(req)
        self._send({"response": open(os.path.join(d, "response.txt")).read()})
http.server.HTTPServer(("127.0.0.1", int(os.environ["PORT"])), H).serve_forever()
' &
  FAKE_PID=$!
  export OLLAMA_URL="http://127.0.0.1:$PORT"
  for _ in $(seq 50); do curl -s "$OLLAMA_URL/api/tags" >/dev/null 2>&1 && break; sleep 0.1; done
  TEXT="acta del 1:1 con Laura Ortiz: baja medica hasta noviembre, no comunicar al equipo"
}

teardown() {
  kill "$FAKE_PID" 2>/dev/null || true
}

fake() { printf '%s' "$1" > "$FAKE_DIR/response.txt"; }
classify() { local out; out=$(printf "%s" "${1:-$TEXT}" | bash "$SCRIPT" --no-cache); [[ "$(echo "$out" | jq -r .llm_verdict)" != "unavailable" ]] || { echo "fake ollama down" >&2; return 1; }; echo "$out"; }
field() { jq -r ".$1"; }

@test "classifier declares set -uo pipefail" {
  head -30 "$SCRIPT" | grep -q 'set -uo pipefail'
}

@test "confidential with verbatim evidence stays confidential" {
  fake '{"label": "confidential", "confidence": 0.9, "evidence": "Laura Ortiz"}'
  run classify
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | field label)" = "confidential" ]
}

@test "confidential without evidence is downgraded to ambiguous (no BLOCK)" {
  fake '{"label": "confidential", "confidence": 0.9, "evidence": ""}'
  run classify
  [ "$(echo "$output" | field label)" = "ambiguous" ]
  [ "$(echo "$output" | field confidence)" = "0.6" ]
}

@test "invalid evidence not present in the text is rejected" {
  fake '{"label": "confidential", "confidence": 0.95, "evidence": "Pedro Gil"}'
  run classify
  [ "$(echo "$output" | field label)" = "ambiguous" ]
}

@test "documented placeholder as evidence is rejected (test-org)" {
  fake '{"label": "confidential", "confidence": 0.9, "evidence": "test-org"}'
  run classify "Usar genericos como test-org o alice en los ejemplos del repo publico."
  [ "$(echo "$output" | field label)" = "ambiguous" ]
}

@test "code identifier as evidence is rejected (kebab-case agent id)" {
  fake '{"label": "confidential", "confidence": 0.9, "evidence": "meeting-confidentiality-judge"}'
  run classify "El agente meeting-confidentiality-judge valida que nada confidencial salga de la reunion."
  [ "$(echo "$output" | field label)" = "ambiguous" ]
}

@test "placeholder inside a real datum still counts (boundary)" {
  fake '{"label": "confidential", "confidence": 0.9, "evidence": "carlos.garcia@acme-corp.example"}'
  run classify "contact: carlos.garcia@acme-corp.example, director financiero de la empresa"
  [ "$(echo "$output" | field label)" = "confidential" ]
}

@test "truncated JSON (long evidence cut by num_predict) recovers the label" {
  fake '{"label": "public", "confidence": 1.0, "evidence": "# savia-env.sh — Provider-agnostic environment la'
  run classify "# savia-env.sh — Provider-agnostic environment layer for scripts and hooks of the workspace"
  [ "$(echo "$output" | field llm_verdict)" = "public" ]
  [ "$(echo "$output" | field label)" = "public" ]
}

@test "truncated confidential verdict never verifies evidence (ambiguous)" {
  fake '{"label": "confidential", "confidence": 0.9, "evidence": "Laura Ort'
  run classify
  [ "$(echo "$output" | field label)" = "ambiguous" ]
}

@test "empty or garbage model output → ambiguous" {
  fake 'esto no es json'
  run classify
  [ "$(echo "$output" | field label)" = "ambiguous" ]
}

@test "request sets num_ctx 8192 so long inputs keep the instructions" {
  fake '{"label": "public", "confidence": 1.0, "evidence": ""}'
  classify >/dev/null
  python3 -c "
import json
o = json.load(open('$FAKE_DIR/last-request.json'))['options']
assert o['num_ctx'] >= 8192, o
assert o['num_predict'] >= 64, o
"
}

@test "prompt edit invalidates the cache (prompt hash in prompt_version)" {
  fake '{"label": "public", "confidence": 1.0, "evidence": ""}'
  v1=$(printf '%s' "$TEXT" | bash "$SCRIPT" | field prompt_version)
  echo "# edit" >> "$CLAUDE_PROJECT_DIR/config/classifier/prompt-v3.txt"
  run bash -c "printf '%s' '$TEXT' | bash '$SCRIPT'"
  [ "$(echo "$output" | field cache_hit)" = "false" ]
  [ "$(echo "$output" | field prompt_version)" != "$v1" ]
}
