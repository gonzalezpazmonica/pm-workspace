#!/usr/bin/env bats
# SE-091: Caveman always-on + auto tribunal hooks
# Verifies: caveman-default loaded in instructions, guards exist and are
# registered in savia-foundation, bash hook files present, opencode.json valid.

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  FOUNDATION=".opencode/plugins/savia-foundation.ts"
  GRILL_GUARD=".opencode/plugins/guards/auto-grill-me.ts"
  ZOOM_GUARD=".opencode/plugins/guards/auto-zoom-out.ts"
  GRILL_HOOK=".opencode/hooks/auto-grill-me.sh"
  ZOOM_HOOK=".opencode/hooks/auto-zoom-out.sh"
  CAVEMAN_RULE="docs/rules/domain/caveman-default.md"
  OC_CONFIG="opencode.json"
}

# ── caveman-default.md (AC-01..AC-02) ────────────────────────────────────────

@test "AC-01: caveman-default.md exists" {
  [[ -f "$CAVEMAN_RULE" ]]
}

@test "AC-01: caveman-default.md has 6 numbered restrictions" {
  local count
  count=$(grep -cE "^\s*[1-6]\." "$CAVEMAN_RULE")
  [ "$count" -ge 6 ]
}

@test "AC-02: caveman-default.md loaded in opencode.json instructions" {
  python3 -c "
import json, sys
d = json.load(open('$OC_CONFIG'))
instr = d.get('instructions', [])
found = any('caveman-default' in i for i in instr)
sys.exit(0 if found else 1)
"
}

# ── Guard files (AC-03..AC-04) ───────────────────────────────────────────────

@test "AC-03: auto-grill-me.ts guard exists" {
  [[ -f "$GRILL_GUARD" ]]
}

@test "AC-03: auto-grill-me.ts exports shouldGrillPath" {
  grep -q "export function shouldGrillPath" "$GRILL_GUARD"
}

@test "AC-03: auto-grill-me.ts exports autoGrillMe" {
  grep -q "export async function autoGrillMe" "$GRILL_GUARD"
}

@test "AC-03: auto-grill-me.ts targets code extensions" {
  grep -qE '"ts"|"py"|"cs"|"go"' "$GRILL_GUARD"
}

@test "AC-04: auto-zoom-out.ts guard exists" {
  [[ -f "$ZOOM_GUARD" ]]
}

@test "AC-04: auto-zoom-out.ts exports shouldZoomOutPath" {
  grep -q "export function shouldZoomOutPath" "$ZOOM_GUARD"
}

@test "AC-04: auto-zoom-out.ts exports autoZoomOut" {
  grep -q "export async function autoZoomOut" "$ZOOM_GUARD"
}

@test "AC-04: auto-zoom-out.ts targets ROADMAP and docs/architecture" {
  grep -qE "ROADMAP|docs.*architecture" "$ZOOM_GUARD"
}

# ── Registration in savia-foundation (AC-05) ─────────────────────────────────

@test "AC-05: savia-foundation imports auto-grill-me" {
  grep -q "autoGrillMe" "$FOUNDATION"
  grep -q "auto-grill-me" "$FOUNDATION"
}

@test "AC-05: savia-foundation imports auto-zoom-out" {
  grep -q "autoZoomOut" "$FOUNDATION"
  grep -q "auto-zoom-out" "$FOUNDATION"
}

@test "AC-05: autoGrillMe in BEFORE_GUARDS array" {
  python3 - <<'PY'
content = open(".opencode/plugins/savia-foundation.ts").read()
guards_block = content[content.index("const BEFORE_GUARDS"):content.index("] as const;", content.index("const BEFORE_GUARDS"))+12]
assert "autoGrillMe" in guards_block, "autoGrillMe not in BEFORE_GUARDS"
PY
}

@test "AC-05: autoZoomOut in BEFORE_GUARDS array" {
  python3 - <<'PY'
content = open(".opencode/plugins/savia-foundation.ts").read()
guards_block = content[content.index("const BEFORE_GUARDS"):content.index("] as const;", content.index("const BEFORE_GUARDS"))+12]
assert "autoZoomOut" in guards_block, "autoZoomOut not in BEFORE_GUARDS"
PY
}

# ── Bash hook files (AC-06 — legacy Claude Code) ─────────────────────────────

@test "AC-06: auto-grill-me.sh bash hook exists" {
  [[ -f "$GRILL_HOOK" ]]
}

@test "AC-06: auto-zoom-out.sh bash hook exists" {
  [[ -f "$ZOOM_HOOK" ]]
}

@test "AC-06: auto-grill-me.sh is executable" {
  [[ -x "$GRILL_HOOK" ]]
}

# ── Semantics: non-blocking (AC-07) ─────────────────────────────────────────

@test "AC-07: autoGrillMe guard does not throw — verified via TS tests" {
  command -v bun >/dev/null 2>&1 || skip "bun not installed (CI runner)"
  cd .opencode && bun test plugins/__tests__/auto-grill-me.test.ts 2>&1 | grep -q "0 fail"
}

@test "AC-07: autoZoomOut guard does not throw — verified via TS tests" {
  command -v bun >/dev/null 2>&1 || skip "bun not installed (CI runner)"
  cd .opencode && bun test plugins/__tests__/auto-zoom-out.test.ts 2>&1 | grep -q "0 fail"
}

# ── opencode.json valid JSON (AC-08) ─────────────────────────────────────────

@test "AC-08: opencode.json is valid JSON after changes" {
  python3 -c "import json; json.load(open('opencode.json'))"
}
