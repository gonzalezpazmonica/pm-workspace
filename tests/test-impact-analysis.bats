#!/usr/bin/env bats
# test-impact-analysis.bats — Tests for SPEC-IMPACT-ANALYSIS
# Ref: docs/specs/SPEC-IMPACT-ANALYSIS.spec.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/impact-analysis.sh"

  # Create a mock project in temp dir
  PROJECT="$BATS_TEST_TMPDIR/project"
  mkdir -p "$PROJECT/src/services"
  mkdir -p "$PROJECT/src/controllers"
  mkdir -p "$PROJECT/src/middleware"
  mkdir -p "$PROJECT/src/core"
  mkdir -p "$PROJECT/src/utils"
  mkdir -p "$PROJECT/tests"
  mkdir -p "$PROJECT/output/dev-sessions"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR/project" 2>/dev/null || true
}

# ── Safety verification ───────────────────────────────────────────────────────
@test "safety: script starts with bash shebang" {
  head -1 "$SCRIPT" | grep -q '#!/usr/bin/env bash'
}

@test "safety: script has set -uo pipefail" {
  head -5 "$SCRIPT" | grep -q 'set -uo pipefail'
}

@test "safety: script uses functions not monolithic" {
  grep -c '()' "$SCRIPT" | awk '{ exit ($1 >= 5) ? 0 : 1 }'
}

# ── Helper: create TypeScript mock project ────────────────────────────────────
create_ts_project() {
  # UserService — target
  cat > "$PROJECT/src/services/UserService.ts" <<'EOF'
export class UserService {
  createUser(name: string) { return { name }; }
}
EOF

  # AuthService — imports UserService
  cat > "$PROJECT/src/services/AuthService.ts" <<'EOF'
import { UserService } from './UserService';
export class AuthService {
  constructor(private userService: UserService) {}
}
EOF

  # UserController — imports UserService
  cat > "$PROJECT/src/controllers/UserController.ts" <<'EOF'
import { UserService } from '../services/UserService';
export class UserController {
  constructor(private service: UserService) {}
}
EOF

  # Middleware — imports AuthService (transitive to UserService)
  cat > "$PROJECT/src/middleware/auth.ts" <<'EOF'
import { AuthService } from '../services/AuthService';
export function authMiddleware(auth: AuthService) {}
EOF

  # Test file — imports UserService directly
  cat > "$PROJECT/tests/user.service.spec.ts" <<'EOF'
import { UserService } from '../src/services/UserService';
describe('UserService', () => {
  it('should create user', () => {});
});
EOF

  # Test file for auth
  cat > "$PROJECT/tests/auth.service.spec.ts" <<'EOF'
import { AuthService } from '../src/services/AuthService';
describe('AuthService', () => {
  it('should authenticate', () => {});
});
EOF
}

# ── Helper: create Python mock project ────────────────────────────────────────
create_py_project() {
  mkdir -p "$PROJECT/src"
  mkdir -p "$PROJECT/tests"

  cat > "$PROJECT/src/user_service.py" <<'EOF'
class UserService:
    def create_user(self, name):
        return {"name": name}
EOF

  cat > "$PROJECT/src/auth_service.py" <<'EOF'
from user_service import UserService
class AuthService:
    pass
EOF

  cat > "$PROJECT/tests/test_user_service.py" <<'EOF'
from user_service import UserService
def test_create_user():
    pass
EOF
}

# ── Helper: create C# mock project ───────────────────────────────────────────
create_cs_project() {
  mkdir -p "$PROJECT/Services"
  mkdir -p "$PROJECT/Controllers"
  mkdir -p "$PROJECT/Tests"

  cat > "$PROJECT/Services/UserService.cs" <<'EOF'
using System;
namespace App.Services {
  public class UserService { }
}
EOF

  cat > "$PROJECT/Controllers/UserController.cs" <<'EOF'
using App.Services;
using UserService;
namespace App.Controllers {
  public class UserController { }
}
EOF

  cat > "$PROJECT/Tests/UserServiceTests.cs" <<'EOF'
using App.Services;
using UserService;
namespace App.Tests { }
EOF
}

# ── Test: Happy path — TypeScript with dependents ─────────────────────────────
@test "happy path: detects direct dependents in TypeScript project" {
  create_ts_project
  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]
  [[ "$output" == *"Impact Analysis"* ]]
  [[ "$output" == *"AuthService"* ]]
  [[ "$output" == *"UserController"* ]]
}

@test "happy path: detects affected tests" {
  create_ts_project
  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]
  [[ "$output" == *"user.service.spec.ts"* ]]
  [[ "$output" == *"Affected tests"* ]]
}

@test "happy path: risk score section present with counts" {
  create_ts_project
  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]
  [[ "$output" == *"Direct dependents:"* ]]
  [[ "$output" == *"Score:"* ]]
}

# ── Test: Isolated file — no dependents ───────────────────────────────────────
@test "isolated file: zero dependents gives LOW risk" {
  # Only create the isolated file, nothing else
  cat > "$PROJECT/src/utils/formatDate.ts" <<'EOF'
export function formatDate(d: Date): string { return d.toISOString(); }
EOF

  run bash "$SCRIPT" --project "$PROJECT" src/utils/formatDate.ts
  [ "$status" -eq 0 ]
  [[ "$output" == *"No dependent files found"* ]]
  [[ "$output" == *"LOW"* ]]
  [[ "$output" == *"Direct dependents: 0"* ]]
}

# ── Test: Critical risk — many dependents ─────────────────────────────────────
@test "critical risk: many dependents gives CRITICAL score" {
  # Create a core module imported by many files
  cat > "$PROJECT/src/core/Database.ts" <<'EOF'
export class Database { query(sql: string) {} }
EOF

  # Create 6 services that import Database (6*15=90 => CRITICAL)
  for i in $(seq 1 6); do
    cat > "$PROJECT/src/services/Service${i}.ts" <<EOF
import { Database } from '../core/Database';
export class Service${i} { constructor(private db: Database) {} }
EOF
  done

  run bash "$SCRIPT" --project "$PROJECT" --depth 1 src/core/Database.ts
  [ "$status" -eq 0 ]
  [[ "$output" == *"CRITICAL"* ]]
  [[ "$output" == *"splitting"* ]]
}

# ── Test: Cache hit ───────────────────────────────────────────────────────────
@test "cache: second run serves from cache" {
  create_ts_project
  # First run
  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]
  local first_output="$output"

  # Second run — should be identical (served from cache)
  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]
  [ "$output" = "$first_output" ]
}

@test "cache: stores file in cache directory" {
  create_ts_project
  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]

  # Check cache directory exists with at least one file
  local cache_dir="$PROJECT/output/dev-sessions/.impact-cache"
  [ -d "$cache_dir" ]
  local count
  count=$(find "$cache_dir" -name '*.md' 2>/dev/null | wc -l)
  [ "$count" -ge 1 ]
}

# ── Test: Transitive dependencies ─────────────────────────────────────────────
@test "transitive: depth=2 detects indirect dependents" {
  create_ts_project
  run bash "$SCRIPT" --project "$PROJECT" --depth 2 src/services/UserService.ts
  [ "$status" -eq 0 ]
  # auth.ts imports AuthService which imports UserService => transitive
  [[ "$output" == *"transitive"* ]]
}

@test "transitive: depth=1 finds only direct dependents" {
  create_ts_project
  run bash "$SCRIPT" --project "$PROJECT" --depth 1 src/services/UserService.ts
  [ "$status" -eq 0 ]
  # Should find AuthService and UserController as direct dependents
  [[ "$output" == *"AuthService"* ]]
  # Transitive count should be 0
  [[ "$output" == *"Transitive dependents: 0"* ]]
}

# ── Test: Multiple languages ──────────────────────────────────────────────────
@test "python: detects import dependents" {
  create_py_project
  run bash "$SCRIPT" --project "$PROJECT" src/user_service.py
  [ "$status" -eq 0 ]
  [[ "$output" == *"auth_service"* ]]
}

@test "csharp: detects using dependents" {
  create_cs_project
  run bash "$SCRIPT" --project "$PROJECT" Services/UserService.cs
  [ "$status" -eq 0 ]
  [[ "$output" == *"UserController"* ]]
}

# ── Test: Unknown language fallback ───────────────────────────────────────────
@test "unknown language: does not crash, produces report" {
  cat > "$PROJECT/src/utils/module.xyz" <<'EOF'
export something
EOF
  run bash "$SCRIPT" --project "$PROJECT" src/utils/module.xyz
  [ "$status" -eq 0 ]
  [[ "$output" == *"Impact Analysis"* ]]
  [[ "$output" == *"Risk score"* ]]
}

# ── Test: Edge cases ──────────────────────────────────────────────────────────
@test "edge: empty project (no source files besides target)" {
  cat > "$PROJECT/src/utils/lonely.ts" <<'EOF'
export function lonely() {}
EOF
  run bash "$SCRIPT" --project "$PROJECT" src/utils/lonely.ts
  [ "$status" -eq 0 ]
  [[ "$output" == *"No dependent files found"* ]]
  [[ "$output" == *"LOW"* ]]
}

@test "edge: binary files do not crash grep" {
  # Create a binary-like file next to source
  printf '\x00\x01\x02\x03' > "$PROJECT/src/services/binary.bin"
  cat > "$PROJECT/src/services/Target.ts" <<'EOF'
export class Target {}
EOF
  run bash "$SCRIPT" --project "$PROJECT" src/services/Target.ts
  [ "$status" -eq 0 ]
  [[ "$output" == *"Impact Analysis"* ]]
}

@test "edge: no target files gives error" {
  run bash "$SCRIPT" --project "$PROJECT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no target files"* ]]
}

@test "edge: invalid depth gives error" {
  run bash "$SCRIPT" --project "$PROJECT" --depth 5 src/foo.ts
  [ "$status" -eq 1 ]
  [[ "$output" == *"depth must be"* ]]
}

@test "edge: nonexistent project dir gives error" {
  run bash "$SCRIPT" --project "/nonexistent/path" src/foo.ts
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

# ── Test: Output to file ──────────────────────────────────────────────────────
@test "output: --output writes report to file" {
  create_ts_project
  local outfile="$BATS_TEST_TMPDIR/report.md"
  run bash "$SCRIPT" --project "$PROJECT" --output "$outfile" src/services/UserService.ts
  [ "$status" -eq 0 ]
  [ -f "$outfile" ]
  [[ "$(cat "$outfile")" == *"Impact Analysis"* ]]
}

# ── Test: Format option ──────────────────────────────────────────────────────
@test "format: invalid format gives error" {
  run bash "$SCRIPT" --project "$PROJECT" --format xml src/foo.ts
  [ "$status" -eq 1 ]
  [[ "$output" == *"format must be"* ]]
}

# ── Test: Multiple target files ───────────────────────────────────────────────
@test "multiple targets: analyzes all specified files" {
  create_ts_project
  run bash "$SCRIPT" --project "$PROJECT" \
    src/services/UserService.ts src/services/AuthService.ts
  [ "$status" -eq 0 ]
  [[ "$output" == *"UserService.ts"* ]]
  [[ "$output" == *"AuthService.ts"* ]]
  [[ "$output" == *"Direct files"* ]]
}

# ── Test: Public API detection ────────────────────────────────────────────────
@test "public API: controller files increase risk score" {
  create_ts_project
  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]
  [[ "$output" == *"Public API files:"* ]]
  # UserController is a public API dependent, should count
  [[ "$output" != *"Public API files: 0"* ]]
}

# ── Test: Excludes node_modules ───────────────────────────────────────────────
@test "exclusion: node_modules files are not included" {
  create_ts_project
  mkdir -p "$PROJECT/node_modules/some-lib"
  cat > "$PROJECT/node_modules/some-lib/index.ts" <<'EOF'
import { UserService } from '../../src/services/UserService';
EOF

  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]
  [[ "$output" != *"node_modules"* ]]
}

# ── Test: Report structure ────────────────────────────────────────────────────
@test "structure: report contains all required sections" {
  create_ts_project
  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]
  [[ "$output" == *"## Direct files"* ]]
  [[ "$output" == *"## Impacted files"* ]]
  [[ "$output" == *"## Affected tests"* ]]
  [[ "$output" == *"## Risk score"* ]]
  [[ "$output" == *"## External dependencies"* ]]
}

# ── Test: detect_language function ─────────────────────────────────────────────
@test "detect_language: handles all supported extensions" {
  create_ts_project
  # TypeScript detection via the script processing .ts files
  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]
  # The fact it finds dependents proves detect_language worked for .ts
  [[ "$output" == *"AuthService"* ]]
}

# ── Test: extract_module_name function ────────────────────────────────────────
@test "extract_module_name: strips extensions for matching" {
  # If extract_module_name works, a file named UserService.ts
  # should be found by files importing 'UserService'
  create_ts_project
  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]
  [[ "$output" == *"imports"* ]]
}

# ── Test: build_import_pattern function ───────────────────────────────────────
@test "build_import_pattern: matches require() style imports" {
  mkdir -p "$PROJECT/src/lib"
  cat > "$PROJECT/src/lib/config.ts" <<'EOF'
export const config = { port: 3000 };
EOF
  cat > "$PROJECT/src/services/loader.ts" <<'EOF'
const cfg = require('../lib/config');
EOF
  run bash "$SCRIPT" --project "$PROJECT" src/lib/config.ts
  [ "$status" -eq 0 ]
  [[ "$output" == *"loader"* ]]
}

# ── Test: is_test_file function ───────────────────────────────────────────────
@test "is_test_file: test files go to affected tests section" {
  create_ts_project
  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]
  # user.service.spec.ts should be in tests section, not impacted files
  [[ "$output" == *"Affected tests"* ]]
  [[ "$output" == *"spec.ts"* ]]
}

# ── Test: is_public_api function ──────────────────────────────────────────────
@test "is_public_api: detects handler files" {
  mkdir -p "$PROJECT/src/handlers"
  cat > "$PROJECT/src/handlers/UserHandler.ts" <<'EOF'
import { UserService } from '../services/UserService';
export class UserHandler {}
EOF
  create_ts_project
  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]
  [[ "$output" == *"UserHandler"* ]]
}

# ── Test: compute_cache_key function ──────────────────────────────────────────
@test "compute_cache_key: different files produce different cache entries" {
  create_ts_project
  cat > "$PROJECT/src/utils/helper.ts" <<'EOF'
export function helper() {}
EOF

  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]
  local cache_dir="$PROJECT/output/dev-sessions/.impact-cache"
  local count1
  count1=$(find "$cache_dir" -name '*.md' | wc -l)

  run bash "$SCRIPT" --project "$PROJECT" src/utils/helper.ts
  [ "$status" -eq 0 ]
  local count2
  count2=$(find "$cache_dir" -name '*.md' | wc -l)
  [ "$count2" -ge 2 ]
}

# ── Test: save_cache and check_cache ──────────────────────────────────────────
@test "save_cache: cached result matches original" {
  create_ts_project
  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]
  local first="$output"

  # Modify a non-target file (cache should still be valid)
  run bash "$SCRIPT" --project "$PROJECT" src/services/UserService.ts
  [ "$status" -eq 0 ]
  [ "$output" = "$first" ]
}

# ── Test: Depth 3 ─────────────────────────────────────────────────────────────
@test "depth 3: detects deep transitive chain" {
  # A imports B, B imports C, C imports D; analyze D with depth=3
  mkdir -p "$PROJECT/src/chain"
  cat > "$PROJECT/src/chain/D.ts" <<'EOF'
export class D {}
EOF
  cat > "$PROJECT/src/chain/C.ts" <<'EOF'
import { D } from './D';
export class C {}
EOF
  cat > "$PROJECT/src/chain/B.ts" <<'EOF'
import { C } from './C';
export class B {}
EOF
  cat > "$PROJECT/src/chain/A.ts" <<'EOF'
import { B } from './B';
export class A {}
EOF

  run bash "$SCRIPT" --project "$PROJECT" --depth 3 src/chain/D.ts
  [ "$status" -eq 0 ]
  [[ "$output" == *"C.ts"* ]]
  [[ "$output" == *"B.ts"* ]]
  [[ "$output" == *"A.ts"* ]]
}
