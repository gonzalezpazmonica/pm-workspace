#!/usr/bin/env bats
# tests/test-context-capability.bats — SE-221 Slice 3 — Capability metadata
#
# Spec: docs/propuestas/SE-221-inverted-security-patterns-as-context-engineering.md (AC-17)
# Refs: CaMeL (Debenedetti 2025), audience-graph cross-concept, KG integration.
#
# Tests para:
#   - scripts/context-capability-check.sh (validador frontmatter audience)
#   - scripts/context-audience-graph.py (graph + cross.tsv generator)
#   - .claude/hooks/subagent-audience-filter.sh (audience filter para subagentes)
#   - scripts/knowledge-graph.py import-audience (integracion KG)
#
# Cobertura: frontmatter valido/invalido, graph generation, cross.tsv, audience
# filter por agente, deny by default, integracion knowledge-graph.

CHECK="$BATS_TEST_DIRNAME/../scripts/context-capability-check.sh"
GRAPH="$BATS_TEST_DIRNAME/../scripts/context-audience-graph.py"
FILTER="$BATS_TEST_DIRNAME/../.claude/hooks/subagent-audience-filter.sh"
KG="$BATS_TEST_DIRNAME/../scripts/knowledge-graph.py"

setup() {
  WS="$BATS_TEST_TMPDIR/ws"
  mkdir -p "$WS/.opencode/agents" "$WS/.opencode/skills" "$WS/docs/rules/domain" "$WS/output"
  touch "$WS/AGENTS.md"
  # Agentes validos
  for a in architect code-reviewer security-guardian; do
    touch "$WS/.opencode/agents/$a.md"
  done
  export SAVIA_WORKSPACE_DIR="$WS"
  export SAVIA_AGENTS_DIR="$WS/.opencode/agents"
}

teardown() {
  unset SAVIA_WORKSPACE_DIR SAVIA_AGENTS_DIR
}

# === Sintaxis y safety ===

@test "check script bash valido" {
  bash -n "$CHECK"
}

@test "filter hook bash valido" {
  bash -n "$FILTER"
}

@test "graph script python sintacticamente valido" {
  python3 -c "import ast; ast.parse(open('$GRAPH').read())"
}

@test "check uses set -uo pipefail" {
  head -10 "$CHECK" | grep -q "set -[euo]*o pipefail"
}

@test "filter uses set -uo pipefail" {
  head -10 "$FILTER" | grep -q "set -[euo]*o pipefail"
}

# === Capability check: frontmatter valido ===

@test "check: fichero sin audience pasa (default implicito)" {
  cat > "$WS/docs/rules/domain/no-aud.md" <<EOF
---
foo: bar
---
content
EOF
  run "$CHECK" --paths "$WS/docs/rules/domain/no-aud.md"
  [ "$status" -eq 0 ]
}

@test "check: audience como lista inline valida" {
  cat > "$WS/docs/rules/domain/list.md" <<EOF
---
audience: [architect, code-reviewer]
---
EOF
  run "$CHECK" --paths "$WS/docs/rules/domain/list.md"
  [ "$status" -eq 0 ]
}

@test "check: audience como string canonico all-agents valida" {
  cat > "$WS/docs/rules/domain/str.md" <<EOF
---
audience: all-agents
---
EOF
  run "$CHECK" --paths "$WS/docs/rules/domain/str.md"
  [ "$status" -eq 0 ]
}

@test "check: audience humans-only es palabra reservada" {
  cat > "$WS/docs/rules/domain/h.md" <<EOF
---
audience: humans-only
---
EOF
  run "$CHECK" --paths "$WS/docs/rules/domain/h.md"
  [ "$status" -eq 0 ]
}

@test "check: audience multilinea YAML valida" {
  cat > "$WS/docs/rules/domain/ml.md" <<EOF
---
audience:
  - architect
  - all-agents
---
EOF
  run "$CHECK" --paths "$WS/docs/rules/domain/ml.md"
  [ "$status" -eq 0 ]
}

# === Capability check: invalidos ===

@test "check: audience con agente inexistente FALLA" {
  cat > "$WS/docs/rules/domain/bad.md" <<EOF
---
audience: [ghost-agent]
---
EOF
  run "$CHECK" --paths "$WS/docs/rules/domain/bad.md"
  [ "$status" -eq 1 ]
}

@test "check: audience mixto con uno invalido FALLA" {
  cat > "$WS/docs/rules/domain/mixed.md" <<EOF
---
audience: [architect, ghost]
---
EOF
  run "$CHECK" --paths "$WS/docs/rules/domain/mixed.md"
  [ "$status" -eq 1 ]
}

@test "check: --strict marca FAIL si falta audience" {
  cat > "$WS/docs/rules/domain/none.md" <<EOF
---
foo: bar
---
EOF
  run "$CHECK" --strict --paths "$WS/docs/rules/domain/none.md"
  [ "$status" -eq 1 ]
}

@test "check: --json devuelve JSON valido" {
  cat > "$WS/docs/rules/domain/x.md" <<EOF
---
audience: [architect]
---
EOF
  run "$CHECK" --json --paths "$WS/docs/rules/domain/x.md"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.errors == 0 and .total == 1' >/dev/null
}

# === Graph generation ===

@test "graph: produce JSON y TSV" {
  cat > "$WS/docs/rules/domain/f1.md" <<EOF
---
audience: [architect, code-reviewer]
---
EOF
  cat > "$WS/docs/rules/domain/f2.md" <<EOF
---
audience: [architect, code-reviewer, security-guardian]
---
EOF
  run python3 "$GRAPH" --workspace "$WS" --quiet
  [ "$status" -eq 0 ]
  [ -f "$WS/output/context-audience-graph.json" ]
  [ -f "$WS/output/context-audience-cross.tsv" ]
}

@test "graph: TSV header correcto" {
  cat > "$WS/docs/rules/domain/f1.md" <<EOF
---
audience: [architect]
---
EOF
  python3 "$GRAPH" --workspace "$WS" --quiet
  head -1 "$WS/output/context-audience-cross.tsv" | grep -q "path_a"
  head -1 "$WS/output/context-audience-cross.tsv" | grep -q "shared_agents"
}

@test "graph: cross.tsv contiene par con >=2 shared agents" {
  cat > "$WS/docs/rules/domain/a.md" <<EOF
---
audience: [architect, code-reviewer]
---
EOF
  cat > "$WS/docs/rules/domain/b.md" <<EOF
---
audience: [architect, code-reviewer, security-guardian]
---
EOF
  python3 "$GRAPH" --workspace "$WS" --quiet
  pair_count=$(tail -n +2 "$WS/output/context-audience-cross.tsv" | wc -l)
  [ "$pair_count" -ge 1 ]
}

@test "graph: pares con solo all-agents NO se cuentan como cross-concept" {
  cat > "$WS/docs/rules/domain/u1.md" <<EOF
---
audience: all-agents
---
EOF
  cat > "$WS/docs/rules/domain/u2.md" <<EOF
---
audience: all-agents
---
EOF
  python3 "$GRAPH" --workspace "$WS" --quiet
  pair_count=$(tail -n +2 "$WS/output/context-audience-cross.tsv" | wc -l)
  [ "$pair_count" -eq 0 ]
}

@test "graph: JSON contiene mapping agent->files" {
  cat > "$WS/docs/rules/domain/x.md" <<EOF
---
audience: [architect]
---
EOF
  python3 "$GRAPH" --workspace "$WS" --quiet
  echo "" | python3 -c "
import json
d = json.load(open('$WS/output/context-audience-graph.json'))
assert 'architect' in d['agents']
assert 'docs/rules/domain/x.md' in d['agents']['architect']
"
}

# === Audience filter (subagent) ===

@test "filter: passthrough cuando NO es Task tool" {
  output=$(echo '{"tool_name":"Read","tool_input":{"file_path":"/tmp/a"}}' | bash "$FILTER")
  [ "$output" = '{"tool_name":"Read","tool_input":{"file_path":"/tmp/a"}}' ]
}

@test "filter: passthrough cuando no hay graph JSON" {
  rm -f "$WS/output/context-audience-graph.json"
  input='{"tool_name":"Task","tool_input":{"subagent_type":"architect"}}'
  output=$(echo "$input" | bash "$FILTER")
  [ "$output" = "$input" ]
}

@test "filter: subagente conocido obtiene allowed con sus paths" {
  cat > "$WS/output/context-audience-graph.json" <<EOF
{"agents":{"architect":["docs/foo.md"],"code-reviewer":["docs/bar.md"],"all-agents":["docs/all.md"]}}
EOF
  echo '{"tool_name":"Task","tool_input":{"subagent_type":"architect"}}' | bash "$FILTER" >/dev/null
  [ -s "$WS/output/audience-filter.jsonl" ]
  jq -e '.filter.allowed | index("docs/foo.md")' "$WS/output/audience-filter.jsonl" >/dev/null
}

@test "filter: deny by default — subagente desconocido solo recibe all-agents" {
  cat > "$WS/output/context-audience-graph.json" <<EOF
{"agents":{"architect":["docs/foo.md"],"all-agents":["docs/all.md"]}}
EOF
  echo '{"tool_name":"Task","tool_input":{"subagent_type":"ghost"}}' | bash "$FILTER" >/dev/null
  jq -e '.filter.allowed | length == 1 and .[0] == "docs/all.md"' "$WS/output/audience-filter.jsonl" >/dev/null
}

@test "filter: humans-only se DENIEGA al subagente" {
  cat > "$WS/output/context-audience-graph.json" <<EOF
{"agents":{"architect":["docs/foo.md"],"humans-only":["docs/private.md"]}}
EOF
  echo '{"tool_name":"Task","tool_input":{"subagent_type":"architect"}}' | bash "$FILTER" >/dev/null
  jq -e '.filter.denied | index("docs/private.md")' "$WS/output/audience-filter.jsonl" >/dev/null
}

@test "filter: subagente listado obtiene archivos especificos + all-agents" {
  cat > "$WS/output/context-audience-graph.json" <<EOF
{"agents":{"architect":["docs/foo.md"],"all-agents":["docs/all.md"]}}
EOF
  echo '{"tool_name":"Task","tool_input":{"subagent_type":"architect"}}' | bash "$FILTER" >/dev/null
  count=$(jq -r '.filter.allowed | length' "$WS/output/audience-filter.jsonl" | tail -1)
  [ "$count" -eq 2 ]
}

# === KG integration ===

@test "kg: import-audience requiere --tsv" {
  run python3 "$KG" import-audience --db "$WS/kg.db"
  [ "$status" -ne 0 ]
}

@test "kg: import-audience con TSV inexistente FALLA limpio" {
  run python3 "$KG" import-audience --tsv "$WS/nope.tsv" --db "$WS/kg.db"
  [ "$status" -eq 1 ]
}

@test "kg: import-audience importa relacion shared_audience" {
  cat > "$WS/output/context-audience-cross.tsv" <<EOF
path_a	path_b	shared_agents	audience_count
docs/a.md	docs/b.md	architect,code-reviewer	2
EOF
  run python3 "$KG" import-audience --tsv "$WS/output/context-audience-cross.tsv" --db "$WS/kg.db" --quiet
  [ "$status" -eq 0 ]
  python3 -c "
import sqlite3
c = sqlite3.connect('$WS/kg.db')
rels = list(c.execute('SELECT relation FROM relations'))
assert ('shared_audience',) in rels, f'expected shared_audience, got {rels}'
"
}

@test "kg: import-audience source contiene shared_audience y count" {
  cat > "$WS/output/context-audience-cross.tsv" <<EOF
path_a	path_b	shared_agents	audience_count
docs/a.md	docs/b.md	architect,code-reviewer	2
EOF
  python3 "$KG" import-audience --tsv "$WS/output/context-audience-cross.tsv" --db "$WS/kg.db" --quiet
  python3 -c "
import sqlite3
c = sqlite3.connect('$WS/kg.db')
src = c.execute('SELECT source FROM relations LIMIT 1').fetchone()[0]
assert 'shared_audience=' in src
assert 'count=2' in src
"
}

# === Spec reference ===

@test "spec_reference: SE-221 documentado en check" {
  grep -q "SE-221" "$CHECK"
}

@test "spec_reference: SE-221 documentado en graph" {
  grep -q "SE-221" "$GRAPH"
}

@test "spec_reference: SE-221 documentado en filter" {
  grep -q "SE-221" "$FILTER"
}
