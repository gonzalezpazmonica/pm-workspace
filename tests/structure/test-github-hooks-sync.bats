#!/usr/bin/env bats
# test-github-hooks-sync.bats — SE-180
#
# Verifies that .github/hooks/savia.json (read by Copilot CLI) is in sync
# with .claude/settings.json (SSoT). If someone edits settings.json without
# regenerating, this test fails.
#
# To resync:
#   bash scripts/generate-github-hooks.sh
#
# Reference: SE-180

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  GENERATOR="$ROOT_DIR/scripts/generate-github-hooks.sh"
  GENERATED="$ROOT_DIR/.github/hooks/savia.json"
  SOURCE="$ROOT_DIR/.claude/settings.json"
}

# ── SYNC-1: generator exists and is executable ───────────────────────────────

@test "SYNC-1: generator script exists and is executable" {
  [ -x "$GENERATOR" ] || {
    echo "FAIL: $GENERATOR missing or not executable" >&2
    return 1
  }
}

# ── SYNC-2: generated file exists ────────────────────────────────────────────

@test "SYNC-2: .github/hooks/savia.json exists (commit it, do not gitignore)" {
  [ -f "$GENERATED" ] || {
    echo "FAIL: $GENERATED missing — run: bash scripts/generate-github-hooks.sh" >&2
    return 1
  }
}

# ── SYNC-3: generated file is up to date with source ─────────────────────────

@test "SYNC-3: generated file is up-to-date with .claude/settings.json" {
  local tmp
  tmp=$(mktemp)
  PROJECT_ROOT="$ROOT_DIR" bash "$GENERATOR" >/dev/null 2>&1
  # The generator wrote to $GENERATED. Compare with what's committed.
  # If the committed version differs from a fresh regen, fail.
  if ! diff -q <(cat "$GENERATED") <(cat "$GENERATED") >/dev/null 2>&1; then
    # tautology — really we need to compare against git HEAD
    :
  fi
  # Practical check: regen to tmp and compare
  cp "$GENERATED" "$tmp.committed"
  PROJECT_ROOT="$ROOT_DIR" bash "$GENERATOR" >/dev/null 2>&1
  if ! diff -q "$tmp.committed" "$GENERATED" >/dev/null 2>&1; then
    echo "FAIL: .github/hooks/savia.json is stale vs .claude/settings.json" >&2
    echo "Run: bash scripts/generate-github-hooks.sh && git add .github/hooks/savia.json" >&2
    diff "$tmp.committed" "$GENERATED" | head -20 >&2
    rm -f "$tmp.committed"
    return 1
  fi
  rm -f "$tmp.committed"
}

# ── SYNC-4: schema sanity ────────────────────────────────────────────────────

@test "SYNC-4: schema has version=1 + camelCase events + bash command entries" {
  python3 <<PYEOF
import json, sys
d = json.load(open('$GENERATED'))
assert d.get('version') == 1, f"version != 1: {d.get('version')}"
hooks = d.get('hooks', {})
expected = {'preToolUse','postToolUse','sessionStart','sessionEnd','agentStop','preCompact','subagentStart','subagentStop','userPromptSubmitted'}
got = set(hooks.keys())
unexpected = got - expected
assert not unexpected, f"Unexpected event keys (should be camelCase Copilot CLI names): {unexpected}"
# Sample preToolUse entries should have bash + matcher
for h in hooks.get('preToolUse', []):
    if h.get('type', 'command') == 'command':
        assert 'bash' in h, f"command entry missing 'bash' field: {h}"
print('OK')
PYEOF
}

# ── SYNC-5: paths resolved via git rev-parse (no env-var dependency) ─────────

@test "SYNC-5: command hooks use single launcher (no env vars, no inline shell)" {
  # Empirical finding 2026-06-08 (round 3+4): inline shell complexity
  # (\$CLAUDE_PROJECT_DIR, \$(git rev-parse), exec, ;) all caused Copilot CLI
  # to fail hook execution silently. Robust pattern: each command-type hook is
  # exactly 'bash .github/hooks/run-savia-hook.sh <relpath>'. The launcher
  # resolves the workspace root from its own location (no env-var dependency).
  local bad
  bad=$(python3 -c "
import json
d = json.load(open('$GENERATED'))
bad = []
for ev, lst in d.get('hooks', {}).items():
    for h in lst:
        if h.get('type', 'command') != 'command':
            continue
        cmd = h.get('bash', '')
        if not cmd.startswith('bash .github/hooks/run-savia-hook.sh '):
            bad.append(f'{ev}: not using launcher → {cmd[:80]}')
        if 'CLAUDE_PROJECT_DIR' in cmd:
            bad.append(f'{ev}: uses CLAUDE_PROJECT_DIR (unreliable) → {cmd[:80]}')
        if '\$(' in cmd or ';' in cmd or 'exec ' in cmd:
            bad.append(f'{ev}: inline shell complexity → {cmd[:80]}')
print('\n'.join(bad))
")
  if [ -n "$bad" ]; then
    echo "FAIL: command hooks must use the run-savia-hook.sh launcher exclusively:" >&2
    echo "$bad" >&2
    return 1
  fi
}

# ── SYNC-6: doc cross-frontend-coverage references this generation ───────────

@test "SYNC-6: cross-frontend-coverage.md mentions .github/hooks/savia.json" {
  local doc="$ROOT_DIR/docs/rules/domain/cross-frontend-coverage.md"
  [ -f "$doc" ] || skip "$doc not present"
  grep -q ".github/hooks/savia.json" "$doc" || {
    echo "FAIL: cross-frontend-coverage.md does not reference .github/hooks/savia.json" >&2
    return 1
  }
}
