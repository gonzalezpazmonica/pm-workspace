#!/usr/bin/env bats
# Tests for slice-context-chain.sh — Knowledge chain between dev-session slices
# Ref: docs/propuestas/SPEC-096-blocker-as-context.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/slice-context-chain.sh"
  TMPDIR_SC=$(mktemp -d)

  # Create mock dev-session directory
  SESSION_DIR="$TMPDIR_SC/dev-session"
  mkdir -p "$SESSION_DIR"/{slices,impl,validation}

  # state.json with 3 slices: 2 completed, 1 pending
  cat > "$SESSION_DIR/state.json" <<'EOF'
{
  "session_id": "20260408-TEST-demo",
  "spec_path": "test.spec.md",
  "total_slices": 3,
  "current_slice": 3,
  "slices": [
    {"id": 1, "name": "Domain entities", "status": "completed", "files": ["Sala.cs"]},
    {"id": 2, "name": "Repository layer", "status": "verified", "files": ["SalaRepo.cs"]},
    {"id": 3, "name": "Controller", "status": "pending", "files": ["SalaCtrl.cs"]}
  ]
}
EOF

  # impl files for completed slices
  cat > "$SESSION_DIR/impl/slice-1.md" <<'EOF'
## Implementation: Domain entities
Created Sala.cs with record-based DTO pattern.
Using Repository pattern with constructor injection.
Convention: PascalCase for public members, _camelCase for private.
public class Sala { public Guid Id { get; init; } }
public record SalaDto(string Name, int Capacity);
EOF

  cat > "$SESSION_DIR/impl/slice-2.md" <<'EOF'
## Implementation: Repository layer
Created SalaRepo.cs following existing pattern.
Chose EF Core Fluent API for configuration approach.
public interface ISalaRepository { Task<Sala?> GetByIdAsync(Guid id); }
public class SalaRepository : ISalaRepository { }
EOF

  # validation files
  cat > "$SESSION_DIR/validation/slice-1.md" <<'EOF'
## Validation: Slice 1
Tests: 4/4 pass | Coherence: 98%
EOF
  cat > "$SESSION_DIR/validation/slice-2.md" <<'EOF'
## Validation: Slice 2
Tests: 6/6 pass | Coherence: 97%
EOF

  # Empty session (no completed slices)
  EMPTY_SESSION="$TMPDIR_SC/empty-session"
  mkdir -p "$EMPTY_SESSION"
  cat > "$EMPTY_SESSION/state.json" <<'EOF'
{
  "session_id": "20260408-EMPTY",
  "slices": [
    {"id": 1, "name": "First slice", "status": "pending", "files": ["A.cs"]}
  ]
}
EOF
}

teardown() {
  rm -rf "$TMPDIR_SC"
}

# ── 1. Script existence and structure ────────────────────────────────────────

@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "script has safety flags (set -uo pipefail)" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "script shows usage without arguments" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

# ── 2. Build context chain ───────────────────────────────────────────────────

@test "build creates context-chain.md" {
  run bash "$SCRIPT" build "$SESSION_DIR"
  [ "$status" -eq 0 ]
  [ -f "$SESSION_DIR/context-chain.md" ]
}

@test "build includes Knowledge Chain header" {
  bash "$SCRIPT" build "$SESSION_DIR"
  grep -q "Knowledge Chain" "$SESSION_DIR/context-chain.md"
}

@test "build includes both completed slices" {
  bash "$SCRIPT" build "$SESSION_DIR"
  grep -q "Slice 1" "$SESSION_DIR/context-chain.md"
  grep -q "Slice 2" "$SESSION_DIR/context-chain.md"
}

@test "build does NOT include pending slice 3" {
  bash "$SCRIPT" build "$SESSION_DIR"
  ! grep -q "Slice 3" "$SESSION_DIR/context-chain.md"
}

@test "build extracts file names from impl" {
  bash "$SCRIPT" build "$SESSION_DIR"
  grep -q "Sala.cs" "$SESSION_DIR/context-chain.md"
}

@test "build reports word count" {
  run bash "$SCRIPT" build "$SESSION_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"words"* ]]
}

# ── 3. Empty session ─────────────────────────────────────────────────────────

@test "build on empty session creates minimal chain" {
  run bash "$SCRIPT" build "$EMPTY_SESSION"
  [ "$status" -eq 0 ]
  [ -f "$EMPTY_SESSION/context-chain.md" ]
  grep -q "No completed slices" "$EMPTY_SESSION/context-chain.md"
}

# ── 4. Update (idempotent rebuild) ───────────────────────────────────────────

@test "update produces same result as build (idempotent)" {
  bash "$SCRIPT" build "$SESSION_DIR"
  local hash_build
  hash_build=$(sha256sum "$SESSION_DIR/context-chain.md" | cut -d' ' -f1)

  bash "$SCRIPT" update "$SESSION_DIR"
  local hash_update
  hash_update=$(sha256sum "$SESSION_DIR/context-chain.md" | cut -d' ' -f1)

  [ "$hash_build" = "$hash_update" ]
}

# ── 5. Show ──────────────────────────────────────────────────────────────────

@test "show displays chain content" {
  bash "$SCRIPT" build "$SESSION_DIR"
  run bash "$SCRIPT" show "$SESSION_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Knowledge Chain"* ]]
}

@test "show fails if no chain exists" {
  run bash "$SCRIPT" show "$TMPDIR_SC/nonexistent"
  [ "$status" -eq 1 ]
}

# ── 6. Stats ─────────────────────────────────────────────────────────────────

@test "stats shows slice coverage" {
  bash "$SCRIPT" build "$SESSION_DIR"
  run bash "$SCRIPT" stats "$SESSION_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Slices covered"* ]]
  [[ "$output" == *"2 / 3"* ]]
}

@test "stats shows word count and token estimate" {
  bash "$SCRIPT" build "$SESSION_DIR"
  run bash "$SCRIPT" stats "$SESSION_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Words"* ]]
  [[ "$output" == *"Est. tokens"* ]]
}

# ── 7. Edge cases ────────────────────────────────────────────────────────────

@test "build fails on missing session directory" {
  run bash "$SCRIPT" build "$TMPDIR_SC/nonexistent"
  [ "$status" -eq 1 ]
}

@test "build fails on missing state.json" {
  mkdir -p "$TMPDIR_SC/no-state"
  run bash "$SCRIPT" build "$TMPDIR_SC/no-state"
  [ "$status" -eq 1 ]
}

@test "unknown command shows error" {
  run bash "$SCRIPT" foobar
  [ "$status" -eq 1 ]
}
