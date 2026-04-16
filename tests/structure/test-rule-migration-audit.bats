#!/usr/bin/env bats
# Tests for rule migration audit: .claude/rules/ → docs/rules/

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  ROOT="$PWD"
}

@test "no stale .claude/rules/domain/ refs in commands" {
  run grep -r '\.claude/rules/domain/' .claude/commands/ --include='*.md' -l
  # Filter out pm-config.local.md refs (stays in .claude/rules/)
  if [ "$status" -eq 0 ]; then
    filtered=$(echo "$output" | while read -r f; do
      grep '\.claude/rules/domain/' "$f" | grep -v 'pm-config\.local' && echo "$f"
    done)
    [ -z "$filtered" ]
  fi
}

@test "no stale .claude/rules/domain/ refs in skills" {
  run grep -r '\.claude/rules/domain/' .claude/skills/ --include='*.md' -l
  if [ "$status" -eq 0 ]; then
    filtered=$(echo "$output" | while read -r f; do
      grep '\.claude/rules/domain/' "$f" | grep -v 'pm-config\.local' && echo "$f"
    done)
    [ -z "$filtered" ]
  fi
}

@test "no stale .claude/rules/domain/ refs in agents" {
  run grep -r '\.claude/rules/domain/' .claude/agents/ --include='*.md' -l
  if [ "$status" -eq 0 ]; then
    filtered=$(echo "$output" | while read -r f; do
      grep '\.claude/rules/domain/' "$f" | grep -v 'pm-config\.local' && echo "$f"
    done)
    [ -z "$filtered" ]
  fi
}

@test "no stale .claude/rules/languages/ refs in agents" {
  run grep -rl '\.claude/rules/languages/' .claude/agents/ --include='*.md'
  [ "$status" -ne 0 ]
}

@test "no stale .claude/rules/languages/ refs in commands" {
  run grep -rl '\.claude/rules/languages/' .claude/commands/ --include='*.md'
  [ "$status" -ne 0 ]
}

@test "rules directory exists at docs/rules/domain" {
  [ -d "$ROOT/docs/rules/domain" ]
  local count
  count=$(ls "$ROOT/docs/rules/domain/"*.md 2>/dev/null | wc -l)
  [ "$count" -gt 100 ]
}

@test "rules directory exists at docs/rules/languages" {
  [ -d "$ROOT/docs/rules/languages" ]
  local count
  count=$(ls "$ROOT/docs/rules/languages/"*.md 2>/dev/null | wc -l)
  [ "$count" -gt 5 ]
}

@test "CLAUDE.md uses docs/rules/ not .claude/rules/" {
  run grep -c '\.claude/rules/domain/' CLAUDE.md
  [ "$status" -ne 0 ] || [ "$output" = "0" ]
}

@test "all @docs/rules/domain refs resolve to existing files" {
  local broken=0
  while IFS= read -r ref; do
    file="docs/rules/domain/${ref}"
    if [ ! -f "$file" ]; then
      echo "BROKEN: $file" >&2
      ((broken++))
    fi
  done < <(grep -rohP '@docs/rules/domain/\K[a-z0-9_-]+\.md' \
    CLAUDE.md .claude/commands/ .claude/skills/ .claude/agents/ 2>/dev/null | sort -u)
  [ "$broken" -eq 0 ]
}

@test "all @docs/rules/languages refs resolve to existing files" {
  local broken=0
  while IFS= read -r ref; do
    file="docs/rules/languages/${ref}"
    if [ ! -f "$file" ]; then
      echo "BROKEN: $file" >&2
      ((broken++))
    fi
  done < <(grep -rohP '@docs/rules/languages/\K[a-z0-9_-]+\.md' \
    .claude/commands/ .claude/skills/ .claude/agents/ 2>/dev/null | sort -u)
  [ "$broken" -eq 0 ]
}

@test "hooks match docs/rules/ paths" {
  run grep -l 'docs/rules' .claude/hooks/prompt-injection-guard.sh \
    .claude/hooks/validate-layer-contract.sh \
    .claude/hooks/agent-hook-premerge.sh \
    .claude/hooks/memory-auto-capture.sh 2>/dev/null
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | wc -l)
  [ "$count" -ge 3 ]
}

@test "check-file-size.sh covers docs/rules path" {
  grep -q 'docs/rules' .claude/compliance/checks/check-file-size.sh
}

@test "rule-usage-analyzer.sh uses docs/rules/domain" {
  grep -q 'docs/rules/domain' scripts/rule-usage-analyzer.sh
}

@test "claudeignore excludes docs/rules/ not .claude/rules/" {
  grep -q 'docs/rules/domain/' .claudeignore
  grep -q 'docs/rules/languages/' .claudeignore
}

@test "tier1 rules are exactly radical-honesty and autonomous-safety" {
  run bash -c "echo '' | $ROOT/scripts/rule-usage-analyzer.sh"
  [ "$status" -eq 0 ]
  local tier1_rules
  tier1_rules=$(echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
t1 = sorted(n for n, i in d['rules'].items() if i['tier'] == 'tier1')
print(' '.join(t1))
")
  [ "$tier1_rules" = "autonomous-safety.md radical-honesty.md" ]
}
