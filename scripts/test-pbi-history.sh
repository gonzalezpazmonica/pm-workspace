#!/usr/bin/env bash
# test-pbi-history.sh — Validates PBI Field-Level History implementation
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
PASS=0; FAIL=0; TOTAL=0

pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  FAIL: $1"; }

PBI_DIRS=("$REPO_ROOT/projects/savia-web/backlog/pbi" "$REPO_ROOT/projects/savia-web/backlog/archive")
HOOK="$REPO_ROOT/.opencode/hooks/pbi-history-capture.sh"

# Collect all PBI files
PBI_FILES=()
for dir in "${PBI_DIRS[@]}"; do
  [[ ! -d "$dir" ]] && continue
  for f in "$dir"/PBI-*.md; do [[ -f "$f" ]] && PBI_FILES+=("$f"); done
done

# ── Test 1: All PBI files have ## Historial section ──────────────────────────
echo ""; echo "=== Test 1: Historial section exists ==="
MISSING=0
for f in "${PBI_FILES[@]}"; do
  grep -q '## Historial' "$f" || { MISSING=$((MISSING+1)); echo "    Missing: $f"; }
done
[[ $MISSING -eq 0 && ${#PBI_FILES[@]} -gt 0 ]] \
  && pass "All ${#PBI_FILES[@]} PBI files have ## Historial" \
  || fail "$MISSING of ${#PBI_FILES[@]} missing ## Historial"

# ── Test 2: Migration entries exist ──────────────────────────────────────────
echo ""; echo "=== Test 2: Migration entries ==="
MISSING=0
for f in "${PBI_FILES[@]}"; do
  grep -q '_migrated' "$f" || { MISSING=$((MISSING+1)); echo "    Missing: $f"; }
done
[[ $MISSING -eq 0 ]] && pass "All have _migrated entry" || fail "$MISSING missing _migrated"

# ── Test 3: Migration entry format ───────────────────────────────────────────
echo ""; echo "=== Test 3: Entry format ==="
BAD=0
for f in "${PBI_FILES[@]}"; do
  LINE=$(grep '_migrated' "$f" 2>/dev/null || true)
  if [[ -n "$LINE" ]]; then
    echo "$LINE" | grep -qE '^\| [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} \| @' \
      || { BAD=$((BAD+1)); echo "    Bad: $f"; }
  fi
done
[[ $BAD -eq 0 ]] && pass "Correct format" || fail "$BAD bad format"

# ── Test 4: Table header correct ─────────────────────────────────────────────
echo ""; echo "=== Test 4: Table header ==="
BAD=0
for f in "${PBI_FILES[@]}"; do
  if grep -q '## Historial' "$f"; then
    grep -q '| Fecha | Autor | Campo | Anterior | Nuevo |' "$f" \
      || { BAD=$((BAD+1)); echo "    Missing header: $f"; }
  fi
done
[[ $BAD -eq 0 ]] && pass "All have correct header" || fail "$BAD bad headers"

# ── Test 5: Hook script exists ───────────────────────────────────────────────
echo ""; echo "=== Test 5: Hook exists ==="
[[ -f "$HOOK" ]] && pass "Hook exists" || fail "Hook not found"

# ── Test 6: Hook is executable ───────────────────────────────────────────────
echo ""; echo "=== Test 6: Hook executable ==="
[[ -x "$HOOK" ]] && pass "Hook is executable" || fail "Not executable (chmod +x)"

# ── Test 7: Hook syntax valid ────────────────────────────────────────────────
echo ""; echo "=== Test 7: Syntax check ==="
bash -n "$HOOK" 2>/dev/null && pass "Syntax OK" || fail "Syntax errors"

# ── Test 8: Hook within line limit ───────────────────────────────────────────
echo ""; echo "=== Test 8: Line limit ==="
if [[ -f "$HOOK" ]]; then
  LINES=$(wc -l < "$HOOK")
  [[ $LINES -le 150 ]] && pass "$LINES lines (limit 150)" || fail "$LINES lines (>150)"
fi

# ── Test 9: @system author ───────────────────────────────────────────────────
echo ""; echo "=== Test 9: @system author ==="
BAD=0
for f in "${PBI_FILES[@]}"; do
  LINE=$(grep '_migrated' "$f" 2>/dev/null || true)
  [[ -n "$LINE" ]] && ! echo "$LINE" | grep -q '@system' && BAD=$((BAD+1))
done
[[ $BAD -eq 0 ]] && pass "All @system" || fail "$BAD wrong author"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "  PBI History Tests: $PASS/$TOTAL passed"
[[ $FAIL -gt 0 ]] && { echo "  FAILURES: $FAIL"; echo "========================================"; exit 1; }
echo "  All tests passed"
echo "========================================"
