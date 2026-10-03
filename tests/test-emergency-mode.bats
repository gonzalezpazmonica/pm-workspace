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
  # Umbrales a 0: los tests no dependen de la RAM ni del disco de la máquina que los ejecuta.
  export LOCALAI_RAM_OK_GB=0 LOCALAI_RAM_MIN_GB=0 LOCALAI_DISK_OK_GB=0 LOCALAI_DISK_MIN_GB=0
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
  [[ "$output" == *"ANTHROPIC_BASE_URL=\"$URL\""* ]]
  [[ "$output" != *"$URL/v1"* ]]
}

@test "requested model missing is a FAIL (exit 2): switching over would break the first request" {
  start_fake other-model
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --json
  [ "$status" -eq 2 ]
  [ "$(check_status "$output" model_available)" = "FAIL" ]
  [[ "$output" == *"qwen2.5:7b"* ]]
  [[ "$output" == *"--model"* ]]
}

@test "requested model missing prints no switchover line" {
  start_fake other-model
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL"
  [ "$status" -eq 2 ]
  [[ "$output" != *"export ANTHROPIC_"* ]]
}

@test "a substring of a loaded id does not satisfy the requested model (exact match)" {
  start_fake other-model
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --model qwen --json
  [ "$(check_status "$output" model_available)" != "OK" ]
  [ "$status" -eq 2 ]
}

@test "switchover exports base URL, ANTHROPIC_MODEL and ANTHROPIC_SMALL_FAST_MODEL" {
  start_fake ready
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"export ANTHROPIC_BASE_URL=\"$URL\""* ]]
  [[ "$output" == *'export ANTHROPIC_MODEL="claude-compatible-local"'* ]]
  [[ "$output" == *'export ANTHROPIC_SMALL_FAST_MODEL="claude-compatible-local"'* ]]
}

@test "JSON switchover carries the model next to the base URL" {
  start_fake ready
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --json
  python3 -c "
import json,sys
sw=json.loads(sys.argv[1])['switchover']
assert sw=={'ANTHROPIC_BASE_URL':sys.argv[2],'ANTHROPIC_MODEL':'claude-compatible-local','ANTHROPIC_SMALL_FAST_MODEL':'claude-compatible-local'}, sw
" "$output" "$URL"
}

@test "printed switchover lines are shell-safe: eval sets the exact model with quotes" {
  start_fake quoted
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --model 'mi "modelo"'
  [ "$status" -eq 0 ]
  lines_=$(printf '%s\n' "$output" | grep '^  export ANTHROPIC_')
  got=$(eval "$lines_"; printf '%s|%s' "$ANTHROPIC_MODEL" "$ANTHROPIC_BASE_URL")
  [ "$got" = "mi \"modelo\"|$URL" ]
}

@test "trailing slash in --url is stripped (no //v1/messages)" {
  start_fake ready
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL/" --json
  [ "$(check_status "$output" anthropic_compat)" = "OK" ]
  python3 -c "import json,sys; assert json.loads(sys.argv[1])['switchover']['ANTHROPIC_BASE_URL']==sys.argv[2]" "$output" "$URL"
}

@test "trailing slash in LOCALAI_URL env is stripped too" {
  start_fake ready
  LOCALAI_URL="$URL/" run bash "$REPO_ROOT/$SCRIPT"
  [[ "$output" == *"export ANTHROPIC_BASE_URL=\"$URL\""* ]]
  [[ "$output" != *"$URL/\""* ]]
}

@test "--url followed by another flag is rejected (exit 2), not taken as the URL" {
  run bash "$REPO_ROOT/$SCRIPT" --url --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"needs a value"* ]]
  [[ "$output" != *"localai_running"* ]]
  run bash "$REPO_ROOT/$SCRIPT" --model --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"needs a value"* ]]
}

@test "unmeasurable RAM (no /proc/meminfo, e.g. macOS) is a WARN 'no medido', not a FAIL" {
  start_fake ready
  LOCALAI_MEMINFO="$TMPDIR/absent" run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --json
  [ "$(check_status "$output" ram)" = "WARN" ]
  [[ "$output" == *"no medido"* ]]
  [ "$status" -eq 1 ]
}

@test "unmeasurable disk is a WARN 'no medido' and still prints the switchover" {
  start_fake ready
  LOCALAI_DISK_PATH="$TMPDIR/absent" run bash "$REPO_ROOT/$SCRIPT" --url "$URL"
  [[ "$output" == *"[WARN] disk"*"no medido"* ]]
  [ "$status" -eq 1 ]
  [[ "$output" == *"export ANTHROPIC_MODEL="* ]]
}

@test "boundary: RAM threshold above the machine RAM is a FAIL, injected via env" {
  start_fake ready
  LOCALAI_RAM_MIN_GB=999999 LOCALAI_RAM_OK_GB=999999 run bash "$REPO_ROOT/$SCRIPT" --url "$URL" --json
  [ "$(check_status "$output" ram)" = "FAIL" ]
  [ "$status" -eq 2 ]
}

@test "invalid threshold value is a usage error (exit 2)" {
  LOCALAI_DISK_MIN_GB=abc run bash "$REPO_ROOT/$SCRIPT" --url "http://127.0.0.1:1" --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"LOCALAI_DISK_MIN_GB"* ]]
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
  [ "$(check_status "$output" model_available)" = "FAIL" ]
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
  local docs=("$REPO_ROOT/.claude/skills/emergency-mode/SKILL.md"
    "$REPO_ROOT/.claude/skills/emergency-mode/DOMAIN.md"
    "$REPO_ROOT/docs/rules/domain/emergency-mode-protocol.md")
  ! grep -nE 'ANTHROPIC_BASE_URL="?https?://[^" ]*/v1"?([[:space:]]|$)' "${docs[@]}"
  # Tampoco el endpoint local descrito en prosa (localhost:8080/v1 invita al mismo error).
  ! grep -nE '(localhost|127\.0\.0\.1):[0-9]+/v1([^/]|$)' "${docs[@]}"
}

@test "skill and protocol export every variable the script prints, and unset them on the way back" {
  start_fake ready
  run bash "$REPO_ROOT/$SCRIPT" --url "$URL"
  vars=$(printf '%s\n' "$output" | sed -nE 's/^  export (ANTHROPIC_[A-Z_]+)=.*/\1/p')
  [ -n "$vars" ]
  for doc in "$REPO_ROOT/.claude/skills/emergency-mode/SKILL.md" "$REPO_ROOT/docs/rules/domain/emergency-mode-protocol.md"; do
    for v in $vars; do
      grep -qE "export $v=" "$doc" || { echo "$doc: falta export $v"; return 1; }
      grep -qE "unset .*\b$v\b|\b$v\b.*unset|Unset vars .*\b$v\b" "$doc" || { echo "$doc: falta unset $v"; return 1; }
    done
  done
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
