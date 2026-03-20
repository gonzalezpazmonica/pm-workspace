#!/usr/bin/env bash
set -uo pipefail
# confidentiality-scan.sh — Scan git diff for PII, credentials, real project names.
# Exit 0 = clean, Exit 1 = violations, Exit 2 = error
# Usage: [--staged|--pr|--full] [--blocklist <file>]
#   --blocklist: path to dynamically generated blocklist (from generate-blocklist.sh)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ALLOWLIST="$ROOT_DIR/scripts/confidentiality-allowlist.txt"
FAILS=0; WARNS=0; MODE="--staged"; DYN_BLOCKLIST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged|--pr|--full) MODE="$1"; shift ;;
    --blocklist) DYN_BLOCKLIST="$2"; shift 2 ;;
    *) shift ;;
  esac
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Confidentiality Scanner"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

EXCLUDE_FILES="confidentiality-scan.sh|confidentiality-check.sh|confidentiality-blocklist"
EXCLUDE_FILES="$EXCLUDE_FILES|security-check-patterns.md|test-stress-hooks.sh|pentest-lab"
EXCLUDE_FILES="$EXCLUDE_FILES|confidentiality-gate.yml|confidentiality-allowlist.txt"

get_diff() {
  local raw
  case "$MODE" in
    --staged) raw=$(git diff --cached --diff-filter=ACMR -U0) ;;
    --pr)     raw=$(git diff origin/main...HEAD --diff-filter=ACMR -U0) ;;
    --full)   raw=$(git diff HEAD~1...HEAD --diff-filter=ACMR -U0) ;;
    *)        raw=$(git diff --cached --diff-filter=ACMR -U0) ;;
  esac
  echo "$raw" | awk -v exc="$EXCLUDE_FILES" '
    /^diff --git/ { skip=0; if (match($0, exc)) skip=1 }
    !skip { print }
  '
}

ADDED_LINES=$(get_diff | grep "^+" | grep -v "^+++" || true)
if [ -z "$ADDED_LINES" ]; then echo "No changes to scan."; exit 0; fi
LINE_COUNT=$(echo "$ADDED_LINES" | wc -l)
echo "Scanning $LINE_COUNT added lines (mode: $MODE)"

# ── Check 1: Blocklist (dynamic or fallback to static) ─────────────────────
echo "-- Check 1: Blocklist"
if [ -z "$DYN_BLOCKLIST" ]; then
  # Auto-generate if not provided and generator exists
  GEN="$SCRIPT_DIR/generate-blocklist.sh"
  if [ -f "$GEN" ]; then
    DYN_BLOCKLIST=$(mktemp)
    bash "$GEN" > "$DYN_BLOCKLIST" 2>/dev/null
    trap "rm -f '$DYN_BLOCKLIST'" EXIT
    echo "  (auto-generated $(wc -l < "$DYN_BLOCKLIST") patterns from workspace)"
  fi
fi
ALL_PATTERNS=""
if [ -n "$DYN_BLOCKLIST" ] && [ -f "$DYN_BLOCKLIST" ]; then
  ALL_PATTERNS=$(grep -v "^#" "$DYN_BLOCKLIST" | grep -v "^$" | tr '\n' '|' | sed 's/|$//')
fi
if [ -n "$ALL_PATTERNS" ]; then
  MATCHES=$(echo "$ADDED_LINES" | grep -iE "$ALL_PATTERNS" || true)
  if [ -n "$MATCHES" ]; then
    echo "::error::BLOCKED: Blocklist terms found"
    echo "$MATCHES" | head -10 | while read -r l; do echo "  FAIL $l"; done
    FAILS=$((FAILS + 1))
  else echo "  OK"; fi
else echo "  WARN: No blocklist patterns (generate-blocklist.sh missing?)"; fi

# ── Check 2: Credentials ──────────────────────────────────────────────────
echo "-- Check 2: Credentials"
CRED=$(echo "$ADDED_LINES" | grep -iE \
  "(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_|AIza[0-9A-Za-z_-]{35}|-----BEGIN.*(PRIVATE|RSA).*KEY)" \
  | grep -v "regex\|pattern\|detect\|example\|test.*hook\|pentest" || true)
if [ -n "$CRED" ]; then
  echo "::error::BLOCKED: Credentials detected"
  echo "$CRED" | head -5 | while read -r l; do echo "  FAIL $l"; done
  FAILS=$((FAILS + 1))
else echo "  OK"; fi

# ── Check 3: Real emails ──────────────────────────────────────────────────
echo "-- Check 3: Emails"
EMAILS=$(echo "$ADDED_LINES" | grep -oiE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" \
  | grep -v "@example\.\|@test\.\|@contoso\.\|@miorganizacion\.\|@anthropic\.\|@github\.\|@savia\.dev\|@empresa\.\|@cliente\." \
  | sort -u || true)
if [ -n "$EMAILS" ]; then
  echo "::error::BLOCKED: Real emails found"
  echo "$EMAILS" | while read -r e; do echo "  FAIL $e"; done
  FAILS=$((FAILS + 1))
else echo "  OK"; fi

# ── Check 4: Forbidden files ──────────────────────────────────────────────
echo "-- Check 4: Forbidden files"
CHANGED=$(get_diff | grep "^diff --git" | sed 's|.*b/||' || true)
FORBID=$(echo "$CHANGED" | grep -iE "\.(env|pat|secret|pem|p12|pfx|key)$|id_rsa|id_ed25519" || true)
if [ -n "$FORBID" ]; then
  echo "::error::BLOCKED: Forbidden file types"
  echo "$FORBID" | while read -r f; do echo "  FAIL $f"; done
  FAILS=$((FAILS + 1))
else echo "  OK"; fi

# ── Check 5: Merge conflict markers ───────────────────────────────────────
echo "-- Check 5: Conflict markers"
if echo "$ADDED_LINES" | grep -qE "^(\+<{7}|\+>{7}|\+={7})"; then
  echo "::error::BLOCKED: Merge conflict markers"; FAILS=$((FAILS + 1))
else echo "  OK"; fi

# ── Check 6: Proper noun heuristic ────────────────────────────────────────
echo "-- Check 6: Proper nouns"
NOUNS=$(echo "$ADDED_LINES" | grep -v "^+#\|^+//\|^+\*\|import \|class " \
  | grep -oE "\b[A-Z][a-z]+\s+[A-Z][a-z]+(\s+[A-Z][a-z]+)?" | sort -u || true)
if [ -n "$NOUNS" ]; then
  ALLOW=""; [ -f "$ALLOWLIST" ] && ALLOW=$(grep -v "^#" "$ALLOWLIST" | grep -v "^$" | tr '\n' '|' | sed 's/|$//')
  FLAGGED="$NOUNS"; [ -n "$ALLOW" ] && FLAGGED=$(echo "$NOUNS" | grep -vE "$ALLOW" || true)
  if [ -n "$FLAGGED" ]; then
    echo "  WARN: Proper nouns not in allowlist:"
    echo "$FLAGGED" | head -10 | while read -r n; do echo "    ? $n"; done
    WARNS=$((WARNS + 1))
  else echo "  OK"; fi
else echo "  OK"; fi

# ── Check 7: Private IPs ──────────────────────────────────────────────────
echo "-- Check 7: Private IPs"
IPS=$(echo "$ADDED_LINES" | grep -oE "(192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+)" | sort -u || true)
if [ -n "$IPS" ]; then
  echo "  WARN: Private IPs:"; echo "$IPS" | while read -r i; do echo "    ? $i"; done
  WARNS=$((WARNS + 1))
else echo "  OK"; fi

# ── Check 8: Real project paths ───────────────────────────────────────────
echo "-- Check 8: Project paths"
GENERIC="proyecto-alpha|proyecto-beta|sala-reservas|example|test|demo|sample|template"
PROJS=$(echo "$ADDED_LINES" | grep -oiE "projects/[a-z][a-z0-9_-]+" \
  | grep -v "projects/\*\|projects/{" | grep -viE "$GENERIC" | sort -u || true)
if [ -n "$PROJS" ]; then
  echo "  WARN: Non-generic project paths:"
  echo "$PROJS" | while read -r p; do echo "    ? $p"; done
  WARNS=$((WARNS + 1))
else echo "  OK"; fi

# ── Results ────────────────────────────────────────────────────────────────
echo ""; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILS -gt 0 ]; then echo "BLOCKED — $FAILS violation(s), $WARNS warning(s)"; exit 1
elif [ $WARNS -gt 0 ]; then echo "PASSED with $WARNS warning(s)"; exit 0
else echo "CLEAN — no violations"; exit 0; fi
