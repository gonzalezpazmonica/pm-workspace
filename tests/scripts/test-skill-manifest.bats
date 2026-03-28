#!/usr/bin/env bats
# test-skill-manifest.bats — Tests for build-skill-manifest.sh (SPEC-140)

setup() {
  export TMPDIR_SKILLS="$BATS_TEST_TMPDIR/skills"
  export TMPDIR_OUTPUT="$BATS_TEST_TMPDIR/skill-manifests.json"
  mkdir -p "$TMPDIR_SKILLS/test-skill-alpha"
  cat > "$TMPDIR_SKILLS/test-skill-alpha/SKILL.md" << 'EOF'
---
name: test-skill-alpha
description: "Test skill alpha para unit tests"
category: pm-operations
maturity: stable
---
Contenido del skill.
EOF
}

@test "build-skill-manifest: genera JSON valido" {
  run bash scripts/build-skill-manifest.sh "$TMPDIR_SKILLS" "$TMPDIR_OUTPUT"
  [ "$status" -eq 0 ]
  [[ -f "$TMPDIR_OUTPUT" ]]
  python3 -c "import json,sys; json.load(open('$TMPDIR_OUTPUT')); print('JSON valido')"
}

@test "build-skill-manifest: incluye campos obligatorios" {
  bash scripts/build-skill-manifest.sh "$TMPDIR_SKILLS" "$TMPDIR_OUTPUT"
  run python3 -c "
import json
m = json.load(open('$TMPDIR_OUTPUT'))
s = m['skills'][0]
assert 'name' in s, 'falta name'
assert 'description' in s, 'falta description'
assert 'path' in s, 'falta path'
assert 'tokens_est' in s, 'falta tokens_est'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == "OK" ]]
}

@test "build-skill-manifest: script es bash valido" {
  bash -n scripts/build-skill-manifest.sh
}
