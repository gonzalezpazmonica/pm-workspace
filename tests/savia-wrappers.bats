#!/usr/bin/env bats
# tests/savia-wrappers.bats — SPEC-SAVIA-MANIFEST Slice 1 wrapper tests.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  INIT_WRAPPER="$ROOT/scripts/savia-init.sh"
  VERIFY_WRAPPER="$ROOT/scripts/savia-verify.sh"
  export PYTHONPATH="$ROOT/scripts/lib:${PYTHONPATH:-}"
  TMPDIR_BATS="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_BATS"
}

@test "savia-init.sh exists and is executable" {
  [ -x "$INIT_WRAPPER" ]
}

@test "savia-init.sh generates savia.manifest.yaml" {
  run bash "$INIT_WRAPPER" --out "$TMPDIR_BATS/savia.manifest.yaml" \
      --workspace-id test-ws --force
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR_BATS/savia.manifest.yaml" ]
}

@test "savia-verify.sh validates a generated manifest" {
  bash "$INIT_WRAPPER" --out "$TMPDIR_BATS/savia.manifest.yaml" \
      --workspace-id test-ws --force
  run bash "$VERIFY_WRAPPER" --manifest "$TMPDIR_BATS/savia.manifest.yaml"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); assert d['valid'] is True"
}

# ── Slice 2: savia-install.sh ─────────────────────────────────────────────────

@test "savia-install.sh exists and is executable" {
  INSTALL_WRAPPER="$ROOT/scripts/savia-install.sh"
  [ -x "$INSTALL_WRAPPER" ]
}

@test "savia-install.sh installs example pack from file:// source" {
  INSTALL_WRAPPER="$ROOT/scripts/savia-install.sh"
  EXAMPLE_PACK="$ROOT/examples/savia-pack-example"
  WORKSPACE="$TMPDIR_BATS/workspace"
  mkdir -p "$WORKSPACE/.opencode/skills" "$WORKSPACE/.opencode/commands" \
            "$WORKSPACE/.opencode/agents"  "$WORKSPACE/.opencode/hooks"
  run bash "$INSTALL_WRAPPER" \
      "file://$EXAMPLE_PACK" \
      --workspace "$WORKSPACE" \
      --conf-max N1
  [ "$status" -eq 0 ]
  [ -f "$WORKSPACE/.opencode/skills/example-skill.md" ]
  [ -f "$WORKSPACE/.opencode/commands/example-command.md" ]
}

@test "savia-install.sh outputs JSON with name and version" {
  INSTALL_WRAPPER="$ROOT/scripts/savia-install.sh"
  EXAMPLE_PACK="$ROOT/examples/savia-pack-example"
  WORKSPACE="$TMPDIR_BATS/workspace2"
  mkdir -p "$WORKSPACE/.opencode/skills" "$WORKSPACE/.opencode/commands" \
            "$WORKSPACE/.opencode/agents"  "$WORKSPACE/.opencode/hooks"
  run bash "$INSTALL_WRAPPER" \
      "file://$EXAMPLE_PACK" \
      --workspace "$WORKSPACE" \
      --conf-max N1
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
assert d['name'] == 'savia-pack-example', f'bad name: {d}'
assert d['version'] == '1.0.0', f'bad version: {d}'
assert len(d['hash']) == 64, f'bad hash: {d}'
"
}

@test "savia-install.sh fails with wrong hash (exit 1)" {
  INSTALL_WRAPPER="$ROOT/scripts/savia-install.sh"
  EXAMPLE_PACK="$ROOT/examples/savia-pack-example"
  WORKSPACE="$TMPDIR_BATS/workspace3"
  mkdir -p "$WORKSPACE/.opencode/skills" "$WORKSPACE/.opencode/commands" \
            "$WORKSPACE/.opencode/agents"  "$WORKSPACE/.opencode/hooks"
  run bash "$INSTALL_WRAPPER" \
      "file://$EXAMPLE_PACK" \
      --workspace "$WORKSPACE" \
      --hash "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
      --conf-max N1
  [ "$status" -eq 1 ]
}

@test "savia-install.sh fails when source not found (exit 3)" {
  INSTALL_WRAPPER="$ROOT/scripts/savia-install.sh"
  run bash "$INSTALL_WRAPPER" "file:///nonexistent/path/to/pack"
  [ "$status" -eq 3 ]
}

# ── Slice 3: savia-lock.sh ────────────────────────────────────────────────────

@test "savia-lock.sh exists and is executable" {
  LOCK_WRAPPER="$ROOT/scripts/savia-lock.sh"
  [ -x "$LOCK_WRAPPER" ]
}

@test "savia-lock.sh generates savia.lock from manifest" {
  LOCK_WRAPPER="$ROOT/scripts/savia-lock.sh"
  MANIFEST="$TMPDIR_BATS/savia.manifest.yaml"
  bash "$ROOT/scripts/savia-init.sh" --out "$MANIFEST" --workspace-id test-lock-ws --force
  run bash "$LOCK_WRAPPER" \
      --manifest "$MANIFEST" \
      --workspace "$TMPDIR_BATS" \
      --out "$TMPDIR_BATS/savia.lock"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR_BATS/savia.lock" ]
}

@test "savia-lock.sh output is valid JSON with components count" {
  LOCK_WRAPPER="$ROOT/scripts/savia-lock.sh"
  MANIFEST="$TMPDIR_BATS/savia.manifest.yaml"
  bash "$ROOT/scripts/savia-init.sh" --out "$MANIFEST" --workspace-id test-lock-ws2 --force
  run bash "$LOCK_WRAPPER" \
      --manifest "$MANIFEST" \
      --workspace "$TMPDIR_BATS" \
      --out "$TMPDIR_BATS/savia.lock"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
assert 'components' in d, f'missing components: {d}'
assert 'manifest_hash' in d, f'missing manifest_hash: {d}'
assert len(d['manifest_hash']) == 64, f'bad hash: {d}'
"
}

@test "savia-lock.sh fails gracefully on missing manifest (exit 1)" {
  LOCK_WRAPPER="$ROOT/scripts/savia-lock.sh"
  run bash "$LOCK_WRAPPER" \
      --manifest "$TMPDIR_BATS/nonexistent.yaml" \
      --workspace "$TMPDIR_BATS" \
      --out "$TMPDIR_BATS/savia.lock"
  [ "$status" -ne 0 ]
}

@test "savia-lock.sh is deterministic (two runs produce same lockfile)" {
  LOCK_WRAPPER="$ROOT/scripts/savia-lock.sh"
  MANIFEST="$TMPDIR_BATS/savia.manifest.yaml"
  bash "$ROOT/scripts/savia-init.sh" --out "$MANIFEST" --workspace-id test-det-ws --force
  bash "$LOCK_WRAPPER" --manifest "$MANIFEST" --workspace "$TMPDIR_BATS" \
      --out "$TMPDIR_BATS/savia.lock.1"
  bash "$LOCK_WRAPPER" --manifest "$MANIFEST" --workspace "$TMPDIR_BATS" \
      --out "$TMPDIR_BATS/savia.lock.2"
  diff "$TMPDIR_BATS/savia.lock.1" "$TMPDIR_BATS/savia.lock.2"
}

# ── Slice 3: savia-sync.sh ────────────────────────────────────────────────────

@test "savia-sync.sh exists and is executable" {
  SYNC_WRAPPER="$ROOT/scripts/savia-sync.sh"
  [ -x "$SYNC_WRAPPER" ]
}

@test "savia-sync.sh returns 0 on empty lockfile with no packs" {
  SYNC_WRAPPER="$ROOT/scripts/savia-sync.sh"
  MANIFEST="$TMPDIR_BATS/savia.manifest.yaml"
  LOCK="$TMPDIR_BATS/savia.lock"
  bash "$ROOT/scripts/savia-init.sh" --out "$MANIFEST" --workspace-id test-sync-ws --force
  bash "$ROOT/scripts/savia-lock.sh" \
      --manifest "$MANIFEST" --workspace "$TMPDIR_BATS" --out "$LOCK"
  run bash "$SYNC_WRAPPER" --lock "$LOCK" --workspace "$TMPDIR_BATS" --force
  [ "$status" -eq 0 ]
}

@test "savia-sync.sh fails when lockfile not found (exit 3)" {
  SYNC_WRAPPER="$ROOT/scripts/savia-sync.sh"
  run bash "$SYNC_WRAPPER" --lock "$TMPDIR_BATS/nonexistent.lock" \
      --workspace "$TMPDIR_BATS"
  [ "$status" -eq 3 ]
}
