#!/usr/bin/env bash
# ci-reliability-gate.sh — SPEC-SE-012
set -uo pipefail
#
# Pre-push reliability check: detects frequent causes of CI failure before
# git push. Run manually or via pr-plan.sh Gate G-pre-push (advisory).
#
# Checks:
#   1. empty-dirs        — empty directories git won't track → CI misses them
#   2. staged-gitignored — files in .gitignore that are accidentally staged
#   3. exec-permissions  — executables that should be 755 but are 644, or vice versa
#   4. broken-symlinks   — symlinks pointing to non-existent targets
#   5. large-files       — files >5MB that should use Git LFS
#   6. encoding          — non-UTF-8 content in .py/.ts/.sh files
#   7. trailing-ws-bats  — trailing whitespace in .bats files (breaks tests)
#   8. tabs-python       — tabs used for indentation in Python files
#
# Output:
#   Human-readable by default.
#   --json: prints JSON to stdout.
#   --fix-empty-dirs: creates .gitkeep in detected empty dirs, then re-checks.
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed
#
# Usage:
#   bash scripts/ci-reliability-gate.sh
#   bash scripts/ci-reliability-gate.sh --json
#   bash scripts/ci-reliability-gate.sh --fix-empty-dirs
#   bash scripts/ci-reliability-gate.sh --fix-empty-dirs --json
#
# Reference: SPEC-SE-012

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SAVIA_WORKSPACE_DIR:-${CLAUDE_PROJECT_DIR:-${OPENCODE_PROJECT_DIR:-"$SCRIPT_DIR/.."}}}" && pwd)"

# ── Argument parsing ──────────────────────────────────────────────────────────
JSON_MODE=0
FIX_EMPTY_DIRS=0
for arg in "${@:-}"; do
  case "$arg" in
    --json)            JSON_MODE=1 ;;
    --fix-empty-dirs)  FIX_EMPTY_DIRS=1 ;;
  esac
done

# ── Result accumulators ───────────────────────────────────────────────────────
declare -a CHECK_NAMES=()
declare -a CHECK_PASSED=()
declare -a CHECK_DETAILS=()

record() {
  local name="$1" passed="$2" details="$3"
  CHECK_NAMES+=("$name")
  CHECK_PASSED+=("$passed")
  CHECK_DETAILS+=("$details")
}

# ── Prune patterns: skip known-slow or irrelevant directories ────────────────
FIND_PRUNE_ARGS=(
  -not -path "*/.git/*"
  -not -path "*/node_modules/*"
  -not -path "*/build/*"
  -not -path "*/.gradle/*"
  -not -path "*/output/*"
  -not -path "*/worktrees/*"
)

# ── Check 1: empty-dirs ───────────────────────────────────────────────────────
check_empty_dirs() {
  local empty_dirs=()
  while IFS= read -r -d "" dir; do
    local nested
    nested=$(find "$dir" -maxdepth 3 -not -type d 2>/dev/null | wc -l || echo 0)
    if (( nested == 0 )); then
      empty_dirs+=("${dir#$WORKSPACE_DIR/}")
    fi
  done < <(find "$WORKSPACE_DIR" -maxdepth 6 -type d       "${FIND_PRUNE_ARGS[@]}" -print0 2>/dev/null | head -z -n 200)

  if (( FIX_EMPTY_DIRS && ${#empty_dirs[@]} > 0 )); then
    for d in "${empty_dirs[@]}"; do
      touch "$WORKSPACE_DIR/$d/.gitkeep"
    done
    check_empty_dirs_nofix
    return
  fi

  if (( ${#empty_dirs[@]} == 0 )); then
    record "empty-dirs" "true" "no empty directories found"
  else
    local dirs_str
    dirs_str="${empty_dirs[*]}"
    record "empty-dirs" "false" "empty dirs (git won not track): ${dirs_str:0:200}"
  fi
}

check_empty_dirs_nofix() {
  local empty_dirs=()
  while IFS= read -r -d "" dir; do
    local nested
    nested=$(find "$dir" -maxdepth 3 -not -type d 2>/dev/null | wc -l || echo 0)
    if (( nested == 0 )); then
      empty_dirs+=("${dir#$WORKSPACE_DIR/}")
    fi
  done < <(find "$WORKSPACE_DIR" -maxdepth 6 -type d       "${FIND_PRUNE_ARGS[@]}" -print0 2>/dev/null | head -z -n 200)
  if (( ${#empty_dirs[@]} == 0 )); then
    record "empty-dirs" "true" "empty dirs fixed with .gitkeep"
  else
    record "empty-dirs" "false" "still empty after fix: ${empty_dirs[*]}"
  fi
}

# ── Check 2: staged-gitignored ────────────────────────────────────────────────
check_staged_gitignored() {
  if ! git -C "$WORKSPACE_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    record "staged-gitignored" "true" "not a git repo — skipped"
    return
  fi
  local staged_ignored
  staged_ignored=$(git -C "$WORKSPACE_DIR" ls-files --cached --ignored --exclude-standard 2>/dev/null | head -10 || true)
  if [[ -z "$staged_ignored" ]]; then
    record "staged-gitignored" "true" "no gitignored files staged"
  else
    record "staged-gitignored" "false" "gitignored files staged: $(echo "$staged_ignored" | tr '\n' ' ' | cut -c1-200)"
  fi
}

# ── Check 3: exec-permissions ─────────────────────────────────────────────────
check_exec_permissions() {
  local issues=()
  # .sh files should be executable
  while IFS= read -r -d '' f; do
    if [[ ! -x "$f" ]]; then
      issues+=("not-exec:${f#$WORKSPACE_DIR/}")
    fi
  done < <(find "$WORKSPACE_DIR/scripts" "$WORKSPACE_DIR/.opencode/hooks" \
      -maxdepth 2 -name "*.sh" -not -path '*/.git/*' -print0 2>/dev/null || true)

  if (( ${#issues[@]} == 0 )); then
    record "exec-permissions" "true" "all .sh files are executable"
  else
    record "exec-permissions" "false" "${issues[*]:0:3} (${#issues[@]} total)"
  fi
}

# ── Check 4: broken-symlinks ──────────────────────────────────────────────────
check_broken_symlinks() {
  local broken=()
  while IFS= read -r link; do
    broken+=("${link#$WORKSPACE_DIR/}")
  done < <(find "$WORKSPACE_DIR" -maxdepth 8 "${FIND_PRUNE_ARGS[@]}" \
      -xtype l 2>/dev/null | head -20 || true)
  if (( ${#broken[@]} == 0 )); then
    record "broken-symlinks" "true" "no broken symlinks found"
  else
    record "broken-symlinks" "false" "broken symlinks: ${broken[*]:0:5}"
  fi
}

# ── Check 5: large-files ──────────────────────────────────────────────────────
check_large_files() {
  local limit_bytes=$((5 * 1024 * 1024))  # 5MB
  local large=()
  while IFS= read -r -d '' f; do
    local size
    size=$(stat -c %s "$f" 2>/dev/null || echo 0)
    if (( size > limit_bytes )); then
      large+=("${f#$WORKSPACE_DIR/}($(( size / 1024 / 1024 ))MB)")
    fi
  done < <(find "$WORKSPACE_DIR" -maxdepth 8 "${FIND_PRUNE_ARGS[@]}" \
      -type f -print0 2>/dev/null | head -z -n 2000 || true)
  if (( ${#large[@]} == 0 )); then
    record "large-files" "true" "no files >5MB found"
  else
    record "large-files" "false" "files >5MB (consider LFS): ${large[*]:0:3}"
  fi
}

# ── Check 6: encoding ─────────────────────────────────────────────────────────
check_encoding() {
  if ! command -v file &>/dev/null; then
    record "encoding" "true" "file command not available — skipped"
    return
  fi
  local issues=()
  while IFS= read -r -d '' f; do
    local enc
    enc=$(file -b --mime-encoding "$f" 2>/dev/null || echo "unknown")
    case "$enc" in
      us-ascii|utf-8|utf-16*|binary) ;;
      unknown) ;;
      *)
        issues+=("${f#$WORKSPACE_DIR/}($enc)")
        ;;
    esac
  done < <(find "$WORKSPACE_DIR" -maxdepth 8 "${FIND_PRUNE_ARGS[@]}" \
      \( -name "*.py" -o -name "*.ts" -o -name "*.sh" \) \
      -type f -print0 2>/dev/null | head -z -n 200 || true)
  if (( ${#issues[@]} == 0 )); then
    record "encoding" "true" "all .py/.ts/.sh files are UTF-8 compatible"
  else
    record "encoding" "false" "non-UTF-8 files: ${issues[*]:0:3}"
  fi
}

# ── Check 7: trailing-ws-bats ─────────────────────────────────────────────────
check_trailing_ws_bats() {
  local issues=()
  while IFS= read -r -d '' f; do
    if grep -qP '\s+$' "$f" 2>/dev/null; then
      issues+=("${f#$WORKSPACE_DIR/}")
    fi
  done < <(find "$WORKSPACE_DIR/tests" -name "*.bats" -type f -print0 2>/dev/null || true)
  if (( ${#issues[@]} == 0 )); then
    record "trailing-ws-bats" "true" "no trailing whitespace in .bats files"
  else
    record "trailing-ws-bats" "false" "trailing whitespace in .bats: ${issues[*]:0:3} (${#issues[@]} total)"
  fi
}

# ── Check 8: tabs-python ──────────────────────────────────────────────────────
check_tabs_python() {
  local issues=()
  while IFS= read -r -d '' f; do
    if grep -qP '^\t' "$f" 2>/dev/null; then
      issues+=("${f#$WORKSPACE_DIR/}")
    fi
  done < <(find "$WORKSPACE_DIR" -maxdepth 8 -name "*.py" "${FIND_PRUNE_ARGS[@]}" \
      -type f -print0 2>/dev/null | head -100 || true)
  if (( ${#issues[@]} == 0 )); then
    record "tabs-python" "true" "no tab-indented Python files"
  else
    record "tabs-python" "false" "Python files with tab indentation: ${issues[*]:0:3} (${#issues[@]} total)"
  fi
}

# ── Run all checks ────────────────────────────────────────────────────────────

check_empty_dirs
check_staged_gitignored
check_exec_permissions
check_broken_symlinks
check_large_files
check_encoding
check_trailing_ws_bats
check_tabs_python

# ── Compute all_passed ────────────────────────────────────────────────────────

ALL_PASSED="true"
for p in "${CHECK_PASSED[@]}"; do
  [[ "$p" == "false" ]] && ALL_PASSED="false" && break
done

# ── Output ────────────────────────────────────────────────────────────────────

if (( JSON_MODE == 1 )); then
  checks_json="["
  first=1
  for i in "${!CHECK_NAMES[@]}"; do
    (( first )) || checks_json+=","
    name="${CHECK_NAMES[$i]}"
    passed="${CHECK_PASSED[$i]}"
    details="${CHECK_DETAILS[$i]}"
    # Escape details for JSON
    details_escaped="${details//\\/\\\\}"
    details_escaped="${details_escaped//\"/\\\"}"
    checks_json+="{\"name\":\"$name\",\"passed\":$passed,\"details\":\"$details_escaped\"}"
    first=0
  done
  checks_json+="]"
  printf '{"checks":%s,"all_passed":%s}\n' "$checks_json" "$ALL_PASSED"
else
  printf 'CI Reliability Gate\n'
  printf '===================\n'
  for i in "${!CHECK_NAMES[@]}"; do
    name="${CHECK_NAMES[$i]}"
    passed="${CHECK_PASSED[$i]}"
    details="${CHECK_DETAILS[$i]}"
    if [[ "$passed" == "true" ]]; then
      printf '  PASS  %-24s %s\n' "$name" "$details"
    else
      printf '  FAIL  %-24s %s\n' "$name" "$details"
    fi
  done
  printf '\n'
  if [[ "$ALL_PASSED" == "true" ]]; then
    printf 'Result: all checks passed\n'
  else
    printf 'Result: one or more checks failed — review above\n'
  fi
fi

[[ "$ALL_PASSED" == "true" ]] && exit 0 || exit 1
