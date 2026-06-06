#!/usr/bin/env bats
# tests/test-se-203-skill-keyword-triggers.bats
# SE-203 — Keyword triggers para skills
# Ref: docs/propuestas/SE-203-skill-keyword-triggers.md

DETECTOR="scripts/skill-keyword-detector.sh"
SKILLS_DIR=".opencode/skills"

setup() {
  TMPDIR_TEST="$(mktemp -d)"
  # Use absolute path so find -L follows symlinks correctly
  export SAVIA_SKILLS_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)/.opencode/skills"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  unset SAVIA_SKILLS_DIR
}

# ── Existence & executability ─────────────────────────────────────────────────

@test "SE-203: skill-keyword-detector.sh exists" {
  [ -f "$DETECTOR" ]
}

@test "SE-203: skill-keyword-detector.sh is executable" {
  [ -x "$DETECTOR" ]
}

# ── set -uo pipefail ──────────────────────────────────────────────────────────

@test "SE-203: skill-keyword-detector.sh contains set -uo pipefail" {
  grep -q "set -uo pipefail" "$DETECTOR"
}

# ── SE-203 reference ──────────────────────────────────────────────────────────

@test "SE-203: SE-203 referenced in skill-keyword-detector.sh" {
  grep -q "SE-203" "$DETECTOR"
}

# ── Individual keyword detections ────────────────────────────────────────────

@test "SE-203: 'tdd' detects tdd-vertical-slices" {
  run bash "$DETECTOR" "quiero hacer tdd para este modulo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tdd-vertical-slices"* ]]
}

@test "SE-203: 'recuerda' detects savia-memory" {
  run bash "$DETECTOR" "recuerda este dato para la proxima sesion"
  [ "$status" -eq 0 ]
  [[ "$output" == *"savia-memory"* ]]
}

@test "SE-203: 'zoom out' detects zoom-out" {
  run bash "$DETECTOR" "necesito hacer zoom out antes de decidir la arquitectura"
  [ "$status" -eq 0 ]
  [[ "$output" == *"zoom-out"* ]]
}

@test "SE-203: 'hotspot' detects performance-audit" {
  run bash "$DETECTOR" "detecta hotspot en este servicio"
  [ "$status" -eq 0 ]
  [[ "$output" == *"performance-audit"* ]]
}

@test "SE-203: 'weekly' detects weekly-report" {
  run bash "$DETECTOR" "genera el weekly de esta semana"
  [ "$status" -eq 0 ]
  [[ "$output" == *"weekly-report"* ]]
}

@test "SE-203: 'grill' detects grill-me" {
  run bash "$DETECTOR" "grill this solution before we ship"
  [ "$status" -eq 0 ]
  [[ "$output" == *"grill-me"* ]]
}

@test "SE-203: 'sdd' detects spec-driven-development" {
  run bash "$DETECTOR" "escribe la sdd para este feature"
  [ "$status" -eq 0 ]
  [[ "$output" == *"spec-driven-development"* ]]
}

# ── case-insensitive ──────────────────────────────────────────────────────────

@test "SE-203: detection is case-insensitive (TDD uppercase)" {
  run bash "$DETECTOR" "Quiero implementar con TDD"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tdd-vertical-slices"* ]]
}

@test "SE-203: detection is case-insensitive (MEMORY uppercase)" {
  run bash "$DETECTOR" "Save this to MEMORY please"
  [ "$status" -eq 0 ]
  [[ "$output" == *"savia-memory"* ]]
}

# ── --list flag ───────────────────────────────────────────────────────────────

@test "SE-203: --list shows skills with triggers registered" {
  run bash "$DETECTOR" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"tdd-vertical-slices"* ]]
  [[ "$output" == *"savia-memory"* ]]
  [[ "$output" == *"zoom-out"* ]]
}

@test "SE-203: --list output contains at least 10 skills" {
  count=$(bash "$DETECTOR" --list | grep -v "^SKILL\|^-----" | grep -c ".")
  [ "$count" -ge 10 ]
}

# ── --json flag ───────────────────────────────────────────────────────────────

@test "SE-203: --json output is valid JSON array" {
  run bash "$DETECTOR" --json "quiero hacer tdd"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys, json; data=json.loads(sys.stdin.read()); assert isinstance(data, list)"
}

@test "SE-203: --json output contains tdd-vertical-slices for 'tdd' input" {
  result=$(bash "$DETECTOR" --json "quiero hacer tdd")
  echo "$result" | python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
assert 'tdd-vertical-slices' in data, f'tdd-vertical-slices not in {data}'
"
}

# ── empty input → exit 2 ─────────────────────────────────────────────────────

@test "SE-203: empty input exits with code 2" {
  run bash "$DETECTOR" ""
  [ "$status" -eq 2 ]
}

@test "SE-203: no arguments exits with code 2" {
  run bash "$DETECTOR"
  [ "$status" -eq 2 ]
}

# ── 10 skills have trigger.keywords in frontmatter ───────────────────────────

@test "SE-203: 10 skills have trigger.keywords in their SKILL.md frontmatter" {
  count=0
  for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
    if grep -q "trigger:" "$skill_md" && grep -q "keywords:" "$skill_md"; then
      count=$((count + 1))
    fi
  done
  [ "$count" -ge 10 ]
}

# ── skill-trigger-map.md ──────────────────────────────────────────────────────

@test "SE-203: skill-trigger-map.md exists" {
  [ -f "docs/rules/domain/skill-trigger-map.md" ]
}

@test "SE-203: skill-trigger-map.md has context_tier and token_budget frontmatter" {
  grep -q "context_tier" "docs/rules/domain/skill-trigger-map.md"
  grep -q "token_budget" "docs/rules/domain/skill-trigger-map.md"
}

# ── edge: input with no matching keywords → empty output, exit 0 ─────────────

@test "SE-203: input with no matching keywords produces empty output and exit 0" {
  run bash "$DETECTOR" "este texto no contiene ninguna palabra clave registrada aqui xyzzy"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ── multi-match ───────────────────────────────────────────────────────────────

@test "SE-203: multi-match returns multiple skills when multiple keywords match" {
  # 'tdd' triggers tdd-vertical-slices, 'memory' triggers savia-memory
  run bash "$DETECTOR" "quiero hacer tdd y tambien guardar en memory"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tdd-vertical-slices"* ]]
  [[ "$output" == *"savia-memory"* ]]
}

# ── Spanish keywords ─────────────────────────────────────────────────────────

@test "SE-203: Spanish keyword 'lento' detects performance-audit" {
  run bash "$DETECTOR" "el servicio esta muy lento en produccion"
  [ "$status" -eq 0 ]
  [[ "$output" == *"performance-audit"* ]]
}

@test "SE-203: Spanish keyword 'grafo' detects knowledge-graph" {
  run bash "$DETECTOR" "construye el grafo de dependencias"
  [ "$status" -eq 0 ]
  [[ "$output" == *"knowledge-graph"* ]]
}
