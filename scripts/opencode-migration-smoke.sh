#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C
# opencode-migration-smoke.sh — SPEC-127 Slice 2b-ii (final migration prep)
#
# 6 fast checks confirming OpenCode v1.14+ can bootstrap Savia. Run after
# `opencode upgrade` and `bash scripts/savia-preferences.sh init`. Fails
# loudly with actionable error messages — no silent skips.
#
# Exit 0 = ready to migrate. Exit non-zero = list of fixes printed to stderr.
#
# Reference: docs/migration-claude-code-to-opencode.md
# Reference: SPEC-127 Slice 2b-ii

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PASS=0
FAIL=0
WARN=0

ok()   { echo "  ✓ $*"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $*" >&2; FAIL=$((FAIL + 1)); }
warn() { echo "  ⚠ $*" >&2; WARN=$((WARN + 1)); }

echo "── OpenCode migration smoke test ──"

# 1. opencode binary version
echo "[1/6] OpenCode binary version"
if ! command -v opencode >/dev/null 2>&1; then
  fail "opencode binary not on PATH — install per docs/migration-claude-code-to-opencode.md"
else
  V=$(opencode --version 2>/dev/null | head -1 | tr -d '[:space:]')
  if [[ -z "$V" ]]; then
    warn "opencode --version produced no output"
  else
    # Compare against 1.14.0
    if printf '%s\n%s\n' "1.14.0" "$V" | sort -V -C; then
      ok "opencode v$V (≥ 1.14.0)"
    else
      fail "opencode v$V is below 1.14.0 — run: opencode upgrade"
    fi
  fi
fi

# 2. opencode.json present and valid
echo "[2/6] opencode.json present and valid JSON"
if [[ ! -f "$ROOT/opencode.json" ]]; then
  fail "opencode.json missing at workspace root"
else
  if python3 -c "import json; json.load(open('$ROOT/opencode.json'))" 2>/dev/null; then
    ok "opencode.json is valid JSON"
  else
    fail "opencode.json is not valid JSON — re-generate or fix manually"
  fi
fi

# 3. agents discovered by OpenCode
echo "[3/6] OpenCode discovers ≥ 70 agents"
if ! command -v opencode >/dev/null 2>&1; then
  warn "skipped — opencode not on PATH"
else
  TMP=$(mktemp)
  if opencode debug config > "$TMP" 2>/dev/null; then
    AGENTS=$(python3 -c "import json; print(len(json.load(open('$TMP')).get('agent',{})))" 2>/dev/null || echo 0)
    if [[ "$AGENTS" -ge 70 ]]; then
      ok "$AGENTS agents discovered"
    elif [[ "$AGENTS" -eq 0 ]]; then
      fail "0 agents discovered — run: bash scripts/agents-opencode-convert.sh --apply"
    else
      warn "$AGENTS agents discovered (expected ≥ 70)"
    fi
  else
    fail "opencode debug config failed — check schema validity"
  fi
  rm -f "$TMP"
fi

# 4. commands discovered
echo "[4/6] OpenCode discovers ≥ 500 commands"
if ! command -v opencode >/dev/null 2>&1; then
  warn "skipped — opencode not on PATH"
else
  TMP=$(mktemp)
  if opencode debug config > "$TMP" 2>/dev/null; then
    CMDS=$(python3 -c "import json; print(len(json.load(open('$TMP')).get('command',{})))" 2>/dev/null || echo 0)
    if [[ "$CMDS" -ge 500 ]]; then
      ok "$CMDS commands discovered"
    else
      fail "$CMDS commands (expected ≥ 500) — verify .opencode/commands symlink"
    fi
  fi
  rm -f "$TMP"
fi

# 5. SKILLS.md index present and ≥ 50 skills
echo "[5/6] SKILLS.md index present"
if [[ ! -f "$ROOT/SKILLS.md" ]]; then
  fail "SKILLS.md missing — run: bash scripts/skills-md-generate.sh --apply"
else
  ROWS=$(grep -cE '^\| [^|]+ \| `\.claude/skills/' "$ROOT/SKILLS.md")
  if [[ "$ROWS" -ge 50 ]]; then
    ok "SKILLS.md lists $ROWS skills"
  else
    warn "SKILLS.md lists $ROWS skills (expected ≥ 50) — re-generate if stale"
  fi
fi

# 6. plugin foundation files
echo "[6/6] OpenCode plugin foundation files present"
MISSING=0
for f in \
  ".opencode/package.json" \
  ".opencode/tsconfig.json" \
  ".opencode/plugins/savia-foundation.ts" \
  ".opencode/plugins/lib/hook-input.ts" \
  ".opencode/plugins/lib/credential-patterns.ts" \
  ".opencode/plugins/guards/block-credential-leak.ts" \
  ".opencode/plugins/guards/validate-bash-global.ts" \
  ".opencode/plugins/guards/tdd-gate.ts"
do
  if [[ ! -f "$ROOT/$f" ]]; then
    fail "$f missing"
    MISSING=$((MISSING + 1))
  fi
done
if [[ $MISSING -eq 0 ]]; then
  ok "all 8 foundation files present"
fi

# ── Verdict ──
echo ""
echo "── Summary ──"
printf "PASS=%d  FAIL=%d  WARN=%d\n" "$PASS" "$FAIL" "$WARN"

if [[ $FAIL -gt 0 ]]; then
  echo "MIGRATION NOT READY — fix the failures above and re-run." >&2
  exit 1
fi
echo "Migration smoke OK. Proceed to: opencode run 'list 3 active commands'"
exit 0
