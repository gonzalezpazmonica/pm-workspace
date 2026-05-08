#!/usr/bin/env bats
# test-data-sovereignty-extended.bats — Edge cases, bypass attempts, stress tests
# Ref: docs/rules/domain/data-sovereignty.md

setup() {
  # Force shield enabled for tests (env may have SAVIA_SHIELD_ENABLED=false from settings.local.json)
  export SAVIA_SHIELD_ENABLED=true
  export CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/workspace"
  mkdir -p "$CLAUDE_PROJECT_DIR/output"
  mkdir -p "$CLAUDE_PROJECT_DIR/projects/test-project"
  mkdir -p "$CLAUDE_PROJECT_DIR/scripts"
  mkdir -p "$CLAUDE_PROJECT_DIR/.claude/hooks"
  mkdir -p "$CLAUDE_PROJECT_DIR/.opencode/hooks"
  SRC="${BATS_TEST_DIRNAME}/.."
  cp "$SRC/.opencode/hooks/data-sovereignty-gate.sh" "$CLAUDE_PROJECT_DIR/.opencode/hooks/"
  cp "$SRC/.opencode/hooks/data-sovereignty-audit.sh" "$CLAUDE_PROJECT_DIR/.opencode/hooks/"
  cp "$SRC/scripts/ollama-classify.sh" "$CLAUDE_PROJECT_DIR/scripts/"
  chmod +x "$CLAUDE_PROJECT_DIR/.opencode/hooks/"*.sh
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/"*.sh
  GATE="$CLAUDE_PROJECT_DIR/.opencode/hooks/data-sovereignty-gate.sh"
  AUDIT_LOG="$CLAUDE_PROJECT_DIR/output/data-sovereignty-audit.jsonl"
  # Disable Ollama for deterministic tests
  export OLLAMA_URL="http://localhost:99999"
}

# --- BYPASS ATTEMPTS ---

@test "Bypass: base64 encoded credential passes regex (known limitation)" {
  # Base64 of "Password=secret123" — regex won't catch this
  INPUT='{"tool_input":{"file_path":"/workspace/docs/x.md","content":"Config: UGFzc3dvcmQ9c2VjcmV0MTIz"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  # This SHOULD pass regex (known limitation, caught by Layer 2 LLM)
  [ "$status" -eq 0 ]
}

@test "Bypass: data after 3000-char truncation is not checked" {
  # Generate 3000 chars of padding + sensitive data
  PADDING=$(printf 'A%.0s' {1..3001})
  INPUT="{\"tool_input\":{\"file_path\":\"/workspace/docs/x.md\",\"content\":\"${PADDING}jdbc:postgresql://real-server:5432/prod\"}}"
  run bash -c "echo '$INPUT' | bash $GATE"
  # After SEC-002: scan window is 20000 chars — this IS caught now
  [ "$status" -eq 2 ]
}

@test "SEC-006: Unicode homoglyph bypass now fixed (see test 48)" {
  skip "Superseded by SEC-006 consolidated test with proper PYTHONUTF8 encoding"
}

@test "Bypass: splitting data across writes is not detected per-write" {
  # First write: partial connection string
  INPUT1='{"tool_input":{"file_path":"/workspace/docs/x.md","content":"Server=prod.internal"}}'
  run bash -c "echo '$INPUT1' | bash $GATE"
  [ "$status" -eq 0 ]
  # Second write: password part
  INPUT2='{"tool_input":{"file_path":"/workspace/docs/x.md","content":"Password=s3cret123"}}'
  run bash -c "echo '$INPUT2' | bash $GATE"
  # "Password=" alone doesn't match our regex (needs Server=.*Password=)
  [ "$status" -eq 0 ]
}

# --- WHITELIST SECURITY ---

@test "Whitelist: only security docs are whitelisted, not arbitrary paths" {
  INPUT='{"tool_input":{"file_path":"/workspace/src/MyService.cs","content":"jdbc:mysql://prod:3306/db?password=real"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
}

@test "Whitelist: path traversal doesn't bypass (../data-sovereignty)" {
  INPUT='{"tool_input":{"file_path":"/workspace/src/../data-sovereignty-fake.md","content":"jdbc:mysql://prod/db?password=real"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  # After FIX-C2: narrow whitelist blocks this
  [ "$status" -eq 2 ]
}

# --- MALFORMED INPUT ---

@test "Malformed: invalid JSON input doesn't crash" {
  run bash -c "echo 'not json at all' | bash $GATE"
  [ "$status" -eq 0 ]
}

@test "Malformed: null file_path doesn't crash" {
  INPUT='{"tool_input":{"file_path":null,"content":"test"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}

@test "Malformed: missing tool_input doesn't crash" {
  INPUT='{"something_else":"value"}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}

@test "Malformed: extremely long content doesn't hang" {
  LONG=$(printf 'X%.0s' {1..5000})
  INPUT="{\"tool_input\":{\"file_path\":\"/workspace/docs/x.md\",\"content\":\"$LONG\"}}"
  run bash -c "echo '$INPUT' | timeout 10 bash $GATE"
  [ "$status" -eq 0 ]
}

# --- DOC CONTEXT BYPASS ---

@test "Doc context: real credential with word 'example' nearby passes" {
  # Content mentions "example" but also has a REAL-looking credential
  INPUT='{"tool_input":{"file_path":"/workspace/docs/x.md","content":"Here is an example config: jdbc:mysql://real-prod:3306/db?password=hunter2"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  # After FIX-C1: credentials ALWAYS blocked
  [ "$status" -eq 2 ]
}

@test "Doc context: real IP without doc words is blocked" {
  INPUT='{"tool_input":{"file_path":"/workspace/deploy.sh","content":"ssh root@192.168.50.10 deploy.sh"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
}

# --- DESTINATION CLASSIFICATION ---

@test "Destination: config.local/ is private" {
  INPUT='{"tool_input":{"file_path":"/workspace/config.local/db.env","content":"jdbc:mysql://prod/db"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}

@test "Destination: .savia/ path is private" {
  INPUT='{"tool_input":{"file_path":"/home/user/.savia/cache/data.json","content":"192.168.1.1"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}

@test "Destination: src/ path is public (no special exclusion)" {
  INPUT='{"tool_input":{"file_path":"/workspace/src/config.ts","content":"jdbc:postgresql://10.0.0.5/app"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
}

# --- AUDIT LOG INTEGRITY ---

@test "Audit log: entries are valid JSON lines" {
  INPUT='{"tool_input":{"file_path":"/workspace/x.md","content":"jdbc:mysql://prod/db?password=x"}}'
  bash -c "echo '$INPUT' | bash $GATE" 2>/dev/null || true
  [ -f "$AUDIT_LOG" ]
  # Each line should be valid JSON
  while IFS= read -r line; do
    echo "$line" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null
    [ $? -eq 0 ]
  done < "$AUDIT_LOG"
}

@test "Audit log: contains required fields" {
  INPUT='{"tool_input":{"file_path":"/workspace/x.md","content":"jdbc:mysql://prod/db?password=x"}}'
  bash -c "echo '$INPUT' | bash $GATE" 2>/dev/null || true
  [ -f "$AUDIT_LOG" ]
  grep -q '"ts"' "$AUDIT_LOG"
  grep -q '"layer"' "$AUDIT_LOG"
  grep -q '"verdict"' "$AUDIT_LOG"
}


# --- FIX VERIFICATION TESTS ---

@test "FIX-C1: doc word 'example' does NOT bypass credential detection" {
  INPUT='{"tool_input":{"file_path":"/workspace/docs/x.md","content":"Here is an example config: jdbc:mysql://real-prod:3306/db?password=hunter2"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  # After fix: credentials ALWAYS blocked regardless of doc words
  [ "$status" -eq 2 ]
  [[ "$output" == *"connection_string"* ]]
}

@test "FIX-C2: docs/rules/ is NOT whitelisted for arbitrary files" {
  INPUT='{"tool_input":{"file_path":"/workspace/docs/rules/domain/my-notes.md","content":"jdbc:mysql://prod/db?password=secret"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
}

@test "FIX-C2: .opencode/hooks/ IS whitelisted (hook code triggers false positives)" {
  INPUT='{"tool_input":{"file_path":"/workspace/.opencode/hooks/my-custom-hook.sh","content":"AKIAIOSFODNN7REALKEY1"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}

@test "FIX-C3: docs/rules/ is treated as PUBLIC destination" {
  INPUT='{"tool_input":{"file_path":"/workspace/docs/rules/domain/test.md","content":"192.168.1.100 internal server"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
}

@test "FIX-H3: blocks 172.16.x.x private IP range" {
  echo '{"tool_input":{"file_path":"/workspace/docs/x.md","content":"Server at 172.16.50.10"}}' > "$BATS_TEST_TMPDIR/input172.json"
  run bash -c "cat $BATS_TEST_TMPDIR/input172.json | bash $GATE"
  [ "$status" -eq 2 ]
}

@test "FIX-H3: blocks OpenAI API key" {
  INPUT='{"tool_input":{"file_path":"/workspace/docs/x.md","content":"export OPENAI_KEY=sk-proj-abcdefghijklmnopqrstuvwxyz0123456789ABCD"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
}

@test "FIX-H3: blocks Azure SAS token" {
  INPUT='{"tool_input":{"file_path":"/workspace/docs/x.md","content":"blob.core?sv=2024-05-04&ss=b&sig=abc"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
}

@test "FIX-H3: blocks private key header" {
  INPUT='{"tool_input":{"file_path":"/workspace/docs/x.md","content":"-----BEGIN RSA PRIVATE KEY-----"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
}

@test "FIX-C2: specific data-sovereignty files ARE still whitelisted" {
  INPUT='{"tool_input":{"file_path":"/workspace/scripts/ollama-classify.sh","content":"jdbc:mysql example pattern detection"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}


# --- BASE64 DETECTION TESTS ---

@test "FIX-base64: detects base64-encoded connection string" {
  # Generate base64 of a JDBC connection string
  B64=$(echo -n "jdbc:mysql://prod:3306/db?password=secret" | base64)
  # Build JSON using python3 to avoid bash quoting issues
  python3 -c "
import json
b64 = '$B64' if '$B64' else 'amRiYzpteXNxbDovL3Byb2Q6MzMwNi9kYj9wYXNzd29yZD1zZWNyZXQ='
payload = json.dumps({'tool_input': {'file_path': '/workspace/docs/x.md', 'content': 'Encoded config: ' + b64}})
print(payload)
" > "$BATS_TEST_TMPDIR/b64input.json"
  run bash -c "cat '$BATS_TEST_TMPDIR/b64input.json' | bash '$GATE'"
  [ "$status" -eq 2 ]
  # Daemon uses "b64_connection_string", fallback uses "base64_credential"
  [[ "$output" == *"b64"* ]] || [[ "$output" == *"base64"* ]]
}


@test "FIX-base64: allows normal long strings that are not base64 secrets" {
  INPUT='{"tool_input":{"file_path":"/workspace/docs/x.md","content":"Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}

# --- PRE-COMMIT HOOK TESTS ---

@test "pre-commit: script exists and is executable" {
  SRC="${BATS_TEST_DIRNAME}/.."
  [ -x "$SRC/scripts/pre-commit-sovereignty.sh" ]
}


# --- SEC-020: Layer 3 audit hook tests ---

@test "SEC-020: Layer 3 detects leak in file on disk" {
  mkdir -p "$BATS_TEST_TMPDIR/workspace/docs"
  echo "Server=prod.db.internal;Password=s3cret123" > "$BATS_TEST_TMPDIR/workspace/docs/leaked.md"
  # Feed the file path to the audit hook
  AUDIT="$CLAUDE_PROJECT_DIR/.opencode/hooks/data-sovereignty-audit.sh"
  INPUT='{"tool_input":{"file_path":"'"$BATS_TEST_TMPDIR/workspace/docs/leaked.md"'"}}'
  run bash -c "echo '$INPUT' | bash '$AUDIT'"
  # Audit should detect the leak (exit 0 because non-blocking, but stderr has alert)
  [[ "$output" == *"ALERTA"* ]] || [[ "$output" == *"LEAK"* ]]
}

@test "SEC-020: Layer 3 clean file produces no alert" {
  mkdir -p "$BATS_TEST_TMPDIR/workspace/docs"
  echo "Hello world clean content" > "$BATS_TEST_TMPDIR/workspace/docs/clean.md"
  AUDIT="$CLAUDE_PROJECT_DIR/.opencode/hooks/data-sovereignty-audit.sh"
  INPUT='{"tool_input":{"file_path":"'"$BATS_TEST_TMPDIR/workspace/docs/clean.md"'"}}'
  run bash -c "echo '$INPUT' | bash '$AUDIT'"
  [[ "$output" != *"ALERTA"* ]]
  [[ "$output" != *"LEAK"* ]]
}

# --- SEC-005: Split-write defense test ---

@test "SEC-005: cross-write detects credential split across writes" {
  # Simulate first write already on disk
  mkdir -p "$BATS_TEST_TMPDIR/workspace/docs"
  echo "Server=prod.db.internal" > "$BATS_TEST_TMPDIR/workspace/docs/config.md"
  # Second write adds password — force fallback mode (bash can read /tmp/ natively)
  INPUT='{"tool_input":{"file_path":"'"$BATS_TEST_TMPDIR/workspace/docs/config.md"'","content":"Password=s3cret123"}}'
  run bash -c "export SAVIA_SHIELD_PORT=19999; echo '$INPUT' | bash $GATE"
  # Should block because combined file+new matches Server=.*Password=
  [ "$status" -eq 2 ]
  [[ "$output" == *"split_write"* ]] || [[ "$output" == *"BLOQUEADO"* ]]
}

# --- SEC-006: Unicode normalization test ---

@test "SEC-006: fullwidth IP digits are normalized and caught" {
  # Use python with UTF-8 encoding to generate fullwidth digits
  PYTHONUTF8=1 python3 -c "
import json, sys
fw = 'Server at １９２.１６８.１.１'
d = json.dumps({'tool_input': {'file_path': '/workspace/docs/x.md', 'content': fw}})
sys.stdout.buffer.write(d.encode('utf-8'))
" > "$BATS_TEST_TMPDIR/unicode_input.json" 2>/dev/null
  if [[ ! -s "$BATS_TEST_TMPDIR/unicode_input.json" ]]; then
    skip "Python UTF-8 output not supported on this platform"
  fi
  run bash -c "cat '$BATS_TEST_TMPDIR/unicode_input.json' | bash $GATE"
  [ "$status" -eq 2 ]
}


# --- SEC-021: Ollama response path tests (mock via override) ---

@test "SEC-021: CONFIDENTIAL Ollama response blocks write" {
  # Mock: create a fake ollama-classify.sh that always returns CONFIDENTIAL
  # Force fallback mode (no daemon) so the hook uses ollama-classify.sh
  mkdir -p "$CLAUDE_PROJECT_DIR/scripts"
  echo '#!/bin/bash' > "$CLAUDE_PROJECT_DIR/scripts/ollama-classify.sh"
  echo 'echo "CONFIDENTIAL"' >> "$CLAUDE_PROJECT_DIR/scripts/ollama-classify.sh"
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/ollama-classify.sh"
  INPUT='{"tool_input":{"file_path":"/workspace/docs/x.md","content":"This is a long enough text that passes regex but needs LLM classification to determine sensitivity level properly"}}'
  run bash -c "export SAVIA_SHIELD_PORT=19999; echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOQUEADO"* ]]
}

@test "SEC-021: AMBIGUOUS Ollama response blocks write (non-N1)" {
  # Force fallback mode (no daemon) so the hook uses ollama-classify.sh
  mkdir -p "$CLAUDE_PROJECT_DIR/scripts"
  echo '#!/bin/bash' > "$CLAUDE_PROJECT_DIR/scripts/ollama-classify.sh"
  echo 'echo "AMBIGUOUS"' >> "$CLAUDE_PROJECT_DIR/scripts/ollama-classify.sh"
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/ollama-classify.sh"
  # Non-N1 path: src/ is neither public N1 (docs, scripts, tests...) nor private exit-0 path
  INPUT='{"tool_input":{"file_path":"/workspace/src/config.js","content":"This is a long enough text that passes regex but needs LLM classification to determine sensitivity level properly"}}'
  run bash -c "export SAVIA_SHIELD_PORT=19999; echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
}

@test "SEC-021: AMBIGUOUS Ollama response warns on N1 destinations" {
  mkdir -p "$CLAUDE_PROJECT_DIR/scripts"
  echo '#!/bin/bash' > "$CLAUDE_PROJECT_DIR/scripts/ollama-classify.sh"
  echo 'echo "AMBIGUOUS"' >> "$CLAUDE_PROJECT_DIR/scripts/ollama-classify.sh"
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/ollama-classify.sh"
  # N1 destinations (docs/) get WARN on AMBIGUOUS per data-sovereignty-gate fix
  INPUT='{"tool_input":{"file_path":"/workspace/docs/x.md","content":"This is a long enough text that passes regex but needs LLM classification to determine sensitivity level properly"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}

@test "SEC-021: PUBLIC Ollama response allows write" {
  mkdir -p "$CLAUDE_PROJECT_DIR/scripts"
  echo '#!/bin/bash' > "$CLAUDE_PROJECT_DIR/scripts/ollama-classify.sh"
  echo 'echo "PUBLIC"' >> "$CLAUDE_PROJECT_DIR/scripts/ollama-classify.sh"
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/ollama-classify.sh"
  INPUT='{"tool_input":{"file_path":"/workspace/docs/x.md","content":"This is a long enough text that passes regex but needs LLM classification to determine sensitivity level properly"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}

@test "gate script has set -uo pipefail safety header" {
  grep -q "set -[euo]" "$GATE" || grep -q "set -[euo]*o pipefail" "$GATE"
}
