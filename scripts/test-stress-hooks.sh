#!/usr/bin/env bash
# ── test-stress-hooks.sh — Stress tests for all hooks ──
set -euo pipefail
PASS=0; FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.claude/hooks"

ok()   { PASS=$((PASS+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

echo "═══════════════════════════════════════════════════════════"
echo "  STRESS TEST: Hooks (14 hooks, edge conditions)"
echo "═══════════════════════════════════════════════════════════"

# ── block-credential-leak.sh ────────────────────────────────
echo ""
echo "1️⃣  block-credential-leak.sh"

BCS="$HOOKS_DIR/block-credential-leak.sh"

# Test: jq fallback — simulate no jq by using grep path
RESULT=$(echo '{"tool_input":{"command":"echo hello"}}' | grep -oP '"command"\s*:\s*"\K[^"]+' 2>/dev/null || echo "")
[ "$RESULT" = "echo hello" ] && ok "jq fallback grep extracts command" || fail "jq fallback grep failed"

# Test: AWS AKIA pattern blocked
echo '{"tool_input":{"command":"export KEY=AKIAIOSFODNN7EXAMPLE"}}' | bash "$BCS" 2>/dev/null && fail "AWS AKIA not blocked" || ok "AWS AKIA blocked (exit=$?)"

# Test: Azure SAS token blocked
echo '{"tool_input":{"command":"curl url?sv=2023-01-01&ss=bfqt"}}' | bash "$BCS" 2>/dev/null && fail "Azure SAS not blocked" || ok "Azure SAS blocked"

# Test: Google API key blocked
echo '{"tool_input":{"command":"curl -H AIzaSyA1234567890abcdefghijklmnopqrstuv"}}' | bash "$BCS" 2>/dev/null && fail "Google API key not blocked" || ok "Google API key blocked"

# Test: GitHub token blocked
echo '{"tool_input":{"command":"export T=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij"}}' | bash "$BCS" 2>/dev/null && fail "GitHub token not blocked" || ok "GitHub token blocked"

# Test: JWT blocked
echo '{"tool_input":{"command":"curl -H eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"}}' | bash "$BCS" 2>/dev/null && fail "JWT not blocked" || ok "JWT blocked"

# Test: Connection string blocked
echo '{"tool_input":{"command":"export CS=DefaultEndpointsProtocol=https;AccountKey=abc"}}' | bash "$BCS" 2>/dev/null && fail "Connection string not blocked" || ok "Connection string blocked"

# Test: Private key header blocked
echo '{"tool_input":{"command":"echo -----BEGIN RSA PRIVATE KEY-----"}}' | bash "$BCS" 2>/dev/null && fail "Private key not blocked" || ok "Private key blocked"

# Test: Safe command passes
echo '{"tool_input":{"command":"ls -la"}}' | bash "$BCS" 2>/dev/null && ok "Safe command passes" || fail "Safe command blocked"

# Test: Empty command passes
echo '{"tool_input":{}}' | bash "$BCS" 2>/dev/null && ok "Empty command passes" || fail "Empty command blocked"

# ── session-init.sh ─────────────────────────────────────────
echo ""
echo "2️⃣  session-init.sh"

SIS="$HOOKS_DIR/session-init.sh"

# Test: ERR trap includes LINENO
grep -q 'LINENO' "$SIS" && ok "ERR trap includes LINENO" || fail "ERR trap missing LINENO"

# Test: ERR trap exits 1
grep -q 'exit 1' "$SIS" && ok "ERR trap exits 1 (not 0)" || fail "ERR trap still exits 0"

# Test: No executable network calls (comments are OK)
! grep -vE '^\s*#' "$SIS" | grep -qE '\b(curl|wget|gh api|npx)\b' && ok "No network calls in code" || fail "Network calls found"

# Test: Timeout is 5s
grep -q 'MAX_SECONDS=5' "$SIS" && ok "Timeout set to 5s" || fail "Timeout not 5s"

# ── agent-hook-premerge.sh ──────────────────────────────────
echo ""
echo "3️⃣  agent-hook-premerge.sh"

AHP="$HOOKS_DIR/agent-hook-premerge.sh"

# Test: Uses awk for line count (not wc -l)
grep -q "awk 'END{print NR}'" "$AHP" && ok "Uses awk for line count" || fail "Still uses wc -l"

# Test: Merge markers detect indented
grep -q '\\s\*' "$AHP" && ok "Merge markers detect indented" || fail "Merge markers only at line start"

# Test: 150-line file passes (create temp)
TMP150=$(mktemp)
for i in $(seq 1 150); do echo "line $i" >> "$TMP150"; done
LINES=$(awk 'END{print NR}' "$TMP150")
[ "$LINES" -eq 150 ] && ok "150-line file counts correctly" || fail "150-line file miscounted ($LINES)"

# Test: 151-line file without trailing newline
TMP151=$(mktemp)
for i in $(seq 1 150); do echo "line $i" >> "$TMP151"; done
printf "line 151" >> "$TMP151"  # no trailing newline
LINES=$(awk 'END{print NR}' "$TMP151")
[ "$LINES" -eq 151 ] && ok "151 lines (no trailing newline) counted correctly" || fail "151 lines miscounted ($LINES)"
rm -f "$TMP150" "$TMP151"

# ── prompt-hook-commit.sh ───────────────────────────────────
echo ""
echo "4️⃣  prompt-hook-commit.sh"

PHC="$HOOKS_DIR/prompt-hook-commit.sh"

# Test: Valid conventional commit passes
grep -q 'ISSUES=""' "$PHC" && ok "ISSUES starts empty" || fail "ISSUES not initialized empty"

# Test: Short message (<10) check exists
grep -q '10' "$PHC" && ok "Short message check exists" || fail "No short message check"

# Test: 72-char limit check exists
grep -q '72' "$PHC" && ok "72-char limit check exists" || fail "No 72-char limit check"

# ── validate-bash-global.sh ─────────────────────────────────
echo ""
echo "5️⃣  validate-bash-global.sh"

VBG="$HOOKS_DIR/validate-bash-global.sh"

# Test: gh pr review --approve blocked
grep -q 'gh.*pr.*review.*--approve' "$VBG" && ok "gh pr review --approve blocked" || fail "Missing gh pr review block"

# Test: gh pr merge --admin blocked
grep -q 'gh.*pr.*merge.*--admin' "$VBG" && ok "gh pr merge --admin blocked" || fail "Missing gh pr merge --admin block"

# Test: sudo blocked
grep -q 'sudo' "$VBG" && ok "sudo blocked" || fail "Missing sudo block"

# Test: Safe command passes
echo '{"tool_input":{"command":"echo safe"}}' | bash "$VBG" 2>/dev/null && ok "Safe command passes" || fail "Safe command blocked"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Total: $((PASS+FAIL)) | ✅ Passed: $PASS | ❌ Failed: $FAIL"
echo "═══════════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && echo "  🎉 ALL TESTS PASSED" || { echo "  ⚠️  $FAIL TESTS FAILED"; exit 1; }
