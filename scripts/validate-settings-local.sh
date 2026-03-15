#!/usr/bin/env bash
# validate-settings-local.sh — Detect private/session data in settings.local.json
# Prevents accidental push of machine-specific paths, URLs or credentials.
# Exit 0 = clean, Exit 1 = private data detected.
set -euo pipefail

FILE=".claude/settings.local.json"

if [ ! -f "$FILE" ]; then
  echo "✅ $FILE not found — nothing to validate"
  exit 0
fi

ERRORS=0

check() {
  local label="$1" pattern="$2"
  if grep -qE "$pattern" "$FILE"; then
    echo "❌ $label"
    grep -nE "$pattern" "$FILE" | head -5 | sed 's/^/   /'
    ERRORS=$((ERRORS + 1))
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Validating $FILE for private data"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Hardcoded localhost URLs with ports (session-specific test commands)
check "Hardcoded localhost URL (use generic wildcard instead)" \
  'localhost:[0-9]+'

# 2. Hardcoded IP addresses
check "Hardcoded IP address" \
  '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+'

# 3. Absolute paths to home directories
check "Absolute home path (use \$HOME or relative)" \
  '/home/[a-zA-Z0-9_]+/'

# 4. Hardcoded usernames in paths
check "Username in path" \
  '/Users/[a-zA-Z0-9_]+/'

# 5. Inline credentials or tokens
check "Inline credential/token value" \
  '(password|token|secret|key|pat)\s*[:=]\s*"[^$][^"]{4,}'

# 6. Specific E2E commands with hardcoded env vars
check "E2E command with hardcoded URL (use npx playwright:* wildcard)" \
  'E2E_BRIDGE_URL=|BASE_URL="http'

# 7. Piped commands (session-specific, not reusable)
check "Complex piped command (use simple wildcard instead)" \
  'Bash\([^)]*\|[^)]*\|'

# 8. Git push/add already covered by Bash(git:*)
if grep -qE '"Bash\(git push:' "$FILE" && grep -qE '"Bash\(git:\*\)"' "$FILE"; then
  echo "⚠️  Redundant: Bash(git push:*) already covered by Bash(git:*)"
fi
if grep -qE '"Bash\(git add:' "$FILE" && grep -qE '"Bash\(git:\*\)"' "$FILE"; then
  echo "⚠️  Redundant: Bash(git add:*) already covered by Bash(git:*)"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$ERRORS" -gt 0 ]; then
  echo "❌ Found $ERRORS issue(s) — clean before committing"
  echo "   Tip: use generic wildcards like Bash(npx playwright:*)"
  exit 1
else
  echo "✅ $FILE is clean — no private data detected"
  exit 0
fi
