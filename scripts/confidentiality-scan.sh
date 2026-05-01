#!/usr/bin/env bash
set -uo pipefail
# confidentiality-scan.sh — Scan for PII, credentials, real project names.
# Exit 0 = clean, Exit 1 = violations, Exit 2 = error
# Usage: [--staged|--pr|--full-repo] [--blocklist <file>]
#   --staged:    scan staged changes only (pre-commit)
#   --pr:        scan PR diff vs origin/main
#   --full-repo: scan ALL tracked file contents (periodic audit)
#   --blocklist: path to dynamically generated blocklist

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ALLOWLIST="$ROOT_DIR/scripts/confidentiality-allowlist.txt"
FAILS=0; WARNS=0; MODE="--staged"; DYN_BLOCKLIST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged|--pr|--full-repo) MODE="$1"; shift ;;
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
EXCLUDE_FILES="$EXCLUDE_FILES|generate-blocklist.sh|confidentiality-sign.sh"
EXCLUDE_FILES="$EXCLUDE_FILES|confidentiality-auditor.md|pii-sanitization.md"
EXCLUDE_FILES="$EXCLUDE_FILES|tests/|test-.*\.sh|community-protocol.md"
EXCLUDE_FILES="$EXCLUDE_FILES|security-guardian.md|block-credential-leak.sh"
EXCLUDE_FILES="$EXCLUDE_FILES|contribute.sh|validate-privacy"
EXCLUDE_FILES="$EXCLUDE_FILES|credential-scan.md|agent-hook-premerge.sh"
EXCLUDE_FILES="$EXCLUDE_FILES|messaging-subject-safety.md|confidentiality-strategies.md"
EXCLUDE_FILES="$EXCLUDE_FILES|pentesting/|checklists.md"
EXCLUDE_FILES="$EXCLUDE_FILES|credential-proxy.sh|managed-agents-patterns.md"
EXCLUDE_FILES="$EXCLUDE_FILES|session-event-log.sh"
# OpenCode TS hook ports (same self-referential exclusion as block-credential-leak.sh)
EXCLUDE_FILES="$EXCLUDE_FILES|\.opencode/plugins/.*\.test\.ts$"
EXCLUDE_FILES="$EXCLUDE_FILES|\.opencode/plugins/lib/credential-patterns\.ts$"
EXCLUDE_FILES="$EXCLUDE_FILES|\.opencode/plugins/lib/injection-patterns\.ts$"
EXCLUDE_FILES="$EXCLUDE_FILES|\.opencode/plugins/lib/leakage-patterns\.ts$"
EXCLUDE_FILES="$EXCLUDE_FILES|\.opencode/plugins/block-credential-leak\.ts$"
EXCLUDE_FILES="$EXCLUDE_FILES|\.opencode/plugins/block-gitignored-references\.ts$"
EXCLUDE_FILES="$EXCLUDE_FILES|\.opencode/plugins/prompt-injection-guard\.ts$"
EXCLUDE_FILES="$EXCLUDE_FILES|\.opencode/plugins/validate-bash-global\.ts$"

get_lines() {
  cd "$ROOT_DIR" || exit 2
  case "$MODE" in
    --staged)
      git diff --cached --diff-filter=ACMR -U0 \
        | awk -v exc="$EXCLUDE_FILES" '/^diff --git/{skip=0; if(match($0,exc)) skip=1} !skip{print}' \
        | grep "^+" | grep -v "^+++"
      ;;
    --pr)
      git diff origin/main...HEAD --diff-filter=ACMR -U0 \
        | awk -v exc="$EXCLUDE_FILES" '/^diff --git/{skip=0; if(match($0,exc)) skip=1} !skip{print}' \
        | grep "^+" | grep -v "^+++"
      ;;
    --full-repo)
      # Scan ALL content of ALL tracked files (excluding self-referencing ones)
      git ls-files \
        | grep -vE "$EXCLUDE_FILES" \
        | while IFS= read -r f; do
            [ -f "$f" ] && sed "s/^/+/" "$f"
          done
      ;;
  esac
}

ADDED_LINES=$(get_lines 2>/dev/null || true)
if [ -z "$ADDED_LINES" ]; then echo "No content to scan."; exit 0; fi
LINE_COUNT=$(echo "$ADDED_LINES" | wc -l)
echo "Scanning $LINE_COUNT lines (mode: $MODE)"

# ── Check 1: Blocklist (dynamic or fallback to static) ─────────────────────
echo "-- Check 1: Blocklist"
if [ -z "$DYN_BLOCKLIST" ]; then
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
    MATCH_COUNT=$(echo "$MATCHES" | wc -l)
    echo "::error::BLOCKED: Blocklist terms found ($MATCH_COUNT lines)"
    echo "$MATCHES" | head -15 | while read -r l; do echo "  FAIL $l"; done
    [ "$MATCH_COUNT" -gt 15 ] && echo "  ... and $((MATCH_COUNT - 15)) more"
    FAILS=$((FAILS + 1))
  else echo "  OK"; fi
else echo "  WARN: No blocklist patterns (generate-blocklist.sh missing?)"; fi

# ── Check 2: Credentials ──────────────────────────────────────────────────
echo "-- Check 2: Credentials"
CRED=$(echo "$ADDED_LINES" | grep -iE \
  "(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_|AIza[0-9A-Za-z_-]{35}|-----BEGIN.*(PRIVATE|RSA).*KEY)" \
  | grep -v "regex\|pattern\|detect\|example\|pentest\|grep\|SECRETS_PATTERN" \
  | grep -v "VALIDATE\|validate\|PRIVATE_KEY:" \
  | grep -v "BEGIN.*KEY-----$\|'.*KEY.*'\|\".*KEY.*\"" \
  | grep -v "\\\\|sed\|awk\|echo.*test\|-E '" || true)
if [ -n "$CRED" ]; then
  echo "::error::BLOCKED: Credentials detected"
  echo "$CRED" | head -5 | while read -r l; do echo "  FAIL $l"; done
  FAILS=$((FAILS + 1))
else echo "  OK"; fi

# ── Check 3: Real emails ──────────────────────────────────────────────────
echo "-- Check 3: Emails"
EMAILS=$(echo "$ADDED_LINES" | grep -oiE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" \
  | grep -v "@example\.\|@test\.\|@contoso\.\|@miorganizacion\.\|@anthropic\.\|@github\.\|@savia\.dev\|@empresa\.\|@cliente\." \
  | grep -v "@domain\.\|@org\.\|@co\.\|@company\.\|@cliente-alpha\.\|@cliente-beta\.\|@acme\." \
  | grep -vE "^@[a-z]+\.[a-z]+$" \
  | grep -vE "@kotlinx\.|@orders\.|@router\.|@app\.|@pytest\.|@override" \
  | sort -u || true)
if [ -n "$EMAILS" ]; then
  echo "::error::BLOCKED: Real emails found"
  echo "$EMAILS" | while read -r e; do echo "  FAIL $e"; done
  FAILS=$((FAILS + 1))
else echo "  OK"; fi

# ── Check 4: Forbidden files (skip for full-repo — files already committed) ─
if [ "$MODE" != "--full-repo" ]; then
  echo "-- Check 4: Forbidden files"
  CHANGED=$(get_lines 2>/dev/null | grep "^diff --git" | sed 's|.*b/||' || true)
  FORBID=$(echo "$CHANGED" | grep -iE "\.(env|pat|secret|pem|p12|pfx|key)$|id_rsa|id_ed25519" || true)
  if [ -n "$FORBID" ]; then
    echo "::error::BLOCKED: Forbidden file types"
    echo "$FORBID" | while read -r f; do echo "  FAIL $f"; done
    FAILS=$((FAILS + 1))
  else echo "  OK"; fi
else
  echo "-- Check 4: Forbidden files (skipped in full-repo mode)"
fi

# ── Check 5: Merge conflict markers ───────────────────────────────────────
echo "-- Check 5: Conflict markers"
if echo "$ADDED_LINES" | grep -qE "^\+<{7}|^\+>{7}|^\+={7}"; then
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
    NOUN_COUNT=$(echo "$FLAGGED" | wc -l)
    echo "  WARN: $NOUN_COUNT proper nouns not in allowlist (top 10):"
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
  echo "$PROJS" | head -10 | while read -r p; do echo "    ? $p"; done
  WARNS=$((WARNS + 1))
else echo "  OK"; fi

# ── Results ────────────────────────────────────────────────────────────────
echo ""; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILS -gt 0 ]; then echo "BLOCKED — $FAILS violation(s), $WARNS warning(s)"; exit 1
elif [ $WARNS -gt 0 ]; then echo "PASSED with $WARNS warning(s)"; exit 0
else echo "CLEAN — no violations"; exit 0; fi
