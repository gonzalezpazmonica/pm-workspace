#!/bin/bash
# readiness-check.sh — Deterministic capability checklist
# Runs on install, update, or manually. Reports what works and what needs setup.
# Exit 0 if core capabilities pass. Exit 1 only if critical failures.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Counters
PASS=0; WARN=0; FAIL=0; SKIP=0; TOTAL=0

check() {
    local level="$1" name="$2" cmd="$3"
    TOTAL=$((TOTAL + 1))
    if eval "$cmd" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
        printf "  %-4s %-45s %s\n" "OK" "$name" ""
    else
        case "$level" in
            critical)
                FAIL=$((FAIL + 1))
                printf "  %-4s %-45s %s\n" "FAIL" "$name" "[CRITICAL]"
                ;;
            recommended)
                WARN=$((WARN + 1))
                printf "  %-4s %-45s %s\n" "WARN" "$name" "[optional]"
                ;;
            optional)
                SKIP=$((SKIP + 1))
                printf "  %-4s %-45s %s\n" "SKIP" "$name" "[optional]"
                ;;
        esac
    fi
}

echo ""
echo "Savia Readiness Check"
echo "====================================="
echo ""

# --- 1. Core runtime ---
echo "[1/7] Core Runtime"
check critical "bash >= 4.0" "bash --version | head -1 | grep -E 'version [4-9]'"
check critical "git" "git --version"
check critical "python3" "command -v python3"
check critical "jq" "command -v jq"
check recommended "node/npm (for Claude Code)" "command -v node"
check recommended "bats (test runner)" "command -v bats"

# --- 2. Workspace structure ---
echo ""
echo "[2/7] Workspace Structure"
check critical "CLAUDE.md exists" "test -f '$ROOT_DIR/CLAUDE.md'"
check critical ".claude/commands/ exists" "test -d '$ROOT_DIR/.claude/commands'"
check critical ".claude/agents/ exists" "test -d '$ROOT_DIR/.claude/agents'"
check critical ".claude/skills/ exists" "test -d '$ROOT_DIR/.claude/skills'"
check critical ".claude/rules/ exists" "test -d '$ROOT_DIR/.claude/rules'"
check critical "scripts/ exists" "test -d '$ROOT_DIR/scripts'"
check critical ".claude/settings.json exists" "test -f '$ROOT_DIR/.claude/settings.json'"

# --- 3. Scripts health ---
echo ""
echo "[3/7] Scripts Health"
check critical "memory-store.sh executable" "test -f '$ROOT_DIR/scripts/memory-store.sh'"
check critical "memory-store.sh runs" "bash '$ROOT_DIR/scripts/memory-store.sh' help | grep -q 'save'"
check critical "validate-ci-local.sh exists" "test -f '$ROOT_DIR/scripts/validate-ci-local.sh'"
check critical "confidentiality-sign.sh exists" "test -f '$ROOT_DIR/scripts/confidentiality-sign.sh'"
check recommended "memory-vector.py valid Python" "python3 -c \"import ast; ast.parse(open('$ROOT_DIR/scripts/memory-vector.py').read())\""

# --- 4. Vector memory (optional tier) ---
echo ""
echo "[4/7] Vector Memory (SPEC-018)"
check optional "sentence-transformers installed" "python3 -c 'import sentence_transformers'"
check optional "hnswlib installed" "python3 -c 'import hnswlib'"
if python3 -c "import hnswlib, sentence_transformers" 2>/dev/null; then
    printf "  %-4s %-45s %s\n" "INFO" "Vector search: Level 2 (full)" ""
else
    printf "  %-4s %-45s %s\n" "INFO" "Vector search: Level 0 (grep fallback)" ""
    printf "  %-4s %-45s %s\n" "TIP " "Install: pip install -r requirements-vector.txt" ""
fi

# --- 5. Hooks ---
echo ""
echo "[5/7] Hooks"
check critical "settings.json valid JSON" "python3 -c \"import json; json.load(open('$ROOT_DIR/.claude/settings.json'))\""
HOOKS_DIR="$ROOT_DIR/.claude/hooks"
if [[ -d "$HOOKS_DIR" ]]; then
    HOOK_COUNT=$(ls "$HOOKS_DIR"/*.sh 2>/dev/null | wc -l)
    printf "  %-4s %-45s %s\n" "INFO" "$HOOK_COUNT hooks found in .claude/hooks/" ""
    for h in "$HOOKS_DIR"/*.sh; do
        [[ -f "$h" ]] || continue
        HNAME=$(basename "$h")
        check recommended "hook $HNAME has set -" "head -5 '$h' | grep -q 'set -'"
    done
fi

# --- 6. Tests ---
echo ""
echo "[6/7] Tests"
check critical "tests/ directory exists" "test -d '$ROOT_DIR/tests'"
check critical "run-all.sh exists" "test -f '$ROOT_DIR/tests/run-all.sh'"
if command -v bats &>/dev/null; then
    TEST_COUNT=$(find "$ROOT_DIR/tests" -name '*.bats' | wc -l)
    printf "  %-4s %-45s %s\n" "INFO" "$TEST_COUNT .bats test files found" ""
fi

# --- 7. Git & CI ---
echo ""
echo "[7/7] Git & CI"
check critical "git repo initialized" "git -C '$ROOT_DIR' rev-parse --is-inside-work-tree"
check critical "not on main branch" "test \"\$(git -C '$ROOT_DIR' branch --show-current)\" != 'main'" || true
check recommended ".gitignore exists" "test -f '$ROOT_DIR/.gitignore'"
check recommended "GitHub remote configured" "git -C '$ROOT_DIR' remote get-url origin 2>/dev/null | grep -q 'github.com'"

# --- Summary ---
echo ""
echo "====================================="
printf "  PASS: %d  |  WARN: %d  |  FAIL: %d  |  SKIP: %d  |  TOTAL: %d\n" "$PASS" "$WARN" "$FAIL" "$SKIP" "$TOTAL"
echo "====================================="

if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "CRITICAL failures detected. Fix before using pm-workspace."
    exit 1
fi

if [[ $WARN -gt 0 ]]; then
    echo ""
    echo "All critical checks pass. $WARN optional items could be installed."
fi

if [[ $FAIL -eq 0 && $WARN -eq 0 ]]; then
    echo ""
    echo "All checks pass. Savia is fully operational."
fi

# Write stamp so session-init knows readiness was verified for this commit
if [[ $FAIL -eq 0 ]]; then
    mkdir -p "$HOME/.pm-workspace"
    git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null > "$HOME/.pm-workspace/.readiness-stamp" || true
fi

exit 0
