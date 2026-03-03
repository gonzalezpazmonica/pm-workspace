#!/usr/bin/env bash
# ── test-era18-commands.sh — Era 18 command structure validation ──
set -euo pipefail
PASS=0; FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMD_DIR="$REPO_ROOT/.claude/commands"
RULES_DIR="$REPO_ROOT/.claude/rules/domain"

ok()   { PASS=$((PASS+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { [ -f "$1" ] && ok "$2 exists" || fail "$2 missing"; }
has()  { grep -qi "$3" "$1" 2>/dev/null && ok "$2: has $3" || fail "$2: missing $3"; }
lines_ok() {
  local f="$1" label="$2" max="${3:-150}"
  local c; c=$(wc -l < "$f")
  [ "$c" -le "$max" ] && ok "$label: $c lines (≤$max)" || fail "$label: $c lines (>$max)"
}

echo "═══════════════════════════════════════════════════════════"
echo "  TEST: Era 18 — Command Structure Validation"
echo "═══════════════════════════════════════════════════════════"

# ── /aepd-compliance ────────────────────────────────────────
echo ""
echo "1️⃣  /aepd-compliance"

AEPD_CMD="$CMD_DIR/aepd-compliance.md"
check "$AEPD_CMD" "aepd-compliance.md"
lines_ok "$AEPD_CMD" "aepd-compliance" 150
has "$AEPD_CMD" "aepd-compliance" "aepd"
has "$AEPD_CMD" "aepd-compliance" "compliance"
has "$AEPD_CMD" "aepd-compliance" "governance"

# ── /excel-report ───────────────────────────────────────────
echo ""
echo "2️⃣  /excel-report"

EXCEL_CMD="$CMD_DIR/excel-report.md"
check "$EXCEL_CMD" "excel-report.md"
lines_ok "$EXCEL_CMD" "excel-report" 150
has "$EXCEL_CMD" "excel-report" "csv"

# ── /savia-gallery ──────────────────────────────────────────
echo ""
echo "3️⃣  /savia-gallery"

GALLERY_CMD="$CMD_DIR/savia-gallery.md"
check "$GALLERY_CMD" "savia-gallery.md"
lines_ok "$GALLERY_CMD" "savia-gallery" 150
has "$GALLERY_CMD" "savia-gallery" "command"

# ── /adoption-assess ────────────────────────────────────────
echo ""
echo "4️⃣  /adoption-assess"

ADOPT_CMD="$CMD_DIR/adoption-assess.md"
check "$ADOPT_CMD" "adoption-assess.md"
lines_ok "$ADOPT_CMD" "adoption-assess" 150
has "$ADOPT_CMD" "adoption-assess" "adoption"

# ── Frontmatter validation (all Era 18 commands) ───────────
echo ""
echo "5️⃣  Frontmatter validation"

ERA18_CMDS=("aepd-compliance.md" "excel-report.md" "savia-gallery.md" "adoption-assess.md")
for cmd_name in "${ERA18_CMDS[@]}"; do
  cmd_file="$CMD_DIR/$cmd_name"
  [ -f "$cmd_file" ] || continue
  if head -1 "$cmd_file" | grep -q "^---$"; then
    grep -q "^name:" "$cmd_file" && ok "$cmd_name: has 'name' field" || fail "$cmd_name: missing 'name'"
    grep -q "^description:" "$cmd_file" && ok "$cmd_name: has 'description' field" || fail "$cmd_name: missing 'description'"
  else
    ok "$cmd_name: legacy format (no frontmatter required)"
  fi
done

# ── Era 18 rules exist and are valid ───────────────────────
echo ""
echo "6️⃣  Era 18 rules file check"

ERA18_RULES=(
  "ai-competency-framework.md"
  "aepd-framework.md"
  "intelligent-hooks.md"
  "source-tracking.md"
  "skillssh-publishing.md"
)
for rule in "${ERA18_RULES[@]}"; do
  rule_file="$RULES_DIR/$rule"
  check "$rule_file" "$rule"
  [ -f "$rule_file" ] && lines_ok "$rule_file" "$rule" 150
done

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Total: $((PASS+FAIL)) | ✅ Passed: $PASS | ❌ Failed: $FAIL"
echo "═══════════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && echo "  🎉 ALL TESTS PASSED" || { echo "  ⚠️  $FAIL TESTS FAILED"; exit 1; }
