#!/usr/bin/env bash
# SPEC-141 · audit-mcp-templates.sh
# Verifies each .opencode/mcp-templates/*.jsonc.example against:
#   - Valid JSONC (strip // comments, parse as JSON)
#   - No hardcoded secrets (PATs, API keys, tokens)
#   - type in {local, remote}
#   - _savia_meta.scope declared
#   - if remote: oauth declared

set -uo pipefail

TEMPLATES_DIR="${1:-.opencode/mcp-templates}"
EXIT_CODE=0
PASS=0
FAIL=0

if [[ ! -d "$TEMPLATES_DIR" ]]; then
  echo "ERROR: $TEMPLATES_DIR not found"
  exit 1
fi

# Regex for hardcoded secrets (gh PAT, GitHub fine-grained, OpenAI, AWS)
SECRET_REGEX='(gh[ps]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82}|sk-[A-Za-z0-9]{48}|AKIA[0-9A-Z]{16})'

audit_template() {
  local f="$1"
  local name
  name=$(basename "$f" .jsonc.example)
  local errors=()

  # 1. Strip // line comments (preserve :// inside URLs) and validate JSON
  local stripped
  stripped=$(python3 -c 'import sys,re; print(re.sub(r"(^|[^:])//[^\n]*", r"\1", sys.stdin.read()))' < "$f")
  if ! printf '%s' "$stripped" | jq empty 2>/dev/null; then
    errors+=("invalid JSON after stripping comments")
  fi

  # 2. Secret scan (on raw file, including comments)
  if grep -qE "$SECRET_REGEX" "$f"; then
    errors+=("hardcoded secret detected")
  fi

  # 3. Schema checks (only if JSON valid)
  if [[ ${#errors[@]} -eq 0 ]]; then
    local mcp_keys type scope oauth
    mcp_keys=$(printf '%s' "$stripped" | jq -r '.mcp | keys[]' 2>/dev/null || echo "")
    if [[ -z "$mcp_keys" ]]; then
      errors+=("no mcp.* key found")
    else
      for key in $mcp_keys; do
        type=$(printf '%s' "$stripped" | jq -r ".mcp.\"$key\".type // \"\"")
        if [[ "$type" != "local" && "$type" != "remote" ]]; then
          errors+=("$key: type must be local or remote (got: $type)")
        fi

        scope=$(printf '%s' "$stripped" | jq -r ".mcp.\"$key\"._savia_meta.scope // \"\"")
        if [[ -z "$scope" ]]; then
          errors+=("$key: _savia_meta.scope not declared")
        fi

        if [[ "$type" == "remote" ]]; then
          oauth=$(printf '%s' "$stripped" | jq -r ".mcp.\"$key\".oauth // empty")
          if [[ -z "$oauth" ]]; then
            errors+=("$key: remote server must declare oauth (true/false)")
          fi
        fi
      done
    fi
  fi

  if [[ ${#errors[@]} -eq 0 ]]; then
    echo "PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $name"
    for e in "${errors[@]}"; do echo "        - $e"; done
    FAIL=$((FAIL + 1))
    EXIT_CODE=1
  fi
}

echo "Auditing MCP templates in $TEMPLATES_DIR"
echo "---"
for f in "$TEMPLATES_DIR"/*.jsonc.example; do
  [[ -f "$f" ]] || continue
  audit_template "$f"
done
echo "---"
echo "Result: $PASS pass, $FAIL fail"
exit $EXIT_CODE
