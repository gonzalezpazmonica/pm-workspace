#!/usr/bin/env bats
# test-se365-org-registrar.bats — BATS tests for SE-365 Company as Code
# Ref: SE-365 — org-registrar, entidades, vocabulario de relaciones

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  REG="$REPO_ROOT/scripts/org-registrar.py"
  export REPO_ROOT REG
  export TEST_ORG="$(mktemp -d)"
}

teardown() {
  if [[ -d "${TEST_ORG:-}" ]]; then
    rm -rf "$TEST_ORG"
  fi
}

@test "entidad piloto del repo es válida" {
  run python3 "$REG" validate --file "$REPO_ROOT/org/company/policies/policy-soberania-datos.md"
  [[ "$status" -eq 0 ]]
}

@test "index del grafo piloto devuelve entidades" {
  run python3 "$REG" index --dir "$REPO_ROOT/org/company" --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['count'] >= 3, f'count={d[\"count\"]}'
"
}

@test "query uses_resource encuentra el recurso" {
  # grafo combinado: company + resources + projects
  python3 - "$REPO_ROOT" "$TEST_ORG/graph.json" << 'PY'
import json, subprocess, sys
root, out = sys.argv[1], sys.argv[2]
merged = {"entities": {}, "count": 0}
for sub in ("org/company", "org/resources", "org/projects"):
    r = json.loads(subprocess.run(
        ["python3", f"{root}/scripts/org-registrar.py", "index", "--dir", f"{root}/{sub}", "--json"],
        capture_output=True, text=True).stdout)
    merged["entities"].update(r["entities"])
    merged["count"] = len(merged["entities"])
json.dump(merged, open(out, "w"))
PY
  run python3 "$REG" query --graph "$TEST_ORG/graph.json" --what uses_resource --id resource-gitlab-homelab
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"project-savia-federacion"* ]]
}

@test "propuesta de entidad inválida → exit != 0" {
  local bad="$TEST_ORG/bad.md"
  printf -- '---\nid: x\ntype: rocket\n---\n' > "$bad"
  run python3 "$REG" propose --file "$bad" --out "$TEST_ORG/proposals"
  [[ "$status" -ne 0 ]]
}

@test "propuesta válida genera diff sin aplicar" {
  local good="$TEST_ORG/good.md"
  cat > "$good" << 'EOF'
---
id: role-auditor
type: role
name: "Auditor/a"
status: active
origin: owner
source: human
---
EOF
  run python3 "$REG" propose --file "$good" --out "$TEST_ORG/proposals"
  [[ "$status" -eq 0 ]]
  [[ -f "$TEST_ORG/proposals/good.md" ]]
  # la entidad NO se aplicó al grafo del repo (company/ no contiene role-auditor)
  run python3 "$REG" index --dir "$REPO_ROOT/org/company" --json
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'role-auditor' not in d['entities'], 'no debe estar en el grafo real'
"
}
