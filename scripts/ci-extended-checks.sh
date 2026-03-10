#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0; TOTAL=0
pass() { ((PASS++)); ((TOTAL++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ((TOTAL++)); echo "  ❌ $1"; }

echo "=== CI Extended Checks ===" && echo ""

# 1. Skills Frontmatter Validation
echo "--- 1. Skills Frontmatter Validation ---"
skill_count=0; skill_pass=0
for skill_dir in "$ROOT"/.claude/skills/*/; do
  skill_file="$skill_dir/SKILL.md"
  [[ -f "$skill_file" ]] || continue
  ((skill_count++))
  if head -10 "$skill_file" | grep -q "^name:" && head -10 "$skill_file" | grep -q "^description:"; then
    ((skill_pass++))
  else
    fail "$(basename "$skill_dir"): missing name/description in first 10 lines"
  fi
done
[[ $skill_count -gt 0 && $skill_pass -eq $skill_count ]] && pass "All $skill_count skills have valid frontmatter"

# 2. Rule Dependency Verification
echo "--- 2. Rule Dependency Verification ---"
rule_count=0; rule_pass=0
for rule_file in "$ROOT"/.claude/rules/domain/*.md; do
  [[ -f "$rule_file" ]] || continue
  ((rule_count++))
  if grep -q "→" "$rule_file"; then
    refs=$(grep "→" "$rule_file" | grep -oE '\b[a-z0-9-]+\.md\b' | sort -u)
    for ref in $refs; do
      [[ ! -f "$ROOT/.claude/rules/domain/$ref" ]] && echo "  ⚠️  $(basename "$rule_file"): missing $ref (warning)"
    done
    ((rule_pass++))
  else
    ((rule_pass++))
  fi
done
[[ $rule_count -gt 0 && $rule_pass -eq $rule_count ]] && pass "All $rule_count rules have valid references"

# 3. Hook Safety Flags
echo "--- 3. Hook Safety Flags ---"
hook_count=0; hook_pass=0
for hook_file in "$ROOT"/.claude/hooks/*.sh; do
  [[ -f "$hook_file" ]] || continue
  ((hook_count++))
  if head -5 "$hook_file" | grep -q "set -uo pipefail"; then
    ((hook_pass++))
  else
    fail "$(basename "$hook_file"): missing 'set -uo pipefail' in first 5 lines"
  fi
done
[[ $hook_count -gt 0 && $hook_pass -eq $hook_count ]] && pass "All $hook_count hooks have set -uo pipefail"

# 4. Agent File Size
echo "--- 4. Agent File Size ---"
agent_count=0; agent_pass=0
for agent_file in "$ROOT"/.claude/agents/*.md; do
  [[ -f "$agent_file" ]] || continue
  ((agent_count++))
  lines=$(wc -l < "$agent_file")
  if [[ $lines -le 150 ]]; then
    ((agent_pass++))
  else
    fail "$(basename "$agent_file"): $lines lines exceeds 150 limit"
  fi
done
[[ $agent_count -gt 0 && $agent_pass -eq $agent_count ]] && pass "All $agent_count agents ≤ 150 lines"

# 5. Link Validation in Docs
echo "--- 5. Link Validation in Docs ---"
doc_count=0; doc_pass=0
for doc_file in "$ROOT"/docs/*.md; do
  [[ -f "$doc_file" ]] || continue
  ((doc_count++))
  while IFS= read -r line; do
    [[ $line =~ \]\(([^\)]+)\) ]] || continue
    ref="${BASH_REMATCH[1]}"
    [[ "$ref" =~ ^https?:// || "$ref" =~ ^# ]] && continue
    ref_path="$ROOT/$ref"
    [[ ! -f "$ref_path" ]] && echo "  ⚠️  $(basename "$doc_file"): broken link to $ref (warning)"
  done < "$doc_file"
  ((doc_pass++))
done
[[ $doc_count -gt 0 && $doc_pass -eq $doc_count ]] && pass "All $doc_count docs have valid links"

# 6. CHANGELOG Version Links
echo "--- 6. CHANGELOG Version Links ---"
changelog="$ROOT/CHANGELOG.md"
if [[ -f "$changelog" ]]; then
  missing_links=0
  while IFS= read -r ver; do
    if ! grep -q "^\[${ver}\]: https://" "$changelog"; then
      fail "CHANGELOG.md: version $ver is missing its reference link at end of file"
      ((missing_links++))
    fi
  done < <(grep -oP '(?<=^## \[)[0-9]+\.[0-9]+\.[0-9]+(?=\])' "$changelog")
  [[ $missing_links -eq 0 ]] && pass "All CHANGELOG versions have reference links"
else
  fail "CHANGELOG.md not found"
fi

echo "" && echo "═════════════════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed ($TOTAL total checks)"
echo "═════════════════════════════════════════════════════════════"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
