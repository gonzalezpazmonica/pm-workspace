#!/usr/bin/env bats
# tests/test-memory-consolidate.bats — SE-317: Memoria reflexiva (S1-S4).
# Ref: docs/propuestas/SE-317-memoria-reflexiva.md (AC-S1..S4)

CONS="scripts/memory-consolidate.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPD="${BATS_TEST_TMPDIR}"
  mkdir -p "$TMPD"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR" 2>/dev/null || true
  cd /
}

make_store() { # file
  cat > "$1" <<'EOF'
{"hash":"h1","title":"Nota A","content":"el servicio gateway sufrio un timeout en produccion","ts":"2026-08-01T10:00:00Z","concepts":["gateway"],"topic_key":"incident/gateway","quality":"unverified","importance_tier":"C"}
{"hash":"h2","title":"Nota A copia","content":"el servicio gateway sufrio un timeout en produccion","ts":"2026-08-01T11:00:00Z","concepts":["gateway"],"topic_key":"incident/gateway","quality":"unverified","importance_tier":"C"}
{"hash":"h3","title":"Nota B","content":"reunion: gateway timeout discutido, se planifico rollback","ts":"2026-08-02T09:00:00Z","concepts":["gateway","rollback"],"topic_key":"incident/gateway","quality":"unverified","importance_tier":"C"}
{"hash":"h4","title":"Nota obsoleta","content":"detalle viejo","ts":"2026-07-01T08:00:00Z","concepts":[],"topic_key":"incident/gateway","quality":"absorbed","importance_tier":"D"}
EOF
}

# ── S1: scan ────────────────────────────────────────────────────────────────

@test "S1.0: script existe, ejecutable, pipefail" {
  [[ -f "$CONS" ]]
  [[ -x "$CONS" ]]
  run grep -c 'set -uo pipefail' "$CONS"
  [[ "$output" -ge 1 ]]
}

@test "AC-S1.1: 2 notas idénticas -> candidato a merge con score 1.0" {
  local s="$TMPD/store.jsonl"
  make_store "$s"
  run bash "$CONS" scan --store "$s"
  [[ "$status" -eq 0 ]]
  run python3 -c "
import json
last = None
with open('$TMPD/scan.jsonl') as f:  # no, leemos de output real
    pass
"
  # buscamos en el fichero de salida real del scan
  local out
  out=$(ls output/memory-consolidation/*-scan.jsonl 2>/dev/null | tail -1)
  run python3 -c "
import json, sys
with open('$out') as f:
    for line in f:
        d = json.loads(line)
        if d.get('type') == 'duplicate' and d.get('score') == 1.0:
            assert d['a']['hash'] == 'h1' and d['b']['hash'] == 'h2'
            sys.exit(0)
sys.exit(1)
"
  [[ "$status" -eq 0 ]]
}

@test "AC-S1.2: notas del mismo episodio -> near-duplicate (score > 0.85)" {
  local s="$TMPD/store2.jsonl"
  cat > "$s" <<'EOF'
{"hash":"n1","title":"X","content":"el mismo contenido del episodio uno dos tres cuatro","ts":"2026-08-01T10:00:00Z","concepts":["a"],"topic_key":"ep/1"}
{"hash":"n2","title":"Y","content":"el mismo contenido del episodio uno dos tres cinco","ts":"2026-08-01T11:00:00Z","concepts":["a"],"topic_key":"ep/1"}
EOF
  bash "$CONS" scan --store "$s" >/dev/null
  local out
  out=$(ls output/memory-consolidation/*-scan.jsonl 2>/dev/null | tail -1)
  run python3 -c "
import json, sys
with open('$out') as f:
    for line in f:
        d = json.loads(line)
        if d.get('type') == 'near_duplicate' and d.get('score', 0) > 0.85:
            sys.exit(0)
sys.exit(1)
"
  [[ "$status" -eq 0 ]]
}

# ── S2: link ────────────────────────────────────────────────────────────────

@test "AC-S2.1: nota que cita a otra existente -> arista derived-from" {
  local s="$TMPD/store3.jsonl"
  cat > "$s" <<'EOF'
{"hash":"a1","title":"Guia","content":"ver hash b1 para detalle del incidente","ts":"2026-08-01T10:00:00Z","concepts":["g"]}
{"hash":"b1","title":"Incidente","content":"detalle completo","ts":"2026-08-01T12:00:00Z","concepts":["g"]}
EOF
  bash "$CONS" link --store "$s" >/dev/null
  local out
  out=$(ls output/memory-consolidation/*-link.jsonl 2>/dev/null | tail -1)
  run python3 -c "
import json, sys
with open('$out') as f:
    for line in f:
        d = json.loads(line)
        if d.get('type') == 'derived-from' and d['from'] == 'a1' and d['to'] == 'b1':
            sys.exit(0)
sys.exit(1)
"
  [[ "$status" -eq 0 ]]
}

# ── S3: distill ─────────────────────────────────────────────────────────────

@test "AC-S3.1: episodio de >=2 notas genera 1 insight con citations" {
  local s="$TMPD/store4.jsonl"
  make_store "$s"
  bash "$CONS" distill --store "$s" >/dev/null
  local out
  out=$(ls output/memory-consolidation/*-distill.jsonl 2>/dev/null | tail -1)
  run python3 -c "
import json, sys
with open('$out') as f:
    for line in f:
        d = json.loads(line)
        if d.get('type') == 'insight':
            assert d['sources'] >= 2, d
            assert 'citations' in d and len(d['citations']) >= 2, d
            sys.exit(0)
sys.exit(1)
"
  [[ "$status" -eq 0 ]]
}

@test "AC-S3.2: fuentes marcadas absorbed (no borradas)" {
  local s="$TMPD/store5.jsonl"
  make_store "$s"
  bash "$CONS" distill --store "$s" >/dev/null
  local out
  out=$(ls output/memory-consolidation/*-distill.jsonl 2>/dev/null | tail -1)
  run python3 -c "
import json, sys
with open('$out') as f:
    for line in f:
        d = json.loads(line)
        if d.get('type') == 'insight':
            assert 'absorbed' in d and len(d['absorbed']) >= 2, d
            sys.exit(0)
sys.exit(1)
"
  [[ "$status" -eq 0 ]]
}

# ── S4: prune ───────────────────────────────────────────────────────────────

@test "AC-S4.1: --dry-run no modifica nada y lista candidatos con razón" {
  local s="$TMPD/store6.jsonl"
  make_store "$s"
  local before after
  before=$(sha256sum "$s" | cut -d' ' -f1)
  bash "$CONS" prune --store "$s" >/dev/null
  after=$(sha256sum "$s" | cut -d' ' -f1)
  [[ "$before" == "$after" ]]
  local out
  out=$(ls output/memory-consolidation/*-prune.jsonl 2>/dev/null | tail -1)
  run python3 -c "
import json, sys
with open('$out') as f:
    for line in f:
        d = json.loads(line)
        assert d.get('type') == 'prune_candidate', d
        assert d.get('dry_run') is True, d
        assert 'reason' in d and d['reason'], d
        sys.exit(0)
sys.exit(1)
"
  [[ "$status" -eq 0 ]]
}

@test "AC-S4.2: automatización semanal registrada en el scheduler" {
  run grep -c 'memory-consolidation' scripts/savia-automations.sh
  [[ "$output" -ge 1 ]]
}

@test "AC-S4.3: cada ejecución deja reporte en output/memory-consolidation/" {
  local s="$TMPD/store7.jsonl"
  make_store "$s"
  bash "$CONS" scan --store "$s" >/dev/null
  run ls output/memory-consolidation/*-scan.jsonl 2>/dev/null
  [[ -n "$output" ]]
}

# ── Seguridad ───────────────────────────────────────────────────────────────

@test "S5.1: no introduce secrets ni IPs internas" {
  run grep -rnE "AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{32,}|192\.168\.|10\.([0-9]{1,3}\.){2}" scripts/memory-consolidate.sh
  [[ -z "$output" ]]
}
