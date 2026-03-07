#!/usr/bin/env bash
# security-scan.sh — Security audit for pm-workspace
# Scans for: leaked credentials, hardcoded URLs, insecure patterns, missing security files
#
# Usage: bash scripts/security-scan.sh [--ci | --verbose]
set -uo pipefail

MODE="${1:---summary}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FINDINGS=0
WARNINGS=0

finding() { FINDINGS=$((FINDINGS + 1)); echo "  🔴 FINDING: $1"; }
warning() { WARNINGS=$((WARNINGS + 1)); echo "  🟡 WARNING: $1"; }
pass()    { [ "$MODE" = "--verbose" ] && echo "  ✅ PASS: $1"; true; }

echo "═══════════════════════════════════════════════════"
echo "  🔒 Security Scan — pm-workspace"
echo "═══════════════════════════════════════════════════"
echo ""

# ── 1. Credential patterns ──
echo "--- Scanning for credential patterns ---"

# Real PAT tokens (52+ char base64, not in mock/example context)
if grep -rn --include="*.sh" --include="*.md" --include="*.json" --include="*.yml" \
  -E '[A-Za-z0-9/+]{52,}' "$ROOT" \
  --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir="output" \
  2>/dev/null | grep -v "mock" | grep -v "example" | grep -v "placeholder" | grep -v "CHANGELOG" | grep -v "test-data" | head -3 | grep -q .; then
  warning "Potential base64 token pattern found (may be false positive)"
else
  pass "No PAT-length base64 tokens found"
fi

# Hardcoded passwords
if grep -rn --include="*.sh" --include="*.md" --include="*.json" \
  -E '(password|passwd|pwd)\s*[:=]\s*["\x27][^"\x27]{8,}' "$ROOT" \
  --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir="test-data" --exclude-dir="projects" --exclude-dir="tests" --exclude-dir="rules" \
  2>/dev/null | grep -v "mock" | grep -v "example" | grep -v "placeholder" | grep -v "CHANGELOG" | head -3 | grep -q .; then
  finding "Hardcoded password pattern found"
else
  pass "No hardcoded passwords found"
fi

# AWS keys (exclude test files and EXAMPLE keys)
if grep -rn --include="*.sh" --include="*.md" --include="*.json" \
  -E 'AKIA[0-9A-Z]{16}' "$ROOT" \
  --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir="test-data" --exclude-dir="projects" --exclude-dir="tests" --exclude-dir="rules" \
  2>/dev/null | grep -v "test-" | grep -v "EXAMPLE" | head -1 | grep -q .; then
  finding "AWS access key pattern (AKIA...) found"
else
  pass "No AWS keys found"
fi

# Private keys (exclude test/project/docs directories)
if grep -rn --include="*.sh" --include="*.pem" --include="*.key" \
  -E 'BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY' "$ROOT" \
  --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir="tests" --exclude-dir="projects" --exclude-dir="docs" --exclude-dir="rules" \
  2>/dev/null | grep -v "test-" | head -1 | grep -q .; then
  finding "Private key found in repository"
else
  pass "No private keys found"
fi

echo ""

# ── 2. Hardcoded URLs ──
echo "--- Scanning for hardcoded sensitive URLs ---"

if grep -rn --include="*.sh" --include="*.md" \
  "dev.azure.com" "$ROOT" \
  --exclude-dir=".git" --exclude-dir="node_modules" \
  2>/dev/null | grep -v "TU-ORGANIZACION" | grep -v "YOUR-ORG" | grep -v "miempresa" \
  | grep -v "example" | grep -v "SETUP" | grep -v "README" | grep -v "CHANGELOG" | grep -v "CONTRIBUTING" | head -3 | grep -q .; then
  warning "Real Azure DevOps org URL may be present"
else
  pass "No hardcoded Azure DevOps URLs"
fi

echo ""

# ── 3. Security files ──
echo "--- Checking security infrastructure ---"

[ -f "$ROOT/SECURITY.md" ] && pass "SECURITY.md exists" || finding "Missing SECURITY.md"
[ -f "$ROOT/.claude/hooks/block-credential-leak.sh" ] && pass "Credential leak hook exists" || finding "Missing credential leak hook"
[ -f "$ROOT/.claude/hooks/block-force-push.sh" ] && pass "Force push hook exists" || finding "Missing force push hook"
[ -f "$ROOT/.claude/hooks/block-infra-destructive.sh" ] && pass "Infra destructive hook exists" || finding "Missing infra destructive hook"

echo ""

# ── 4. Hook coverage ──
echo "--- Checking hook test coverage ---"
for h in "$ROOT/.claude/hooks/"*.sh; do
  [ -f "$h" ] || continue
  name=$(basename "$h" .sh)
  if ls "$ROOT"/tests/hooks/test-"$name"*.bats 2>/dev/null | grep -q .; then
    pass "Hook $name has BATS tests"
  else
    warning "Hook $name has no BATS tests"
  fi
done

echo ""

# ── 5. Sensitive file patterns in .gitignore ──
echo "--- Checking .gitignore coverage ---"
if [ -f "$ROOT/.gitignore" ]; then
  for pattern in ".env" "*.pem" "*.key" "credentials" "secrets"; do
    if grep -q "$pattern" "$ROOT/.gitignore" 2>/dev/null; then
      pass ".gitignore covers $pattern"
    else
      warning ".gitignore missing pattern: $pattern"
    fi
  done
else
  finding "No .gitignore file found"
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Results: $FINDINGS findings, $WARNINGS warnings"
echo "═══════════════════════════════════════════════════"

if [ "$MODE" = "--ci" ]; then
  if [ "$FINDINGS" -gt 0 ]; then
    echo "FAIL: $FINDINGS security findings"
    exit 1
  fi
  echo "PASS: No critical security findings"
fi
