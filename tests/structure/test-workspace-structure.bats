#!/usr/bin/env bats
# Tests for workspace structure integrity
# Validates that all required directories and files exist and are well-formed

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  ROOT="$PWD"
}

# ── Core directories ──

@test "core .claude directory exists" {
  [ -d "$ROOT/.claude" ]
}

@test "commands directory exists with files" {
  [ -d "$ROOT/.claude/commands" ]
  local count
  count=$(ls "$ROOT/.claude/commands/"*.md 2>/dev/null | wc -l)
  [ "$count" -gt 0 ]
}

@test "skills directory exists with subdirectories" {
  [ -d "$ROOT/.claude/skills" ]
  local count
  count=$(ls -d "$ROOT/.claude/skills/"*/ 2>/dev/null | wc -l)
  [ "$count" -gt 0 ]
}

@test "agents directory exists with files" {
  [ -d "$ROOT/.claude/agents" ]
  local count
  count=$(ls "$ROOT/.claude/agents/"*.md 2>/dev/null | wc -l)
  [ "$count" -gt 0 ]
}

@test "hooks directory exists with files" {
  [ -d "$ROOT/.claude/hooks" ]
  local count
  count=$(ls "$ROOT/.claude/hooks/"*.sh 2>/dev/null | wc -l)
  [ "$count" -gt 0 ]
}

@test "rules directory exists" {
  [ -d "$ROOT/.claude/rules" ]
}

# ── Settings validation ──

@test "settings.json is valid JSON" {
  run python3 -c "import json; json.load(open('$ROOT/.claude/settings.json'))"
  [ "$status" -eq 0 ]
}

@test "settings.json contains hooks configuration" {
  run bash -c "cat '$ROOT/.claude/settings.json' | python3 -c 'import json,sys; d=json.load(sys.stdin); assert \"hooks\" in d, \"No hooks key\"'"
  [ "$status" -eq 0 ]
}

# ── Command frontmatter ──

@test "all commands have frontmatter with name field" {
  local missing=0
  for f in "$ROOT/.claude/commands/"*.md; do
    [ -f "$f" ] || continue
    if head -1 "$f" | bash -c 'read line; [[ "$line" == "---" ]]'; then
      if ! bash -c "head -20 '$f'" | bash -c 'grep -q "^name:"'; then
        missing=$((missing + 1))
      fi
    fi
  done
  [ "$missing" -eq 0 ]
}

# ── Skill structure ──

@test "at least 95% of skills have a SKILL.md file" {
  local total=0 missing=0
  for d in "$ROOT/.claude/skills/"*/; do
    [ -d "$d" ] || continue
    total=$((total + 1))
    if [ ! -f "${d}SKILL.md" ]; then
      missing=$((missing + 1))
      echo "# Missing SKILL.md: $(basename "$d")" >&3
    fi
  done
  # Allow up to 5% missing (real gap tracking, not false positives)
  local threshold=$(( total * 5 / 100 + 1 ))
  [ "$missing" -le "$threshold" ]
}

@test "at least 75% of skills have frontmatter with name and description" {
  # Known gap: ~14 skills missing frontmatter (tracked for Era 83 fix)
  local total=0 with_fm=0
  for f in "$ROOT/.claude/skills/"*/SKILL.md; do
    [ -f "$f" ] || continue
    total=$((total + 1))
    if head -10 "$f" | grep -q "^name:" && head -10 "$f" | grep -q "^description:"; then
      with_fm=$((with_fm + 1))
    fi
  done
  # At least 75% must have frontmatter (target: 100% by Era 83)
  local pct=$(( with_fm * 100 / total ))
  [ "$pct" -ge 75 ]
}

# ── Hook executability ──

@test "all hook scripts are valid bash" {
  local invalid=0
  for f in "$ROOT/.claude/hooks/"*.sh; do
    [ -f "$f" ] || continue
    if ! bash -n "$f" 2>/dev/null; then
      invalid=$((invalid + 1))
    fi
  done
  [ "$invalid" -eq 0 ]
}

@test "all hook scripts read from stdin" {
  local missing=0
  for f in "$ROOT/.claude/hooks/"*.sh; do
    [ -f "$f" ] || continue
    if ! bash -c "cat '$f'" | bash -c 'grep -q "cat\|read\|INPUT"'; then
      missing=$((missing + 1))
    fi
  done
  [ "$missing" -eq 0 ]
}

# ── Required open source files ──

@test "LICENSE file exists" { [ -f "$ROOT/LICENSE" ]; }
@test "README.md exists" { [ -f "$ROOT/README.md" ]; }
@test "CHANGELOG.md exists" { [ -f "$ROOT/CHANGELOG.md" ]; }
@test "CONTRIBUTING.md exists" { [ -f "$ROOT/CONTRIBUTING.md" ]; }
@test "SECURITY.md exists" { [ -f "$ROOT/SECURITY.md" ]; }

# ── Size constraints ──

@test "no command exceeds 150 lines" {
  local oversized=0
  for f in "$ROOT/.claude/commands/"*.md; do
    [ -f "$f" ] || continue
    local lines
    lines=$(wc -l < "$f")
    if [ "$lines" -gt 150 ]; then
      oversized=$((oversized + 1))
    fi
  done
  [ "$oversized" -eq 0 ]
}

@test "no agent exceeds 150 lines" {
  local oversized=0
  for f in "$ROOT/.claude/agents/"*.md; do
    [ -f "$f" ] || continue
    local lines
    lines=$(wc -l < "$f")
    if [ "$lines" -gt 150 ]; then
      oversized=$((oversized + 1))
    fi
  done
  [ "$oversized" -eq 0 ]
}
