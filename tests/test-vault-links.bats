#!/usr/bin/env bats
# tests/test-vault-links.bats — SE-325: Vault adjacency inline + relaciones tipadas.
# Ref: docs/propuestas/SE-325-vault-adjacency-inline.md (AC-S1..S4)

LINKS="scripts/vault-links.sh"
RELATIONS="projects/savia-vaults/schema/relations.yaml"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPD="${BATS_TEST_TMPDIR}"
  mkdir -p "$TMPD"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR" 2>/dev/null || true
  cd /
}

make_vault() { # dir
  local v="$1"
  mkdir -p "$v"
  cat > "$v/a.md" <<'EOF'
---
entity: {type: document, id: doc-a}
title: Documento A
status: approved
---
# Doc A
Ver [[doc-b]] para detalle.
EOF
  cat > "$v/b.md" <<'EOF'
---
entity: {type: document, id: doc-b}
title: Documento B
status: draft
links:
  - to: doc-a
    rel: supports
---
# Doc B
EOF
  cat > "$v/c.md" <<'EOF'
---
entity: {type: document, id: doc-c}
title: Documento C
status: approved
---
# Doc C
EOF
}

# ── S1: extract ─────────────────────────────────────────────────────────────

@test "S1.0: vault-links.sh existe, ejecutable, pipefail" {
  [[ -f "$LINKS" ]]
  [[ -x "$LINKS" ]]
  run grep -c 'set -uo pipefail' "$LINKS"
  [[ "$output" -ge 1 ]]
}

@test "AC-S1.1: nota con links: explícito -> arista from/to/rel" {
  local v="$TMPD/v1"
  make_vault "$v"
  run bash -c "bash '$LINKS' extract '$v'"
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import json, sys
edges = [json.loads(l) for l in sys.stdin.read().splitlines() if l.strip()]
supports = [e for e in edges if e.get('rel') == 'supports' and e['from'] == 'doc-b' and e['to'] == 'doc-a']
assert supports, edges
"
}

@test "AC-S1.2: wikilink [[x]] -> arista derived-from auto" {
  local v="$TMPD/v2"
  make_vault "$v"
  run bash -c "bash '$LINKS' extract '$v'"
  echo "$output" | python3 -c "
import json, sys
edges = [json.loads(l) for l in sys.stdin.read().splitlines() if l.strip()]
df = [e for e in edges if e.get('rel') == 'derived-from' and e['from'] == 'doc-a' and e['to'] == 'doc-b']
assert df, edges
"
}

@test "AC-S1.3: nota sin links -> sin aristas" {
  local v="$TMPD/v3"
  make_vault "$v"
  run bash -c "bash '$LINKS' extract '$v'"
  # doc-c no emite aristas
  echo "$output" | python3 -c "
import json, sys
edges = [json.loads(l) for l in sys.stdin.read().splitlines() if l.strip()]
assert not any(e['from'] == 'doc-c' for e in edges), edges
"
}

# ── S2: validate ────────────────────────────────────────────────────────────

@test "AC-S2.1: arista con rel fuera de vocabulario -> warning" {
  local v="$TMPD/v4"
  make_vault "$v"
  bash "$LINKS" extract "$v" > "$TMPD/l.jsonl"
  printf '{"from":"x","from_type":"document","to":"y","to_type":"document","rel":"flying-to-mars"}\n' >> "$TMPD/l.jsonl"
  run bash -c "bash '$LINKS' validate '$TMPD/l.jsonl'"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"WARN"* ]]
}

@test "AC-S2.2: --strict con arista inválida -> exit 1" {
  local v="$TMPD/v5"
  make_vault "$v"
  bash "$LINKS" extract "$v" > "$TMPD/l.jsonl"
  printf '{"from":"x","from_type":"document","to":"y","to_type":"document","rel":"flying-to-mars"}\n' >> "$TMPD/l.jsonl"
  run bash -c "bash '$LINKS' validate '$TMPD/l.jsonl' --strict"
  [[ "$status" -eq 1 ]]
}

@test "AC-S2.3: arista válida -> sin warning" {
  local v="$TMPD/v6"
  make_vault "$v"
  bash "$LINKS" extract "$v" > "$TMPD/l.jsonl"
  run bash -c "bash '$LINKS' validate '$TMPD/l.jsonl'"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"WARN"* ]]
}

# ── S3: traverse ────────────────────────────────────────────────────────────

@test "AC-S3.1: traverse depth 2 -> niveles con profundidad" {
  local v="$TMPD/v7"
  make_vault "$v"
  bash "$LINKS" extract "$v" > "$TMPD/l.jsonl"
  run bash -c "bash '$LINKS' traverse '$TMPD/l.jsonl' doc-b --depth 2"
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
levels = {t['level'] for t in d['traversal']}
assert 0 in levels and 1 in levels, d
assert d['start'] == 'doc-b', d
"
}

@test "AC-S3.2: vault.traverse aparece en telemetry" {
  local v="$TMPD/v8"
  make_vault "$v"
  bash "$LINKS" extract "$v" > "$TMPD/l.jsonl"
  SAVIA_TELEMETRY_FILE="$TMPD/tl.jsonl" bash "$LINKS" traverse "$TMPD/l.jsonl" doc-b --depth 2 >/dev/null
  run grep -c 'vault.traverse' "$TMPD/tl.jsonl"
  [[ "$output" -ge 1 ]]
}

@test "AC-S3.3: nodo sin vecinos -> solo level 0, exit 0" {
  local v="$TMPD/v9"
  make_vault "$v"
  bash "$LINKS" extract "$v" > "$TMPD/l.jsonl"
  run bash -c "bash '$LINKS' traverse '$TMPD/l.jsonl' doc-c --depth 2"
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert len(d['traversal']) == 1 and d['traversal'][0]['level'] == 0, d
"
}

# ── S4: query + integración ─────────────────────────────────────────────────

@test "AC-S4.1: query --filter status:approved devuelve solo aprobadas" {
  local v="$TMPD/v10"
  make_vault "$v"
  run bash -c "bash '$LINKS' query '$v' --filter 'status:approved'"
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import json, sys
lines = [l for l in sys.stdin.read().splitlines() if l.strip()]
hits = [json.loads(l) for l in lines if l.startswith('{')]
ids = {h['id'] for h in hits}
assert ids == {'doc-a', 'doc-c'}, ids
"
}

@test "AC-S4.2: comando /vault-graph existe" {
  [[ -f ".claude/commands/vault-graph.md" ]]
}

@test "AC-S4.3: job CI vault-graph registrado (report-only)" {
  run grep -c "Vault Graph (report-only)" .github/workflows/ci.yml
  [[ "$output" -ge 1 ]]
  run grep -c "continue-on-error: true" .github/workflows/ci.yml
  [[ "$output" -ge 1 ]]
}

# ── Seguridad ───────────────────────────────────────────────────────────────

@test "S5.1: no introduce secrets ni IPs internas" {
  run grep -rnE "AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{32,}|192\.168\.|10\.([0-9]{1,3}\.){2}" scripts/vault-links.sh projects/savia-vaults/schema/relations.yaml
  [[ -z "$output" ]]
}
