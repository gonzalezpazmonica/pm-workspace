#!/usr/bin/env bats
# Tests for block-credential-leak.sh hook
# Validates detection of 11 credential patterns + safe commands pass through

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  HOOK="$PWD/.claude/hooks/block-credential-leak.sh"
}

run_hook() {
  run bash -c "echo '$1' | bash '$HOOK'"
}

make_input() {
  echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}"
}

# ── Empty/missing command should pass ──

@test "empty command passes through" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":""}}'
  [ "$status" -eq 0 ]
}

@test "missing command field passes through" {
  run_hook '{"tool_name":"Bash","tool_input":{}}'
  [ "$status" -eq 0 ]
}

# ── Safe commands pass ──

@test "safe echo command passes" {
  run_hook "$(make_input 'echo hello world')"
  [ "$status" -eq 0 ]
}

@test "safe git status passes" {
  run_hook "$(make_input 'git status')"
  [ "$status" -eq 0 ]
}

@test "safe npm install passes" {
  run_hook "$(make_input 'npm install express')"
  [ "$status" -eq 0 ]
}

# ── Pattern 1: Generic secrets ──

@test "BLOCKS password= with value" {
  run_hook "$(make_input 'curl -u user:password=MyS3cretP@ssword https://api.com')"
  [ "$status" -eq 2 ]
}

@test "BLOCKS api_key= with value" {
  run_hook "$(make_input 'export api_key=abcdef1234567890')"
  [ "$status" -eq 2 ]
}

@test "BLOCKS client_secret= with value" {
  run_hook "$(make_input 'export client_secret=a1b2c3d4e5f6g7h8')"
  [ "$status" -eq 2 ]
}

# ── Pattern 2: AWS Access Keys ──

@test "BLOCKS AWS access key AKIA" {
  run_hook "$(make_input 'aws configure set aws_access_key_id AKIAIOSFODNN7EXAMPLE')"
  [ "$status" -eq 2 ]
}

# ── Pattern 3: GitHub tokens ──

@test "BLOCKS GitHub token ghp_" {
  run_hook "$(make_input 'git clone https://ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn@github.com/repo')"
  [ "$status" -eq 2 ]
}

# ── Pattern 4: OpenAI keys ──

@test "BLOCKS OpenAI API key sk-" {
  run_hook "$(make_input 'export OPENAI_API_KEY=sk-abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnop')"
  [ "$status" -eq 2 ]
}

# ── Pattern 5: Azure connection strings ──

@test "BLOCKS Azure DefaultEndpointsProtocol" {
  run_hook "$(make_input 'export CONN=DefaultEndpointsProtocol=https')"
  [ "$status" -eq 2 ]
}

@test "BLOCKS Azure AccountKey=" {
  run_hook "$(make_input 'export KEY=AccountKey=base64encodedkey')"
  [ "$status" -eq 2 ]
}

# ── Pattern 7: PAT hardcoded ──

@test "BLOCKS hardcoded PAT token" {
  run_hook "$(make_input 'export pat=abcdefghijklmnopqrstuvwxyz0123456789abcdefghij')"
  [ "$status" -eq 2 ]
}

# ── Pattern 8: Private keys ──

@test "BLOCKS RSA private key header" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":"echo -----BEGIN RSA PRIVATE KEY-----"}}'
  [ "$status" -eq 2 ]
}

# ── Pattern 9: Azure SAS tokens ──

@test "BLOCKS Azure SAS token" {
  run_hook "$(make_input 'curl https://myaccount.blob.core.windows.net?sv=2023-01-01&sp=r')"
  [ "$status" -eq 2 ]
}

# ── Pattern 10: Google API keys ──

@test "BLOCKS Google API key AIza" {
  run_hook "$(make_input 'export GAPI=AIzaSyA1234567890abcdefghijklmnopqrstuvwx')"
  [ "$status" -eq 2 ]
}

# ── Pattern 11: echo secrets to file ──

@test "BLOCKS echo secret to file" {
  run_hook "$(make_input 'echo my_secret_value >> config.txt')"
  [ "$status" -eq 2 ]
}

@test "safe echo without secret keyword passes" {
  run_hook "$(make_input 'echo hello >> output.log')"
  [ "$status" -eq 0 ]
}
