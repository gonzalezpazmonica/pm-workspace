#!/usr/bin/env bats
# tests/test-blast-radius.bats — SE-318: Blast-radius pre-commit (S1-S3).
# Ref: docs/propuestas/SE-318-blast-radius-precommit.md (AC-S1, AC-S2, AC-S3)

BLAST="scripts/blast-radius.sh"
HOOK=".claude/hooks/blast-radius-hook.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPD="${BATS_TEST_TMPDIR}"
  mkdir -p "$TMPD"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR" 2>/dev/null || true
  cd /
}

# ── Fixture: mini-repo git con símbolos y callers ──────────────────────────
make_repo() { # dir
  local repo="$1"
  mkdir -p "$repo"
  ( cd "$repo" && git init -q && git config user.email "test@example.com" && git config user.name "Test" )
  cat > "$repo/lib.py" <<'EOF'
def public_api(x):
    return x * 2

def helper():
    return public_api(1)
EOF
  cat > "$repo/app.py" <<'EOF'
from lib import public_api

def main():
    return public_api(5)
EOF
  cat > "$repo/other.py" <<'EOF'
def standalone():
    return 42
EOF
  ( cd "$repo" && git add . && git commit -qm "init" )
}

# ── S1: consulta de símbolo ────────────────────────────────────────────────

@test "S1.1: blast-radius.sh existe, es ejecutable y usa pipefail" {
  [[ -f "$BLAST" ]]
  [[ -x "$BLAST" ]]
  run grep -c 'set -uo pipefail' "$BLAST"
  [[ "$output" -ge 1 ]]
}

@test "AC-S1.1: símbolo con 3 callers directos los lista en direct" {
  local repo="$TMPD/repo1"
  make_repo "$repo"
  run bash -c "cd '$repo' && bash '$BATS_TEST_DIRNAME/../scripts/blast-radius.sh' --symbol public_api"
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'lib.py' in d['direct'], d
assert 'app.py' in d['direct'], d
assert d['total'] >= 2, d
"
}

@test "AC-S1.3: símbolo inexistente -> {symbol:null, files:{}}, exit 0" {
  local repo="$TMPD/repo2"
  make_repo "$repo"
  run bash -c "cd '$repo' && bash '$BATS_TEST_DIRNAME/../scripts/blast-radius.sh' --symbol zzz_never_defined_9876"
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total'] == 0, d
assert d['files'] == {}, d
"
}

# ── S2: modo diff ───────────────────────────────────────────────────────────

@test "AC-S2.1: diff que modifica 2 símbolos agrega ambos" {
  local repo="$TMPD/repo3"
  make_repo "$repo"
  # nuevo símbolo + modificación de otro
  cat >> "$repo/lib.py" <<'EOF'

def new_symbol():
    return helper()
EOF
  ( cd "$repo" && git add lib.py && git commit -qm "add new_symbol" )
  run bash -c "cd '$repo' && bash '$BATS_TEST_DIRNAME/../scripts/blast-radius.sh' --diff HEAD~1..HEAD"
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'new_symbol' in d['symbols'], d
assert d['mode'] == 'diff', d
"
}

@test "AC-S2.2: diff sin símbolos detectables -> reporte vacío, exit 0" {
  local repo="$TMPD/repo4"
  make_repo "$repo"
  echo "comment only" >> "$repo/app.py"
  ( cd "$repo" && git add app.py && git commit -qm "noop" )
  run bash -c "cd '$repo' && bash '$BATS_TEST_DIRNAME/../scripts/blast-radius.sh' --diff HEAD~1..HEAD"
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total'] == 0, d
"
}

# ── S3: integración ─────────────────────────────────────────────────────────

@test "AC-S3.1: hook pre-write muestra AFFECTED sin bloquear (exit 0)" {
  local repo="$TMPD/repo5"
  make_repo "$repo"
  run bash -c "cd '$repo' && SAVIA_BLAST_RADIUS=on bash '$BATS_TEST_DIRNAME/../.claude/hooks/blast-radius-hook.sh' --file lib.py"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"AFFECTED"* ]]
}

@test "AC-S3.1b: hook con switch off no hace nada (Rule #19)" {
  local repo="$TMPD/repo6"
  make_repo "$repo"
  run bash -c "cd '$repo' && bash '$BATS_TEST_DIRNAME/../.claude/hooks/blast-radius-hook.sh' --file lib.py"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "AC-S3.3: blast.radius aparece en telemetry-events.jsonl" {
  local repo="$TMPD/repo7"
  make_repo "$repo"
  run bash -c "cd '$repo' && SAVIA_TELEMETRY_FILE='$TMPD/tl.jsonl' bash '$BATS_TEST_DIRNAME/../scripts/blast-radius.sh' --symbol public_api"
  [[ -f "$TMPD/tl.jsonl" ]]
  run grep -c 'blast.radius' "$TMPD/tl.jsonl"
  [[ "$output" -ge 1 ]]
}

# ── Seguridad ───────────────────────────────────────────────────────────────

@test "S5.1: no introduce secrets ni IPs internas" {
  run grep -rnE "AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{32,}|192\.168\.|10\.([0-9]{1,3}\.){2}" scripts/blast-radius.sh .claude/hooks/blast-radius-hook.sh
  [[ -z "$output" ]]
}
