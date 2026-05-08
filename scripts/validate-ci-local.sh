#!/usr/bin/env bash
# ── validate-ci-local.sh — Parallel CI validation ────────────────────────
# Runs checks in parallel for speed (~5x faster on Windows).
# Usage: bash scripts/validate-ci-local.sh [--quick]
set -uo pipefail

QUICK_MODE=false; [ "${1:-}" = "--quick" ] && QUICK_MODE=true
TMPDIR_CI=$(mktemp -d 2>/dev/null || echo "/tmp/ci-$$"); mkdir -p "$TMPDIR_CI"
trap 'rm -rf "$TMPDIR_CI"' EXIT

echo ""
echo "--- Validacion CI Local — pm-workspace (parallel) ---"
echo ""

# ── Check functions (each writes result to tmpfile) ──────────────────────
check_branch() {
  local out="$TMPDIR_CI/0-branch"
  local b; b=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ "$b" == "main" || "$b" == "master" ]]; then
    echo "FAIL Branch: on $b" > "$out"
  else echo "PASS Branch: $b" > "$out"; fi
}

check_file_sizes() {
  local out="$TMPDIR_CI/1-sizes" fails=0 checked=0
  for pattern in ".opencode/commands/*.md" ".opencode/skills/*/SKILL.md" ".opencode/agents/*.md"; do
    for file in $pattern; do
      [ -f "$file" ] || continue; checked=$((checked+1))
      local lines; lines=$(wc -l < "$file")
      [ "$lines" -gt 150 ] && { echo "FAIL Size: $file ($lines lines)" >> "$out.fails"; fails=$((fails+1)); }
    done
  done
  if [ "$fails" -gt 0 ]; then cat "$out.fails" > "$out"
  else echo "PASS Sizes: $checked files OK" > "$out"; fi
  rm -f "$out.fails"
}

check_frontmatter() {
  local out="$TMPDIR_CI/2-frontmatter" fails=0 legacy=0
  for file in .opencode/commands/*.md; do
    [ -f "$file" ] || continue
    if head -1 "$file" | grep -q "^---$"; then
      grep -q "^name:" "$file" || { echo "FAIL FM: $file missing name" >> "$out.f"; fails=$((fails+1)); }
      grep -q "^description:" "$file" || { echo "FAIL FM: $file missing description" >> "$out.f"; fails=$((fails+1)); }
    else legacy=$((legacy+1)); fi
  done
  if [ "$fails" -gt 0 ]; then cat "$out.f" > "$out"
  else echo "PASS Frontmatter OK ($legacy legacy)" > "$out"; fi
  rm -f "$out.f"
}

check_settings_json() {
  local out="$TMPDIR_CI/3-settings"
  if [ -f ".claude/settings.json" ]; then
    if python3 -c "import json; json.load(open('.claude/settings.json'))" 2>/dev/null; then
      echo "PASS settings.json valid" > "$out"
    else echo "FAIL settings.json invalid JSON" > "$out"; fi
  else echo "WARN settings.json not found" > "$out"; fi
}

check_changelog() {
  local out="$TMPDIR_CI/4-changelog"
  if [ ! -f "CHANGELOG.md" ]; then echo "FAIL CHANGELOG.md not found" > "$out"; return; fi
  local m; m="<""<""<""<""<""<""<"
  if grep -qE "^${m}" CHANGELOG.md; then echo "FAIL CHANGELOG: merge conflict markers" > "$out"; return; fi
  local vers; vers=$(grep -oP '(?<=^## \[)[0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md)
  local dups; dups=$(echo "$vers" | sort | uniq -d)
  if [ -n "$dups" ]; then echo "FAIL CHANGELOG: duplicate versions: $dups" > "$out"; return; fi
  local count; count=$(echo "$vers" | wc -l)
  echo "PASS CHANGELOG OK ($count versions)" > "$out"
}

check_required_files() {
  local out="$TMPDIR_CI/5-required" fails=0
  for f in LICENSE README.md CHANGELOG.md CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md; do
    [ -f "$f" ] || { echo "FAIL Missing: $f" >> "$out.f"; fails=$((fails+1)); }
  done
  if [ "$fails" -gt 0 ]; then cat "$out.f" > "$out"
  else echo "PASS Required files present" > "$out"; fi
  rm -f "$out.f"
}

check_secrets() {
  local out="$TMPDIR_CI/6-secrets"
  if grep -rn --include="*.md" --include="*.sh" --include="*.json" --include="*.yml" \
    -E '[a-z0-9]{52}' --exclude-dir=".git" --exclude-dir="node_modules" \
    --exclude-dir="projects" \
    --exclude-dir="output" \
    . 2>/dev/null | grep -v "mock\|example\|placeholder\|test-data\|\"hash\"\|sha256\|Hash:" > /dev/null 2>&1; then
    echo "WARN Possible secret pattern detected" > "$out"
  else echo "PASS No secrets detected" > "$out"; fi
}

# ── Run checks in parallel ───────────────────────────────────────────────
check_branch &
check_file_sizes &
check_frontmatter &
check_settings_json &
check_changelog &
if ! $QUICK_MODE; then
  check_required_files &
  check_secrets &
fi
wait

# ── Collect results ──────────────────────────────────────────────────────
PASS=0; FAIL=0; WARN=0; ERRORS=""
for f in "$TMPDIR_CI"/*; do
  [ -f "$f" ] || continue
  while IFS= read -r line; do
    case "$line" in
      PASS*) PASS=$((PASS+1)); echo "  OK ${line#PASS }" ;;
      FAIL*) FAIL=$((FAIL+1)); ERRORS+="  ${line#FAIL }\n"; echo "  FAIL ${line#FAIL }" ;;
      WARN*) WARN=$((WARN+1)); echo "  WARN ${line#WARN }" ;;
    esac
  done < "$f"
done

echo ""
echo "--- Results: $PASS passed, $FAIL failed, $WARN warnings ---"

if [ "$FAIL" -gt 0 ]; then
  echo -e "\n  BLOCKED:\n$ERRORS"
  echo "  Run again after fixing: bash scripts/validate-ci-local.sh"
  exit 1
fi
echo ""
echo "  safe to push"
exit 0
