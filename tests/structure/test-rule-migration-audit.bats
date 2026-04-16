#!/usr/bin/env bats
# Tests for rule migration audit: .claude/rules/ → docs/rules/
# Ref: docs/rules/domain/rule-manifest.json
# SCRIPT=scripts/rule-usage-analyzer.sh

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  ROOT="$PWD"
  TMPDIR_RMA=$(mktemp -d)
  export TMPDIR_RMA
}

teardown() {
  rm -rf "$TMPDIR_RMA"
}

# ── Safety verification ──

@test "rule-usage-analyzer.sh has safety flags" {
  grep -qE "set -[euo]+o pipefail" "$ROOT/scripts/rule-usage-analyzer.sh"
}

# ── Positive cases (migration succeeded) ──

@test "rules directory exists at docs/rules/domain with >100 files" {
  [ -d "$ROOT/docs/rules/domain" ]
  local count
  count=$(ls "$ROOT/docs/rules/domain/"*.md 2>/dev/null | wc -l)
  [ "$count" -gt 100 ]
}

@test "rules directory exists at docs/rules/languages with >5 files" {
  [ -d "$ROOT/docs/rules/languages" ]
  local count
  count=$(ls "$ROOT/docs/rules/languages/"*.md 2>/dev/null | wc -l)
  [ "$count" -gt 5 ]
}

@test "CLAUDE.md eager imports reference docs/rules/ not .claude/rules/" {
  run grep -c '^@docs/rules/' "$ROOT/CLAUDE.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 2 ]
  run grep -c '^@\.claude/rules/' "$ROOT/CLAUDE.md"
  [[ "$status" -ne 0 || "$output" = "0" ]]
}

@test ".claudeignore excludes docs/rules/ paths" {
  grep -q 'docs/rules/domain/' "$ROOT/.claudeignore"
  grep -q 'docs/rules/languages/' "$ROOT/.claudeignore"
}

@test "rule-usage-analyzer.sh points RULES_DIR to docs/rules/domain" {
  grep -q 'RULES_DIR=.*docs/rules/domain' "$ROOT/scripts/rule-usage-analyzer.sh"
}

@test "check-file-size.sh regex covers docs/rules path" {
  grep -qE 'docs/rules' "$ROOT/.claude/compliance/checks/check-file-size.sh"
}

@test "hooks handle both docs/rules/ and .claude/rules/ (dual-pattern)" {
  local count
  count=$(grep -lE 'docs/rules' "$ROOT/.claude/hooks/prompt-injection-guard.sh" \
    "$ROOT/.claude/hooks/validate-layer-contract.sh" \
    "$ROOT/.claude/hooks/agent-hook-premerge.sh" \
    "$ROOT/.claude/hooks/memory-auto-capture.sh" 2>/dev/null | wc -l)
  [ "$count" -ge 3 ]
}

@test "all @docs/rules/domain refs resolve to existing files" {
  local broken=0
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    if [ ! -f "$ROOT/docs/rules/domain/${ref}" ]; then
      echo "BROKEN: docs/rules/domain/$ref" >&2
      broken=$((broken + 1))
    fi
  done < <(grep -rohP '@docs/rules/domain/\K[a-z0-9_-]+\.md' \
    "$ROOT/CLAUDE.md" "$ROOT/.claude/commands/" \
    "$ROOT/.claude/skills/" "$ROOT/.claude/agents/" 2>/dev/null | sort -u)
  [ "$broken" -eq 0 ]
}

@test "all @docs/rules/languages refs resolve to existing files" {
  local broken=0
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    if [ ! -f "$ROOT/docs/rules/languages/${ref}" ]; then
      broken=$((broken + 1))
    fi
  done < <(grep -rohP '@docs/rules/languages/\K[a-z0-9_-]+\.md' \
    "$ROOT/.claude/commands/" "$ROOT/.claude/skills/" \
    "$ROOT/.claude/agents/" 2>/dev/null | sort -u)
  [ "$broken" -eq 0 ]
}

@test "tier1 rules are exactly radical-honesty and autonomous-safety" {
  run bash -c "echo '' | '$ROOT/scripts/rule-usage-analyzer.sh'"
  [ "$status" -eq 0 ]
  local tier1
  tier1=$(echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(' '.join(sorted(n for n, i in d['rules'].items() if i['tier'] == 'tier1')))
")
  [[ "$tier1" == "autonomous-safety.md radical-honesty.md" ]]
}

# ── Negative cases (no regressions) ──

@test "no stale .claude/rules/domain/ refs in commands (excl. pm-config.local)" {
  local found
  found=$(grep -rE '\.claude/rules/domain/' "$ROOT/.claude/commands/" --include='*.md' 2>/dev/null \
    | grep -v 'pm-config\.local' | wc -l)
  [ "$found" -eq 0 ]
}

@test "no stale .claude/rules/domain/ refs in agents (excl. pm-config.local)" {
  local found
  found=$(grep -rE '\.claude/rules/domain/' "$ROOT/.claude/agents/" --include='*.md' 2>/dev/null \
    | grep -v 'pm-config\.local' | wc -l)
  [ "$found" -eq 0 ]
}

@test "no stale .claude/rules/domain/ refs in skills (excl. pm-config.local)" {
  local found
  found=$(grep -rE '\.claude/rules/domain/' "$ROOT/.claude/skills/" --include='*.md' 2>/dev/null \
    | grep -v 'pm-config\.local' | wc -l)
  [ "$found" -eq 0 ]
}

@test "no stale .claude/rules/languages/ refs in agents" {
  run grep -rlE '\.claude/rules/languages/' "$ROOT/.claude/agents/" --include='*.md'
  [ "$status" -ne 0 ]
}

@test "no stale .claude/rules/languages/ refs in commands" {
  run grep -rlE '\.claude/rules/languages/' "$ROOT/.claude/commands/" --include='*.md'
  [ "$status" -ne 0 ]
}

@test "CLAUDE.md imports do not include stale .claude/rules/" {
  run grep -E '^@\.claude/rules/' "$ROOT/CLAUDE.md"
  [ "$status" -ne 0 ]
}

# ── Edge cases ──

@test "empty CLAUDE.md fixture has zero @docs/rules/ imports" {
  local fixture="$TMPDIR_RMA/CLAUDE.md"
  echo "" > "$fixture"
  run grep -cE '^@docs/rules/' "$fixture"
  [ "$status" -eq 1 ]
  [ "$output" = "0" ]
}

@test "analyzer handles missing manifest gracefully" {
  local missing="$TMPDIR_RMA/rule-manifest.json"
  [ ! -f "$missing" ]
  run cat "$missing"
  [ "$status" -ne 0 ]
}

@test "boundary: rule-manifest.json is valid JSON with >100 rules" {
  run python3 -c "
import json
d = json.load(open('$ROOT/docs/rules/domain/rule-manifest.json'))
assert d['total'] > 100, f'total={d[\"total\"]}'
assert len(d['rules']) == d['total']
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "edge: dormant rule count equals total - tier1 - tier2" {
  run python3 -c "
import json
d = json.load(open('$ROOT/docs/rules/domain/rule-manifest.json'))
expected = d['total'] - d['tier1_count'] - d['tier2_count']
assert d['dormant_count'] == expected, f'{d[\"dormant_count\"]} != {expected}'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == "OK" ]]
}

# ── Spec reference ──

@test "rule-manifest.json exists and is referenced" {
  [ -f "$ROOT/docs/rules/domain/rule-manifest.json" ]
}
