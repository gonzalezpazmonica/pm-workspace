#!/usr/bin/env bash
# ── test-stress-security.sh — Security pattern coverage (SEC-1 to SEC-9) ──
set -euo pipefail
PASS=0; FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

ok()   { PASS=$((PASS+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

echo "═══════════════════════════════════════════════════════════"
echo "  STRESS TEST: Security Patterns (SEC-1 through SEC-9)"
echo "═══════════════════════════════════════════════════════════"

RULES="$REPO_ROOT/docs/rules/domain/security-check-patterns.md"
CONF="$REPO_ROOT/docs/rules/domain/confidentiality-config.md"

# ── SEC-1: Credential patterns ─────────────────────────────
echo ""
echo "1️⃣  SEC-1 — Credentials and secrets"

# Each pattern must be documented in security-check-patterns.md
grep -q 'AKIA\[0-9A-Z\]' "$RULES" && ok "SEC-1: AWS AKIA pattern documented" || fail "SEC-1: AWS AKIA missing"
grep -q 'sv=20' "$RULES" && ok "SEC-1: Azure SAS pattern documented" || fail "SEC-1: Azure SAS missing"
grep -q 'AIza' "$RULES" && ok "SEC-1: Google API key pattern documented" || fail "SEC-1: Google key missing"
grep -q 'ghp_' "$RULES" && ok "SEC-1: GitHub token pattern documented" || fail "SEC-1: GitHub token missing"
grep -q 'BEGIN.*PRIVATE KEY' "$RULES" && ok "SEC-1: Private key pattern documented" || fail "SEC-1: Private key missing"
grep -q 'password' "$RULES" && ok "SEC-1: Password pattern documented" || fail "SEC-1: Password missing"

# Verify hook implements these patterns
HOOK="$REPO_ROOT/.claude/hooks/block-credential-leak.sh"
grep -q 'AKIA' "$HOOK" && ok "SEC-1: AKIA implemented in hook" || fail "SEC-1: AKIA not in hook"
grep -q 'sv=20' "$HOOK" && ok "SEC-1: Azure SAS implemented in hook" || fail "SEC-1: SAS not in hook"
grep -q 'AIza' "$HOOK" && ok "SEC-1: Google key implemented in hook" || fail "SEC-1: Google not in hook"

# ── SEC-2: Private project names ────────────────────────────
echo ""
echo "2️⃣  SEC-2 — Private project names"

grep -q 'SEC-2' "$RULES" && ok "SEC-2: Section exists" || fail "SEC-2: Section missing"
grep -q 'projects/' "$RULES" && ok "SEC-2: Projects path check documented" || fail "SEC-2: No projects path check"

# ── SEC-3: IPs and hostnames ───────────────────────────────
echo ""
echo "3️⃣  SEC-3 — IPs and hostnames"

grep -qF '192\.' "$RULES" && ok "SEC-3: RFC1918 192.168.x.x documented" || fail "SEC-3: Missing 192.168"
grep -qF '10\.' "$RULES" && ok "SEC-3: RFC1918 10.x.x.x documented" || fail "SEC-3: Missing 10.x"
grep -q '\.internal' "$RULES" && ok "SEC-3: .internal hostname documented" || fail "SEC-3: Missing .internal"

# ── SEC-4: Personal data (GDPR) ────────────────────────────
echo ""
echo "4️⃣  SEC-4 — Personal data (GDPR)"

grep -q 'SEC-4' "$RULES" && ok "SEC-4: Section exists" || fail "SEC-4: Section missing"
grep -qF 'example' "$RULES" && ok "SEC-4: Example email exclusion" || fail "SEC-4: No email exclusion"

# ── SEC-5: Private repo URLs ───────────────────────────────
echo ""
echo "5️⃣  SEC-5 — Private repo URLs"

grep -q 'SEC-5' "$RULES" && ok "SEC-5: Section exists" || fail "SEC-5: Section missing"

# ── SEC-6: Staged sensitive files ──────────────────────────
echo ""
echo "6️⃣  SEC-6 — Staged sensitive files"

grep -q '\.env\$' "$RULES" && ok "SEC-6: .env files checked" || fail "SEC-6: No .env check"
grep -q '\.pem' "$RULES" && ok "SEC-6: .pem files checked" || fail "SEC-6: No .pem check"
grep -q '\.pat' "$RULES" && ok "SEC-6: .pat files checked" || fail "SEC-6: No .pat check"

# ── SEC-7: Infrastructure info ─────────────────────────────
echo ""
echo "7️⃣  SEC-7 — Infrastructure connection strings"

grep -q 'jdbc:' "$RULES" && ok "SEC-7: JDBC pattern documented" || fail "SEC-7: No JDBC"
grep -q 'mongodb://' "$RULES" && ok "SEC-7: MongoDB pattern documented" || fail "SEC-7: No MongoDB"
grep -q 'redis://' "$RULES" && ok "SEC-7: Redis pattern documented" || fail "SEC-7: No Redis"

# ── SEC-8: Merge conflict markers ──────────────────────────
echo ""
echo "8️⃣  SEC-8 — Merge conflict markers"

grep -q '<{7}' "$RULES" && ok "SEC-8: <<<<<<< pattern documented" || fail "SEC-8: No <<<<<<< pattern"
grep -q 'orig' "$RULES" && ok "SEC-8: .orig files documented" || fail "SEC-8: No .orig check"

# ── SEC-9: Revealing comments ──────────────────────────────
echo ""
echo "9️⃣  SEC-9 — Revealing comments"

grep -q 'SEC-9' "$RULES" && ok "SEC-9: Section exists" || fail "SEC-9: Section missing"
grep -q 'servidor real' "$RULES" && ok "SEC-9: 'servidor real' pattern" || fail "SEC-9: No 'servidor real'"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Total: $((PASS+FAIL)) | ✅ Passed: $PASS | ❌ Failed: $FAIL"
echo "═══════════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && echo "  🎉 ALL TESTS PASSED" || { echo "  ⚠️  $FAIL TESTS FAILED"; exit 1; }
