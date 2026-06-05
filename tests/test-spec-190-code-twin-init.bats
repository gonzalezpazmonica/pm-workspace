#!/usr/bin/env bats
# SCRIPT='scripts/code-twin-init.sh'
# test-spec-190-code-twin-init.bats — BATS suite for SPEC-190 Slice 2 (init)
# Spec: SPEC-190 AC-3, AC-4, AC-5
# Score target: ≥80 (SPEC-055 quality gate)
# Exercises: scaffold mkdir meta domain application index.md CTI DRAFT stubs error-handling

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
INIT="$REPO_ROOT/scripts/code-twin-init.sh"
LINT="$REPO_ROOT/scripts/code-twin-lint.sh"

setup() {
  TMP_PROJECT="$(mktemp -d)/project"
  mkdir -p "$TMP_PROJECT"
}

teardown() {
  rm -rf "$(dirname "$TMP_PROJECT")"
}

# ---------------------------------------------------------------------------
# Happy path — structure
# ---------------------------------------------------------------------------

@test "init: creates code-twin/ dir inside project" {
  run bash "$INIT" "$TMP_PROJECT"
  [ "$status" -eq 0 ]
  [ -d "$TMP_PROJECT/code-twin" ]
}

@test "init: creates all 6 layer subdirs" {
  bash "$INIT" "$TMP_PROJECT"
  for layer in domain application infrastructure api frontend; do
    [ -d "$TMP_PROJECT/code-twin/$layer" ] || {
      echo "missing layer dir: $layer" >&2; return 1
    }
  done
}

@test "init: creates meta/ subdir" {
  bash "$INIT" "$TMP_PROJECT"
  [ -d "$TMP_PROJECT/code-twin/meta" ]
}

@test "init: creates infrastructure/db/seeds subdir" {
  bash "$INIT" "$TMP_PROJECT"
  [ -d "$TMP_PROJECT/code-twin/infrastructure/db/seeds" ]
}

@test "init: creates index.md (CTI)" {
  bash "$INIT" "$TMP_PROJECT"
  [ -f "$TMP_PROJECT/code-twin/index.md" ]
}

@test "init: index.md passes CTI lint" {
  bash "$INIT" "$TMP_PROJECT"
  run bash "$LINT" --index "$TMP_PROJECT/code-twin/index.md"
  [ "$status" -eq 0 ]
}

@test "init: index.md contains required CTI table columns" {
  bash "$INIT" "$TMP_PROJECT"
  grep -qE "\|\s*module_id\s*\|" "$TMP_PROJECT/code-twin/index.md"
  grep -qE "\|\s*layer\s*\|" "$TMP_PROJECT/code-twin/index.md"
  grep -qE "\|\s*tokens\s*\|" "$TMP_PROJECT/code-twin/index.md"
}

@test "init: creates meta/tech-stack.md stub" {
  bash "$INIT" "$TMP_PROJECT"
  [ -f "$TMP_PROJECT/code-twin/meta/tech-stack.md" ]
}

@test "init: tech-stack.md has status DRAFT" {
  bash "$INIT" "$TMP_PROJECT"
  grep -q "status: DRAFT" "$TMP_PROJECT/code-twin/meta/tech-stack.md"
}

@test "init: output mentions OK" {
  run bash "$INIT" "$TMP_PROJECT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK:"* ]]
}

# ---------------------------------------------------------------------------
# Domain stubs (AC-3)
# ---------------------------------------------------------------------------

@test "AC-3: creates domain/entities.md stub" {
  bash "$INIT" "$TMP_PROJECT"
  [ -f "$TMP_PROJECT/code-twin/domain/entities.md" ]
}

@test "AC-3: creates domain/value-objects.md stub" {
  bash "$INIT" "$TMP_PROJECT"
  [ -f "$TMP_PROJECT/code-twin/domain/value-objects.md" ]
}

@test "AC-3: creates domain/business-rules.md stub" {
  bash "$INIT" "$TMP_PROJECT"
  [ -f "$TMP_PROJECT/code-twin/domain/business-rules.md" ]
}

@test "AC-3: domain stubs have status DRAFT" {
  bash "$INIT" "$TMP_PROJECT"
  for stub in entities value-objects business-rules; do
    grep -q "status: DRAFT" "$TMP_PROJECT/code-twin/domain/${stub}.md" || {
      echo "stub missing DRAFT: $stub" >&2; return 1
    }
  done
}

@test "AC-3: domain stubs have layer: domain" {
  bash "$INIT" "$TMP_PROJECT"
  for stub in entities value-objects business-rules; do
    grep -q "^layer: domain" "$TMP_PROJECT/code-twin/domain/${stub}.md" || {
      echo "stub missing domain layer: $stub" >&2; return 1
    }
  done
}

@test "AC-3: domain stubs have all 8 required CTF frontmatter fields" {
  bash "$INIT" "$TMP_PROJECT"
  for field in module_id layer version last_sync token_budget depends_on provides stale_after_days; do
    grep -q "^${field}:" "$TMP_PROJECT/code-twin/domain/entities.md" || {
      echo "entities.md missing field: $field" >&2; return 1
    }
  done
}

@test "AC-3: domain DRAFT stubs are rejected by linter (by design)" {
  bash "$INIT" "$TMP_PROJECT"
  run bash "$LINT" "$TMP_PROJECT/code-twin/domain/entities.md"
  [ "$status" -eq 2 ]
  [[ "$output" == *"DRAFT"* ]]
}

# ---------------------------------------------------------------------------
# Application stubs (AC-4)
# ---------------------------------------------------------------------------

@test "AC-4: creates application/use-cases.md stub" {
  bash "$INIT" "$TMP_PROJECT"
  [ -f "$TMP_PROJECT/code-twin/application/use-cases.md" ]
}

@test "AC-4: creates application/commands.md stub" {
  bash "$INIT" "$TMP_PROJECT"
  [ -f "$TMP_PROJECT/code-twin/application/commands.md" ]
}

@test "AC-4: creates application/queries.md stub" {
  bash "$INIT" "$TMP_PROJECT"
  [ -f "$TMP_PROJECT/code-twin/application/queries.md" ]
}

@test "AC-4: application stubs have status DRAFT" {
  bash "$INIT" "$TMP_PROJECT"
  for stub in use-cases commands queries; do
    grep -q "status: DRAFT" "$TMP_PROJECT/code-twin/application/${stub}.md" || {
      echo "stub missing DRAFT: $stub" >&2; return 1
    }
  done
}

@test "AC-4: application stubs have layer: application" {
  bash "$INIT" "$TMP_PROJECT"
  for stub in use-cases commands queries; do
    grep -q "^layer: application" "$TMP_PROJECT/code-twin/application/${stub}.md" || {
      echo "stub missing application layer: $stub" >&2; return 1
    }
  done
}

@test "AC-4: application DRAFT stubs are rejected by linter (by design)" {
  bash "$INIT" "$TMP_PROJECT"
  run bash "$LINT" "$TMP_PROJECT/code-twin/application/use-cases.md"
  [ "$status" -eq 2 ]
  [[ "$output" == *"DRAFT"* ]]
}

# ---------------------------------------------------------------------------
# Infrastructure stubs (AC-5 extended)
# ---------------------------------------------------------------------------

@test "Slice3: creates infrastructure/db/schema.md stub" {
  bash "$INIT" "$TMP_PROJECT"
  [ -f "$TMP_PROJECT/code-twin/infrastructure/db/schema.md" ]
}

@test "Slice3: creates infrastructure/repos/example-repository.md stub" {
  bash "$INIT" "$TMP_PROJECT"
  [ -f "$TMP_PROJECT/code-twin/infrastructure/repos/example-repository.md" ]
}

@test "Slice3: creates infrastructure/external/example-client.md stub" {
  bash "$INIT" "$TMP_PROJECT"
  [ -f "$TMP_PROJECT/code-twin/infrastructure/external/example-client.md" ]
}

@test "Slice3: infrastructure stubs have status DRAFT" {
  bash "$INIT" "$TMP_PROJECT"
  for stub in "infrastructure/db/schema.md" "infrastructure/repos/example-repository.md" "infrastructure/external/example-client.md"; do
    grep -q "status: DRAFT" "$TMP_PROJECT/code-twin/${stub}" || {
      echo "stub missing DRAFT: $stub" >&2; return 1
    }
  done
}

@test "Slice3: infrastructure stubs have layer: infrastructure" {
  bash "$INIT" "$TMP_PROJECT"
  for stub in "infrastructure/db/schema.md" "infrastructure/repos/example-repository.md" "infrastructure/external/example-client.md"; do
    grep -q "^layer: infrastructure" "$TMP_PROJECT/code-twin/${stub}" || {
      echo "stub missing infrastructure layer: $stub" >&2; return 1
    }
  done
}

# ---------------------------------------------------------------------------
# Error handling (AC-5)
# ---------------------------------------------------------------------------

@test "AC-5: no args → exit 2 with usage" {
  run bash "$INIT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "AC-5: missing project dir → exit 2" {
  run bash "$INIT" "/tmp/nonexistent-project-xyz-$$"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

@test "AC-5: code-twin already exists → exit 1" {
  bash "$INIT" "$TMP_PROJECT"
  run bash "$INIT" "$TMP_PROJECT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}

@test "AC-5: second run does not overwrite existing code-twin" {
  bash "$INIT" "$TMP_PROJECT"
  # Manually modify entities.md
  echo "# custom" >> "$TMP_PROJECT/code-twin/domain/entities.md"
  run bash "$INIT" "$TMP_PROJECT"
  [ "$status" -eq 1 ]
  # custom content must still be there
  grep -q "# custom" "$TMP_PROJECT/code-twin/domain/entities.md"
}

# ---------------------------------------------------------------------------
# Safety & structure checks
# ---------------------------------------------------------------------------

@test "script has set -uo pipefail" {
  grep -q "set -uo pipefail" "$INIT"
}

@test "init is executable" {
  [ -x "$INIT" ]
}
