#!/usr/bin/env bash
# skill-validator.sh — SE-147: Skill behavior validator
# Verifies structural and content rules for all .opencode/skills/*/SKILL.md files.
#
# Usage:
#   bash tests/skill-behavior/skill-validator.sh [--path <skill-file>]
#
# Exit codes:
#   0 — All skills PASS (WARNs are non-blocking)
#   1 — One or more skills FAIL

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
SKILLS_GLOB=".opencode/skills/*/SKILL.md"
MAX_LINES=150
DESCRIPTION_TRAP_WORDS="pipeline|workflow|executes|runs|generates|produces"

# Colours (disabled if not a terminal)
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; RESET=''
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
pass()  { echo -e "  ${GREEN}PASS${RESET}  $1"; }
fail()  { echo -e "  ${RED}FAIL${RESET}  $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn()  { echo -e "  ${YELLOW}WARN${RESET}  $1"; WARN_COUNT=$((WARN_COUNT + 1)); }

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
TOTAL=0

validate_skill() {
  local file="$1"
  local name
  name=$(basename "$(dirname "$file")")
  local file_pass=true

  echo ""
  echo "── $name ──"

  # 1. File exists
  if [[ ! -f "$file" ]]; then
    fail "SKILL.md missing: $file"
    return
  fi

  # 2. Line count ≤ 150 (Rule 11)
  local lines
  lines=$(wc -l < "$file")
  if [[ "$lines" -le "$MAX_LINES" ]]; then
    pass "lines ($lines ≤ $MAX_LINES)"
  else
    fail "lines ($lines > $MAX_LINES) — Rule 11 violation"
    file_pass=false
  fi

  # 3. Has at least one markdown heading
  if grep -qE '^## ' "$file"; then
    pass "has ## heading"
  else
    fail "missing ## heading — no navigable sections"
    file_pass=false
  fi

  # 4. If frontmatter present, check description: field exists
  local has_frontmatter=false
  if head -1 "$file" | grep -q '^---'; then
    has_frontmatter=true
  fi

  if [[ "$has_frontmatter" == true ]]; then
    if grep -qE '^description:' "$file"; then
      pass "frontmatter has description:"
    else
      fail "frontmatter missing description: field"
      file_pass=false
    fi

    # 5. Description Trap check (WARN, not FAIL — has known false-positives in repo)
    local desc_line
    desc_line=$(grep -E '^description:' "$file" | head -1 || true)
    if echo "$desc_line" | grep -qiE "\b($DESCRIPTION_TRAP_WORDS)\b"; then
      warn "description may be process-summary — contains: $(echo "$desc_line" | grep -oiE "$DESCRIPTION_TRAP_WORDS" | tr '\n' ',' | sed 's/,$//') — consider trigger-only wording"
    else
      pass "description is trigger-only (no process-summary words)"
    fi
  else
    warn "no YAML frontmatter — skipping description checks"
  fi

  if [[ "$file_pass" == true ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
  fi
  TOTAL=$((TOTAL + 1))
}

# ── Main ──────────────────────────────────────────────────────────────────────
# Resolve workspace root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${SAVIA_WORKSPACE_DIR:-}"
if [[ -z "$WORKSPACE" ]]; then
  WORKSPACE="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/../..")"
fi
cd "$WORKSPACE"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Savia Skill Validator — SE-147                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "  Workspace : $WORKSPACE"
echo "  Skills    : $SKILLS_GLOB"
echo "  Max lines : $MAX_LINES"
echo ""

# Allow single-file mode for BATS tests
if [[ "${1:-}" == "--path" && -n "${2:-}" ]]; then
  validate_skill "$2"
else
  for skill_file in $SKILLS_GLOB; do
    validate_skill "$skill_file"
  done
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Skills validated : $TOTAL"
echo -e "  ${GREEN}PASS${RESET}             : $PASS_COUNT"
echo -e "  ${YELLOW}WARN${RESET}             : $WARN_COUNT  (non-blocking)"
echo -e "  ${RED}FAIL${RESET}             : $FAIL_COUNT"
echo "══════════════════════════════════════════════════════════════"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo -e "  ${RED}Result: FAILED — $FAIL_COUNT skill(s) need attention${RESET}"
  exit 1
else
  echo -e "  ${GREEN}Result: PASSED — all skills meet structural requirements${RESET}"
  exit 0
fi
