#!/usr/bin/env bats
# Ref: docs/rules/domain/emergency-mode-protocol.md — SPEC-122 / SE-376
#
# Comportamiento de scripts/localai-readiness-check.sh contra un LocalAI falso (servidor HTTP
# local que se configura por escenario) y coherencia del switchover documentado: Claude Code
# añade /v1/messages a ANTHROPIC_BASE_URL, así que la base nunca debe terminar en /v1.

SCRIPT="scripts/localai-readiness-check.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMPDIR="$(mktemp -d)"
  cat > "$TMPDIR/fake_localai.py" <<'EOF'
import http.server, json, os, sys
MODE = os.environ.get("FAKE_MODE", "ready")
class H(http.server.BaseHTTPRequestHandler):
    def _send(self, code, body=b""):
        self.send_response(code); self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        if self.path == "/readyz" and MODE != "down":
            return self._send(200, b"ok")
        if self.path == "/v1/models" and MODE != "down":
            ids = {"ready": ["claude-compatible-local"], "other-model": ["qwen2.5:7b"],
                   "no-models": [], "no-messages": ["claude-compatible-local"],
                   "quoted": ['mi "modelo"'], "lookalike": ["qwen2x5:7b"]}[MODE]
            return self._send(200, json.dumps({"data": [{"id": i} for i in ids]}).encode())
        return self._send(404)
    def do_OPTIONS(self):
        if self.path == "/v1/messages" and MODE not in ("no-messages", "down"):
            return self._send(405)
        return self._send(404)
    def log_message(self, *a): pass
s = http.server.HTTPServer(("127.0.0.1", 0), H)
open(sys.argv[1], "w").write(str(s.server_address[1]))
s.serve_forever()
EOF
}

teardown() {
  [[ -n "${FAKE_PID:-}" ]] && kill "$FAKE_PID" 2>/dev/null
  rm -rf "$TMPDIR"
}

start_fake() {
  FAKE_MODE="$1" python3 "$TMPDIR/fake_localai.py" "$TMPDIR/port" &
  FAKE_PID=$!
  for _ in $(seq 1 50); do [[ -s "$TMPDIR/port" ]] && break; sleep 0.1; done
  URL="http://127.0.0.1:$(cat "$TMPDIR/port")"
}

check_status() {
  python3 -c "import json,sys; d=json.loads(sys.argv[1]); print({c['check']:c['status'] for c in d['checks']}[sys.argv[2]])" "$1" "$2"
}

@test "target has safety flags" {
  grep -q "set -uo pipefail" "$REPO_ROOT/$SCRIPT"
}

@test "ready LocalAI: running, Anthropic shim and model are OK" {
  start_fake ready
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --json
  [ "$(check_status "$output" localai_running)" = "OK" ]
  [ "$(check_status "$output" anthropic_compat)" = "OK" ]
  [ "$(check_status "$output" model_available)" = "OK" ]
}

@test "overall and exit code match the worst check" {
  start_fake ready
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --json
  worst=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(max({'OK':0,'WARN':1,'FAIL':2}[c['status']] for c in d['checks']))" "$output")
  [ "$status" -eq "$worst" ]
  python3 -c "import json,sys; assert json.loads(sys.argv[1])['overall']==int(sys.argv[2])" "$output" "$worst"
}

@test "readiness prints the switchover base URL without /v1" {
  start_fake ready
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL"
  [[ "$output" == *"ANTHROPIC_BASE_URL=$URL"* ]]
  [[ "$output" != *"ANTHROPIC_BASE_URL=$URL/v1"* ]]
}

@test "other model loaded is a WARN for model_available" {
  start_fake other-model
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --json
  [ "$(check_status "$output" model_available)" = "WARN" ]
}

@test "no models loaded is a FAIL with exit 2" {
  start_fake no-models
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --json
  [ "$status" -eq 2 ]
  [ "$(check_status "$output" model_available)" = "FAIL" ]
}

@test "missing /v1/messages shim is a FAIL with exit 2" {
  start_fake no-messages
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --json
  [ "$status" -eq 2 ]
  [ "$(check_status "$output" anthropic_compat)" = "FAIL" ]
}

@test "model names are matched literally, not as regex" {
  start_fake other-model
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --model "qwen2.5:7b" --json
  [ "$(check_status "$output" model_available)" = "OK" ]
}

@test "a lookalike model id does not satisfy the requested model" {
  start_fake lookalike
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --model "qwen2.5:7b" --json
  [ "$(check_status "$output" model_available)" = "WARN" ]
}

@test "JSON stays valid when the model name contains quotes" {
  start_fake quoted
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --model 'mi "modelo"' --json
  python3 -c "import json,sys; json.loads(sys.argv[1])" "$output"
  [ "$(check_status "$output" model_available)" = "OK" ]
}

@test "missing value for --url or --model is a usage error (exit 2), not a WARN" {
  run bash "$REPO_ROOT/$SCRIPT" --url
  [ "$status" -eq 2 ]
  run bash "$REPO_ROOT/$SCRIPT" --model
  [ "$status" -eq 2 ]
}

@test "documented switchover never points ANTHROPIC_BASE_URL at /v1" {
  # Claude Code pide <base>/v1/messages: una base terminada en /v1 da /v1/v1/messages (404).
  ! grep -nE 'ANTHROPIC_BASE_URL="?https?://[^" ]*/v1"?([[:space:]]|$)' \
    "$REPO_ROOT/.claude/skills/emergency-mode/SKILL.md" \
    "$REPO_ROOT/docs/rules/domain/emergency-mode-protocol.md"
}

@test "skill documents the verdicts the script really prints" {
  grep -q "NOT READY" "$REPO_ROOT/.claude/skills/emergency-mode/SKILL.md"
  ! grep -qE "VIABLE|NEEDS_INSTALL" "$REPO_ROOT/.claude/skills/emergency-mode/SKILL.md"
}

@test "edge: LocalAI down (empty port) is a FAIL with exit 2" {
  start_fake down
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --json
  [ "$status" -eq 2 ]
  [ "$(check_status "$output" localai_running)" = "FAIL" ]
}

@test "edge: zero checks skipped — all five are reported" {
  start_fake ready
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --json
  [ "$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])['checks']))" "$output")" -eq 5 ]
}
