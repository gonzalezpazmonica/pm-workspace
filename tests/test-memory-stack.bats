#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-089-memory-stack-l0l3.md
# Tests for memory-stack-load.sh and memory-cache-rebuild.sh
# SPEC-089: Memory Stack L0-L3 — token-budgeted progressive loading

HOOK='scripts/memory-stack-load.sh'
SCRIPT="$BATS_TEST_DIRNAME/../scripts/memory-stack-load.sh"
CACHE_SCRIPT="$BATS_TEST_DIRNAME/../scripts/memory-cache-rebuild.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMPDIR_MS="$(mktemp -d)"
  export HOME="$TMPDIR_MS"
  export SAVIA_PROFILES_DIR="$TMPDIR_MS/profiles"

  # Create mock active-user pointing to alice
  mkdir -p "$SAVIA_PROFILES_DIR/users/alice"
  cat > "$SAVIA_PROFILES_DIR/active-user.md" <<'EOF'
active_slug: alice
EOF
  cat > "$SAVIA_PROFILES_DIR/users/alice/identity.md" <<'EOF'
---
name: "Alice"
slug: "alice"
role: "Developer"
---
EOF
  cat > "$SAVIA_PROFILES_DIR/users/alice/preferences.md" <<'EOF'
---
language: "en"
---
EOF

  # Create mock auto-memory
  mkdir -p "$TMPDIR_MS/.claude/projects/test-project/memory"
  cat > "$TMPDIR_MS/.claude/projects/test-project/memory/MEMORY.md" <<'EOF'
- [feedback_one.md](feedback_one.md) — Always use set -uo pipefail in scripts
- [project_two.md](project_two.md) — Sprint velocity is 38 story points average
- [reference_three.md](reference_three.md) — GitHub PAT stored at ~/.azure/devops-pat
EOF
  cat > "$TMPDIR_MS/.claude/projects/test-project/memory/feedback_one.md" <<'EOF'
Always use set -uo pipefail in bash scripts.
This prevents silent failures and unset variable bugs.
EOF
  cat > "$TMPDIR_MS/.claude/projects/test-project/memory/project_two.md" <<'EOF'
Sprint velocity is 38 story points on average.
Team capacity has been stable for 3 sprints.
EOF

  mkdir -p "$TMPDIR_MS/.savia"
}

teardown() {
  rm -rf "$TMPDIR_MS"
}

# ── Positive: L0 returns identity info ─────────────────────────────────────

@test "L0 returns user identity information" {
  run bash "$SCRIPT" L0
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Alice"* ]]
  [[ "$output" == *"Developer"* ]]
}

@test "L0 includes language from preferences" {
  run bash "$SCRIPT" L0
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Lang:"* ]]
}

@test "L0 output respects token budget (max 200 chars)" {
  run bash "$SCRIPT" L0
  [[ "$status" -eq 0 ]]
  local len=${#output}
  [[ "$len" -le 200 ]]
}

# ── Positive: L1 returns memory index entries ──────────────────────────────

@test "L1 returns memory index entries" {
  run bash "$SCRIPT" L1
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"pipefail"* ]]
}

@test "L1 output respects token budget (max 600 chars)" {
  run bash "$SCRIPT" L1
  [[ "$status" -eq 0 ]]
  local len=${#output}
  [[ "$len" -le 600 ]]
}

# ── Positive: L2 with topic returns topic file content ─────────────────────

@test "L2 with topic returns matching file content" {
  run bash "$SCRIPT" L2 feedback
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"pipefail"* ]]
}

@test "L2 with topic searches by grep fallback" {
  run bash "$SCRIPT" L2 velocity
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"velocity"* ]] || [[ "$output" == *"sprint"* ]] || [[ "$output" == *"Sprint"* ]]
}

# ── Negative: L2 without topic shows usage ─────────────────────────────────

@test "L2 without topic shows usage message" {
  run bash "$SCRIPT" L2
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Usage"* ]]
}

# ── Negative: missing profile gracefully handled ───────────────────────────

@test "L0 handles missing profile gracefully" {
  rm -rf "$SAVIA_PROFILES_DIR"
  run bash "$SCRIPT" L0
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"unknown"* ]]
}

# ── Negative: L3 without topic shows usage ─────────────────────────────────

@test "L3 without topic shows usage message" {
  run bash "$SCRIPT" L3
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Usage"* ]]
}

# ── Edge: L3 without SQLite falls back to grep ─────────────────────────────

@test "L3 without SQLite falls back to grep search" {
  rm -f "$TMPDIR_MS/.savia/memory-cache.db"
  run bash "$SCRIPT" L3 pipefail
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"pipefail"* ]] || [[ "$output" == *"feedback"* ]]
}

# ── Positive: L3 with SQLite returns results (or falls back) ───────────────

@test "L3 with SQLite cache returns results or falls back" {
  # Build cache if sqlite3 available
  bash "$CACHE_SCRIPT" >/dev/null 2>&1 || true
  run bash "$SCRIPT" L3 pipefail
  [[ "$status" -eq 0 ]]
  # Should find something via SQLite or grep fallback
  [[ -n "$output" ]]
}

# ── Positive: cache-rebuild runs without error ─────────────────────────────

@test "cache-rebuild exits successfully" {
  run bash "$CACHE_SCRIPT"
  [[ "$status" -eq 0 ]]
  # Script uses python3 sqlite3 module — verify db created or success message
  if python3 -c "import sqlite3" 2>/dev/null; then
    [[ "$output" == *"Cache rebuilt"* ]] || [[ "$output" == *"entries"* ]]
  else
    [[ "$output" == *"python3 with sqlite3"* ]]
  fi
}

# ── Positive: cache-rebuild creates expected tables (if sqlite3 present) ───

@test "cache-rebuild creates tables when sqlite3 available" {
  if ! command -v sqlite3 &>/dev/null; then
    skip "sqlite3 not installed"
  fi
  bash "$CACHE_SCRIPT" >/dev/null 2>&1
  local tables
  tables="$(sqlite3 "$TMPDIR_MS/.savia/memory-cache.db" ".tables" 2>/dev/null)"
  [[ "$tables" == *"memory_entries"* ]]
  [[ "$tables" == *"memory_index"* ]]
}

# ── Edge: cache-rebuild with no memory files exits gracefully ──────────────

@test "cache-rebuild with empty memory dir exits gracefully" {
  rm -rf "$TMPDIR_MS/.claude"
  run bash "$CACHE_SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Empty cache"* ]] || [[ "$output" == *"No memory"* ]] || [[ "$output" == *"sqlite3"* ]]
}

# ── Safety: scripts have safety flags ──────────────────────────────────────

@test "memory-stack-load.sh has safety flags" {
  head -10 "$SCRIPT" | grep -qE "set -(e|u).*pipefail"
}

@test "memory-cache-rebuild.sh has safety flags" {
  head -10 "$CACHE_SCRIPT" | grep -qE "set -(e|u).*pipefail"
}

# ── Edge: no-arg invocation shows help ─────────────────────────────────────

@test "no-arg invocation shows usage help" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"L0"* ]]
  [[ "$output" == *"L1"* ]]
  [[ "$output" == *"L2"* ]]
  [[ "$output" == *"L3"* ]]
}

# ── Edge: invalid layer handled gracefully ─────────────────────────────────

@test "invalid layer shows usage instead of error" {
  run bash "$SCRIPT" L9
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Usage"* ]]
}

# ── Edge: nonexistent topic returns gracefully ─────────────────────────────

@test "L2 nonexistent topic returns message" {
  run bash "$SCRIPT" L2 zzz_nonexistent_zzz
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"No topic"* ]] || [[ -n "$output" ]]
}

# ── Edge: zero-length MEMORY.md handled ────────────────────────────────────

@test "L1 with zero-length MEMORY.md returns gracefully" {
  truncate -s 0 "$TMPDIR_MS/.claude/projects/test-project/memory/MEMORY.md"
  run bash "$SCRIPT" L1
  [[ "$status" -eq 0 ]]
}

# ── Coverage: BUDGET variables defined ─────────────────────────────────────

@test "budget constants defined in stack-load script" {
  grep -q "BUDGET_L0" "$SCRIPT"
  grep -q "BUDGET_L1" "$SCRIPT"
  grep -q "BUDGET_L2" "$SCRIPT"
  grep -q "BUDGET_L3" "$SCRIPT"
}

@test "cache-rebuild uses sqlite3 CLI" {
  grep -q "sqlite3" "$CACHE_SCRIPT"
}

# ── Coverage: key functions exist in target ────────────────────────────────

@test "script defines load_l0 and load_l1 functions" {
  grep -q "load_l0" "$SCRIPT"
  grep -q "load_l1" "$SCRIPT"
}

@test "script defines load_l2 and load_l3 functions" {
  grep -q "load_l2" "$SCRIPT"
  grep -q "load_l3" "$SCRIPT"
}

@test "script defines truncate_to and find_memory_dir helpers" {
  grep -q "truncate_to" "$SCRIPT"
  grep -q "find_memory_dir" "$SCRIPT"
}
