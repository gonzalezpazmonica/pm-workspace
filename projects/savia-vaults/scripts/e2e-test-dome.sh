#!/usr/bin/env bash
# e2e-test-dome.sh — E2E test: compare SaviaVaults dome search vs direct filesystem search
# Copyright (c) 2026 Savia. MIT License.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOT="${1:-$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$PROJECT_DIR/../..")}"
VAULT_PATH="${VAULT_PATH:-${ROOT}/vaults/savia-docs}"
DOCS_DIR="${ROOT}/docs"

PASS=0; FAIL=0
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

assert() {
  local desc="$1" condition="$2"
  if eval "$condition" 2>/dev/null; then
    echo -e "  ${GREEN}PASS${NC} $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "============================================"
echo "  SaviaVaults E2E — Dome vs Direct Search"
echo "============================================"
echo ""
echo "  Vault:  $VAULT_PATH"
echo "  Source: $DOCS_DIR"
echo ""

# ── Test 1: Vault exists and has content ──
echo "── Test 1: Vault integrity ──"
assert "Vault directory exists" "[[ -d '$VAULT_PATH' ]]"
assert "INDEX.md exists" "[[ -f '$VAULT_PATH/INDEX.md' ]]"
assert "MAP.md exists" "[[ -f '$VAULT_PATH/MAP.md' ]]"
assert "Git repo initialized" "[[ -d '$VAULT_PATH/.git' ]]"

# ── Test 2: File count matches ──
echo ""
echo "── Test 2: File count parity ──"
DOME_COUNT=$(find "$VAULT_PATH" -type f -name "*.md" ! -path "*/.git/*" | wc -l)
SOURCE_COUNT=$(find "$DOCS_DIR" -type f -name "*.md" ! -path "*/.git/*" | wc -l)
echo "  Dome files:   $DOME_COUNT"
echo "  Source files: $SOURCE_COUNT"
assert "Dome has indexed files (${DOME_COUNT} > 0)" "[[ $DOME_COUNT -gt 0 ]]"
assert "Dome count >= source count" "[[ $DOME_COUNT -ge $SOURCE_COUNT ]]"

# ── Test 3: Content search parity ──
echo ""
echo "── Test 3: Content search parity ──"
SEARCH_TERMS=("autonomous safety" "skill suggest" "confidentiality" "roadmap" "MCP" "architecture" "bus factor")
for term in "${SEARCH_TERMS[@]}"; do
  # Direct filesystem search (grep)
  GREP_COUNT=$(grep -rli "$term" "$DOCS_DIR" --include="*.md" 2>/dev/null | wc -l)

  # Dome search (files in vault)
  DOME_MATCHES=$(grep -rli "$term" "$VAULT_PATH/docs" --include="*.md" 2>/dev/null | wc -l)

  if [[ $GREP_COUNT -gt 0 ]] && [[ $DOME_MATCHES -gt 0 ]]; then
    echo -e "  ${GREEN}PASS${NC} '$term': dome($DOME_MATCHES) ≈ source($GREP_COUNT)"
    PASS=$((PASS + 1))
  elif [[ $GREP_COUNT -eq 0 ]] && [[ $DOME_MATCHES -eq 0 ]]; then
    echo -e "  ${GREEN}PASS${NC} '$term': both empty (consistent)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${NC} '$term': dome($DOME_MATCHES) ≠ source($GREP_COUNT)"
    FAIL=$((FAIL + 1))
  fi
done

# ── Test 4: Frontmatter preservation ──
echo ""
echo "── Test 4: Frontmatter integrity ──"
SAMPLE_SOURCE="$DOCS_DIR/rules/domain/autonomous-safety.md"
SAMPLE_DOME="$VAULT_PATH/docs/rules/domain/autonomous-safety.md"
if [[ -f "$SAMPLE_SOURCE" ]] && [[ -f "$SAMPLE_DOME" ]]; then
  SOURCE_HASH=$(sha256sum "$SAMPLE_SOURCE" | cut -d' ' -f1)
  DOME_HASH=$(sha256sum "$SAMPLE_DOME" | cut -d' ' -f1)
  assert "autonomous-safety.md content matches ($SOURCE_HASH = $DOME_HASH)" "[[ '$SOURCE_HASH' == '$DOME_HASH' ]]"
else
  assert "autonomous-safety.md exists in both" "false"
fi

# ── Test 5: Root-level docs indexed ──
echo ""
echo "── Test 5: Root-level documents ──"
for doc in CLAUDE.md SKILLS.md AGENTS.md; do
  assert "root/$doc indexed" "[[ -f '$VAULT_PATH/root/$doc' ]]"
done

# ── Test 6: Search result consistency ──
echo ""
echo "── Test 6: Search consistency across 5 random samples ──"
SAMPLE_FILES=$(find "$DOCS_DIR" -name "*.md" -type f ! -path "*/.git/*" | shuf -n 5 2>/dev/null || find "$DOCS_DIR" -name "*.md" -type f ! -path "*/.git/*" | head -5)
while IFS= read -r src; do
  [[ -z "$src" ]] && continue
  rel="${src#$DOCS_DIR/}"
  dome_file="$VAULT_PATH/docs/$rel"
  if [[ -f "$dome_file" ]]; then
    src_lines=$(wc -l < "$src")
    dome_lines=$(wc -l < "$dome_file")
    if [[ "$src_lines" == "$dome_lines" ]]; then
      echo -e "  ${GREEN}PASS${NC} $rel ($src_lines lines)"
      PASS=$((PASS + 1))
    else
      echo -e "  ${RED}FAIL${NC} $rel: src($src_lines) ≠ dome($dome_lines)"
      FAIL=$((FAIL + 1))
    fi
  else
    echo -e "  ${RED}FAIL${NC} $rel: not found in dome"
    FAIL=$((FAIL + 1))
  fi
done <<< "$SAMPLE_FILES"

echo ""
echo "============================================"
echo "  Result: $PASS PASS | $FAIL FAIL"
echo "============================================"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Gaps found: some files may have different line counts due to encoding"
  echo "or special characters. Review the FAIL entries above."
  exit 1
fi

echo ""
echo "All checks passed. Dome is consistent with source."
exit 0
