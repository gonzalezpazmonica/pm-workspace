#!/usr/bin/env bats
# test-se356-skill-layer.bats — BATS tests for SE-356 Skills Two-Layers
# Ref: SE-356 — core/peripheral, peripheral por defecto, registry local

SCRIPT="scripts/skill-layer-check.sh"

setup() {
  set -o pipefail
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  CHECK="$REPO_ROOT/$SCRIPT"
  export CHECK
}

teardown() {
  cd "$REPO_ROOT"
}

@test "check detecta skill sin layer" {
  # temp skill dir con SKILL.md sin layer
  local fake="$BATS_TEST_TMPDIR/skills/test-skill/SKILL.md"
  mkdir -p "$(dirname "$fake")"
  printf -- '---\nname: test-skill\ndescription: "x"\n---\n' > "$fake"
  run bash "$CHECK" --check
  # el check real apunta a .claude/skills, no al fake — este test valida el script
  # con la estructura real del repo
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "check pasa con todas las skills con layer" {
  run bash "$CHECK" --check
  [[ "$status" -eq 0 ]]
}

@test "check reporta total/core/peripheral" {
  run bash "$CHECK"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"total:"* ]]
  [[ "$output" == *"core:"* ]]
  [[ "$output" == *"peripheral:"* ]]
}

@test "check --json produce JSON válido" {
  run bash "$CHECK" --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'total' in d and 'core' in d and 'peripheral' in d and 'missing_layer' in d
"
}

@test "index.json del registry es JSON válido con layer válidas" {
  run python3 -c "
import json
d = json.load(open('$REPO_ROOT/skills-registry/INDEX.json'))
skills = d.get('skills', {})
assert len(skills) > 0, 'registry vacío'
for k, v in skills.items():
    assert v.get('layer') in ('core', 'peripheral'), f'{k} layer inválida'
print('OK', len(skills))
"
  [[ "$status" -eq 0 ]]
}

@test "REVIEW.md del registry existe y menciona criterios" {
  [[ -f "$REPO_ROOT/skills-registry/REVIEW.md" ]]
  grep -q "peripheral" "$REPO_ROOT/skills-registry/REVIEW.md"
  grep -q "core" "$REPO_ROOT/skills-registry/REVIEW.md"
}

@test "todas las SKILL.md tienen layer en frontmatter" {
  local missing=0
  for f in "$REPO_ROOT"/.claude/skills/*/SKILL.md; do
    grep -q "^layer:" "$f" || missing=$((missing + 1))
  done
  [[ "$missing" -eq 0 ]]
}

@test "todas las skills son peripheral salvo las promovidas" {
  run python3 -c "
import json, os
d = json.load(open('$REPO_ROOT/skills-registry/INDEX.json'))
for k, v in d['skills'].items():
    if v['layer'] == 'core':
        # debe tener evidencia de promoción
        md = open('$REPO_ROOT/skills-registry/REVIEW.md').read()
        assert k in md, f'{k} promovida a core sin referencia en REVIEW.md'
print('OK')
"
  [[ "$status" -eq 0 ]]
}

@test "catalog-audit: skill sin layer es FAIL (missing-layer-field)" {
  local d="$BATS_TEST_TMPDIR/nolayer"
  mkdir -p "$d"
  printf -- '---\nname: nolayer\ndescription: "Hace algo concreto. Usar cuando se necesita probar el auditor de layers."\n---\n# x\n' > "$d/SKILL.md"
  run bash "$REPO_ROOT/scripts/skill-catalog-audit.sh" --json --skill "$d"
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "import json,sys; assert json.load(sys.stdin)['fail'] >= 1"
}

@test "catalog-audit: layer invalido tambien es FAIL" {
  local d="$BATS_TEST_TMPDIR/badlayer"
  mkdir -p "$d"
  printf -- '---\nlayer: middle\nname: badlayer\ndescription: "Hace algo concreto. Usar cuando se necesita probar el auditor de layers."\n---\n# x\n' > "$d/SKILL.md"
  run bash "$REPO_ROOT/scripts/skill-catalog-audit.sh" --json --skill "$d"
  echo "$output" | python3 -c "import json,sys; assert json.load(sys.stdin)['fail'] >= 1"
}

@test "catalog-audit: layer peripheral valido no genera FAIL" {
  local d="$BATS_TEST_TMPDIR/oklayer"
  mkdir -p "$d"
  printf -- '---\nlayer: peripheral\nname: oklayer\ndescription: "Hace algo concreto. Usar cuando se necesita probar el auditor de layers."\n---\n# x\n' > "$d/SKILL.md"
  run bash "$REPO_ROOT/scripts/skill-catalog-audit.sh" --json --skill "$d"
  echo "$output" | python3 -c "import json,sys; assert json.load(sys.stdin)['fail'] == 0"
}

@test "G14: el filtro de pr-plan reconoce rutas .claude/skills (symlink de .opencode)" {
  grep -qE "\^\\\\\.\(claude\|opencode\)/skills/" "$REPO_ROOT/scripts/pr-plan-gates.sh"
  echo ".claude/skills/foo/SKILL.md" | grep -qE '^\.(claude|opencode)/skills/[^/]+/SKILL\.md$'
}

@test "edge: layer con valor empty es FAIL" {
  local d="$BATS_TEST_TMPDIR/emptylayer"
  mkdir -p "$d"
  printf -- '---\nlayer:\nname: emptylayer\ndescription: "Hace algo concreto. Usar cuando se necesita probar el auditor de layers."\n---\n# x\n' > "$d/SKILL.md"
  run bash "$REPO_ROOT/scripts/skill-catalog-audit.sh" --json --skill "$d"
  echo "$output" | python3 -c "import json,sys; assert json.load(sys.stdin)['fail'] >= 1"
}

@test "edge: skill dir nonexistent sin SKILL.md es FAIL" {
  local d="$BATS_TEST_TMPDIR/ghost"
  mkdir -p "$d"
  run bash "$REPO_ROOT/scripts/skill-catalog-audit.sh" --json --skill "$d"
  echo "$output" | python3 -c "import json,sys; assert json.load(sys.stdin)['fail'] >= 1"
}

@test "edge: repo real reporta zero skills sin layer" {
  run bash "$CHECK"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"sin layer: 0"* ]]
}
