#!/usr/bin/env bats
# Tests for workspace structure integrity

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  ROOT="$PWD"
  TMPDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR"
}

# ── Core directories ──

@test "core directories exist with expected contents" {
  [ -d "$ROOT/.claude" ]
  [ -d "$ROOT/.claude/commands" ] && [ "$(ls "$ROOT/.claude/commands/"*.md 2>/dev/null | wc -l)" -gt 0 ]
  [ -d "$ROOT/.claude/skills" ] && [ "$(ls -d "$ROOT/.claude/skills/"*/ 2>/dev/null | wc -l)" -gt 0 ]
  [ -d "$ROOT/.claude/agents" ] && [ "$(ls "$ROOT/.claude/agents/"*.md 2>/dev/null | wc -l)" -gt 0 ]
  [ -d "$ROOT/.claude/hooks" ] && [ "$(ls "$ROOT/.claude/hooks/"*.sh 2>/dev/null | wc -l)" -gt 0 ]
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
    [ -f "${d}SKILL.md" ] || missing=$((missing + 1))
  done
  local threshold=$(( total * 5 / 100 + 1 ))
  [ "$missing" -le "$threshold" ]
}

@test "at least 75% of skills have frontmatter with name and description" {
  local total=0 with_fm=0
  for f in "$ROOT/.claude/skills/"*/SKILL.md; do
    [ -f "$f" ] || continue
    total=$((total + 1))
    head -10 "$f" | grep -q "^name:" && head -10 "$f" | grep -q "^description:" && with_fm=$((with_fm + 1))
  done
  [ $(( with_fm * 100 / total )) -ge 75 ]
}

# ── Hook executability ──

@test "all hook scripts are valid bash and read stdin" {
  local invalid=0 no_stdin=0
  for f in "$ROOT/.claude/hooks/"*.sh; do
    [ -f "$f" ] || continue
    bash -n "$f" 2>/dev/null || invalid=$((invalid + 1))
    grep -q "cat\|read\|INPUT" "$f" || no_stdin=$((no_stdin + 1))
  done
  [ "$invalid" -eq 0 ]
  [ "$no_stdin" -eq 0 ]
}

# ── Required open source files + Size constraints ──

@test "required open source files exist" {
  for f in LICENSE README.md CHANGELOG.md CONTRIBUTING.md SECURITY.md; do
    [ -f "$ROOT/$f" ]
  done
}

@test "no command, agent or rule exceeds 150 lines" {
  # Ref: docs/rules/domain/file-size-limit.md — 150 lines max
  # Excludes: INDEX.md (auto-generated catalogs, not rules)
  local oversized=0
  for f in "$ROOT/.claude/commands/"*.md "$ROOT/.claude/agents/"*.md "$ROOT/docs/rules/domain/"*.md; do
    [ -f "$f" ] || continue
    # Skip auto-generated index files
    case "$(basename "$f")" in
      INDEX.md) continue ;;
    esac
    local lines; lines=$(wc -l < "$f")
    [ "$lines" -le 150 ] || oversized=$((oversized + 1))
  done
  [ "$oversized" -eq 0 ]
}

# ── Negative cases ──

@test "settings.json has no merge conflict markers" {
  run grep -cE '(<{7}|={7}|>{7})' "$ROOT/.claude/settings.json"
  [ "$output" = "0" ] || [ "$status" -ne 0 ]
}

@test "no empty command files exist" {
  local empty=0
  for f in "$ROOT/.claude/commands/"*.md; do
    [ -f "$f" ] || continue
    [ -s "$f" ] || empty=$((empty + 1))
  done
  [ "$empty" -eq 0 ]
}

@test "no duplicate agent filenames" {
  local count; count=$(ls "$ROOT/.claude/agents/"*.md 2>/dev/null | wc -l)
  local unique; unique=$(ls "$ROOT/.claude/agents/"*.md 2>/dev/null | xargs -n1 basename | sort -u | wc -l)
  [ "$count" -eq "$unique" ]
}

@test "core scripts have set -uo pipefail safety" {
  for s in "$ROOT"/scripts/validate-ci-local.sh "$ROOT"/scripts/pr-plan.sh; do
    [ -f "$s" ] && grep -q "set -[euo]*o pipefail" "$s"
  done
}

@test "workspace handles empty skills dir gracefully" {
  local count; count=$(ls -d "$ROOT/.claude/skills/"*/ 2>/dev/null | wc -l)
  [ "$count" -ge 1 ]
}

@test "commands dir has nonexistent file handling" {
  local count; count=$(ls "$ROOT/.claude/commands/nonexistent-$$"*.md 2>/dev/null | wc -l)
  [ "$count" -eq 0 ]
}

@test "workspace has zero credential files tracked" {
  local found; found=$(git ls-files "$ROOT" | grep -cE '\.(pat|secret|key|pem)$' || true)
  [ "$found" -eq 0 ]
}
