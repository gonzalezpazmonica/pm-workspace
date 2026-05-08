#!/usr/bin/env bats
# Ref: SPEC-127 OpenCode bootstrap (workspace config + cross-frontend symlinks)
# Spec: docs/propuestas/SPEC-127-savia-opencode-provider-agnostic.md
#
# Ships:
#   - opencode.json (workspace config — instructions array)
#   - SKILLS.md (auto-generated cross-frontend skills catalog)
#   - scripts/skills-md-generate.sh (generator, idempotent)
#   - .opencode/commands → ../.claude/commands (symlink)
#   - .opencode/skills   → ../.claude/skills   (symlink)
#   - .opencode/hooks    → ../.claude/hooks    (symlink)
#
# These regression tests enforce that OpenCode v1.14+ can bootstrap
# Savia's memory, personality, knowledge, rules, and discover agents/
# commands/skills on session start.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="scripts/skills-md-generate.sh"
  CONFIG="$REPO_ROOT/opencode.json"
  SKILLS_MD="$REPO_ROOT/SKILLS.md"
  AGENTS_MD="$REPO_ROOT/AGENTS.md"
  GEN="$REPO_ROOT/$SCRIPT"
  OPENCODE_DIR="$REPO_ROOT/.opencode"
  TMPDIR_O=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_O"
}

# ── opencode.json ──────────────────────────────────────────────────────────

@test "opencode.json: exists at workspace root" {
  [ -f "$CONFIG" ]
}

@test "opencode.json: is valid JSON" {
  python3 -c "import json; json.load(open('$CONFIG'))"
}

@test "opencode.json: declares \$schema pointing to opencode.ai" {
  python3 -c "
import json
d = json.load(open('$CONFIG'))
assert d.get('\$schema','').startswith('https://opencode.ai/'), 'missing or wrong schema'
"
}

@test "opencode.json: instructions array has ≥10 entries" {
  count=$(python3 -c "import json; print(len(json.load(open('$CONFIG')).get('instructions',[])))")
  [ "$count" -ge 10 ]
}

@test "opencode.json: instructions includes AGENTS.md and SKILLS.md" {
  python3 -c "
import json
ins = json.load(open('$CONFIG')).get('instructions',[])
assert 'AGENTS.md' in ins, 'AGENTS.md not in instructions'
assert 'SKILLS.md' in ins, 'SKILLS.md not in instructions'
"
}

@test "opencode.json: instructions includes memory + personality + radical-honesty" {
  python3 -c "
import json
ins = json.load(open('$CONFIG')).get('instructions',[])
patterns = ['MEMORY.md', 'savia.md', 'radical-honesty.md', 'autonomous-safety.md']
for p in patterns:
    assert any(p in i for i in ins), f'missing pattern: {p}'
"
}

@test "opencode.json: every PUBLIC instructions path resolves to an existing file" {
  # Per-user / gitignored paths are skipped — they exist on the operator's
  # machine but not in CI fresh checkout. OpenCode runtime tolerates missing
  # instructions files (silent skip). Public-repo paths MUST exist.
  python3 -c "
import json, os, subprocess
ins = json.load(open('$CONFIG')).get('instructions',[])
root = '$REPO_ROOT'

def is_gitignored(rel):
    res = subprocess.run(['git', '-C', root, 'check-ignore', '-q', rel],
                         capture_output=True)
    return res.returncode == 0

def is_in_external_symlink(rel):
    # Paths under .claude/external-memory/ resolve via a symlink to
    # \$HOME/.savia-memory which is per-user, never in repo.
    return rel.startswith('.claude/external-memory/')

missing = []
for p in ins:
    if is_in_external_symlink(p) or is_gitignored(p):
        continue  # per-user path — runtime decides
    if not os.path.isfile(os.path.join(root, p)):
        missing.append(p)
assert not missing, f'missing public files: {missing}'
"
}

@test "opencode.json: autoupdate is false (PV-04 — operator controls upgrades)" {
  python3 -c "
import json
d = json.load(open('$CONFIG'))
assert d.get('autoupdate') is False, 'autoupdate should be false'
"
}

@test "opencode.json: share is 'manual' (no auto-share of sessions)" {
  python3 -c "
import json
d = json.load(open('$CONFIG'))
assert d.get('share') == 'manual', 'share must be manual'
"
}

@test "opencode.json: does NOT pin model (PV-06 — provider-agnostic)" {
  python3 -c "
import json
d = json.load(open('$CONFIG'))
# model and provider should be empty/absent so user's preferences.yaml decides
assert 'model' not in d or not d['model'], 'model should not be pinned'
assert 'provider' not in d or not d['provider'], 'provider should not be pinned'
"
}

# ── SKILLS.md + generator ──────────────────────────────────────────────────

@test "SKILLS.md: exists at workspace root" {
  [ -f "$SKILLS_MD" ]
}

@test "SKILLS.md: declares auto-generated banner (do not edit by hand)" {
  grep -q "Auto-generated" "$SKILLS_MD"
  grep -qiE "do not edit" "$SKILLS_MD"
}

@test "SKILLS.md: lists ≥50 skills (catalog completeness)" {
  count=$(grep -cE '^\| [^|]+ \| `\.opencode/skills/' "$SKILLS_MD")
  [ "$count" -ge 50 ]
}

@test "AGENTS.md: exists at workspace root (cross-frontend mirror)" {
  [ -f "$AGENTS_MD" ]
}

@test "AC: skills-md-generate.sh exists, executable, has shebang" {
  [ -f "$GEN" ]
  head -1 "$GEN" | grep -q '^#!'
  [ -x "$GEN" ]
}

@test "AC: generator declares 'set -uo pipefail'" {
  head -5 "$GEN" | grep -q "set -uo pipefail"
}

@test "AC: generator passes bash -n syntax check" {
  bash -n "$GEN"
}

@test "AC: generator --check is idempotent (in sync)" {
  run bash "$GEN" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"in sync"* ]]
}

@test "negative: generator with missing SKILLS_DIR exits 3" {
  run env SKILLS_DIR="$TMPDIR_O/nonexistent" bash "$GEN"
  [ "$status" -eq 3 ]
}

@test "negative: generator with unknown flag exits 2" {
  run bash "$GEN" --bogus
  [ "$status" -eq 2 ]
}

@test "AC: generator --apply twice yields same content (idempotent)" {
  cp "$SKILLS_MD" "$TMPDIR_O/first.md"
  bash "$GEN" --apply >/dev/null
  diff -q "$SKILLS_MD" "$TMPDIR_O/first.md"
}

# ── .opencode symlinks ─────────────────────────────────────────────────────

@test ".opencode/commands symlink resolves to .claude/commands" {
  [ -L "$OPENCODE_DIR/commands" ]
  target=$(readlink "$OPENCODE_DIR/commands")
  [[ "$target" == *".claude/commands"* ]]
  [ -d "$OPENCODE_DIR/commands" ]
}

@test ".opencode/skills symlink resolves to .claude/skills" {
  [ -L "$OPENCODE_DIR/skills" ]
  target=$(readlink "$OPENCODE_DIR/skills")
  [[ "$target" == *".claude/skills"* ]]
  [ -d "$OPENCODE_DIR/skills" ]
}

@test ".opencode/hooks symlink resolves to .claude/hooks" {
  [ -L "$OPENCODE_DIR/hooks" ]
  target=$(readlink "$OPENCODE_DIR/hooks")
  [[ "$target" == *".claude/hooks"* ]]
  [ -d "$OPENCODE_DIR/hooks" ]
}

@test "no .opencode/agents symlink (schema mismatch — Slice 2b adds converter)" {
  # OpenCode v1.14 expects strict agent schema (color hex, tools as object).
  # Claude Code agents use array tools + named colors. Until Slice 2b
  # implements a converter, we don't expose .opencode/agents/ to OpenCode.
  # AGENTS.md provides cross-frontend discovery in the meantime.
  [ ! -e "$OPENCODE_DIR/agents" ] || [ ! -L "$OPENCODE_DIR/agents" ]
}

# ── PV-06 — no vendor lock-in ──────────────────────────────────────────────

@test "PV-06: opencode.json does not hardcode an inference vendor" {
  ! grep -qiE '"github.copilot"|"anthropic.com/v1"|"copilot.enterprise"' "$CONFIG"
}

# ── Spec ref ────────────────────────────────────────────────────────────────

@test "spec ref: SPEC-127 referenced in this test file" {
  grep -q "docs/propuestas/SPEC-127" "$BATS_TEST_FILENAME"
}

@test "spec ref: skills-md-generate.sh references SPEC-127 or SE-078" {
  grep -qE "SPEC-127|SE-078" "$GEN"
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: empty skills dir produces minimal SKILLS.md (boundary)" {
  mkdir -p "$TMPDIR_O/empty-skills"
  out=$(env SKILLS_DIR="$TMPDIR_O/empty-skills" bash "$GEN")
  [ -n "$out" ]
  echo "$out" | grep -q "Skills"
}

@test "edge: skills with no name field fall back to dir basename (graceful)" {
  mkdir -p "$TMPDIR_O/sk/no-name-skill"
  cat > "$TMPDIR_O/sk/no-name-skill/SKILL.md" <<'EOF'
---
description: skill without name field
---
body
EOF
  out=$(env SKILLS_DIR="$TMPDIR_O/sk" bash "$GEN")
  echo "$out" | grep -q "no-name-skill"
}

# ── Coverage ────────────────────────────────────────────────────────────────

@test "coverage: generator supports 3 modes (generate/apply/check)" {
  grep -qE 'generate\)' "$GEN"
  grep -qE 'apply\)' "$GEN"
  grep -qE 'check\)' "$GEN"
}

@test "coverage: opencode.json instructions cover 4 categories" {
  python3 -c "
import json
ins = json.load(open('$CONFIG')).get('instructions',[])
cats = {
  'memory': any('MEMORY.md' in i for i in ins),
  'personality': any('savia.md' in i for i in ins),
  'rules': any('autonomous-safety' in i or 'radical-honesty' in i for i in ins),
  'catalog': any('AGENTS.md' in i or 'agents-catalog' in i for i in ins),
}
missing = [k for k,v in cats.items() if not v]
assert not missing, f'missing categories: {missing}'
"
}
