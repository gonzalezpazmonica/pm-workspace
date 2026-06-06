#!/usr/bin/env bats
# test-spec-190-code-twin-extract.bats — SPEC-190 Slice 7
# AC-7: TypeScript layer detection via @Injectable/@Controller/@Component decorators
# AC-8: C# layer detection via namespace segments (Domain/Application/Api)
# Ref: SPEC-190 docs/propuestas/SPEC-190-application-code-twin.md

SCRIPT='scripts/code-twin-extract.sh'
FIXTURES_TS="tests/fixtures/ts-sample"
FIXTURES_CS="tests/fixtures/cs-sample"

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT_FULL="${REPO_ROOT}/${SCRIPT}"
  TS_SRC="${REPO_ROOT}/${FIXTURES_TS}"
  CS_SRC="${REPO_ROOT}/${FIXTURES_CS}"
  OUT_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "${OUT_DIR}"
}

# ---------------------------------------------------------------------------
# Safety
# ---------------------------------------------------------------------------

@test "script has set -uo pipefail safety guard" {
  grep -q 'set -uo pipefail' "${SCRIPT_FULL}"
}

# ---------------------------------------------------------------------------
# AC-7: TypeScript — extraction and layer detection
# ---------------------------------------------------------------------------

@test "typescript extraction exits with code 0" {
  run bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  [ "$status" -eq 0 ]
}

@test "typescript extraction reports 3 ctfs in json output" {
  run bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d['extracted']==3 else 1)"
}

@test "typescript maps @Injectable decorator to application layer" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  [ -f "${OUT_DIR}/ts/application/user-service.md" ]
}

@test "typescript maps @Controller decorator to api layer" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  [ -f "${OUT_DIR}/ts/api/user-controller.md" ]
}

@test "typescript maps @Component decorator to frontend layer" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  [ -f "${OUT_DIR}/ts/frontend/user-list-component.md" ]
}

@test "typescript ctf has at least 3 function entries" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  count=$(grep -c '^####' "${OUT_DIR}/ts/application/user-service.md")
  [ "$count" -ge 3 ]
}

@test "typescript ctf layer value matches output directory path" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  layer=$(grep '^layer:' "${OUT_DIR}/ts/application/user-service.md" | awk '{print $2}')
  [[ "$layer" == "application" ]]
}

@test "typescript output json ctfs array has 3 entries" {
  run bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert len(d['ctfs'])==3, f'got {len(d[\"ctfs\"])}'"
}

@test "typescript output json ctfs include output_dir field" {
  run bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  [[ "$output" == *"output_dir"* ]]
}

@test "typescript generates index.md" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  [ -f "${OUT_DIR}/ts/index.md" ]
}

@test "typescript index.md contains all 3 module ids" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  grep -q 'UserService' "${OUT_DIR}/ts/index.md"
  grep -q 'UserController' "${OUT_DIR}/ts/index.md"
  grep -q 'UserListComponent' "${OUT_DIR}/ts/index.md"
}

# ---------------------------------------------------------------------------
# AC-7 + schema: frontmatter fields (8 required)
# ---------------------------------------------------------------------------

@test "typescript ctf frontmatter has module_id field" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  grep -q '^module_id:' "${OUT_DIR}/ts/application/user-service.md"
}

@test "typescript ctf frontmatter has layer field" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  grep -q '^layer:' "${OUT_DIR}/ts/application/user-service.md"
}

@test "typescript ctf frontmatter has version field" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  grep -q '^version:' "${OUT_DIR}/ts/application/user-service.md"
}

@test "typescript ctf frontmatter has last_sync field" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  grep -q '^last_sync:' "${OUT_DIR}/ts/application/user-service.md"
}

@test "typescript ctf frontmatter has token_budget field" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  grep -q '^token_budget:' "${OUT_DIR}/ts/application/user-service.md"
}

@test "typescript ctf frontmatter has provides field" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  grep -q '^provides:' "${OUT_DIR}/ts/application/user-service.md"
}

@test "typescript ctf frontmatter has stale_after_days field" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  grep -q '^stale_after_days:' "${OUT_DIR}/ts/application/user-service.md"
}

@test "typescript ctf frontmatter has status field" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  grep -q '^status:' "${OUT_DIR}/ts/application/user-service.md"
}

@test "typescript ctf token_budget is a positive integer" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  budget=$(grep '^token_budget:' "${OUT_DIR}/ts/application/user-service.md" | awk '{print $2}')
  [ "$budget" -gt 0 ]
}

@test "typescript ctf status is DRAFT" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/ts"
  grep -q '^status: DRAFT' "${OUT_DIR}/ts/application/user-service.md"
}

# ---------------------------------------------------------------------------
# AC-8: C# — extraction and layer detection
# ---------------------------------------------------------------------------

@test "csharp extraction exits with code 0" {
  run bash "${SCRIPT_FULL}" --lang csharp --src "${CS_SRC}" --out "${OUT_DIR}/cs"
  [ "$status" -eq 0 ]
}

@test "csharp extraction reports 3 ctfs in json output" {
  run bash "${SCRIPT_FULL}" --lang csharp --src "${CS_SRC}" --out "${OUT_DIR}/cs"
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d['extracted']==3 else 1)"
}

@test "csharp maps Project.Domain namespace to domain layer" {
  bash "${SCRIPT_FULL}" --lang csharp --src "${CS_SRC}" --out "${OUT_DIR}/cs"
  [ -f "${OUT_DIR}/cs/domain/user.md" ]
}

@test "csharp maps Project.Application namespace to application layer" {
  bash "${SCRIPT_FULL}" --lang csharp --src "${CS_SRC}" --out "${OUT_DIR}/cs"
  [ -f "${OUT_DIR}/cs/application/user-service.md" ]
}

@test "csharp maps Project.Api namespace to api layer" {
  bash "${SCRIPT_FULL}" --lang csharp --src "${CS_SRC}" --out "${OUT_DIR}/cs"
  [ -f "${OUT_DIR}/cs/api/users-controller.md" ]
}

@test "csharp ctf has at least 3 function entries" {
  bash "${SCRIPT_FULL}" --lang csharp --src "${CS_SRC}" --out "${OUT_DIR}/cs"
  count=$(grep -c '^####' "${OUT_DIR}/cs/domain/user.md")
  [ "$count" -ge 3 ]
}

@test "csharp ctf frontmatter has all 8 required fields" {
  bash "${SCRIPT_FULL}" --lang csharp --src "${CS_SRC}" --out "${OUT_DIR}/cs"
  f="${OUT_DIR}/cs/domain/user.md"
  grep -q '^module_id:' "$f"
  grep -q '^layer:' "$f"
  grep -q '^version:' "$f"
  grep -q '^last_sync:' "$f"
  grep -q '^token_budget:' "$f"
  grep -q '^provides:' "$f"
  grep -q '^stale_after_days:' "$f"
  grep -q '^status:' "$f"
}

@test "csharp ctf token_budget is a positive integer" {
  bash "${SCRIPT_FULL}" --lang csharp --src "${CS_SRC}" --out "${OUT_DIR}/cs"
  budget=$(grep '^token_budget:' "${OUT_DIR}/cs/domain/user.md" | awk '{print $2}')
  [ "$budget" -gt 0 ]
}

@test "csharp ctf layer value matches output directory path" {
  bash "${SCRIPT_FULL}" --lang csharp --src "${CS_SRC}" --out "${OUT_DIR}/cs"
  layer=$(grep '^layer:' "${OUT_DIR}/cs/domain/user.md" | awk '{print $2}')
  [[ "$layer" == "domain" ]]
}

@test "csharp generates index.md" {
  bash "${SCRIPT_FULL}" --lang csharp --src "${CS_SRC}" --out "${OUT_DIR}/cs"
  [ -f "${OUT_DIR}/cs/index.md" ]
}

# ---------------------------------------------------------------------------
# Error / failure cases
# ---------------------------------------------------------------------------

@test "missing --lang argument exits with error" {
  run bash "${SCRIPT_FULL}" --src "${TS_SRC}" --out "${OUT_DIR}/err"
  [ "$status" -ne 0 ]
}

@test "missing --src argument exits with error" {
  run bash "${SCRIPT_FULL}" --lang typescript --out "${OUT_DIR}/err"
  [ "$status" -ne 0 ]
}

@test "invalid language exits with error" {
  run bash "${SCRIPT_FULL}" --lang cobol --src "${TS_SRC}" --out "${OUT_DIR}/err"
  [ "$status" -ne 0 ]
}

@test "nonexistent source directory exits with error" {
  run bash "${SCRIPT_FULL}" --lang typescript --src "/nonexistent/path/xyz-absent" --out "${OUT_DIR}/err"
  [ "$status" -ne 0 ]
}

@test "no extractable classes returns failure exit code" {
  empty_dir="$(mktemp -d)"
  run bash "${SCRIPT_FULL}" --lang typescript --src "${empty_dir}" --out "${OUT_DIR}/empty"
  [ "$status" -ne 0 ]
  rm -rf "${empty_dir}"
}

# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

@test "nonexistent output dir is created automatically" {
  bash "${SCRIPT_FULL}" --lang typescript --src "${TS_SRC}" --out "${OUT_DIR}/new/nested/out"
  [ -d "${OUT_DIR}/new/nested/out" ]
}

@test "empty typescript file with no classes returns failure exit code" {
  empty_ts="$(mktemp -d)"
  touch "${empty_ts}/empty.ts"
  run bash "${SCRIPT_FULL}" --lang typescript --src "${empty_ts}" --out "${OUT_DIR}/emptyts"
  [ "$status" -ne 0 ]
  rm -rf "${empty_ts}"
}

@test "boundary case single ts file with one class produces 1 ctf" {
  single_dir="$(mktemp -d)"
  cat > "${single_dir}/thing.ts" << 'EOF'
import { Injectable } from '@angular/core';
@Injectable({ providedIn: 'root' })
export class ThingService {
  doWork(): void {}
}
EOF
  run bash "${SCRIPT_FULL}" --lang typescript --src "${single_dir}" --out "${OUT_DIR}/single"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['extracted']==1, f'expected 1 got {d[\"extracted\"]}'"
  rm -rf "${single_dir}"
}
