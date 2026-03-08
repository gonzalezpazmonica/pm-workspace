#!/bin/bash
# test-install.sh — Structural validation for pm-workspace installers
# Tests file structure, content, and key functions without running installation

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
TOTAL=0

pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  ❌ $1"; }
check() { if bash -c "$2" 2>/dev/null; then pass "$1"; else fail "$1"; fi; }

echo "═══ Testing One-Line Installers ═══"

# --- Section 1: install.sh structure -------------------------------------------
echo ""
echo "Section 1: install.sh (macOS + Linux)"

check "File exists" "[[ -f '$REPO_ROOT/install.sh' ]]"
check "Has shebang" "head -1 '$REPO_ROOT/install.sh' | grep -q '#!/bin/bash'"
check "File ≤ 250 lines" "[[ \$(wc -l < '$REPO_ROOT/install.sh') -le 250 ]]"
check "Has set -euo pipefail" "grep -q 'set -euo pipefail' '$REPO_ROOT/install.sh'"
check "Has error trap" "grep -q 'trap.*ERR' '$REPO_ROOT/install.sh'"
check "Detects OS" "grep -q 'OSTYPE.*darwin\|OSTYPE.*linux' '$REPO_ROOT/install.sh'"
check "Detects architecture" "grep -q 'uname -m' '$REPO_ROOT/install.sh'"
check "Checks git" "grep -qi 'command -v git\|which git' '$REPO_ROOT/install.sh'"
check "Checks node" "grep -qi 'command -v node\|which node' '$REPO_ROOT/install.sh'"
check "Checks Claude Code" "grep -qi 'command -v claude\|which claude' '$REPO_ROOT/install.sh'"
check "Installs Claude Code" "grep -q 'claude.ai/install.sh' '$REPO_ROOT/install.sh'"
check "Clones pm-workspace" "grep -q 'git clone' '$REPO_ROOT/install.sh'"
check "Has SAVIA_HOME env var" "grep -q 'SAVIA_HOME' '$REPO_ROOT/install.sh'"
check "Has --help flag" "grep -q '\-\-help' '$REPO_ROOT/install.sh'"
check "Has --skip-tests flag" "grep -q '\-\-skip-tests\|SKIP_TESTS' '$REPO_ROOT/install.sh'"
check "Has npm install" "grep -q 'npm install' '$REPO_ROOT/install.sh'"
check "Has next steps output" "grep -qi 'next steps\|cd.*claude' '$REPO_ROOT/install.sh'"
check "Detects WSL" "grep -qi 'wsl\|microsoft' '$REPO_ROOT/install.sh'"
check "Handles existing directory" "grep -q 'git pull\|already exists' '$REPO_ROOT/install.sh'"
check "Has exit codes" "grep -q 'exit [123]' '$REPO_ROOT/install.sh'"

# --- Section 2: install.ps1 structure ------------------------------------------
echo ""
echo "Section 2: install.ps1 (Windows)"

check "File exists" "[[ -f '$REPO_ROOT/install.ps1' ]]"
check "File ≤ 250 lines" "[[ \$(wc -l < '$REPO_ROOT/install.ps1') -le 250 ]]"
check "Has ErrorActionPreference" "grep -q 'ErrorActionPreference' '$REPO_ROOT/install.ps1'"
check "Checks git" "grep -qi 'Get-Command git\|git --version' '$REPO_ROOT/install.ps1'"
check "Checks node" "grep -qi 'Get-Command node\|node --version' '$REPO_ROOT/install.ps1'"
check "Checks Claude Code" "grep -qi 'Get-Command claude\|claude' '$REPO_ROOT/install.ps1'"
check "Installs Claude Code" "grep -q 'claude.ai/install.ps1' '$REPO_ROOT/install.ps1'"
check "Clones pm-workspace" "grep -q 'git clone' '$REPO_ROOT/install.ps1'"
check "Has SAVIA_HOME env var" "grep -q 'SAVIA_HOME' '$REPO_ROOT/install.ps1'"
check "Has --help flag" "grep -q '\-\-help' '$REPO_ROOT/install.ps1'"
check "Has --skip-tests flag" "grep -q '\-\-skip-tests\|SKIP_TESTS' '$REPO_ROOT/install.ps1'"
check "Has npm install" "grep -q 'npm install' '$REPO_ROOT/install.ps1'"
check "Detects WSL" "grep -qi 'wsl' '$REPO_ROOT/install.ps1'"
check "Has winget or choco hints" "grep -qi 'winget\|choco' '$REPO_ROOT/install.ps1'"
check "Handles existing directory" "grep -q 'already exists\|Test-Path' '$REPO_ROOT/install.ps1'"

# --- Section 3: Documentation references ---------------------------------------
echo ""
echo "Section 3: Documentation"

check "README.md mentions install.sh" "grep -q 'install.sh' '$REPO_ROOT/README.md'"
check "README.en.md mentions install.sh" "grep -q 'install.sh' '$REPO_ROOT/README.en.md'"
check "CHANGELOG mentions v2.4.0" "grep -q '2.4.0' '$REPO_ROOT/CHANGELOG.md'"
check "CHANGELOG has comparison link" "grep -q '\[2.4.0\]:' '$REPO_ROOT/CHANGELOG.md'"

# --- Section 4: Cross-references -----------------------------------------------
echo ""
echo "Section 4: Cross-references"

check "install.sh references repo URL" "grep -q 'gonzalezpazmonica/pm-workspace' '$REPO_ROOT/install.sh'"
check "install.ps1 references repo URL" "grep -q 'gonzalezpazmonica/pm-workspace' '$REPO_ROOT/install.ps1'"
check "install.sh references ADOPTION_GUIDE" "grep -qi 'ADOPTION_GUIDE' '$REPO_ROOT/install.sh'"
check "install.ps1 references ADOPTION_GUIDE" "grep -qi 'ADOPTION_GUIDE' '$REPO_ROOT/install.ps1'"

# --- Results -------------------------------------------------------------------
echo ""
echo "═══ One-Line Installers: ${PASS}/${TOTAL} passed ═══"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
