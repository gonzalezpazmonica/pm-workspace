#!/usr/bin/env bash
# vuln-scan.sh — Vulnerability scanner for pm-workspace scripts
# Detects common security anti-patterns in bash scripts, hooks, and configs.
#
# Usage: bash scripts/vuln-scan.sh [--ci | --verbose | --explain]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE="${1:---summary}"
VULNS=0
WARNINGS=0

vuln()    { VULNS=$((VULNS + 1)); echo "  🔴 VULN: $1"; }
warn()    { WARNINGS=$((WARNINGS + 1)); echo "  🟡 WARN: $1"; }
pass()    { [ "$MODE" = "--verbose" ] && echo "  ✅ PASS: $1"; true; }
explain() { [ "$MODE" = "--explain" ] && echo "      ℹ️  $1"; true; }

echo "═══════════════════════════════════════════════════"
echo "  🛡️  Vulnerability Scanner — pm-workspace"
echo "═══════════════════════════════════════════════════"
echo ""

# ── 1. Unquoted variable expansion in scripts ──
echo "--- Checking for unquoted variable expansion ---"
unquoted=0
for f in "$ROOT/.claude/hooks/"*.sh "$ROOT/scripts/"*.sh; do
  [ -f "$f" ] || continue
  # Look for $VAR in contexts where it should be "$VAR" (excluding comments, assignments)
  if grep -nE '([ =])\$[A-Z_]+[^"'\'')}]' "$f" 2>/dev/null \
     | grep -v "^[0-9]*:#" | grep -v 'PIPESTATUS' | grep -v '\\$' \
     | grep -v '\$\$' | grep -v '\${' | head -1 | grep -q .; then
    unquoted=$((unquoted + 1))
  fi
done
if [ "$unquoted" -gt 5 ]; then
  warn "$unquoted scripts have potentially unquoted variables"
  explain "Unquoted variables can cause word splitting and glob expansion issues"
else
  pass "Minimal unquoted variable issues ($unquoted scripts)"
fi

echo ""

# ── 2. eval usage (only in hooks — scripts/test-* are legacy) ──
echo "--- Checking for eval usage in hooks ---"
if grep -rn "eval " "$ROOT/.claude/hooks/"*.sh 2>/dev/null \
   | grep -v "^[^:]*:#" | head -1 | grep -q .; then
  vuln "eval found in hooks (command injection risk)"
  explain "eval can execute arbitrary code. Use safer alternatives."
else
  pass "No eval usage in hooks"
fi
# Warn about eval in scripts (lower severity)
eval_scripts=$(grep -rl "eval " "$ROOT/scripts/"*.sh 2>/dev/null | grep -v "vuln-scan" | grep -v "^[^:]*:#" | wc -l)
if [ "$eval_scripts" -gt 0 ]; then
  warn "$eval_scripts scripts use eval (review for safety)"
else
  pass "No eval usage in scripts"
fi

echo ""

# ── 3. Temp file security ──
echo "--- Checking temp file handling ---"
insecure_tmp=0
for f in "$ROOT/.claude/hooks/"*.sh "$ROOT/scripts/"*.sh; do
  [ -f "$f" ] || continue
  # Check for /tmp/ usage without mktemp
  if grep -n '/tmp/' "$f" 2>/dev/null | grep -v "mktemp" | grep -v "^[^:]*:#" | head -1 | grep -q .; then
    if ! grep -q "mktemp" "$f" 2>/dev/null; then
      insecure_tmp=$((insecure_tmp + 1))
    fi
  fi
done
if [ "$insecure_tmp" -gt 0 ]; then
  warn "$insecure_tmp scripts use /tmp/ without mktemp"
  explain "Use mktemp for temp files to avoid symlink attacks"
else
  pass "Temp files use mktemp or avoid /tmp"
fi

echo ""

# ── 4. Curl/wget without cert verification ──
echo "--- Checking HTTP client security ---"
if grep -rn "curl.*-k\|curl.*--insecure\|wget.*--no-check-certificate" \
   "$ROOT/.claude/hooks/"*.sh "$ROOT/scripts/"*.sh 2>/dev/null \
   | grep -v "^[^:]*:#" | grep -v "vuln-scan.sh" | head -1 | grep -q .; then
  vuln "Insecure HTTP client usage (cert verification disabled)"
  explain "Never disable TLS cert verification — enables MITM attacks"
else
  pass "No insecure curl/wget flags"
fi

echo ""

# ── 5. Hardcoded paths ──
echo "--- Checking for hardcoded user paths ---"
if grep -rn "/home/[a-z]" "$ROOT/.claude/hooks/"*.sh "$ROOT/scripts/"*.sh 2>/dev/null \
   | grep -v "^[^:]*:#" | grep -v "test-data" | head -1 | grep -q .; then
  warn "Hardcoded user home paths found"
  explain "Use \$HOME or relative paths for portability"
else
  pass "No hardcoded user paths"
fi

echo ""

# ── 6. Permission checks ──
echo "--- Checking script permissions ---"
non_exec=0
for f in "$ROOT/.claude/hooks/"*.sh; do
  [ -f "$f" ] || continue
  if [ ! -x "$f" ]; then
    non_exec=$((non_exec + 1))
  fi
done
if [ "$non_exec" -gt 0 ]; then
  warn "$non_exec hook scripts are not executable"
  explain "Hooks should be chmod +x for direct execution"
else
  pass "All hook scripts are executable"
fi

echo ""

# ── 7. set -u (nounset) in hooks ──
echo "--- Checking strict mode usage ---"
no_strict=0
for f in "$ROOT/.claude/hooks/"*.sh; do
  [ -f "$f" ] || continue
  if ! head -5 "$f" | grep -qE "set.*-[a-z]*u|set.*nounset"; then
    no_strict=$((no_strict + 1))
  fi
done
if [ "$no_strict" -gt 3 ]; then
  warn "$no_strict hooks lack 'set -u' (undefined variable protection)"
  explain "set -u catches typos and missing variables early"
else
  pass "Most hooks use strict mode ($no_strict without)"
fi

echo ""

# ── 8. Input validation in hooks ──
echo "--- Checking hook input validation ---"
no_validation=0
for f in "$ROOT/.claude/hooks/"*.sh; do
  [ -f "$f" ] || continue
  # Hooks should validate stdin JSON — check for jq or json parsing
  if ! grep -q "jq\|JSON\|json" "$f" 2>/dev/null; then
    no_validation=$((no_validation + 1))
  fi
done
if [ "$no_validation" -gt 2 ]; then
  warn "$no_validation hooks don't validate JSON input"
  explain "Hooks receive JSON via stdin — validate with jq before processing"
else
  pass "Most hooks validate JSON input ($no_validation without)"
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Results: $VULNS vulnerabilities, $WARNINGS warnings"
echo "═══════════════════════════════════════════════════"

if [ "$MODE" = "--ci" ]; then
  if [ "$VULNS" -gt 0 ]; then
    echo "FAIL: $VULNS vulnerabilities found"
    exit 1
  fi
  echo "PASS: No vulnerabilities found"
fi
