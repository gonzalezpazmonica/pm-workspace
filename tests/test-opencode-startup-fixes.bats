#!/usr/bin/env bats
# test-opencode-startup-fixes.bats — SE-234: OpenCode startup error fixes

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
OPENCODE_JSON="$REPO_ROOT/opencode.json"
OPENCODE_DIR="$REPO_ROOT/.opencode"
DOC_FILE="$REPO_ROOT/docs/rules/domain/opencode-known-startup-issues.md"

# ── Fix 1: ppt MCP removed ────────────────────────────────────────────────

@test "Fix1: ppt MCP entry is not present in opencode.json" {
  run python3 -c "
import json, sys
d = json.load(open('$OPENCODE_JSON'))
mcp = d.get('mcp', {})
if 'ppt' in mcp:
    print('ppt entry still present')
    sys.exit(1)
sys.exit(0)
"
  [ "$status" -eq 0 ]
}

@test "Fix1: opencode.json is valid JSON after ppt removal" {
  run python3 -c "import json; json.load(open('$OPENCODE_JSON'))"
  [ "$status" -eq 0 ]
}

@test "Fix1: codebase-memory-mcp is still present in mcp config" {
  run python3 -c "
import json, sys
d = json.load(open('$OPENCODE_JSON'))
if 'codebase-memory-mcp' not in d.get('mcp', {}):
    sys.exit(1)
sys.exit(0)
"
  [ "$status" -eq 0 ]
}

@test "Fix1: no literal \$HOME in any MCP command string" {
  run python3 -c "
import json, sys
d = json.load(open('$OPENCODE_JSON'))
for name, cfg in d.get('mcp', {}).items():
    for part in cfg.get('command', []):
        if '\$HOME' in str(part) or '\$USER' in str(part):
            print(f'literal env var in {name}: {part}')
            sys.exit(1)
sys.exit(0)
"
  [ "$status" -eq 0 ]
}

# ── Fix 2: .opencode/.claude symlink removed ─────────────────────────────

@test "Fix2: .opencode/.claude symlink does not exist" {
  [ ! -e "$OPENCODE_DIR/.claude" ]
}

@test "Fix2: .opencode/skills symlink exists (primary skill path preserved)" {
  [ -L "$OPENCODE_DIR/skills" ]
}

@test "Fix2: .opencode/skills points to ../.claude/skills" {
  local target
  target=$(readlink "$OPENCODE_DIR/skills")
  [[ "$target" == "../.claude/skills" ]] || [[ "$target" == "../.claude/skills/" ]]
}

@test "Fix2: .opencode/commands symlink still exists" {
  [ -L "$OPENCODE_DIR/commands" ]
}

@test "Fix2: .opencode/hooks symlink still exists" {
  [ -L "$OPENCODE_DIR/hooks" ]
}

@test "Fix2: .opencode/agents is a real directory (not symlink)" {
  [ -d "$OPENCODE_DIR/agents" ]
  [ ! -L "$OPENCODE_DIR/agents" ]
}

# ── Fix 3: -32601 documented as known false positive ─────────────────────

@test "Fix3: opencode-known-startup-issues.md exists" {
  [ -f "$DOC_FILE" ]
}

@test "Fix3: known-issues doc mentions -32601 error" {
  grep -q "32601\|Method not found" "$DOC_FILE"
}

@test "Fix3: known-issues doc mentions ppt fix" {
  grep -qi "ppt" "$DOC_FILE"
}

@test "Fix3: known-issues doc mentions duplicate skill fix" {
  grep -qi "duplicate\|\.opencode/\.claude\|symlink" "$DOC_FILE"
}
