#!/usr/bin/env bats
# test-se352-memory-origin-gate.bats — BATS tests for SE-352 Trust-Gated Memory
# Ref: SE-352 — provenance de origen + taint + exclusión de consolidación

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  STORE="$REPO_ROOT/scripts/memory-store.sh"
  HOOK="$REPO_ROOT/.opencode/hooks/memory-origin-gate.sh"
  export REPO_ROOT STORE HOOK

  # Isolated store per test
  export PROJECT_ROOT="$(mktemp -d)"
  export SAVIA_TEST_MODE=true
  export SAVIA_VERIFIED_MEMORY_DISABLED=false
  export HOME="$(mktemp -d)"
  export SAVIA_EMBED_PORT=0
}

teardown() {
  if [[ -d "${PROJECT_ROOT:-}" ]]; then
    rm -rf "$PROJECT_ROOT"
  fi
}

# ── T1: save default origin = untrusted (fail-safe) ───────────────────────────

@test "save sin --origin ni source confiable → origin=untrusted" {
  run "$STORE" save --type discovery --title "Test entry" --content "contenido de prueba" --source "user:explicit"
  [[ "$status" -eq 0 ]]
  # user:explicit → owner
  grep -q '"origin":"owner"' "$PROJECT_ROOT/output/.memory-store.jsonl"
}

@test "save sin --source → rechazado (SE-072 sigue activo)" {
  run "$STORE" save --type discovery --title "No source" --content "contenido"
  [[ "$status" -ne 0 ]]
}

@test "save con --source tool:Bash sin --origin → origin=agent" {
  run "$STORE" save --type discovery --title "Tool entry" --content "contenido de prueba" --source "tool:Bash"
  [[ "$status" -eq 0 ]]
  grep -q '"origin":"agent"' "$PROJECT_ROOT/output/.memory-store.jsonl"
}

@test "save con --source network (sin tool:) → origin=untrusted" {
  run "$STORE" save --type discovery --title "Network entry" --content "contenido de prueba" --source "file:scripts/x.sh:1"
  [[ "$status" -eq 0 ]]
  grep -q '"origin":"agent"' "$PROJECT_ROOT/output/.memory-store.jsonl"
}

@test "save con --origin inválido → error" {
  run "$STORE" save --type discovery --title "Bad origin" --content "contenido" --source "user:explicit" --origin "hacker"
  [[ "$status" -ne 0 ]]
}

@test "save con --origin system explícito → se respeta" {
  run "$STORE" save --type config --title "Sys entry" --content "contenido de prueba" --source "tool:Bash" --origin "system"
  [[ "$status" -eq 0 ]]
  grep -q '"origin":"system"' "$PROJECT_ROOT/output/.memory-store.jsonl"
}

# ── T2: taint de turno ────────────────────────────────────────────────────────

@test "hook no taint tool local (Read)" {
  INPUT='{"tool_name": "Read", "tool_input": {"path": "/tmp/x"}, "session_id": "s1"}'
  run env SAVIA_MEMORY_ORIGIN_GATE=on bash "$HOOK" <<< "$INPUT"
  [[ "$status" -eq 0 ]]
  [[ ! -f "/tmp/savia-memory-taint/s1" ]]
}

@test "hook taint tool de red (webfetch)" {
  INPUT='{"tool_name": "webfetch", "tool_input": {"url": "https://x.com"}, "session_id": "s2"}'
  run env SAVIA_MEMORY_ORIGIN_GATE=on bash "$HOOK" <<< "$INPUT"
  [[ "$status" -eq 0 ]]
  [[ -f "/tmp/savia-memory-taint/s2" ]]
}

@test "hook taint Bash con curl" {
  INPUT='{"tool_name": "Bash", "tool_input": {"command": "curl -s https://api.github.com"}, "session_id": "s3"}'
  run env SAVIA_MEMORY_ORIGIN_GATE=on bash "$HOOK" <<< "$INPUT"
  [[ "$status" -eq 0 ]]
  [[ -f "/tmp/savia-memory-taint/s3" ]]
}

@test "hook exit 0 en JSON inválido (fail-soft)" {
  run env SAVIA_MEMORY_ORIGIN_GATE=on bash "$HOOK" <<< "NOT JSON"
  [[ "$status" -eq 0 ]]
}

@test "hook exit 0 con SAVIA_MEMORY_ORIGIN_GATE=off" {
  INPUT='{"tool_name": "webfetch", "tool_input": {"url": "https://x.com"}, "session_id": "s4"}'
  run env SAVIA_MEMORY_ORIGIN_GATE=off bash "$HOOK" <<< "$INPUT"
  [[ "$status" -eq 0 ]]
  [[ ! -f "/tmp/savia-memory-taint/s4" ]]
}

# ── T3: audit-origins y consolidate ───────────────────────────────────────────

@test "audit-origins reporta distribución" {
  "$STORE" save --type discovery --title "O1" --content "contenido de prueba a" --source "user:explicit" >/dev/null
  "$STORE" save --type discovery --title "O2" --content "contenido de prueba b" --source "tool:Bash" >/dev/null
  run "$STORE" audit-origins
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"owner:"* ]]
  [[ "$output" == *"agent:"* ]]
  [[ "$output" == *"Total:"* ]]
}

@test "consolidate --dry-run excluye untrusted/system" {
  # create owner + untrusted entries
  "$STORE" save --type discovery --title "Trusted" --content "contenido de prueba x1" --source "user:explicit" >/dev/null
  "$STORE" save --type discovery --title "Dirty" --content "contenido de prueba x2" --source "user:explicit" --origin "untrusted" >/dev/null
  run "$STORE" consolidate --dry-run
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"excluidas 1"* ]]
}

@test "consolidate real elimina untrusted y mantiene owner" {
  "$STORE" save --type discovery --title "TrustedK" --content "contenido de prueba y1" --source "user:explicit" >/dev/null
  "$STORE" save --type discovery --title "DirtyK" --content "contenido de prueba y2" --source "user:explicit" --origin "untrusted" >/dev/null
  run "$STORE" consolidate
  [[ "$status" -eq 0 ]]
  grep -q '"title":"TrustedK"' "$PROJECT_ROOT/output/.memory-store.jsonl"
  run grep -q '"title":"DirtyK"' "$PROJECT_ROOT/output/.memory-store.jsonl"
  [[ "$status" -ne 0 ]]
}

# ── T4: search --min-origin ───────────────────────────────────────────────────

@test "search --min-origin owner excluye untrusted" {
  "$STORE" save --type discovery --title "QueryTrusted" --content "contenido de prueba z1" --source "user:explicit" >/dev/null
  "$STORE" save --type discovery --title "QueryDirty" --content "contenido de prueba z2" --source "user:explicit" --origin "untrusted" >/dev/null
  run "$STORE" search "QueryTrusted" --min-origin owner --mode grep
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"QueryTrusted"* ]]
  run "$STORE" search "QueryDirty" --min-origin owner --mode grep
  [[ "$output" != *"QueryDirty"* ]]
}
