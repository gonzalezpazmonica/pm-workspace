#!/usr/bin/env bats
# test-se355-audit-receipts.bats — BATS tests for SE-355 Audit Ledger metadata-only
# Ref: SE-355 — decision receipts con `enforced`, metadata-only, retention 30d

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  LEDGER="$REPO_ROOT/scripts/audit-receipts.sh"
  export LEDGER
  # Ledger aislado por test
  export SAVIA_AUDIT_DIR="$(mktemp -d)"
}

teardown() {
  if [[ -d "${SAVIA_AUDIT_DIR:-}" ]]; then
    rm -rf "$SAVIA_AUDIT_DIR"
  fi
}

# ── T1: write / schema ────────────────────────────────────────────────────────

@test "write crea receipt con seq incrementado" {
  run "$LEDGER" write --action gate_deny --actor agente-x --outcome enforced_deny --gate G13 --session s1
  [[ "$status" -eq 0 ]]
  run "$LEDGER" write --action commit --actor agente-x --outcome success --session s2
  [[ "$status" -eq 0 ]]
  run grep -q '"seq":1' "$SAVIA_AUDIT_DIR/actions.jsonl"
  [[ "$status" -eq 0 ]]
  run grep -q '"seq":2' "$SAVIA_AUDIT_DIR/actions.jsonl"
  [[ "$status" -eq 0 ]]
}

@test "write con gate → enforced=true" {
  "$LEDGER" write --action gate_deny --actor a --outcome enforced_deny --gate G13 --session s >/dev/null
  run grep -q '"enforced":true' "$SAVIA_AUDIT_DIR/actions.jsonl"
  [[ "$status" -eq 0 ]]
}

@test "write sin gate → enforced=false" {
  "$LEDGER" write --action commit --actor a --outcome success --session s >/dev/null
  run grep -q '"enforced":false' "$SAVIA_AUDIT_DIR/actions.jsonl"
  [[ "$status" -eq 0 ]]
}

@test "write sin action/actor → error" {
  run "$LEDGER" write --action solo
  [[ "$status" -ne 0 ]]
}

@test "write outcome inválido → error" {
  run "$LEDGER" write --action x --actor a --outcome inventado
  [[ "$status" -ne 0 ]]
}

# ── T2: metadata-only (AC-0) ──────────────────────────────────────────────────

@test "ledger nunca contiene prompts/bodies/args" {
  "$LEDGER" write --action commit --actor a --outcome success --session s >/dev/null
  run grep -qE 'prompt|body|argument|filename|content|tool_input' "$SAVIA_AUDIT_DIR/actions.jsonl"
  [[ "$status" -ne 0 ]]
}

# ── T3: governed (AC-1) ───────────────────────────────────────────────────────

@test "governed solo devuelve enforced=true" {
  "$LEDGER" write --action gate_deny --actor a --outcome enforced_deny --gate G13 --session s >/dev/null
  "$LEDGER" write --action commit --actor a --outcome success --session s >/dev/null
  run "$LEDGER" governed
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"G13"* ]]
  [[ "$output" != *'"outcome":"success"'* ]]
}

# ── T4: query filtros ─────────────────────────────────────────────────────────

@test "query --gate filtra por gate" {
  "$LEDGER" write --action gate_deny --actor a --outcome enforced_deny --gate G13 --session s >/dev/null
  "$LEDGER" write --action gate_deny --actor a --outcome enforced_deny --gate G5 --session s >/dev/null
  run "$LEDGER" query --gate G13 --all
  [[ "$output" == *"G13"* ]]
  [[ "$output" != *'"gate_id":"G5"'* ]]
}

@test "query --actor filtra por actor" {
  "$LEDGER" write --action commit --actor alice --outcome success --session s >/dev/null
  "$LEDGER" write --action commit --actor bob --outcome success --session s >/dev/null
  run "$LEDGER" query --actor alice --all
  [[ "$output" == *"alice"* ]]
  [[ "$output" != *"bob"* ]]
}

@test "query --days excluye registros viejos" {
  # escribe receipt con ts antiguo directamente
  mkdir -p "$SAVIA_AUDIT_DIR"
  printf '{"seq":1,"ts":"2020-01-01T00:00:00Z","session_id":"s","actor":"old","action":"commit","outcome":"success","enforced":false,"gate_id":"null"}\n' >> "$SAVIA_AUDIT_DIR/actions.jsonl"
  printf '{"seq":2,"ts":"%s","session_id":"s","actor":"new","action":"commit","outcome":"success","enforced":false,"gate_id":"null"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$SAVIA_AUDIT_DIR/actions.jsonl"
  run "$LEDGER" query
  [[ "$output" == *"new"* ]]
  [[ "$output" != *"old"* ]]
}

# ── T5: prune (AC-4) ──────────────────────────────────────────────────────────

@test "prune borra en batch solo registros expirables" {
  mkdir -p "$SAVIA_AUDIT_DIR"
  printf '{"seq":1,"ts":"2020-01-01T00:00:00Z","session_id":"s","actor":"old","action":"commit","outcome":"success","enforced":false,"gate_id":"null"}\n' >> "$SAVIA_AUDIT_DIR/actions.jsonl"
  printf '{"seq":2,"ts":"%s","session_id":"s","actor":"new","action":"commit","outcome":"success","enforced":false,"gate_id":"null"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$SAVIA_AUDIT_DIR/actions.jsonl"
  run "$LEDGER" prune --days 30
  [[ "$status" -eq 0 ]]
  run grep -q '"actor":"old"' "$SAVIA_AUDIT_DIR/actions.jsonl"
  [[ "$status" -ne 0 ]]
  run grep -q '"actor":"new"' "$SAVIA_AUDIT_DIR/actions.jsonl"
  [[ "$status" -eq 0 ]]
}

# ── T6: stats ─────────────────────────────────────────────────────────────────

@test "stats reporta resumen" {
  "$LEDGER" write --action gate_deny --actor a --outcome enforced_deny --gate G13 --session s >/dev/null
  "$LEDGER" write --action commit --actor a --outcome success --session s >/dev/null
  run "$LEDGER" stats
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"2 receipts"* ]]
  [[ "$output" == *"1"* ]]  # alguna métrica numérica
}
