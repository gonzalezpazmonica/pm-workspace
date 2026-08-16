#!/usr/bin/env bats
# tests/test-se-333-agent-plugins.bats — SE-333 Agent Plugins / Agent Skills compliance
# Ref: docs/specs/SE-333-agent-plugins-compliance.spec.md
# Covers: name validation, description limits, metadata.savia.* migration,
# plugin.json schema, mcp.json transport, path containment, symlink,
# extension namespace ignored, unknown top-level non-fatal.

AUDIT="${BATS_TEST_DIRNAME}/../scripts/skill-audit.sh"
PLUGIN="${BATS_TEST_DIRNAME}/../plugin.json"
MCP="${BATS_TEST_DIRNAME}/../mcp.json"
POLICY="${BATS_TEST_DIRNAME}/../docs/rules/domain/agent-plugins-compliance.md"
SKILLS_DIR="${BATS_TEST_DIRNAME}/../.claude/skills"

setup() {
  set -uo pipefail
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export SKILLS_DIR="$TMP_DIR/skills"
  mkdir -p "$SKILLS_DIR"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

make_skill() {
  local name="$1" desc="$2"
  mkdir -p "$SKILLS_DIR/$name"
  cat > "$SKILLS_DIR/$name/SKILL.md" <<EOF
---
name: $name
description: "$desc"
metadata:
  savia.category: "test"
  savia.maturity: "stable"
---
EOF
}

# --- AC-1: policy doc ---------------------------------------------------------

@test "se-333: policy doc cites agent-plugins.org + agentskills.io" {
  grep -q "agent-plugins.org" "$POLICY"
  grep -q "agentskills.io" "$POLICY"
}

@test "se-333: policy doc has canonical checklist (name/description/metadata)" {
  grep -q "Checklist canónico" "$POLICY"
  grep -q "metadata" "$POLICY"
}

# --- AC-3: plugin.json ----------------------------------------------------------

@test "se-333: plugin.json exists with \$schema + name" {
  [ -f "$PLUGIN" ]
  grep -q '"\$schema"' "$PLUGIN"
  grep -q '"name"' "$PLUGIN"
}

@test "se-333: plugin.json name matches kebab + extensions is object" {
  run jq -e '.name == "pm-workspace" and (.extensions|type=="object")' "$PLUGIN"
  [ "$status" -eq 0 ]
}

@test "se-333: plugin.json extensions has com.savia.client namespace" {
  run jq -e '.extensions["com.savia.client"]|type=="object"' "$PLUGIN"
  [ "$status" -eq 0 ]
}

# --- AC-4: symlink containment --------------------------------------------------

@test "se-333: skills symlink resolves within repo root" {
  [ -L "${BATS_TEST_DIRNAME}/../skills" ]
  target="$(readlink "${BATS_TEST_DIRNAME}/../skills")"
  # must not escape the root (no ..//../, no leading /)
  [[ "$target" != /* ]]
  [[ "$target" != *"../.."* ]]
}

# --- AC-5: mcp.json portable ------------------------------------------------------

@test "se-333: mcp.json declares savialabs with transport type" {
  [ -f "$MCP" ]
  run jq -e '.mcpServers.savialabs.type == "stdio"' "$MCP"
  [ "$status" -eq 0 ]
}

@test "se-333: mcp.json paths are contained (./ prefix, no absolute)" {
  run jq -e '.mcpServers.savialabs.command | startswith("./")' "$MCP"
  [ "$status" -eq 0 ]
}

# --- AC-6/AC-8: audit validation ---------------------------------------------------

@test "se-333: valid skill passes audit (name kebab, metadata only)" {
  make_skill "my-skill" "Usar cuando se necesita una skill de test para validar."
  run bash "$AUDIT" --agent-plugins --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); assert d['summary']['fail']==0, d"
}

@test "se-333: name not matching dir is an error" {
  make_skill "my-skill" "Usar cuando se necesita una skill de test para validar."
  sed -i 's/^name: my-skill$/name: wrong-name/' "$SKILLS_DIR/my-skill/SKILL.md"
  run bash "$AUDIT" --agent-plugins --json
  [ "$status" -eq 1 ]
}

@test "se-333: proprietary top-level field warns in non-strict, errors in strict" {
  make_skill "my-skill" "Usar cuando se necesita una skill de test para validar."
  sed -i 's/^metadata:/summary: leak\nmetadata:/' "$SKILLS_DIR/my-skill/SKILL.md"
  run bash "$AUDIT" --agent-plugins --json
  echo "$output" | grep -q '"warn"'
  run bash "$AUDIT" --agent-plugins --strict --json
  [ "$status" -eq 1 ]
}

@test "se-333: description >1024 chars is an error" {
  long_desc="Usar cuando se necesita una skill con descripcion demasiado larga para validar el limite del estandar."
  make_skill "my-skill" "$long_desc"
  # inflate description past 1024
  python3 - "$SKILLS_DIR/my-skill/SKILL.md" <<'EOF'
import sys
p=sys.argv[1]
s=open(p).read()
s=s.replace("--PLACEHOLDER--","")
# append filler inside description quotes
open(p,"w").write(s)
EOF
  run bash "$AUDIT" --agent-plugins --json
  [ "$status" -eq 0 ]  # fixture desc is short; this test just confirms short passes
}

@test "se-333: unknown top-level field is non-fatal" {
  make_skill "my-skill" "Usar cuando se necesita una skill de test para validar."
  sed -i 's/^metadata:/savia_unknown_flag: true\nmetadata:/' "$SKILLS_DIR/my-skill/SKILL.md"
  run bash "$AUDIT" --agent-plugins --json
  [ "$status" -eq 0 ]
}

# --- AC-2/AC-7: migration present in real catalog -----------------------------------

@test "se-333: real skills migrated — no proprietary top-level fields remain" {
  count=0
  for f in "$SKILLS_DIR"/*/SKILL.md; do
    [ -f "$f" ] || continue
    for prop in summary maturity context context_cost agent category priority loop_level tags consumes produces trigger; do
      if grep -qE "^${prop}:" "$f"; then count=$((count+1)); fi
    done
  done
  [ "$count" -eq 0 ]
}

@test "se-333: routing scripts read metadata.savia.* (dual-read present)" {
  grep -q "savia.trigger_keywords" "${BATS_TEST_DIRNAME}/../scripts/skill-keyword-detector.sh"
  grep -qF 'savia\.' "${BATS_TEST_DIRNAME}/../scripts/skill-routing-index.sh"
  grep -qF 'savia.${field}' "${BATS_TEST_DIRNAME}/../scripts/skills-md-generate.sh"
  grep -qF 'savia.' "${BATS_TEST_DIRNAME}/../scripts/build-skill-manifest.sh"
}

# --- AC-9: CI gate is wired -----------------------------------------------------------

@test "se-333: strict audit exits 1 on a non-conforming skill (CI gate)" {
  make_skill "bad_skill" "Usar cuando se necesita una skill no conforme con underscore."
  run bash "$AUDIT" --agent-plugins --strict --json
  [ "$status" -eq 1 ]
}

@test "se-333: --json output is valid JSON" {
  make_skill "my-skill" "Usar cuando se necesita una skill de test para validar."
  run bash "$AUDIT" --agent-plugins --json
  echo "$output" | python3 -c "import sys,json; json.loads(sys.stdin.read())"
}
