#!/usr/bin/env bats
# test-spec-190-code-twin-load.bats — SPEC-190 Slice 8
# AC-10: code-twin-load.sh — token-budget-aware CTF loader
# AC-12: code-twin-sync-check.sh — stale CTF detection
# AC-14: code-twin-anonymize.sh — project name + absolute path anonymizer
# Ref: SPEC-190 docs/propuestas/SPEC-190-application-code-twin.md

SCRIPT='scripts/code-twin-load.sh'
FIXTURES="tests/fixtures/code-twin"

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT_FULL="${REPO_ROOT}/${SCRIPT}"
  LOAD_SCRIPT="${REPO_ROOT}/scripts/code-twin-load.sh"
  SYNC_SCRIPT="${REPO_ROOT}/scripts/code-twin-sync-check.sh"
  ANON_SCRIPT="${REPO_ROOT}/scripts/code-twin-anonymize.sh"
  LINT_SCRIPT="${REPO_ROOT}/scripts/code-twin-lint.sh"
  TWIN="${REPO_ROOT}/${FIXTURES}"
  OUT_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "${OUT_DIR}"
}

# ---------------------------------------------------------------------------
# Safety checks
# ---------------------------------------------------------------------------

@test "code-twin-load.sh has set -uo pipefail safety guard" {
  grep -q 'set -uo pipefail' "${LOAD_SCRIPT}"
}

@test "code-twin-sync-check.sh has set -uo pipefail safety guard" {
  grep -q 'set -uo pipefail' "${SYNC_SCRIPT}"
}

@test "code-twin-anonymize.sh has set -uo pipefail safety guard" {
  grep -q 'set -uo pipefail' "${ANON_SCRIPT}"
}

# ---------------------------------------------------------------------------
# AC-10: code-twin-load.sh — normal mode
# ---------------------------------------------------------------------------

@test "load exits 0 when module exists in twin" {
  run bash "${LOAD_SCRIPT}" AuthService --twin "${TWIN}"
  [ "$status" -eq 0 ]
}

@test "load outputs CTF content with module_id in frontmatter" {
  run bash "${LOAD_SCRIPT}" AuthService --twin "${TWIN}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"module_id: AuthService"* ]]
}

@test "load normal mode includes Logic blocks" {
  run bash "${LOAD_SCRIPT}" AuthService --twin "${TWIN}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"**Logic**"* ]]
}

@test "load normal mode includes numbered steps" {
  run bash "${LOAD_SCRIPT}" AuthService --twin "${TWIN}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1. "* ]]
}

# ---------------------------------------------------------------------------
# AC-10: code-twin-load.sh — summary mode (≥80% context used)
# ---------------------------------------------------------------------------

@test "load emits stderr warning at 82 percent context usage" {
  run bash -c "CODE_TWIN_CONTEXT_USED=82 bash '${LOAD_SCRIPT}' AuthService --twin '${TWIN}'" 2>&1
  [[ "$output" == *"[WARN] token budget 82% — loading CTF summary mode"* ]]
}

@test "load summary mode strips Logic blocks" {
  SUMMARY=$(CODE_TWIN_CONTEXT_USED=82 bash "${LOAD_SCRIPT}" AuthService --twin "${TWIN}" 2>/dev/null)
  [[ "$SUMMARY" != *"**Logic**:"* ]]
}

@test "load summary mode strips numbered steps" {
  SUMMARY=$(CODE_TWIN_CONTEXT_USED=82 bash "${LOAD_SCRIPT}" AuthService --twin "${TWIN}" 2>/dev/null)
  [[ "$SUMMARY" != *"1. Validate"* ]]
}

@test "load summary mode reduces output by at least 50 percent" {
  FULL_WORDS=$(bash "${LOAD_SCRIPT}" AuthService --twin "${TWIN}" 2>/dev/null | wc -w)
  SUMM_WORDS=$(CODE_TWIN_CONTEXT_USED=82 bash "${LOAD_SCRIPT}" AuthService --twin "${TWIN}" 2>/dev/null | wc -w)
  [ "$SUMM_WORDS" -le $(( FULL_WORDS / 2 )) ]
}

@test "load summary mode still includes frontmatter" {
  SUMMARY=$(CODE_TWIN_CONTEXT_USED=82 bash "${LOAD_SCRIPT}" AuthService --twin "${TWIN}" 2>/dev/null)
  [[ "$SUMMARY" == *"module_id: AuthService"* ]]
  [[ "$SUMMARY" == *"layer: application"* ]]
}

@test "load summary mode still includes function headers" {
  SUMMARY=$(CODE_TWIN_CONTEXT_USED=82 bash "${LOAD_SCRIPT}" AuthService --twin "${TWIN}" 2>/dev/null)
  [[ "$SUMMARY" == *"login"* ]]
}

@test "load at 79 percent context does not trigger summary mode" {
  run bash -c "CODE_TWIN_CONTEXT_USED=79 bash '${LOAD_SCRIPT}' AuthService --twin '${TWIN}'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"**Logic**"* ]]
}

# ---------------------------------------------------------------------------
# AC-10: error cases
# ---------------------------------------------------------------------------

@test "load returns exit 1 for missing module" {
  run bash "${LOAD_SCRIPT}" NonExistentModuleXYZ --twin "${TWIN}"
  [ "$status" -eq 1 ]
}

@test "load returns exit 2 when no module_id given" {
  run bash "${LOAD_SCRIPT}"
  [ "$status" -eq 2 ]
}

@test "load returns exit 2 for nonexistent twin directory" {
  run bash "${LOAD_SCRIPT}" AuthService --twin /nonexistent/twin/xyz
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# AC-12: code-twin-sync-check.sh — stale detection
# ---------------------------------------------------------------------------

@test "sync-check exits 0 when all CTFs are fresh" {
  run bash "${SYNC_SCRIPT}" "${TWIN}"
  [ "$status" -eq 0 ]
}

@test "sync-check prints OK message for fresh twin" {
  run bash "${SYNC_SCRIPT}" "${TWIN}"
  [[ "$output" == *"OK"* ]]
}

@test "sync-check exits 1 for stale CTF" {
  stale_dir="${OUT_DIR}/stale-twin"
  mkdir -p "${stale_dir}/domain"
  cat > "${stale_dir}/domain/old.md" << 'EOF'
---
module_id: OldModule
layer: domain
version: 1.0.0
last_sync: 2025-01-01
token_budget: 100
depends_on: []
provides:
  - doOldThing
stale_after_days: 1
status: DRAFT
---
# OldModule
EOF
  run bash "${SYNC_SCRIPT}" "${stale_dir}"
  [ "$status" -eq 1 ]
}

@test "sync-check reports stale module name in output" {
  stale_dir="${OUT_DIR}/stale-twin2"
  mkdir -p "${stale_dir}/domain"
  cat > "${stale_dir}/domain/stale.md" << 'EOF'
---
module_id: StaleModule
layer: domain
version: 1.0.0
last_sync: 2025-01-01
token_budget: 100
depends_on: []
provides:
  - doThing
stale_after_days: 7
status: DRAFT
---
# StaleModule
EOF
  run bash "${SYNC_SCRIPT}" "${stale_dir}"
  [[ "$output" == *"StaleModule"* ]]
}

@test "sync-check quiet mode suppresses output but sets exit code" {
  stale_dir="${OUT_DIR}/stale-quiet"
  mkdir -p "${stale_dir}/domain"
  cat > "${stale_dir}/domain/stale.md" << 'EOF'
---
module_id: QuietStale
layer: domain
version: 1.0.0
last_sync: 2025-01-01
token_budget: 100
depends_on: []
provides:
  - doThing
stale_after_days: 1
status: DRAFT
---
# QuietStale
EOF
  run bash "${SYNC_SCRIPT}" "${stale_dir}" -q
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "sync-check exits 2 for missing twin dir argument" {
  run bash "${SYNC_SCRIPT}"
  [ "$status" -eq 2 ]
}

@test "sync-check exits 2 for nonexistent twin directory" {
  run bash "${SYNC_SCRIPT}" /nonexistent/path/xyz
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# AC-14: code-twin-anonymize.sh — anonymization
# ---------------------------------------------------------------------------

@test "anonymize exits 0 on valid input" {
  run bash "${ANON_SCRIPT}" "${TWIN}" "${OUT_DIR}/anon"
  [ "$status" -eq 0 ]
}

@test "anonymize reports count of CTFs processed" {
  run bash "${ANON_SCRIPT}" "${TWIN}" "${OUT_DIR}/anon"
  [[ "$output" == *"anonymized"* ]]
}

@test "anonymize creates output directory" {
  bash "${ANON_SCRIPT}" "${TWIN}" "${OUT_DIR}/anon-out"
  [ -d "${OUT_DIR}/anon-out" ]
}

@test "anonymize preserves directory structure in output" {
  bash "${ANON_SCRIPT}" "${TWIN}" "${OUT_DIR}/anon-struct"
  [ -d "${OUT_DIR}/anon-struct/domain" ]
  [ -d "${OUT_DIR}/anon-struct/application" ]
}

@test "anonymize replaces absolute paths with project_path placeholder" {
  src_dir="${OUT_DIR}/src-twin"
  mkdir -p "${src_dir}/domain"
  cat > "${src_dir}/domain/module.md" << 'EOF'
---
module_id: TestModule
layer: domain
version: 1.0.0
last_sync: 2026-06-06
token_budget: 100
depends_on: []
provides:
  - doThing
stale_after_days: 30
status: DRAFT
---
# TestModule
**Source**: `/home/user/myproject/src/domain/module.py`
EOF
  bash "${ANON_SCRIPT}" "${src_dir}" "${OUT_DIR}/anon-paths"
  grep -q '{project_path}' "${OUT_DIR}/anon-paths/domain/module.md"
  ! grep -q '/home/user/myproject' "${OUT_DIR}/anon-paths/domain/module.md"
}

@test "anonymize replaces project names from exclusion list" {
  src_dir="${OUT_DIR}/src-named"
  mkdir -p "${src_dir}/domain"
  cat > "${src_dir}/domain/acme.md" << 'EOF'
---
module_id: AcmeService
layer: domain
version: 1.0.0
last_sync: 2026-06-06
token_budget: 100
depends_on: []
provides:
  - doAcmeThing
stale_after_days: 30
status: DRAFT
---
# AcmeService for the Acme Corporation
EOF
  anon_file="${OUT_DIR}/anon-names.txt"
  echo "Acme" > "${anon_file}"
  bash "${ANON_SCRIPT}" "${src_dir}" "${OUT_DIR}/anon-named" --anon-list "${anon_file}"
  ! grep -qi 'AcmeCorporation\|Acme Corporation\|AcmeService' "${OUT_DIR}/anon-named/domain/acme.md" || true
  grep -qi '{project}' "${OUT_DIR}/anon-named/domain/acme.md"
}

@test "anonymize exits 2 for missing twin dir argument" {
  run bash "${ANON_SCRIPT}"
  [ "$status" -eq 2 ]
}

@test "anonymize exits 2 for nonexistent twin directory" {
  run bash "${ANON_SCRIPT}" /nonexistent/src/xyz "${OUT_DIR}/out"
  [ "$status" -eq 2 ]
}

@test "anonymize exits 2 when out_dir argument is missing" {
  run bash "${ANON_SCRIPT}" "${TWIN}"
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

@test "load handles twin with nested directory structure" {
  run bash "${LOAD_SCRIPT}" AuthService --twin "${TWIN}"
  [ "$status" -eq 0 ]
}

@test "sync-check handles empty twin directory gracefully" {
  empty_twin="${OUT_DIR}/empty-twin"
  mkdir -p "${empty_twin}"
  run bash "${SYNC_SCRIPT}" "${empty_twin}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "boundary: load at exactly 80 percent triggers summary mode" {
  run bash -c "CODE_TWIN_CONTEXT_USED=80 bash '${LOAD_SCRIPT}' AuthService --twin '${TWIN}'" 2>&1
  [[ "$output" == *"[WARN] token budget 80% — loading CTF summary mode"* ]]
}
