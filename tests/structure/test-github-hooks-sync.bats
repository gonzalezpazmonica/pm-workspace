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
# Ref: SE-180 — isolation: tests never write the real .github/hooks/savia.json

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  GENERATOR="$ROOT_DIR/scripts/generate-github-hooks.sh"
  GENERATED="$ROOT_DIR/.github/hooks/savia.json"
  SOURCE="$ROOT_DIR/.claude/settings.json"
  set -o pipefail
  FX="$(mktemp -d)"
  mkdir -p "$FX/.claude" "$FX/.github/hooks"
}

teardown() {
  cd /
}

fx_settings() { # <hook-script-name>
  printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"\\"$CLAUDE_PROJECT_DIR\\"/.opencode/hooks/%s"}]}]}}\n' "$1" > "$FX/.claude/settings.json"
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

@test "SYNC-3: generated file is up-to-date with .claude/settings.json (read-only check)" {
  before=$(sha256sum "$GENERATED")
  run bash "$GENERATOR" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"GITHUB-HOOKS: FRESH"* ]]
  [ "$(sha256sum "$GENERATED")" = "$before" ]
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

# ── Isolation and --check contract (fixtures, never the real repo) ───────────

@test "SYNC-7: --check reports STALE and fails when settings changed, without writing" {
  fx_settings a.sh
  PROJECT_ROOT="$FX" bash "$GENERATOR" >/dev/null
  fx_settings b.sh
  before=$(sha256sum "$FX/.github/hooks/savia.json")
  run env PROJECT_ROOT="$FX" bash "$GENERATOR" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"GITHUB-HOOKS: STALE"* ]]
  [ "$(sha256sum "$FX/.github/hooks/savia.json")" = "$before" ]
}

@test "SYNC-8: --check passes right after a regeneration" {
  fx_settings a.sh
  PROJECT_ROOT="$FX" bash "$GENERATOR" >/dev/null
  run env PROJECT_ROOT="$FX" bash "$GENERATOR" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"GITHUB-HOOKS: FRESH"* ]]
}

@test "SYNC-9: missing settings.json fails with an error" {
  run env PROJECT_ROOT="$FX" bash "$GENERATOR" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing"* ]]
}

@test "SYNC-10: nonexistent generated file makes --check fail instead of creating it" {
  fx_settings a.sh
  run env PROJECT_ROOT="$FX" bash "$GENERATOR" --check
  [ "$status" -eq 1 ]
  [ ! -e "$FX/.github/hooks/savia.json" ]
}

@test "SYNC-11: empty hooks section still produces valid JSON" {
  printf '{"hooks":{}}\n' > "$FX/.claude/settings.json"
  run env PROJECT_ROOT="$FX" bash "$GENERATOR"
  [ "$status" -eq 0 ]
  python3 -m json.tool "$FX/.github/hooks/savia.json" >/dev/null
}

@test "SYNC-12: safety — generator runs under set -uo pipefail" {
  grep -q '^set -uo pipefail' "$GENERATOR"
}
