#!/usr/bin/env bash
# pre-commit-sovereignty.sh — Git pre-commit hook
# Scans ALL staged files for sensitive data patterns
# Full file content, no truncation — last line of defense before git
# NOTE: -e omitted intentionally — grep returns 1 on no-match which would
# abort the script. All error paths are guarded explicitly with || or if/fi.
set -uo pipefail

RED='\033[0;31m'; NC='\033[0m'

# Only scan files that are git-tracked (N1 public)
STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)
[[ -z "$STAGED" ]] && exit 0

BLOCKED=0
FINDINGS=""

while IFS= read -r file; do
  [[ ! -f "$file" ]] && continue

  # Skip private paths (N2-N4)
  case "$file" in
    projects/*|output/*|*.local.*|config.local/*|private-agent-memory/*) continue ;;
  esac

  # Skip binary files (portable: use git diff numstat, binary shows as -)
  git diff --cached --numstat -- "$file" 2>/dev/null | grep -q "^-" && continue

  # High-confidence credential patterns — FULL file scan
  HIT=""
  if grep -qiE "(jdbc:|mongodb[+]srv://|Server=.*Password=)" "$file" 2>/dev/null; then
    HIT="connection_string"
  elif grep -qE "AKIA[0-9A-Z]{16}" "$file" 2>/dev/null; then
    HIT="aws_key"
  elif grep -qE "(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82,})" "$file" 2>/dev/null; then
    HIT="github_token"
  elif grep -qE "sk-(proj-)?[A-Za-z0-9]{32,}" "$file" 2>/dev/null; then
    HIT="openai_key"
  elif grep -qiE "sv=20[0-9]{2}-" "$file" 2>/dev/null; then
    HIT="azure_sas"
  elif grep -qE "AIza[0-9A-Za-z_-]{35}" "$file" 2>/dev/null; then
    HIT="google_api_key"
  elif grep -qiE -- "-----BEGIN.*PRIVATE KEY-----" "$file" 2>/dev/null; then
    HIT="private_key"
  elif grep -qE "(192[.]168[.][0-9]+[.][0-9]+|10[.][0-9]+[.][0-9]+[.][0-9]+|172[.](1[6-9]|2[0-9]|3[01])[.][0-9]+[.][0-9]+)" "$file" 2>/dev/null; then
    # Exclude RFC 5737 documentation IPs (used by Savia Shield masking)
    if ! grep -qE "(192[.]0[.]2[.]|198[.]51[.]100[.]|203[.]0[.]113[.])" "$file" 2>/dev/null; then
      HIT="internal_ip"
    fi
  fi

  # Base64 encoded secrets
  if [[ -z "$HIT" ]]; then
    B64=$(grep -oE '[A-Za-z0-9+/]{40,200}={0,2}' "$file" 2>/dev/null | head -20)
    if [[ -n "$B64" ]]; then
      DECODED=$(echo "$B64" | while IFS= read -r b; do echo "$b" | base64 -d 2>/dev/null; done)
      if echo "$DECODED" | grep -qiE "(jdbc:|Server=.*Password=|AKIA|ghp_|sk-)" 2>/dev/null; then
        HIT="base64_encoded_secret"
      fi
    fi
  fi

  if [[ -n "$HIT" ]]; then
    BLOCKED=$((BLOCKED + 1))
    FINDINGS+="  $file ($HIT)\n"
  fi
done <<< "$STAGED"

if [[ $BLOCKED -gt 0 ]]; then
  echo -e "${RED}SAVIA SHIELD: $BLOCKED file(s) contain sensitive data${NC}" >&2
  echo -e "$FINDINGS" >&2
  echo "Move sensitive data to projects/, config.local/ or .local files." >&2
  echo "To inspect: grep -rn 'pattern' <file>" >&2
  exit 1
fi

exit 0
