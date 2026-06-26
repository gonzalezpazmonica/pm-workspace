#!/usr/bin/env bats
# test-spec-190-code-twin.bats — SPEC-190 MVP BATS suite
# Covers: code-twin-init.sh, code-twin-sync-check.sh, code-twin-agent.md,
#         code-twin-protocol.md, code-twin-generate.py
# Exit conventions: 0 = pass, non-zero = fail

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
INIT="$REPO_ROOT/scripts/code-twin-init.sh"
SYNC_CHECK="$REPO_ROOT/scripts/code-twin-sync-check.sh"
GENERATE="$REPO_ROOT/scripts/code-twin-generate.py"
AGENT_MD="$REPO_ROOT/.opencode/agents/code-twin-agent.md"
PROTOCOL_MD="$REPO_ROOT/docs/rules/domain/code-twin-protocol.md"
TS_FIXTURE="$REPO_ROOT/tests/fixtures/ts-sample/user.service.ts"

setup() {
  TMP_DIR="$(mktemp -d)"
  TMP_PROJECT="$TMP_DIR/project"
  mkdir -p "$TMP_PROJECT"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ---------------------------------------------------------------------------
# AC-1: code-twin-init.sh exists and generates manifest
# ---------------------------------------------------------------------------

@test "AC-1: code-twin-init.sh exists and is executable" {
  [ -f "$INIT" ]
  [ -x "$INIT" ]
}

@test "AC-1: init generates manifest.yaml in twin dir" {
  run bash "$INIT" "$TMP_PROJECT"
  [ "$status" -eq 0 ]
  [ -f "$TMP_PROJECT/code-twin/manifest.yaml" ]
}

@test "AC-1: manifest.yaml contains version field" {
  bash "$INIT" "$TMP_PROJECT"
  grep -q "^version:" "$TMP_PROJECT/code-twin/manifest.yaml"
}

@test "AC-1: manifest.yaml contains project field" {
  bash "$INIT" "$TMP_PROJECT"
  grep -q "^project:" "$TMP_PROJECT/code-twin/manifest.yaml"
}

@test "AC-1: manifest.yaml contains modules field" {
  bash "$INIT" "$TMP_PROJECT"
  grep -q "^modules:" "$TMP_PROJECT/code-twin/manifest.yaml"
}

@test "AC-1: init generates README.md" {
  bash "$INIT" "$TMP_PROJECT"
  [ -f "$TMP_PROJECT/code-twin/README.md" ]
}

# ---------------------------------------------------------------------------
# AC-2: code-twin-sync-check.sh exists and produces JSON
# ---------------------------------------------------------------------------

@test "AC-2: code-twin-sync-check.sh exists and is executable" {
  [ -f "$SYNC_CHECK" ]
  [ -x "$SYNC_CHECK" ]
}

@test "AC-2: sync-check produces valid JSON with --json flag" {
  # Create a twin with one fresh CTF
  local twin_dir="$TMP_DIR/twin"
  mkdir -p "$twin_dir"
  local today
  today="$(date +%Y-%m-%d)"
  cat > "$twin_dir/fresh.md" << CTF
---
module_id: FreshService
layer: application
version: "1.0.0"
last_sync: "${today}"
token_budget: 200
stale_after_days: 7
depends_on: []
provides:
  - doWork
status: STABLE
---
# FreshService
CTF

  run bash "$SYNC_CHECK" "$twin_dir" --json
  # valid JSON output
  echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)"
  [ "$?" -eq 0 ]
}

@test "AC-2: sync-check JSON has required keys" {
  local twin_dir="$TMP_DIR/twin2"
  mkdir -p "$twin_dir"
  local today
  today="$(date +%Y-%m-%d)"
  cat > "$twin_dir/svc.md" << CTF
---
module_id: SvcModule
layer: domain
version: "1.0.0"
last_sync: "${today}"
token_budget: 100
stale_after_days: 14
depends_on: []
provides:
  - run
status: STABLE
---
# SvcModule
CTF

  output_json="$(bash "$SYNC_CHECK" "$twin_dir" --json)"
  echo "$output_json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for k in ('total_ctfs','stale_count','fresh_count','stale_files'):
    assert k in d, f'missing key: {k}'
print('OK')
"
  [ "$?" -eq 0 ]
}

@test "AC-2: sync-check supports --twin-dir flag" {
  local twin_dir="$TMP_DIR/twin3"
  mkdir -p "$twin_dir"
  run bash "$SYNC_CHECK" --twin-dir "$twin_dir" --json
  # Empty twin returns JSON (no CTFs = all fresh)
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# AC-3: code-twin-agent.md exists
# ---------------------------------------------------------------------------

@test "AC-3: code-twin-agent.md exists" {
  [ -f "$AGENT_MD" ]
}

@test "AC-3: agent md has name field" {
  grep -q "^name:" "$AGENT_MD"
}

@test "AC-3: agent md references sync-check" {
  grep -q "code-twin-sync-check" "$AGENT_MD"
}

@test "AC-3: agent md has SIMULATION restriction note" {
  grep -q "SIMULATION" "$AGENT_MD"
}

# ---------------------------------------------------------------------------
# AC-4: protocol.md exists
# ---------------------------------------------------------------------------

@test "AC-4: code-twin-protocol.md exists" {
  [ -f "$PROTOCOL_MD" ]
}

@test "AC-4: protocol doc mentions stale_after_days" {
  grep -q "stale_after_days" "$PROTOCOL_MD"
}

@test "AC-4: protocol doc mentions anti-patterns" {
  grep -q -i "anti.pattern\|Anti-pattern" "$PROTOCOL_MD"
}

@test "AC-4: protocol doc defines valid layers" {
  grep -q "domain" "$PROTOCOL_MD"
  grep -q "application" "$PROTOCOL_MD"
  grep -q "infrastructure" "$PROTOCOL_MD"
}

# ---------------------------------------------------------------------------
# AC-5: init.sh does not fail in an empty project directory
# ---------------------------------------------------------------------------

@test "AC-5: init.sh handles empty project directory without error" {
  local empty_project="$TMP_DIR/empty-project"
  mkdir -p "$empty_project"
  run bash "$INIT" "$empty_project"
  [ "$status" -eq 0 ]
  [ -d "$empty_project/code-twin" ]
}

@test "AC-5: init.sh accepts --project flag" {
  local proj="$TMP_DIR/flagproject"
  mkdir -p "$proj"
  run bash "$INIT" --project "$proj"
  [ "$status" -eq 0 ]
  [ -d "$proj/code-twin" ]
}

@test "AC-5: init.sh accepts --project and --output flags" {
  local proj="$TMP_DIR/proj2"
  local outdir="$TMP_DIR/custom-twin"
  mkdir -p "$proj"
  run bash "$INIT" --project "$proj" --output "$outdir"
  [ "$status" -eq 0 ]
  [ -d "$outdir" ]
  [ -f "$outdir/manifest.yaml" ]
}

# ---------------------------------------------------------------------------
# AC-6: sync-check exits 0 when no CTFs exist
# ---------------------------------------------------------------------------

@test "AC-6: sync-check exits 0 on empty twin dir" {
  local empty_twin="$TMP_DIR/empty-twin"
  mkdir -p "$empty_twin"
  run bash "$SYNC_CHECK" "$empty_twin" --json
  [ "$status" -eq 0 ]
}

@test "AC-6: sync-check JSON stale_count=0 on empty dir" {
  local empty_twin="$TMP_DIR/empty-twin2"
  mkdir -p "$empty_twin"
  output_json="$(bash "$SYNC_CHECK" "$empty_twin" --json)"
  stale="$(echo "$output_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['stale_count'])")"
  [ "$stale" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Bonus: code-twin-generate.py exists and works
# ---------------------------------------------------------------------------

@test "generate.py exists" {
  [ -f "$GENERATE" ]
}

@test "generate.py exits 0 for valid Python file" {
  # Create a minimal Python file
  cat > "$TMP_DIR/svc.py" << 'PY'
class DataService:
    def fetch(self, id: str) -> dict:
        return {}
    def save(self, data: dict) -> bool:
        return True
PY
  run python3 "$GENERATE" --file "$TMP_DIR/svc.py" --output "$TMP_DIR/ctf-out"
  [ "$status" -eq 0 ]
  ls "$TMP_DIR/ctf-out/"*.md
}

@test "generate.py exits 2 for missing file" {
  run python3 "$GENERATE" --file "/nonexistent/file.py" --output "$TMP_DIR/out"
  [ "$status" -eq 2 ]
}

@test "generate.py produces CTF with frontmatter for TypeScript" {
  [ -f "$TS_FIXTURE" ] || skip "TypeScript fixture not found"
  run python3 "$GENERATE" --file "$TS_FIXTURE" --output "$TMP_DIR/ts-out" --lang typescript
  [ "$status" -eq 0 ]
  # Verify frontmatter present
  grep -q "module_id:" "$TMP_DIR/ts-out/"*.md
  grep -q "stale_after_days:" "$TMP_DIR/ts-out/"*.md
}
