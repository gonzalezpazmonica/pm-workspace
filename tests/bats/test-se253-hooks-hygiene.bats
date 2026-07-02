#!/usr/bin/env bats
# test-se253-hooks-hygiene.bats — SE-253 Slice 5: Hook registry hygiene
# AC-5.1: No empty matchers in PreToolUse/PostToolUse
# AC-5.2: No orphan hooks in root dir
# AC-5.3: doc-counts-check.sh passes
# AC-5.4: HOOKS-STRATEGY.md lacks fossil count "69"

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SETTINGS="$REPO_ROOT/.claude/settings.json"
HOOKS_DIR="$REPO_ROOT/.claude/hooks"
HOOKS_STRATEGY="$REPO_ROOT/.opencode/HOOKS-STRATEGY.md"
DOC_COUNTS="$REPO_ROOT/scripts/doc-counts-check.sh"

@test "AC-5.1: settings.json has zero empty matchers in PreToolUse" {
  run python3 -c "
import json, sys
d = json.load(open('$SETTINGS'))
empty = [h for h in d.get('hooks',{}).get('PreToolUse',[]) if h.get('matcher','') == '']
if empty:
    print(f'FAIL: {len(empty)} empty matchers in PreToolUse')
    sys.exit(1)
print('PASS')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "AC-5.1: settings.json has zero empty matchers in PostToolUse" {
  run python3 -c "
import json, sys
d = json.load(open('$SETTINGS'))
empty = [h for h in d.get('hooks',{}).get('PostToolUse',[]) if h.get('matcher','') == '']
if empty:
    for h in empty:
        print('FAIL matcher empty:', h.get('hooks',[{}])[0].get('command','?')[:60])
    sys.exit(1)
print('PASS')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "AC-5.2: _legacy dir exists for deactivated hooks" {
  [ -d "$HOOKS_DIR/_legacy" ]
}

@test "AC-5.2: recommendation-tribunal-pre-output.sh is in _legacy (PreOutput event unavailable)" {
  [ -f "$HOOKS_DIR/_legacy/recommendation-tribunal-pre-output.sh" ]
}

@test "AC-5.2: recommendation-tribunal-pre-output.sh NOT in active hooks root" {
  [ ! -f "$HOOKS_DIR/recommendation-tribunal-pre-output.sh" ]
}

@test "AC-5.2: recommendation-tribunal-followup.sh is registered in settings.json" {
  grep -q "recommendation-tribunal-followup.sh" "$SETTINGS"
}

@test "AC-5.2: twin-posttooluse.sh is registered in settings.json" {
  grep -q "twin-posttooluse.sh" "$SETTINGS"
}

@test "AC-5.2: twin-posttooluse.sh has non-empty matcher" {
  run python3 -c "
import json
d = json.load(open('$SETTINGS'))
for event_hooks in d.get('hooks',{}).values():
    if not isinstance(event_hooks, list): continue
    for h in event_hooks:
        for subh in h.get('hooks',[]):
            if 'twin-posttooluse' in subh.get('command',''):
                if h.get('matcher','') == '':
                    print('FAIL: empty matcher')
                    exit(1)
                print('PASS: matcher=' + repr(h.get('matcher')))
                exit(0)
print('hook not found — skip')
"
  [[ "$output" != *"FAIL"* ]]
}

@test "AC-5.3: scripts/doc-counts-check.sh exists and is executable" {
  [ -f "$DOC_COUNTS" ]
  [ -x "$DOC_COUNTS" ]
}

@test "AC-5.3: doc-counts-check.sh passes on current repo state" {
  run bash "$DOC_COUNTS" --warn
  [ "$status" -eq 0 ]
}

@test "AC-5.4: HOOKS-STRATEGY.md does not declare '69 hooks' (fossilized count)" {
  run grep -c "69 hooks" "$HOOKS_STRATEGY"
  [ "$status" -ne 0 ] || [ "$output" -eq 0 ]
}

@test "AC-5.4: _legacy README exists to document deactivated hooks" {
  [ -f "$HOOKS_DIR/_legacy/README.md" ]
}
