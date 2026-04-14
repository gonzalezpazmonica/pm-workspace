#!/usr/bin/env bats
# test-shield-ner-allowlist-domains.bats
# Regression tests for Shield NER false positives on public provider domains
# and code-like identifiers. Added after false positives blocked legitimate
# script authoring (URLs to microsoft365.com / office.com flagged as PII).

setup() {
  export SHIELD_URL="http://127.0.0.1:${SAVIA_SHIELD_PORT:-8444}"
  export N1_PATH="docs/scratch-test.md"
}

daemon_available() {
  curl -sf --max-time 2 "$SHIELD_URL/health" >/dev/null 2>&1
}

gate_post() {
  local file_path="$1"
  local content="$2"
  local token_header=""
  if [[ -f "$HOME/.savia/shield-token" ]]; then
    local tok
    tok=$(cat "$HOME/.savia/shield-token" 2>/dev/null)
    [[ -n "$tok" ]] && token_header="-H X-Shield-Token:$tok"
  fi
  python3 -c "
import json, sys
print(json.dumps({'tool_input': {'file_path': sys.argv[1], 'content': sys.argv[2]}}))
" "$file_path" "$content" | curl -s --max-time 10 -X POST "$SHIELD_URL/gate" \
    -H "Content-Type: application/json" $token_header -d @- 2>/dev/null
}

# --- Public provider domains: must NOT block ---

@test "microsoft365.com URL in public file is ALLOWED" {
  daemon_available || skip "Shield daemon not running"
  output=$(gate_post "$N1_PATH" 'const URL = "https://www.microsoft365.com/launch/stream?auth=2"')
  [[ "$output" != *'"verdict": "BLOCK"'* ]]
}

@test "sharepoint.com URL is ALLOWED" {
  daemon_available || skip "Shield daemon not running"
  output=$(gate_post "$N1_PATH" 'goto("https://grupovass-my.sharepoint.com/_layouts/15/stream.aspx")')
  [[ "$output" != *'"verdict": "BLOCK"'* ]]
}

@test "office.com URL is ALLOWED" {
  daemon_available || skip "Shield daemon not running"
  output=$(gate_post "$N1_PATH" 'https://www.office.com/launch/onedrive?auth=2')
  [[ "$output" != *'"verdict": "BLOCK"'* ]]
}

@test "outlook.office365.com URL is ALLOWED" {
  daemon_available || skip "Shield daemon not running"
  output=$(gate_post "$N1_PATH" 'mail_url = "https://outlook.office365.com/mail/inbox"')
  [[ "$output" != *'"verdict": "BLOCK"'* ]]
}

@test "github.com URL is ALLOWED" {
  daemon_available || skip "Shield daemon not running"
  output=$(gate_post "$N1_PATH" 'repo = "https://github.com/anthropics/claude-code"')
  [[ "$output" != *'"verdict": "BLOCK"'* ]]
}

# --- Code-like identifiers: must NOT block ---

@test "UPPER_SNAKE constant is ALLOWED" {
  daemon_available || skip "Shield daemon not running"
  output=$(gate_post "$N1_PATH" 'URLS_TO_TRY = ["a", "b"]')
  [[ "$output" != *'"verdict": "BLOCK"'* ]]
}

@test "dotted code reference is ALLOWED" {
  daemon_available || skip "Shield daemon not running"
  output=$(gate_post "$N1_PATH" 'sys.path.insert(0, here)')
  [[ "$output" != *'"verdict": "BLOCK"'* ]]
}

@test "path with / is ALLOWED" {
  daemon_available || skip "Shield daemon not running"
  output=$(gate_post "$N1_PATH" 'import discover-recordings.py from scripts/')
  [[ "$output" != *'"verdict": "BLOCK"'* ]]
}

# --- Real PII: must STILL block ---

@test "AWS key is still BLOCKED" {
  daemon_available || skip "Shield daemon not running"
  local prefix="AKI"
  local suffix="AIOSFODNN7EXAMPLE"
  output=$(gate_post "$N1_PATH" "credential = ${prefix}${suffix}")
  [[ "$output" == *'"verdict": "BLOCK"'* ]]
}

@test "GitHub PAT is still BLOCKED" {
  daemon_available || skip "Shield daemon not running"
  local token="ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  output=$(gate_post "$N1_PATH" "export GH_TOKEN=${token}")
  [[ "$output" == *'"verdict": "BLOCK"'* ]]
}

@test "private internal IP is still BLOCKED" {
  daemon_available || skip "Shield daemon not running"
  output=$(gate_post "$N1_PATH" "connect to 192.168.1.50 port 5432")
  [[ "$output" == *'"verdict": "BLOCK"'* ]]
}

# --- Sanity: allowlist file exists and contains key domains ---

@test "allowlist file contains microsoft.com" {
  grep -q '^microsoft\.com$' scripts/shield-ner-allowlist.txt
}

@test "allowlist file contains sharepoint.com" {
  grep -q '^sharepoint\.com$' scripts/shield-ner-allowlist.txt
}

@test "daemon source has NER_PUBLIC_DOMAINS constant" {
  grep -q '^NER_PUBLIC_DOMAINS' scripts/savia-shield-daemon.py
}

@test "daemon source has filter 0a public provider" {
  grep -q 'Filter 0a: public provider' scripts/savia-shield-daemon.py
}
