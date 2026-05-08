#!/usr/bin/env bats
# Ref: SE-082 + SE-083 — architectural vocabulary discipline + TDD vertical-slices skill
# Spec: docs/propuestas/SE-082-architectural-vocabulary-discipline.md
# Spec: docs/propuestas/SE-083-tdd-vertical-slice-skill.md
# Re-implementation pattern from mattpocock/skills MIT (clean-room).
# Safety: tests enforce 'set -uo pipefail' presence in the auditor wrapper.

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="scripts/architectural-vocabulary-audit.sh"
  AUDITOR_ABS="$ROOT_DIR/$SCRIPT"
  VOCAB_DOC="$ROOT_DIR/docs/rules/domain/architectural-vocabulary.md"
  TDD_SKILL="$ROOT_DIR/.opencode/skills/tdd-vertical-slices/SKILL.md"
  TDD_DOMAIN="$ROOT_DIR/.opencode/skills/tdd-vertical-slices/DOMAIN.md"
  ARCHITECT="$ROOT_DIR/.opencode/agents/architect.md"
  AJUDGE="$ROOT_DIR/.opencode/agents/architecture-judge.md"
  TARCHITECT="$ROOT_DIR/.opencode/agents/test-architect.md"
  ANCHOR="$ROOT_DIR/docs/rules/domain/attention-anchor.md"
  TMPDIR_T=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_T"
}

# ── SE-082: vocabulary doc + cross-refs ─────────────────────────────────────

@test "SE-082: architectural-vocabulary.md exists and defines 6 canonical terms" {
  [ -f "$VOCAB_DOC" ]
  for term in Module Interface Implementation Seam Adapter Depth Locality; do
    grep -qE "^### $term" "$VOCAB_DOC"
  done
}

@test "SE-082: vocabulary doc declares _Avoid_ rejection set per term" {
  grep -qE '_Avoid_:.*unit.*component.*service' "$VOCAB_DOC"
  grep -qE '_Avoid_:.*API.*signature' "$VOCAB_DOC"
  grep -qE '_Avoid_:.*boundary' "$VOCAB_DOC"
}

@test "SE-082: vocabulary doc cites Pocock MIT clean-room attribution" {
  grep -q "mattpocock/skills" "$VOCAB_DOC"
  grep -q "MIT" "$VOCAB_DOC"
  grep -qE "clean.room" "$VOCAB_DOC"
}

@test "SE-082: vocabulary doc states ratchet principles (deletion test, interface=test surface, one adapter)" {
  grep -qiE "deletion test" "$VOCAB_DOC"
  grep -qiE "interface.*test surface" "$VOCAB_DOC"
  grep -qiE "one adapter.*hypothetical seam" "$VOCAB_DOC"
}

@test "SE-082: attention-anchor.md cross-references vocabulary doc" {
  grep -q "architectural-vocabulary" "$ANCHOR"
  grep -q "SE-082" "$ANCHOR"
}

@test "SE-082: architect agent references vocabulary doc" {
  grep -q "architectural-vocabulary" "$ARCHITECT"
  grep -q "SE-082" "$ARCHITECT"
}

@test "SE-082: architecture-judge agent references vocabulary doc" {
  grep -q "architectural-vocabulary" "$AJUDGE"
  grep -q "SE-082" "$AJUDGE"
}

# ── SE-082: auditor positive cases ──────────────────────────────────────────

@test "auditor: file exists, has shebang, and is executable" {
  [ -f "$AUDITOR_ABS" ]
  head -1 "$AUDITOR_ABS" | grep -q '^#!'
  [ -x "$AUDITOR_ABS" ]
}

@test "auditor: declares 'set -uo pipefail' for safety" {
  grep -q "set -[uo]o pipefail" "$AUDITOR_ABS"
}

@test "auditor: --report on a clean file produces zero violations" {
  cat > "$TMPDIR_T/clean.md" <<'EOF'
# Architecture review

The user intake module exposes a small interface; the storage adapter satisfies it at the persistence seam. Depth is high because all retry logic concentrates in one place — locality is preserved.
EOF
  run bash "$AUDITOR_ABS" --json --file "$TMPDIR_T/clean.md"
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; r=json.loads(sys.argv[1]); assert r['violations']==0" "$output"
}

@test "auditor: --report detects boundary in prose and suggests 'seam'" {
  cat > "$TMPDIR_T/dirty.md" <<'EOF'
# Bad review

The auth boundary is unclear and the user component leaks state.
EOF
  run bash "$AUDITOR_ABS" --report --file "$TMPDIR_T/dirty.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"boundary"* ]]
  [[ "$output" == *"prefer: seam"* ]]
}

@test "auditor: detects component / service / api in prose" {
  cat > "$TMPDIR_T/multi.md" <<'EOF'
The user service calls the auth component via a REST API.
EOF
  run bash "$AUDITOR_ABS" --report --file "$TMPDIR_T/multi.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"service"* ]]
  [[ "$output" == *"component"* ]]
  [[ "$output" == *"api"* ]]
}

@test "auditor: skips fenced code blocks (BoundaryService class identifier is fine in code)" {
  cat > "$TMPDIR_T/code.md" <<'EOF'
# Review

The intake module talks to the storage adapter through a clean seam.

```typescript
class BoundaryService {
  callApi() { return fetch('/api'); }
}
```

End of file.
EOF
  run bash "$AUDITOR_ABS" --json --file "$TMPDIR_T/code.md"
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; r=json.loads(sys.argv[1]); assert r['violations']==0" "$output"
}

@test "auditor: skips inline backtick-code spans" {
  cat > "$TMPDIR_T/inline.md" <<'EOF'
The intake module exposes a small interface, satisfied by the storage adapter at one seam. Identifiers like \`BoundaryService\` and \`callApi()\` are fine inside backticks.
EOF
  run bash "$AUDITOR_ABS" --json --file "$TMPDIR_T/inline.md"
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; r=json.loads(sys.argv[1]); assert r['violations']==0" "$output"
}

@test "auditor: --gate fails (exit 1) when violations present" {
  cat > "$TMPDIR_T/dirty.md" <<'EOF'
The auth boundary is unclear.
EOF
  run bash "$AUDITOR_ABS" --gate --file "$TMPDIR_T/dirty.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"GATE FAIL"* ]]
}

@test "auditor: --gate passes (exit 0) when no violations" {
  cat > "$TMPDIR_T/clean.md" <<'EOF'
The intake module has a deep interface; the storage adapter satisfies it at the persistence seam.
EOF
  run bash "$AUDITOR_ABS" --gate --file "$TMPDIR_T/clean.md"
  [ "$status" -eq 0 ]
}

@test "auditor: --json output is parseable and has required keys" {
  run bash "$AUDITOR_ABS" --json --file "$VOCAB_DOC"
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; r=json.loads(sys.argv[1]); assert 'file_count' in r and 'violations' in r and 'tsv' in r" "$output"
}

# ── SE-082: auditor negative + edge cases ───────────────────────────────────

@test "negative: unknown CLI argument exits 2" {
  run bash "$AUDITOR_ABS" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown arg"* ]]
}

@test "negative: --file with nonexistent path exits 2" {
  run bash "$AUDITOR_ABS" --file /no/such/$$.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

@test "edge: empty file produces zero violations" {
  : > "$TMPDIR_T/empty.md"
  run bash "$AUDITOR_ABS" --json --file "$TMPDIR_T/empty.md"
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; r=json.loads(sys.argv[1]); assert r['violations']==0" "$output"
}

@test "edge: zero matching files (no glob hits) → zero violations" {
  AUDIT_GLOBS="output/no-such-pattern-*-$$.md" run bash "$AUDITOR_ABS" --json
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; r=json.loads(sys.argv[1]); assert r['file_count']==0; assert r['violations']==0" "$output"
}

@test "edge: large file (>10 KiB) with many violations is processed" {
  python3 -c "
for _ in range(500):
    print('The user service has unclear boundary with the auth component via the API.')
" > "$TMPDIR_T/big.md"
  run bash "$AUDITOR_ABS" --json --file "$TMPDIR_T/big.md"
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; r=json.loads(sys.argv[1]); assert r['violations'] >= 500" "$output"
}

@test "edge: term as part of a longer identifier is NOT flagged (word-boundary)" {
  cat > "$TMPDIR_T/wordbound.md" <<'EOF'
The CardComponentRegistry is a Postgres-backed thing; ServiceLocator is a pattern name.
EOF
  # CardComponentRegistry contains "Component" but not as standalone word — should still NOT match because regex uses \b
  # Actually "Component" IS a word inside "CardComponentRegistry"? No — \bComponent\b requires word boundary, and CamelCase letter transitions are NOT word boundaries in regex.
  run bash "$AUDITOR_ABS" --json --file "$TMPDIR_T/wordbound.md"
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; r=json.loads(sys.argv[1]); assert r['violations']==0" "$output"
}

# ── SE-083: TDD skill ───────────────────────────────────────────────────────

@test "SE-083: tdd-vertical-slices SKILL.md exists with valid frontmatter" {
  [ -f "$TDD_SKILL" ]
  head -1 "$TDD_SKILL" | grep -q '^---'
  grep -q '^name: tdd-vertical-slices' "$TDD_SKILL"
  grep -qE '^description:.*Use when' "$TDD_SKILL"
}

@test "SE-083: tdd skill names the horizontal-slicing anti-pattern explicitly" {
  grep -qiE "horizontal slicing" "$TDD_SKILL"
  grep -qE "DO NOT|NO escribas todos" "$TDD_SKILL"
}

@test "SE-083: tdd skill describes vertical pattern (RED → GREEN per behavior)" {
  grep -qE "RED.*GREEN" "$TDD_SKILL"
  grep -qiE "tracer bullet" "$TDD_SKILL"
}

@test "SE-083: tdd DOMAIN.md exists with the required sections" {
  [ -f "$TDD_DOMAIN" ]
  grep -qiE "Por qué existe" "$TDD_DOMAIN"
  grep -qiE "Conceptos de dominio" "$TDD_DOMAIN"
  grep -qiE "Reglas de negocio" "$TDD_DOMAIN"
}

@test "SE-083: tdd skill cites Pocock MIT clean-room" {
  grep -q "mattpocock/skills" "$TDD_SKILL"
  grep -q "MIT" "$TDD_SKILL"
  grep -qE "clean.room" "$TDD_SKILL"
}

@test "SE-083: test-architect agent references tdd-vertical-slices skill" {
  grep -q "tdd-vertical-slices" "$TARCHITECT"
  grep -q "SE-083" "$TARCHITECT"
}

@test "SE-083: tdd skill cross-references SE-082 architectural-vocabulary" {
  grep -q "architectural-vocabulary" "$TDD_SKILL"
  grep -q "SE-082" "$TDD_SKILL"
}

# ── Spec ref + assertion quality reinforcement ──────────────────────────────

@test "spec ref: docs/propuestas/SE-082 + SE-083 referenced in this test file" {
  grep -q "docs/propuestas/SE-082" "$BATS_TEST_FILENAME"
  grep -q "docs/propuestas/SE-083" "$BATS_TEST_FILENAME"
}
