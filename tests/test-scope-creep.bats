#!/usr/bin/env bats
# tests/test-scope-creep.bats — SE-315: Scope Creep Gate (S1 + S2).
# Ref: docs/propuestas/SE-315-scope-creep-gate.md (AC-S1, AC-S2)

DECLARE="scripts/scope-declare.sh"
CHECK="scripts/scope-creep-check.sh"
FIXTURES_DIR="tests/fixtures/scope-creep"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPD="${BATS_TEST_TMPDIR}"
  mkdir -p "$TMPD"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR" 2>/dev/null || true
  cd /
}

# ── Fixture: spec con tabla de ficheros ────────────────────────────────────
make_spec() {
  cat > "$1" <<'EOF'
# Spec: SE-999 — fixture

## Ficheros a Crear/Modificar

| Fichero | Proposito |
|---|---|
| scripts/alpha.sh | core |
| tests/test-alpha.bats | tests |
EOF
}

ABS_DECLARE="$BATS_TEST_DIRNAME/../scripts/scope-declare.sh"
ABS_CHECK="$BATS_TEST_DIRNAME/../scripts/scope-creep-check.sh"

run_in() { # repo args...
  local repo="$1"; shift
  ( cd "$repo" && bash "$ABS_CHECK" "$@" )
}

# ── S1: scope-declare.sh ───────────────────────────────────────────────────

@test "S1.1: script existe y es ejecutable" {
  [[ -f "$DECLARE" ]]
  [[ -x "$DECLARE" ]]
}

@test "S1.2: usa set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$DECLARE"
  [[ "$output" -ge 1 ]]
}

@test "AC-S1.1: extrae declared_paths de una spec con tabla" {
  local spec="$TMPD/spec.md"
  make_spec "$spec"
  run bash "$DECLARE" "$spec"
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['spec_id'] == 'SE-999', d
assert 'scripts/alpha.sh' in d['declared_paths'], d
assert 'tests/test-alpha.bats' in d['declared_paths'], d
assert 'scripts' in d['root_dirs'], d
"
}

@test "AC-S1.2: spec sin ficheros → declared_paths vacío + WARN en salida" {
  local spec="$TMPD/empty.md"
  printf '# Spec vacia\n\nSin declaracion de ficheros.\n' > "$spec"
  run bash "$DECLARE" "$spec"
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['declared_paths'] == [], d
"
}

@test "S1.3: spec inexistente → exit 2" {
  run bash "$DECLARE" /no/existe/spec.md
  [[ "$status" -eq 2 ]]
}

@test "S1.4: salida JSON parseable" {
  local spec="$TMPD/spec.md"
  make_spec "$spec"
  run bash "$DECLARE" "$spec"
  echo "$output" | python3 -m json.tool > /dev/null
}

# ── S2: scope-creep-check.sh ───────────────────────────────────────────────
# Se usa un repo git temporal para producir diffs controlados.

make_gitrepo() {
  local dir="$1"
  mkdir -p "$dir/scripts" "$dir/tests"
  cp "$DECLARE" "$CHECK" "$dir/" 2>/dev/null || true
  ( cd "$dir" \
    && git init -q \
    && git config user.email "test@test" \
    && git config user.name "test" \
    && echo "x" > scripts/alpha.sh \
    && echo "x" > tests/test-alpha.bats \
    && echo "x" > scripts/extra.sh \
    && git add -A \
    && git commit -qm base )
}

add_file() { # repo file
  ( cd "$1" && mkdir -p "$(dirname "$2")" && echo "y" > "$2" && git add "$2" && git commit -qm "change $2" )
}

@test "S2.1: script existe y es ejecutable" {
  [[ -f "$CHECK" ]]
  [[ -x "$CHECK" ]]
}

@test "S2.2: usa set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$CHECK"
  [[ "$output" -ge 1 ]]
}

@test "AC-S2.1: diff 100% declared → IN_SCOPE" {
  local repo="$TMPD/repo-in"
  make_gitrepo "$repo"
  local spec="$repo/spec.md"
  cat > "$spec" <<'EOF'
| Fichero | Proposito |
|---|---|
| scripts/alpha.sh | core |
| tests/test-alpha.bats | tests |
EOF
  add_file "$repo" scripts/alpha.sh
  run run_in "$repo" --spec "$spec" --base HEAD~1 --head HEAD --verdict
  [[ "$status" -eq 0 ]]
  [[ "$output" == "IN_SCOPE" ]]
}

@test "AC-S2.2: 1 fichero unrelated → EXTRA_FILES listándolo" {
  local repo="$TMPD/repo-extra"
  make_gitrepo "$repo"
  local spec="$repo/spec.md"
  cat > "$spec" <<'EOF'
| Fichero | Proposito |
|---|---|
| scripts/alpha.sh | core |
EOF
  add_file "$repo" docs/extra.md
  run run_in "$repo" --spec "$spec" --base HEAD~1 --head HEAD --verdict
  [[ "$status" -eq 0 ]]
  [[ "$output" == "EXTRA_FILES" ]]
  run run_in "$repo" --spec "$spec" --base HEAD~1 --head HEAD --files-unrelated
  [[ "$output" == "docs/extra.md" ]]
}

@test "AC-S2.3: declared + unrelated → MIXED_SCOPE con ambos grupos" {
  local repo="$TMPD/repo-mixed"
  make_gitrepo "$repo"
  local spec="$repo/spec.md"
  cat > "$spec" <<'EOF'
| Fichero | Proposito |
|---|---|
| scripts/alpha.sh | core |
EOF
  add_file "$repo" scripts/alpha.sh
  add_file "$repo" docs/extra.md
  run run_in "$repo" --spec "$spec" --base HEAD~2 --head HEAD --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['verdict'] == 'MIXED_SCOPE', d
assert 'scripts/alpha.sh' in d['declared'], d
assert 'docs/extra.md' in d['unrelated'], d
"
}

@test "AC-S2.4: exit 0 incluso con veredicto no-IN_SCOPE (report-only)" {
  local repo="$TMPD/repo-exit"
  make_gitrepo "$repo"
  local spec="$repo/spec.md"
  cat > "$spec" <<'EOF'
| Fichero | Proposito |
|---|---|
| scripts/alpha.sh | core |
EOF
  add_file "$repo" docs/extra.md
  run run_in "$repo" --spec "$spec" --base HEAD~1 --head HEAD --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['verdict'] == 'EXTRA_FILES', d
"
}

@test "S2.5: sin --spec → exit 2 (usage)" {
  run bash "$CHECK"
  [[ "$status" -eq 2 ]]
}

@test "S2.6: spec inexistente → exit 2" {
  run run_in "$repo" --spec /no/existe.md --base HEAD~1 --head HEAD
  [[ "$status" -eq 2 ]]
}

@test "S2.7: whitelist estructural nunca cuenta como unrelated" {
  local repo="$TMPD/repo-wl"
  make_gitrepo "$repo"
  local spec="$repo/spec.md"
  cat > "$spec" <<'EOF'
| Fichero | Proposito |
|---|---|
| scripts/alpha.sh | core |
EOF
  add_file "$repo" CHANGELOG.md
  run run_in "$repo" --spec "$spec" --base HEAD~1 --head HEAD --json
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['verdict'] == 'IN_SCOPE', d
"
}

@test "S2.8: fichero en directorio declarado cuenta como related" {
  local repo="$TMPD/repo-rel"
  make_gitrepo "$repo"
  local spec="$repo/spec.md"
  cat > "$spec" <<'EOF'
| Fichero | Proposito |
|---|---|
| scripts/alpha.sh | core |
EOF
  add_file "$repo" scripts/alpha.sh
  add_file "$repo" scripts/helper.sh
  run run_in "$repo" --spec "$spec" --base HEAD~2 --head HEAD --json
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['verdict'] == 'IN_SCOPE', d
assert 'scripts/helper.sh' in d['related'], d
"
}

# ── S3: Integración ─────────────────────────────────────────────────────────

@test "AC-S3.1: G17 definido en pr-plan-gates.sh y registrado en pr-plan.sh" {
  run grep -c 'g17_scope_creep()' scripts/pr-plan-gates.sh
  [[ "$output" -ge 1 ]]
  run grep -c 'gate "G17"' scripts/pr-plan.sh
  [[ "$output" -ge 1 ]]
}

@test "AC-S3.1b: G17 report-only — nunca bloquea (sin FAIL, solo WARN/PASS)" {
  run grep -A8 'g17_scope_creep()' scripts/pr-plan-gates.sh
  [[ "$output" == *"WARN"* ]]
  # No debe contener "FAIL:" propio (report-only por diseño AC-S2.4)
  local body; body=$(sed -n '/g17_scope_creep()/,/^}/p' scripts/pr-plan-gates.sh)
  [[ "$body" != *'echo "FAIL'* ]]
}
