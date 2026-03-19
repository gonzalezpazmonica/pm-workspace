#!/usr/bin/env bash
set -uo pipefail

# ── Confidentiality Scanner ──────────────────────────────────────────────────
# Scans git diff for PII: real names, companies, sensitive data.
# Uses blocklist + heuristic proper noun detection.
# Exit 0 = clean, Exit 1 = violations found, Exit 2 = error
#
# Usage:
#   bash scripts/confidentiality-scan.sh              # scan staged changes
#   bash scripts/confidentiality-scan.sh --pr         # scan PR diff vs main
#   bash scripts/confidentiality-scan.sh --full       # scan all tracked files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BLOCKLIST="$ROOT_DIR/scripts/confidentiality-blocklist.txt"
ALLOWLIST="$ROOT_DIR/scripts/confidentiality-allowlist.txt"

FAILS=0
WARNS=0
MODE="${1:---staged}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔒 Confidentiality Scanner"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Get diff content ─────────────────────────────────────────────────────────
# Files to exclude from scanning (the scanner itself, test fixtures, regex docs)
EXCLUDE_FILES="confidentiality-scan.sh|confidentiality-blocklist.txt|confidentiality-allowlist.txt"
EXCLUDE_FILES="$EXCLUDE_FILES|security-check-patterns.md|test-stress-hooks.sh|pentest-lab"
EXCLUDE_FILES="$EXCLUDE_FILES|confidentiality-gate.yml"

get_diff() {
  local raw
  case "$MODE" in
    --staged) raw=$(git diff --cached --diff-filter=ACMR -U0) ;;
    --pr)     raw=$(git diff origin/main...HEAD --diff-filter=ACMR -U0) ;;
    --full)   raw=$(git diff HEAD~1...HEAD --diff-filter=ACMR -U0) ;;
    *)        raw=$(git diff --cached --diff-filter=ACMR -U0) ;;
  esac
  # Filter out excluded files by splitting on diff headers
  echo "$raw" | awk -v exc="$EXCLUDE_FILES" '
    /^diff --git/ { skip=0; if (match($0, exc)) skip=1 }
    !skip { print }
  '
}

# Only scan added lines (^+), skip diff headers (^+++)
ADDED_LINES=$(get_diff | grep "^+" | grep -v "^+++" || true)

if [ -z "$ADDED_LINES" ]; then
  echo "✅ No changes to scan."
  exit 0
fi

LINE_COUNT=$(echo "$ADDED_LINES" | wc -l)
echo "📋 Scanning $LINE_COUNT added lines (mode: $MODE)"
echo ""

# ── Check 1: Blocklist (known PII terms) ────────────────────────────────────
echo "── Check 1: Blocklist scan"
if [ -f "$BLOCKLIST" ]; then
  BLOCK_PATTERNS=$(grep -v "^#" "$BLOCKLIST" | grep -v "^$" | tr '\n' '|' | sed 's/|$//')
  if [ -n "$BLOCK_PATTERNS" ]; then
    MATCHES=$(echo "$ADDED_LINES" | grep -iE "$BLOCK_PATTERNS" || true)
    if [ -n "$MATCHES" ]; then
      echo "::error::BLOCKED: Blocklist terms found in changes"
      echo "$MATCHES" | head -10 | while read -r line; do
        echo "  🔴 $line"
      done
      MATCH_COUNT=$(echo "$MATCHES" | wc -l)
      if [ "$MATCH_COUNT" -gt 10 ]; then
        echo "  ... and $((MATCH_COUNT - 10)) more"
      fi
      FAILS=$((FAILS + 1))
    else
      echo "  ✅ No blocklist terms found"
    fi
  fi
else
  echo "  ⚠️  No blocklist file found at $BLOCKLIST"
fi

# ── Check 2: Credential patterns ────────────────────────────────────────────
echo "── Check 2: Credential patterns"
CRED_MATCHES=$(echo "$ADDED_LINES" | grep -iE \
  "(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_|AIza[0-9A-Za-z_-]{35}|-----BEGIN.*(PRIVATE|RSA).*KEY)" \
  | grep -v "regex\|pattern\|detect\|example\|test.*hook\|pentest" || true)
if [ -n "$CRED_MATCHES" ]; then
  echo "::error::BLOCKED: Potential credentials detected"
  echo "$CRED_MATCHES" | head -5 | while read -r line; do echo "  🔴 $line"; done
  FAILS=$((FAILS + 1))
else
  echo "  ✅ No credentials detected"
fi

# ── Check 3: Real emails ────────────────────────────────────────────────────
echo "── Check 3: Real email addresses"
EMAIL_MATCHES=$(echo "$ADDED_LINES" | grep -oiE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" \
  | grep -v "@example\.\|@test\.\|@contoso\.\|@miorganizacion\.\|@anthropic\.\|@github\.\|@savia\.dev\|@empresa\.\|@cliente\." \
  | sort -u || true)
if [ -n "$EMAIL_MATCHES" ]; then
  echo "::error::BLOCKED: Real email addresses found"
  echo "$EMAIL_MATCHES" | while read -r email; do echo "  🔴 $email"; done
  FAILS=$((FAILS + 1))
else
  echo "  ✅ No real emails detected"
fi

# ── Check 4: Forbidden files ────────────────────────────────────────────────
echo "── Check 4: Forbidden file types"
CHANGED_FILES=$(get_diff | grep "^diff --git" | sed 's|.*b/||' || true)
FORBIDDEN=$(echo "$CHANGED_FILES" | grep -iE "\.(env|pat|secret|pem|p12|pfx|key)$|id_rsa|id_ed25519" || true)
if [ -n "$FORBIDDEN" ]; then
  echo "::error::BLOCKED: Forbidden file types in changes"
  echo "$FORBIDDEN" | while read -r f; do echo "  🔴 $f"; done
  FAILS=$((FAILS + 1))
else
  echo "  ✅ No forbidden files"
fi

# ── Check 5: Merge conflict markers ─────────────────────────────────────────
echo "── Check 5: Merge conflict markers"
CONFLICT=$(echo "$ADDED_LINES" | grep -E "^(\+<{7}|\+>{7}|\+={7})" || true)
if [ -n "$CONFLICT" ]; then
  echo "::error::BLOCKED: Merge conflict markers found"
  FAILS=$((FAILS + 1))
else
  echo "  ✅ No conflict markers"
fi

# ── Check 6: Proper noun heuristic (2+ capitalized words) ───────────────────
echo "── Check 6: Proper noun heuristic"
# Extract sequences of 2+ capitalized words that could be real names
# Exclude: common tech terms, file paths, markdown headers, code
NOUN_CANDIDATES=$(echo "$ADDED_LINES" \
  | grep -v "^+#\|^+//\|^+\*\|import \|class \|interface \|enum " \
  | grep -oE "\b[A-Z][a-z]+\s+[A-Z][a-z]+(\s+[A-Z][a-z]+)?" \
  | sort -u || true)

if [ -n "$NOUN_CANDIDATES" ] && [ -f "$ALLOWLIST" ]; then
  ALLOW_PATTERNS=$(grep -v "^#" "$ALLOWLIST" | grep -v "^$" | tr '\n' '|' | sed 's/|$//')
  FLAGGED=$(echo "$NOUN_CANDIDATES" | grep -vE "$ALLOW_PATTERNS" || true)
  if [ -n "$FLAGGED" ]; then
    echo "  ⚠️  Potential proper nouns not in allowlist (verify manually):"
    echo "$FLAGGED" | while read -r noun; do echo "    🟡 $noun"; done
    WARNS=$((WARNS + 1))
  else
    echo "  ✅ All proper nouns are in allowlist"
  fi
elif [ -n "$NOUN_CANDIDATES" ]; then
  echo "  ⚠️  Proper nouns detected (no allowlist to validate against):"
  echo "$NOUN_CANDIDATES" | head -10 | while read -r noun; do echo "    🟡 $noun"; done
  WARNS=$((WARNS + 1))
else
  echo "  ✅ No suspicious proper nouns"
fi

# ── Check 7: Private IPs ────────────────────────────────────────────────────
echo "── Check 7: Private IP addresses"
IP_MATCHES=$(echo "$ADDED_LINES" \
  | grep -oE "(192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+)" \
  | grep -v "YOUR_PC_IP\|placeholder\|example" \
  | sort -u || true)
if [ -n "$IP_MATCHES" ]; then
  echo "  ⚠️  Private IPs found (should be placeholders):"
  echo "$IP_MATCHES" | while read -r ip; do echo "    🟡 $ip"; done
  WARNS=$((WARNS + 1))
else
  echo "  ✅ No private IPs"
fi

# ── Results ──────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILS -gt 0 ]; then
  echo "🔴 BLOCKED — $FAILS violation(s), $WARNS warning(s)"
  echo "   Fix blockers before merging."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 1
elif [ $WARNS -gt 0 ]; then
  echo "🟡 PASSED with $WARNS warning(s)"
  echo "   Review warnings — may contain false positives."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
else
  echo "✅ CLEAN — no violations, no warnings"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
fi
