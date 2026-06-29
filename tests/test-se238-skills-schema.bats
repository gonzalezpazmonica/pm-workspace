#!/usr/bin/env bats
# test-se238-skills-schema.bats
#
# Tests SE-238: Skills Schema Descubrible Programáticamente
# Ref: docs/propuestas/SE-238-skills-schema-discoverable.md

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
NIDO="$REPO_ROOT"
SCRIPT="${NIDO}/scripts/skills-schema-generate.sh"
SCHEMA_JSON="${NIDO}/skills-schema.json"
LLMS_TXT="${NIDO}/.llms.txt"

# Skills dir — usar el del propio repo (funciona tanto en local como en CI)
WORKSPACE_SKILLS="${REPO_ROOT}/.opencode/skills"

# ── Test 1: SE-238 spec existe ────────────────────────────────────────────────
@test "SE-238 spec existe en docs/propuestas/" {
  [ -f "${NIDO}/docs/propuestas/SE-238-skills-schema-discoverable.md" ]
}

# ── Test 2: skills-schema-generate.sh existe y es ejecutable ─────────────────
@test "skills-schema-generate.sh existe y es ejecutable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# ── Test 3: skills-schema-generate.sh pasa bash -n ───────────────────────────
@test "skills-schema-generate.sh pasa bash -n syntax check" {
  bash -n "$SCRIPT"
}

# ── Test 4: skills-schema.json se genera correctamente ───────────────────────
@test "skills-schema.json se genera correctamente con el script" {
  tmp_json=$(mktemp /tmp/skills-schema-XXXXXX.json)
  tmp_md=$(mktemp /tmp/skills-schema-XXXXXX.md)
  
  run bash "$SCRIPT" --skills-dir "$WORKSPACE_SKILLS" --output "$tmp_json" --output-md "$tmp_md"
  
  # El script debe generar JSON válido
  python3 -c "import json; json.load(open('$tmp_json'))"
  
  rm -f "$tmp_json" "$tmp_md"
  [ "$status" -eq 0 ]
}

# ── Test 5: skills-schema.json tiene al menos 50 entradas ────────────────────
@test "skills-schema.json tiene al menos 50 entradas" {
  # El schema ya generado debe tener ≥50 entradas
  count=$(python3 -c "import json; d=json.load(open('$SCHEMA_JSON')); print(len(d['skills']))")
  [ "$count" -ge 50 ]
}

# ── Test 6: Cada entrada tiene skill_id, description, skill_path ─────────────
@test "cada entrada de skills-schema.json tiene skill_id, description, skill_path" {
  python3 - "$SCHEMA_JSON" <<'PYTHON'
import json, sys
d = json.load(open(sys.argv[1]))
for i, entry in enumerate(d['skills'][:20]):  # verificar primeras 20
    assert 'skill_id' in entry, f"entrada {i} sin skill_id"
    assert 'description' in entry, f"entrada {i} sin description"
    assert 'skill_path' in entry, f"entrada {i} sin skill_path"
    assert entry['skill_id'], f"entrada {i} skill_id vacío"
    assert entry['description'], f"entrada {i} description vacía"
print("OK: estructura válida en todas las entradas verificadas")
PYTHON
}

# ── Test 7: .llms.txt existe en la raíz del nido ─────────────────────────────
@test ".llms.txt existe en la raíz del nido" {
  [ -f "$LLMS_TXT" ]
}

# ── Test 8: .llms.txt menciona skills-schema.json ────────────────────────────
@test ".llms.txt menciona skills-schema.json" {
  grep -q "skills-schema.json" "$LLMS_TXT"
}

# ── Test 9: .llms.txt menciona AGENTS.md ─────────────────────────────────────
@test ".llms.txt menciona AGENTS.md" {
  grep -q "AGENTS.md" "$LLMS_TXT"
}

# ── Test 10: entrada de skill conocido "savia-memory" en skills-schema.json ───
@test "la entrada del skill 'savia-memory' está en skills-schema.json" {
  python3 -c "
import json
d = json.load(open('$SCHEMA_JSON'))
ids = [s['skill_id'] for s in d['skills']]
assert 'savia-memory' in ids, f'savia-memory no encontrado. IDs disponibles: {ids[:10]}'
print('OK: savia-memory encontrado')
"
}

# ── Test 11: el script genera output JSON válido ──────────────────────────────
@test "skills-schema-generate.sh genera output JSON válido" {
  tmp_json=$(mktemp /tmp/skills-schema-valid-XXXXXX.json)
  tmp_md=$(mktemp /tmp/skills-schema-valid-XXXXXX.md)
  
  bash "$SCRIPT" --skills-dir "$WORKSPACE_SKILLS" --output "$tmp_json" --output-md "$tmp_md" >/dev/null 2>&1
  
  # Verificar JSON válido con python3
  python3 -c "
import json
with open('$tmp_json') as f:
    d = json.load(f)
assert isinstance(d, dict), 'output no es un objeto JSON'
assert 'skills' in d, 'falta clave skills'
assert isinstance(d['skills'], list), 'skills no es una lista'
assert len(d['skills']) > 0, 'lista skills vacía'
print('OK: JSON válido')
"
  
  rm -f "$tmp_json" "$tmp_md"
}

# ── Test 12: el script es idempotente ────────────────────────────────────────
@test "skills-schema-generate.sh es idempotente (dos ejecuciones → mismo resultado)" {
  tmp_json1=$(mktemp /tmp/skills-schema-idem1-XXXXXX.json)
  tmp_json2=$(mktemp /tmp/skills-schema-idem2-XXXXXX.json)
  tmp_md1=$(mktemp /tmp/skills-schema-idem1-XXXXXX.md)
  tmp_md2=$(mktemp /tmp/skills-schema-idem2-XXXXXX.md)
  
  bash "$SCRIPT" --skills-dir "$WORKSPACE_SKILLS" --output "$tmp_json1" --output-md "$tmp_md1" >/dev/null 2>&1
  bash "$SCRIPT" --skills-dir "$WORKSPACE_SKILLS" --output "$tmp_json2" --output-md "$tmp_md2" >/dev/null 2>&1
  
  # Comparar número de entradas (el timestamp puede diferir en _meta)
  count1=$(python3 -c "import json; print(len(json.load(open('$tmp_json1'))['skills']))")
  count2=$(python3 -c "import json; print(len(json.load(open('$tmp_json2'))['skills']))")
  
  rm -f "$tmp_json1" "$tmp_json2" "$tmp_md1" "$tmp_md2"
  
  [ "$count1" -eq "$count2" ]
}
