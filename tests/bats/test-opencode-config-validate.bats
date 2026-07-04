#!/usr/bin/env bats
# tests/bats/test-opencode-config-validate.bats — opencode-config-validate.sh
#
# SE-253 errata: prevents unknown keys (like 'catalog') from being added
# to opencode.json where they cause startup failures in OpenCode >=1.16.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/opencode-config-validate.sh"
  TMPDIR="$(mktemp -d)"
  CONFIG="$TMPDIR/opencode.json"
}

teardown() {
  rm -rf "$TMPDIR"
}

# ─────────────────────────────────────────────────────────────────────────────
# AC-1: Fichero inexistente (no error, skip)
# ─────────────────────────────────────────────────────────────────────────────

@test "AC-1: config inexistente sale con exit 0" {
  OPENCODE_CONFIG="$TMPDIR/nonexistent.json" run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
}

# ─────────────────────────────────────────────────────────────────────────────
# AC-2: JSON no valido
# ─────────────────────────────────────────────────────────────────────────────

@test "AC-2: JSON invalido sale con exit 2" {
  printf '%s\n' 'not json{' > "$CONFIG"
  OPENCODE_CONFIG="$CONFIG" run bash "$SCRIPT" --check
  [ "$status" -eq 2 ]
}

# ─────────────────────────────────────────────────────────────────────────────
# AC-3: Solo keys validas
# ─────────────────────────────────────────────────────────────────────────────

@test "AC-3a: solo schema — valido" {
  cat > "$CONFIG" <<'ENDJSON'
{"$schema": "https://opencode.ai/config.json"}
ENDJSON
  OPENCODE_CONFIG="$CONFIG" run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
}

@test "AC-3b: keys tipicas (agent, mcp, command) — valido" {
  cat > "$CONFIG" <<'ENDJSON'
{"$schema":"x","agent":{"b":{"mode":"primary"}},"mcp":{},"command":{}}
ENDJSON
  OPENCODE_CONFIG="$CONFIG" run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
}

# ─────────────────────────────────────────────────────────────────────────────
# AC-4: Key desconocida bloquea en --check, avisa en --warn
# ─────────────────────────────────────────────────────────────────────────────

@test "AC-4a: key catalog bloquea en --check (exit 1)" {
  cat > "$CONFIG" <<'ENDJSON'
{"$schema":"x","catalog":{"tier_field":"tier","default_tier":"core"}}
ENDJSON
  OPENCODE_CONFIG="$CONFIG" run bash "$SCRIPT" --check
  [ "$status" -eq 1 ]
}

@test "AC-4b: key catalog avisa en --warn (exit 0)" {
  cat > "$CONFIG" <<'ENDJSON'
{"$schema":"x","catalog":{"tier":"core"}}
ENDJSON
  OPENCODE_CONFIG="$CONFIG" run bash "$SCRIPT" --warn
  [ "$status" -eq 0 ]
}

@test "AC-4c: key inventada bloquea en --check" {
  cat > "$CONFIG" <<'ENDJSON'
{"$schema":"x","foo_bad":123}
ENDJSON
  OPENCODE_CONFIG="$CONFIG" run bash "$SCRIPT" --check
  [ "$status" -eq 1 ]
}

@test "AC-4d: multiple keys desconocidas" {
  cat > "$CONFIG" <<'ENDJSON'
{"$schema":"x","catalog":{},"bad_key":null}
ENDJSON
  OPENCODE_CONFIG="$CONFIG" run bash "$SCRIPT" --check
  [ "$status" -eq 1 ]
}

# ─────────────────────────────────────────────────────────────────────────────
# AC-5: Modo invalido
# ─────────────────────────────────────────────────────────────────────────────

@test "AC-5: modo invalido sale con exit 2" {
  cat > "$CONFIG" <<'ENDJSON'
{"$schema":"x"}
ENDJSON
  OPENCODE_CONFIG="$CONFIG" run bash "$SCRIPT" --invalid
  [ "$status" -eq 2 ]
}

# ─────────────────────────────────────────────────────────────────────────────
# AC-6: Config real del repo pasa (regresion)
# ─────────────────────────────────────────────────────────────────────────────

@test "AC-6: opencode.json real del repo pasa" {
  OPENCODE_CONFIG="$REPO_ROOT/opencode.json" run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
}
