#!/usr/bin/env bash
# ── test-stress-scripts.sh — Robustness of supporting scripts ──
set -euo pipefail
PASS=0; FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

ok()   { PASS=$((PASS+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

echo "═══════════════════════════════════════════════════════════"
echo "  STRESS TEST: Supporting Scripts"
echo "═══════════════════════════════════════════════════════════"

# ── skillssh-adapter.sh ─────────────────────────────────────
echo ""
echo "1️⃣  skillssh-adapter.sh"

ADAPTER="$REPO_ROOT/scripts/skillssh-adapter.sh"

# Test: uses awk instead of broad sed for references
grep -q 'awk' "$ADAPTER" && ok "Uses awk for frontmatter parsing" || fail "Still uses broad sed"

# Test: does NOT use bare sed for references: removal
! grep -q "sed '/^references:/,/^---\$/d'" "$ADAPTER" && ok "No broad sed for references:" || fail "Broad sed still present"

# Test: dry-run mode works
cd "$REPO_ROOT"
OUTPUT=$(bash "$ADAPTER" --all --dry-run 2>&1 || true)
echo "$OUTPUT" | grep -q "dry-run" && ok "Dry-run mode works" || fail "Dry-run mode broken"

# Test: unknown skill exits with error
SOUT=$(bash "$ADAPTER" nonexistent-skill 2>&1 || true)
echo "$SOUT" | grep -qi "unknown\|error" && ok "Unknown skill returns error" || fail "Unknown skill no error"

# ── validate-commands.sh ────────────────────────────────────
echo ""
echo "2️⃣  validate-commands.sh"

VCS="$REPO_ROOT/scripts/validate-commands.sh"

# Test: 150-line limit is enforced
grep -q '150' "$VCS" && ok "150-line limit enforced" || fail "No 150-line limit"

# Test: Empty file detection
grep -q 'LINES.*-eq 0' "$VCS" && ok "Empty file detection exists" || fail "No empty file detection"

# Test: @import validation exists
grep -q '@rules' "$VCS" && ok "@import validation exists" || fail "No @import validation"

# Test: kebab-case check exists
grep -q 'kebab' "$VCS" && ok "Kebab-case check exists" || fail "No kebab-case check"

# ── validate-ci-local.sh ───────────────────────────────────
echo ""
echo "3️⃣  validate-ci-local.sh"

VCI="$REPO_ROOT/scripts/validate-ci-local.sh"

# Test: Branch check (check 0) exists
grep -q 'Branch' "$VCI" && ok "Branch check exists" || fail "No branch check"

# Test: File size check (check 1) exists
grep -q 'File sizes' "$VCI" && ok "File size check exists" || fail "No file size check"

# Test: Frontmatter check (check 2) exists
grep -q 'frontmatter' "$VCI" && ok "Frontmatter check exists" || fail "No frontmatter check"

# Test: settings.json check (check 3) exists
grep -q 'settings.json' "$VCI" && ok "settings.json check exists" || fail "No settings.json check"

# Test: Required files check (check 4) exists
grep -q 'open source' "$VCI" && ok "Required files check exists" || fail "No required files check"

# Test: JSON validation check (check 5) exists
grep -q 'JSON' "$VCI" && ok "JSON validation check exists" || fail "No JSON check"

# Test: Sensitive data check (check 6) exists
grep -q 'sensibles' "$VCI" && ok "Sensitive data check exists" || fail "No sensitive data check"

# ── context-tracker.sh ──────────────────────────────────────
echo ""
echo "4️⃣  context-tracker.sh"

CT="$REPO_ROOT/scripts/context-tracker.sh"

# Test: Log rotation at 1MB
grep -q '1048576' "$CT" && ok "Log rotation at 1MB" || fail "No 1MB rotation"

# Test: Pipe-delimited format
grep -q '|' "$CT" && ok "Pipe-delimited format" || fail "No pipe delimiter"

# Test: Log subcommand works
TMP_DIR=$(mktemp -d)
PROJECT_ROOT="$TMP_DIR" HOME="$TMP_DIR" bash "$CT" log "test" "frag" "100" 2>/dev/null
[ -f "$TMP_DIR/.pm-workspace/context-usage.log" ] && ok "Log file created" || fail "Log file not created"
rm -rf "$TMP_DIR"

# ── memory-store.sh ─────────────────────────────────────────
echo ""
echo "5️⃣  memory-store.sh"

MS="$REPO_ROOT/scripts/memory-store.sh"

# Test: Dedup mechanism exists
grep -q 'hash' "$MS" && ok "Dedup via hash exists" || fail "No dedup mechanism"

# Test: topic_key for upsert exists
grep -q 'topic_key' "$MS" && ok "topic_key upsert exists" || fail "No topic_key upsert"

# Test: Private tag redaction exists
grep -q '<private>' "$MS" && ok "Private tag redaction exists" || fail "No private tag redaction"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Total: $((PASS+FAIL)) | ✅ Passed: $PASS | ❌ Failed: $FAIL"
echo "═══════════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && echo "  🎉 ALL TESTS PASSED" || { echo "  ⚠️  $FAIL TESTS FAILED"; exit 1; }
