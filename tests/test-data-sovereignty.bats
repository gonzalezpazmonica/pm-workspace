#!/usr/bin/env bats
# test-data-sovereignty.bats — Tests para el sistema Data Sovereignty Gate
# Valida las 3 capas: regex, Ollama, auditoria
# Ref: docs/rules/domain/data-sovereignty.md

setup() {
  # Force shield enabled for tests (env may have SAVIA_SHIELD_ENABLED=false from settings.local.json)
  export SAVIA_SHIELD_ENABLED=true
  export CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/workspace"
  mkdir -p "$CLAUDE_PROJECT_DIR/output"
  mkdir -p "$CLAUDE_PROJECT_DIR/projects/test-project"
  mkdir -p "$CLAUDE_PROJECT_DIR/scripts"
  mkdir -p "$CLAUDE_PROJECT_DIR/.claude/hooks"
  # Copiar scripts al tmpdir
  SRC="${BATS_TEST_DIRNAME}/.."
  cp "$SRC/.claude/hooks/data-sovereignty-gate.sh" "$CLAUDE_PROJECT_DIR/.claude/hooks/"
  cp "$SRC/.claude/hooks/data-sovereignty-audit.sh" "$CLAUDE_PROJECT_DIR/.claude/hooks/"
  cp "$SRC/scripts/ollama-classify.sh" "$CLAUDE_PROJECT_DIR/scripts/"
  chmod +x "$CLAUDE_PROJECT_DIR/.claude/hooks/"*.sh
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/"*.sh
  GATE="$CLAUDE_PROJECT_DIR/.claude/hooks/data-sovereignty-gate.sh"
  AUDIT="$CLAUDE_PROJECT_DIR/.claude/hooks/data-sovereignty-audit.sh"
  AUDIT_LOG="$CLAUDE_PROJECT_DIR/output/data-sovereignty-audit.jsonl"
}

# --- CAPA 1: Regex determinista ---

@test "Capa 1: bloquea connection string en fichero publico" {
  INPUT='{"tool_input":{"file_path":"/workspace/docs/setup.md","content":"Server=prod.db.internal;Password=s3cr3t;Database=app"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOQUEADO"* ]]
  [[ "$output" == *"connection_string"* ]]
}

@test "Capa 1: bloquea AWS key en fichero publico" {
  INPUT='{"tool_input":{"file_path":"/workspace/README.md","content":"Use key AKIAIOSFODNN7TESTING to connect"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
  [[ "$output" == *"aws_key"* ]]
}

@test "Capa 1: bloquea IP interna en fichero publico" {
  INPUT='{"tool_input":{"file_path":"/workspace/docs/arch.md","content":"Deploy to 192.168.1.100 on port 8080"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
  [[ "$output" == *"internal_ip"* ]]
}

@test "Capa 1: permite contenido generico en fichero publico" {
  INPUT='{"tool_input":{"file_path":"/workspace/README.md","content":"Hello world"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}

@test "Capa 1: permite dato sensible en fichero N4 (projects/)" {
  INPUT='{"tool_input":{"file_path":"/workspace/projects/alpha/config.md","content":"Server=prod.db;Password=s3cr3t"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}

@test "Capa 1: permite dato sensible en fichero .local" {
  INPUT='{"tool_input":{"file_path":"/workspace/CLAUDE.local.md","content":"PAT=ghp_abcdef1234567890abcdef1234567890abcd"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}

@test "Capa 1: permite dato sensible en output/" {
  INPUT='{"tool_input":{"file_path":"/workspace/output/report.md","content":"10.0.0.1 internal server"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}

@test "Capa 1: permite dato sensible en private-agent-memory/" {
  INPUT='{"tool_input":{"file_path":"/workspace/private-agent-memory/savia/MEMORY.md","content":"192.168.1.50 lab server"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}

# --- Input edge cases ---

@test "permite input sin file_path" {
  INPUT='{"tool_input":{}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}

@test "permite input vacio" {
  run bash -c "echo '' | bash $GATE"
  [ "$status" -eq 0 ]
}

@test "Capa 1: bloquea GitHub PAT en fichero publico" {
  INPUT='{"tool_input":{"file_path":"/workspace/scripts/deploy.sh","content":"export TOKEN=ghp_ABC123def456ghi789jkl012mno345pqr678"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
  # Daemon uses "github_pat", fallback uses "github_token" — accept both
  [[ "$output" == *"github"* ]]
}

# --- CAPA 2: Ollama (mock) ---

@test "Capa 2: degrada sin Ollama (no bloquea)" {
  # Sin Ollama corriendo, Capa 2 debe degradar silenciosamente
  export OLLAMA_URL="http://localhost:99999"
  INPUT='{"tool_input":{"file_path":"/workspace/docs/guide.md","content":"This is a longer text that passes regex but might need LLM classification for proper analysis of content sensitivity level"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 0 ]
}

# --- AUDITORIA ---

@test "Capa 3: audit log se crea al bloquear" {
  INPUT='{"tool_input":{"file_path":"/workspace/docs/x.md","content":"jdbc:postgresql://10.0.0.5:5432/prod?password=secret"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
  [ -f "$AUDIT_LOG" ]
  # Daemon writes "BLOCK", fallback writes "BLOCKED" — accept both
  grep -qE "BLOCK" "$AUDIT_LOG"
}

# --- ollama-classify.sh unit tests ---

@test "ollama-classify: falla sin texto" {
  run bash "$CLAUDE_PROJECT_DIR/scripts/ollama-classify.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "ollama-classify: devuelve UNAVAILABLE sin servidor" {
  export OLLAMA_URL="http://localhost:99999"
  run bash "$CLAUDE_PROJECT_DIR/scripts/ollama-classify.sh" "test text"
  [ "$status" -eq 1 ]
  [[ "$output" == "UNAVAILABLE" ]]
}

@test "Capa 1: blocks private key header in public file" {
  INPUT='{"tool_input":{"file_path":"/workspace/docs/x.md","content":"-----BEGIN RSA PRIVATE KEY-----"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
}

@test "Capa 1: blocks OpenAI key in public file" {
  INPUT='{"tool_input":{"file_path":"/workspace/docs/x.md","content":"export KEY=sk-proj-abcdefghijklmnopqrstuvwxyz0123456789ABCD"}}'
  run bash -c "echo '$INPUT' | bash $GATE"
  [ "$status" -eq 2 ]
}

@test "gate script has set -uo pipefail safety header" {
  grep -q "set -[euo]" "$GATE" || grep -q "set -[euo]*o pipefail" "$GATE"
}
