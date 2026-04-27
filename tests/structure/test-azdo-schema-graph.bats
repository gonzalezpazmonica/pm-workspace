#!/usr/bin/env bats
# Ref: SE-076 Slice 2 — scripts/build-azdo-schema-graph.sh

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$ROOT_DIR/scripts/build-azdo-schema-graph.sh"
  TMP=$(mktemp -d)
  FIX="$TMP/fixtures"
  mkdir -p "$FIX"
  OUT="$TMP/graph.json"
  export AZDO_SCHEMA_GRAPH_FILE="$OUT"
  export PROJECT_ROOT="$TMP"
}
teardown() { rm -rf "$TMP"; }

# Fixture builder helper
make_fixtures() {
  cat > "$FIX/fields.json" <<'EOF'
{"value":[
  {"name":"State","referenceName":"System.State","type":"string","allowedValues":["Active","Closed","Resolved"]},
  {"name":"AreaPath","referenceName":"System.AreaPath","type":"treePath"},
  {"name":"AssignedTo","referenceName":"System.AssignedTo","type":"identity"}
]}
EOF
  cat > "$FIX/areas.json" <<'EOF'
[{"name":"P1","path":"\\P1","children":[
   {"name":"Backend","path":"\\P1\\Backend","children":[]},
   {"name":"Frontend","path":"\\P1\\Frontend","children":[]}
]}]
EOF
  cat > "$FIX/iterations.json" <<'EOF'
[{"name":"Sprint1","path":"\\P1\\S1","children":[]}]
EOF
  cat > "$FIX/work-item-types.json" <<'EOF'
{"value":[
  {"name":"Bug","fields":[{"referenceName":"System.State"},{"referenceName":"System.AreaPath"}]},
  {"name":"Task","fields":[{"referenceName":"System.State"},{"referenceName":"System.AssignedTo"}]}
]}
EOF
}

# ── Usage / dispatch ────────────────────────────────────────────────────────

@test "schema-graph: --help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "schema-graph: rejects unknown flag with exit 2" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "schema-graph: live mode requires --org and --project" {
  run bash "$SCRIPT" --org acme
  [ "$status" -eq 2 ]
  [[ "$output" == *"required"* ]]
}

# ── Fixture mode (offline) ──────────────────────────────────────────────────

@test "schema-graph: --from-fixtures errors when dir missing exit 4" {
  run bash "$SCRIPT" --from-fixtures "$TMP/nope"
  [ "$status" -eq 4 ]
}

@test "schema-graph: --from-fixtures produces nodes and edges arrays" {
  make_fixtures
  run bash "$SCRIPT" --from-fixtures "$FIX"
  [ "$status" -eq 0 ]
  [ -f "$OUT" ]
  python3 -c "
import json
d = json.load(open('$OUT'))
assert isinstance(d['nodes'], list) and len(d['nodes']) > 0
assert isinstance(d['edges'], list) and len(d['edges']) > 0
"
}

@test "schema-graph: emits Field, AreaPath, IterationPath, WorkItemType, AllowedValue node types" {
  make_fixtures
  bash "$SCRIPT" --from-fixtures "$FIX" >/dev/null
  python3 -c "
import json
d = json.load(open('$OUT'))
types = {n['type'] for n in d['nodes']}
expected = {'Field','AreaPath','IterationPath','WorkItemType','AllowedValue'}
missing = expected - types
assert not missing, f'missing node types: {missing}'
"
}

@test "schema-graph: emits HAS_FIELD, ALLOWED_VALUE, PARENT_OF edge types" {
  make_fixtures
  bash "$SCRIPT" --from-fixtures "$FIX" >/dev/null
  python3 -c "
import json
d = json.load(open('$OUT'))
types = {e['type'] for e in d['edges']}
assert 'HAS_FIELD' in types
assert 'ALLOWED_VALUE' in types
assert 'PARENT_OF' in types
"
}

@test "schema-graph: WorkItemType has HAS_FIELD edge to its declared fields" {
  make_fixtures
  bash "$SCRIPT" --from-fixtures "$FIX" >/dev/null
  python3 -c "
import json
d = json.load(open('$OUT'))
edges = [(e['from'], e['to'], e['type']) for e in d['edges']]
assert ('Bug', 'System.State', 'HAS_FIELD') in edges
assert ('Bug', 'System.AreaPath', 'HAS_FIELD') in edges
assert ('Task', 'System.State', 'HAS_FIELD') in edges
"
}

@test "schema-graph: Field with allowedValues emits AllowedValue nodes + edges" {
  make_fixtures
  bash "$SCRIPT" --from-fixtures "$FIX" >/dev/null
  python3 -c "
import json
d = json.load(open('$OUT'))
nodes = {n['id'] for n in d['nodes']}
assert 'System.State:Active' in nodes
assert 'System.State:Closed' in nodes
"
}

@test "schema-graph: AreaPath children emit PARENT_OF edges to root" {
  make_fixtures
  bash "$SCRIPT" --from-fixtures "$FIX" >/dev/null
  python3 -c "
import json
d = json.load(open('$OUT'))
edges = [(e['from'], e['to'], e['type']) for e in d['edges']]
assert any(e[2] == 'PARENT_OF' for e in edges)
"
}

@test "schema-graph: writes to AZDO_SCHEMA_GRAPH_FILE env var path" {
  make_fixtures
  bash "$SCRIPT" --from-fixtures "$FIX" >/dev/null
  [ -f "$OUT" ]
}

@test "schema-graph: --output flag overrides default" {
  make_fixtures
  CUSTOM="$TMP/custom-graph.json"
  bash "$SCRIPT" --from-fixtures "$FIX" --output "$CUSTOM" >/dev/null
  [ -f "$CUSTOM" ]
}

@test "schema-graph: source field is 'fixtures' for offline mode" {
  make_fixtures
  bash "$SCRIPT" --from-fixtures "$FIX" >/dev/null
  python3 -c "
import json; d = json.load(open('$OUT')); assert d.get('source') == 'fixtures'"
}

@test "schema-graph: generated_at field present" {
  make_fixtures
  bash "$SCRIPT" --from-fixtures "$FIX" >/dev/null
  python3 -c "
import json; d = json.load(open('$OUT')); assert 'generated_at' in d"
}

# ── Validate mode ──────────────────────────────────────────────────────────

@test "schema-graph: --validate accepts a valid graph" {
  make_fixtures
  bash "$SCRIPT" --from-fixtures "$FIX" >/dev/null
  run bash "$SCRIPT" --validate "$OUT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "schema-graph: --validate rejects malformed JSON exit 5" {
  echo "not-json" > "$TMP/broken.json"
  run bash "$SCRIPT" --validate "$TMP/broken.json"
  [ "$status" -eq 5 ]
}

@test "schema-graph: --validate rejects missing nodes/edges exit 5" {
  echo '{"foo": "bar"}' > "$TMP/empty.json"
  run bash "$SCRIPT" --validate "$TMP/empty.json"
  [ "$status" -eq 5 ]
}

@test "schema-graph: --validate exits 5 when file missing" {
  run bash "$SCRIPT" --validate "$TMP/missing.json"
  [ "$status" -eq 5 ]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: empty fixture files produce empty graph but no crash" {
  echo '{"value":[]}' > "$FIX/fields.json"
  echo '[]' > "$FIX/areas.json"
  echo '[]' > "$FIX/iterations.json"
  echo '{"value":[]}' > "$FIX/work-item-types.json"
  run bash "$SCRIPT" --from-fixtures "$FIX"
  [ "$status" -eq 0 ]
  python3 -c "
import json; d = json.load(open('$OUT'))
assert d['nodes'] == [] and d['edges'] == []"
}

@test "edge: nonexistent fixture file is tolerated (treated as empty)" {
  # Only fields.json exists; areas/iterations/wit missing
  echo '{"value":[{"name":"X","referenceName":"System.X"}]}' > "$FIX/fields.json"
  run bash "$SCRIPT" --from-fixtures "$FIX"
  [ "$status" -eq 0 ]
  python3 -c "
import json; d = json.load(open('$OUT'))
assert any(n['type'] == 'Field' for n in d['nodes'])"
}

@test "edge: large fixture (100 fields) handled without timeout" {
  python3 -c "
import json
fields = [{'name': f'F{i}', 'referenceName': f'System.F{i}', 'type': 'string'} for i in range(100)]
json.dump({'value': fields}, open('$FIX/fields.json', 'w'))
json.dump([], open('$FIX/areas.json', 'w'))
json.dump([], open('$FIX/iterations.json', 'w'))
json.dump({'value': []}, open('$FIX/work-item-types.json', 'w'))
"
  run bash "$SCRIPT" --from-fixtures "$FIX"
  [ "$status" -eq 0 ]
  python3 -c "
import json; d = json.load(open('$OUT'))
assert sum(1 for n in d['nodes'] if n['type'] == 'Field') == 100"
}

# ── Static / safety / spec ref ─────────────────────────────────────────────

@test "spec ref: SE-076 Slice 2 cited in script header" {
  grep -q "SE-076 Slice 2" "$SCRIPT"
}

@test "safety: build-azdo-schema-graph.sh has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: PAT read via cat \$PAT_FILE (Rule #1)" {
  grep -qE 'cat[[:space:]]+"?\$PAT_FILE"?|cat[[:space:]]+"?\$\{PAT_FILE\}"?' "$SCRIPT"
}

@test "safety: never invokes git push or merge" {
  ! grep -E '^[^#]*git\s+(push|merge)' "$SCRIPT"
}
