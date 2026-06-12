#!/usr/bin/env bats
# tests/scripts/test-memory-canary-check.bats — SE-220 Output Filtering + Canary
#
# Spec: docs/propuestas/SE-220-jailbreak-defenses.md (AC-03, AC-06)
# Ref: SPEC-142, SE-073, AgentPoison (Chen et al. 2024)
#
# Tests para memory-canary-check.sh: defensa contra memory-poisoning.
# Verifica invariantes de MEMORY.md y existencia del canary token.
#
# Safety: el script target usa set -uo pipefail.

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/memory-canary-check.sh"

setup() {
  MEMDIR="$BATS_TEST_TMPDIR/savia-mem"
  mkdir -p "$MEMDIR/auto"
  export SAVIA_MEMORY_DIR="$MEMDIR"
}

teardown() {
  unset SAVIA_MEMORY_DIR
}

# Helper: crear un MEMORY.md valido + canary
make_valid_memory() {
  cat > "$MEMDIR/auto/.canary" <<EOF
MEMORY_INDEX_CANARY_20260611_abcd1234
issued_at: 2026-06-11T00:00:00Z
purpose: test
verified_by: scripts/memory-canary-check.sh
EOF
  cat > "$MEMDIR/auto/MEMORY.md" <<EOF
# MEMORY Index
<!-- ENTRIES_START -->
- decision: foo [decision/foo]
- decision: bar [decision/bar]
<!-- ENTRIES_END -->
EOF
}

@test "script es bash valido" {
  bash -n "$SCRIPT"
}

@test "uses set -uo pipefail" {
  head -10 "$SCRIPT" | grep -q "set -[euo]*o pipefail"
}

@test "PASS con MEMORY.md y canary validos" {
  make_valid_memory
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "FAIL si canary missing" {
  cat > "$MEMDIR/auto/MEMORY.md" <<EOF
# MEMORY Index
<!-- ENTRIES_START -->
- decision: foo [decision/foo]
<!-- ENTRIES_END -->
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"canary_missing"* ]]
}

@test "FAIL si MEMORY.md missing" {
  cat > "$MEMDIR/auto/.canary" <<EOF
MEMORY_INDEX_CANARY_20260611_abcd1234
issued_at: 2026-06-11T00:00:00Z
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"index_missing"* ]]
}

@test "FAIL si canary token malformado" {
  cat > "$MEMDIR/auto/.canary" <<EOF
INVALID_TOKEN_FORMAT
issued_at: 2026-06-11
EOF
  cat > "$MEMDIR/auto/MEMORY.md" <<EOF
<!-- ENTRIES_START -->
<!-- ENTRIES_END -->
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"canary_token_malformed"* ]]
}

@test "FAIL si hay duplicados de topic_key" {
  make_valid_memory
  echo "- decision: foo-again [decision/foo]" >> "$MEMDIR/auto/MEMORY.md"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"topic_key_duplicates"* ]]
}

@test "FAIL si lineas exceden cap" {
  cat > "$MEMDIR/auto/.canary" <<EOF
MEMORY_INDEX_CANARY_20260611_abcd1234
issued_at: 2026-06-11T00:00:00Z
EOF
  {
    echo "<!-- ENTRIES_START -->"
    for i in $(seq 1 250); do
      echo "- decision: entry-$i [decision/entry-$i]"
    done
    echo "<!-- ENTRIES_END -->"
  } > "$MEMDIR/auto/MEMORY.md"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"lines_over_cap"* ]]
}

@test "FAIL si tamaño excede 25KB" {
  cat > "$MEMDIR/auto/.canary" <<EOF
MEMORY_INDEX_CANARY_20260611_abcd1234
issued_at: 2026-06-11T00:00:00Z
EOF
  # 30000 bytes, pero pocas lineas (lineas largas)
  {
    echo "<!-- ENTRIES_START -->"
    for i in $(seq 1 50); do
      pad=$(printf '%.0s_' $(seq 1 600))
      echo "- decision: title-$i [decision/key-$i]_padding_${pad}"
    done
    echo "<!-- ENTRIES_END -->"
  } > "$MEMDIR/auto/MEMORY.md"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"size_over_cap"* ]] || [[ "$output" == *"lines_over_cap"* ]]
}

@test "FAIL si falta ENTRIES_START" {
  cat > "$MEMDIR/auto/.canary" <<EOF
MEMORY_INDEX_CANARY_20260611_abcd1234
issued_at: 2026-06-11T00:00:00Z
EOF
  cat > "$MEMDIR/auto/MEMORY.md" <<EOF
# MEMORY Index
- decision: orphan [decision/orphan]
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"entries_start_missing"* ]]
}

@test "JSON output PASS valido" {
  make_valid_memory
  run bash "$SCRIPT" --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"verdict":"PASS"'* ]]
  [[ "$output" == *'"lines":'* ]]
}

@test "JSON output FAIL valido" {
  run bash "$SCRIPT" --json
  [ "$status" -eq 1 ]
  [[ "$output" == *'"verdict":"FAIL"'* ]]
  [[ "$output" == *'"errors":'* ]]
}

@test "--rotate genera nuevo canary" {
  run bash "$SCRIPT" --rotate
  [ "$status" -eq 0 ]
  [[ "$output" == *"Canary rotated:"* ]]
  [[ -f "$MEMDIR/auto/.canary" ]]
  grep -q '^MEMORY_INDEX_CANARY_' "$MEMDIR/auto/.canary"
}

@test "--rotate dos veces produce canaries distintos" {
  bash "$SCRIPT" --rotate >/dev/null
  c1=$(head -1 "$MEMDIR/auto/.canary")
  sleep 1
  bash "$SCRIPT" --rotate >/dev/null
  c2=$(head -1 "$MEMDIR/auto/.canary")
  [ "$c1" != "$c2" ]
}

@test "FAIL si entry mal formada (sin topic_key entre brackets)" {
  cat > "$MEMDIR/auto/.canary" <<EOF
MEMORY_INDEX_CANARY_20260611_abcd1234
issued_at: 2026-06-11T00:00:00Z
EOF
  cat > "$MEMDIR/auto/MEMORY.md" <<EOF
<!-- ENTRIES_START -->
- decision: missing-topic-key
- decision: ok [decision/ok]
<!-- ENTRIES_END -->
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"malformed_entries"* ]]
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "EDGE: empty MEMORY.md (zero bytes) — falla por entries_start_missing" {
  cat > "$MEMDIR/auto/.canary" <<EOF
MEMORY_INDEX_CANARY_20260611_abcd1234
issued_at: 2026-06-11T00:00:00Z
EOF
  : > "$MEMDIR/auto/MEMORY.md"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"entries_start_missing"* ]]
}

@test "EDGE: nonexistent SAVIA_MEMORY_DIR — falla con index_missing" {
  export SAVIA_MEMORY_DIR="/nonexistent-path-$$"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing"* ]]
}

@test "EDGE: large valid MEMORY.md (boundary del cap 200) — PASS" {
  cat > "$MEMDIR/auto/.canary" <<EOF
MEMORY_INDEX_CANARY_20260611_abcd1234
issued_at: 2026-06-11T00:00:00Z
EOF
  {
    echo "<!-- ENTRIES_START -->"
    for i in $(seq 1 195); do
      echo "- decision: t$i [decision/k-$i]"
    done
    echo "<!-- ENTRIES_END -->"
  } > "$MEMDIR/auto/MEMORY.md"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "BOUNDARY: 200 lineas exactas — pasa" {
  cat > "$MEMDIR/auto/.canary" <<EOF
MEMORY_INDEX_CANARY_20260611_abcd1234
issued_at: 2026-06-11T00:00:00Z
EOF
  {
    echo "<!-- ENTRIES_START -->"
    for i in $(seq 1 198); do
      echo "- decision: t$i [decision/k-$i]"
    done
    echo "<!-- ENTRIES_END -->"
  } > "$MEMDIR/auto/MEMORY.md"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "EDGE: empty .canary file — falla con malformed token" {
  : > "$MEMDIR/auto/.canary"
  cat > "$MEMDIR/auto/MEMORY.md" <<EOF
<!-- ENTRIES_START -->
<!-- ENTRIES_END -->
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"canary_token_malformed"* ]]
}

@test "EDGE: zero entries (block vacio) — PASS" {
  cat > "$MEMDIR/auto/.canary" <<EOF
MEMORY_INDEX_CANARY_20260611_abcd1234
issued_at: 2026-06-11T00:00:00Z
EOF
  cat > "$MEMDIR/auto/MEMORY.md" <<EOF
<!-- ENTRIES_START -->
<!-- ENTRIES_END -->
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

# ── Spec reference ──────────────────────────────────────────────────────────

@test "SPEC-220 doc: file de spec existe en docs/propuestas/" {
  [ -f "$BATS_TEST_DIRNAME/../../docs/propuestas/SE-220-jailbreak-defenses.md" ]
}
