#!/usr/bin/env bash
# test-accessibility.sh — Validates accessibility universal feature files
set -euo pipefail

PASS=0; FAIL=0; TOTAL=0
pass() { ((PASS++)); ((TOTAL++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ((TOTAL++)); echo "  ❌ $1"; }
check_exists()  { [[ -f "$1" ]] && pass "Exists: $1" || fail "Missing: $1"; }
check_content() { grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"; }
check_max_lines() {
  local lines
  lines=$(wc -l < "$1")
  (( lines <= $2 )) && pass "$1 ≤ $2 lines ($lines)" || fail "$1 exceeds $2 lines ($lines)"
}

echo "=== Accessibility Universal Tests ==="
echo ""

# --- A1: Profile fragment ---
echo "--- A1: Profile fragment ---"
F=".claude/profiles/users/template/accessibility.md"
check_exists "$F"
check_content "$F" "screen_reader" "Has screen_reader field"
check_content "$F" "guided_work" "Has guided_work field"
check_content "$F" "cognitive_load" "Has cognitive_load field"
check_content "$F" "motor_accommodation" "Has motor_accommodation field"
check_content "$F" "dyslexia_friendly" "Has dyslexia_friendly field"
check_content "$F" "review_sensitivity" "Has review_sensitivity field"
check_max_lines "$F" 60

# --- A2: accessibility-setup ---
echo "--- A2: accessibility-setup ---"
F=".opencode/commands/accessibility-setup.md"
check_exists "$F"
check_content "$F" "accessibility-setup" "Has command name"
check_max_lines "$F" 150

# --- A3: accessibility-mode ---
echo "--- A3: accessibility-mode ---"
F=".opencode/commands/accessibility-mode.md"
check_exists "$F"
check_content "$F" "status" "Has status option"
check_max_lines "$F" 150

# --- A4: guided-work (CENTRAL) ---
echo "--- A4: guided-work (CENTRAL) ---"
F=".opencode/commands/guided-work.md"
check_exists "$F"
check_content "$F" "guided-work" "Has command name"
check_content "$F" "\-\-task" "Has --task parameter"
check_content "$F" "\-\-continue" "Has --continue parameter"
check_content "$F" "alto\|medio\|bajo" "Has guidance levels"
check_max_lines "$F" 150

# --- A5: focus-mode ---
echo "--- A5: focus-mode ---"
F=".opencode/commands/focus-mode.md"
check_exists "$F"
check_content "$F" "focus-mode" "Has command name"
check_max_lines "$F" 150

# --- A6: guided-work-protocol ---
echo "--- A6: guided-work-protocol rule ---"
F="docs/rules/domain/guided-work-protocol.md"
check_exists "$F"
check_content "$F" "dignidad\|autonomía" "Has dignity/autonomy principle"
check_content "$F" "bloqueo\|Detección" "Has block detection"
check_max_lines "$F" 150

# --- A7: accessibility-output ---
echo "--- A7: accessibility-output rule ---"
F="docs/rules/domain/accessibility-output.md"
check_exists "$F"
check_content "$F" "screen_reader" "Handles screen_reader"
check_content "$F" "cognitive_load" "Handles cognitive_load"
check_content "$F" "high_contrast" "Handles high_contrast"
check_max_lines "$F" 150

# --- A8: inclusive-review ---
echo "--- A8: inclusive-review rule ---"
F="docs/rules/domain/inclusive-review.md"
check_exists "$F"
check_content "$F" "review_sensitivity" "Has review_sensitivity trigger"
check_content "$F" "fortaleza\|strength" "Has strengths-first concept"
check_max_lines "$F" 150

# --- A9: guide-accessibility ---
echo "--- A9: guide-accessibility ---"
F="docs/guides/guide-accessibility.md"
check_exists "$F"
check_content "$F" "ADHD\|cognitiv" "Covers cognitive/ADHD"
check_content "$F" "guided.work\|guided_work" "References guided-work"
check_max_lines "$F" 150

# --- A10: Docs ES + EN ---
echo "--- A10: Docs ES + EN ---"
check_exists "docs/accessibility-es.md"
check_exists "docs/accessibility-en.md"
check_content "docs/accessibility-es.md" "screen_reader" "ES doc has screen_reader"
check_content "docs/accessibility-en.md" "screen_reader" "EN doc has screen_reader"

# --- B: ACKNOWLEDGMENTS ---
echo "--- B: ACKNOWLEDGMENTS ---"
F="ACKNOWLEDGMENTS.md"
check_exists "$F"
check_content "$F" "claude-code-templates" "Credits claude-code-templates"
check_content "$F" "kimun" "Credits kimun"
check_content "$F" "Engram" "Credits Engram"
check_content "$F" "BullshitBench" "Credits BullshitBench"
check_content "$F" "LLYC" "Credits LLYC"
check_content "$F" "N-CAPS" "Credits N-CAPS"
check_content "$F" "DX Core" "Credits DX Core 4"
check_content "$F" "Daniel Avila\|davila7" "Credits Daniel Avila"
check_max_lines "$F" 120

# --- B2: README updates ---
echo "--- B2: README updates ---"
check_content "README.md" "ACKNOWLEDGMENTS" "README.md links to ACKNOWLEDGMENTS"
check_content "README.en.md" "ACKNOWLEDGMENTS" "README.en.md links to ACKNOWLEDGMENTS"

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && echo "All tests passed." || { echo "SOME TESTS FAILED."; exit 1; }
