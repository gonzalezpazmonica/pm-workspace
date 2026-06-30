#!/usr/bin/env bats
# tests/test-se252-distribute.bats — SE-252 Bus Factor Shield
# Tests para scripts/bus-factor-distribute.sh

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
DIST_SCRIPT="$REPO_ROOT/scripts/bus-factor-distribute.sh"
SCAN_SCRIPT="$REPO_ROOT/scripts/bus-factor-scan.sh"
SCAN_PY="$REPO_ROOT/scripts/bus-factor-scan.py"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  DIST_SCRIPT="$REPO_ROOT/scripts/bus-factor-distribute.sh"
  SCAN_SCRIPT="$REPO_ROOT/scripts/bus-factor-scan.sh"
  SCAN_PY="$REPO_ROOT/scripts/bus-factor-scan.py"
  TEST_REPO="$BATS_TMPDIR/dist-repo-$$"
  BF_OUT="$BATS_TMPDIR/dist-bf-out-$$"
  mkdir -p "$TEST_REPO" "$BF_OUT"
  export BF_OUTPUT_DIR="$BF_OUT"
}

teardown() {
  rm -rf "$TEST_REPO" "$BF_OUT" 2>/dev/null || true
}

_setup_single_author_repo() {
  cd "$TEST_REPO"
  git init -q
  git config user.email "alice@test.com"
  git config user.name "Alice"
  mkdir -p src lib
  for i in $(seq 1 6); do
    printf "src%s\n" "$i" > "src/main.py"
    printf "lib%s\n" "$i" > "lib/utils.py"
    git add -A
    git commit -q -m "commit $i"
  done
}

_run_scan() {
  local proj_name
  proj_name="$(basename "$TEST_REPO")"
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" python3 "$SCAN_PY" \
    --project "$proj_name" \
    --output "$BF_OUT/${proj_name}.json" \
    "$TEST_REPO" 2>/dev/null
}

_inject_scan_json() {
  local proj_name
  proj_name="$(basename "$TEST_REPO")"
  local jfile="$BF_OUT/${proj_name}.json"
  python3 -c "
import json
data = {
  'generated_at': '2026-06-30T00:00:00Z',
  'project': 'test-project',
  'modules': [
    {
      'name': 'src', 'path': 'src',
      'bus_factor': 1, 'risk_level': 'CRITICAL',
      'owners': [{'dev': 'alice@test.com', 'score': 1.0, 'files_owned': 2}],
      'files': [
        {'path': 'src/main.py', 'bus_factor': 1,
         'owners': [{'dev': 'alice@test.com', 'score': 1.0, 'files_owned': 0}],
         'warnings': []},
        {'path': 'src/helper.py', 'bus_factor': 1,
         'owners': [{'dev': 'alice@test.com', 'score': 1.0, 'files_owned': 0}],
         'warnings': []}
      ],
      'warnings': []
    },
    {
      'name': 'lib', 'path': 'lib',
      'bus_factor': 2, 'risk_level': 'HIGH',
      'owners': [
        {'dev': 'alice@test.com', 'score': 0.6, 'files_owned': 1},
        {'dev': 'bob@test.com',   'score': 0.4, 'files_owned': 1}
      ],
      'files': [
        {'path': 'lib/utils.py', 'bus_factor': 2,
         'owners': [
           {'dev': 'alice@test.com', 'score': 0.6, 'files_owned': 0},
           {'dev': 'bob@test.com',   'score': 0.4, 'files_owned': 0}
         ],
         'warnings': []}
      ],
      'warnings': []
    },
    {
      'name': 'docs', 'path': 'docs',
      'bus_factor': 3, 'risk_level': 'MEDIUM',
      'owners': [
        {'dev': 'alice@test.com', 'score': 0.4, 'files_owned': 1},
        {'dev': 'bob@test.com',   'score': 0.3, 'files_owned': 1},
        {'dev': 'carol@test.com', 'score': 0.3, 'files_owned': 1}
      ],
      'files': [
        {'path': 'docs/index.md', 'bus_factor': 3,
         'owners': [
           {'dev': 'alice@test.com', 'score': 0.4, 'files_owned': 0},
           {'dev': 'bob@test.com',   'score': 0.3, 'files_owned': 0},
           {'dev': 'carol@test.com', 'score': 0.3, 'files_owned': 0}
         ],
         'warnings': []}
      ],
      'warnings': []
    }
  ],
  'summary': {'total_modules': 3, 'critical': 1, 'high': 1, 'medium': 1, 'low': 0},
  'warnings': []
}
with open('$jfile', 'w') as f:
    json.dump(data, f, indent=2)
print('injected')
" 2>/dev/null
  mkdir -p "$TEST_REPO/src" "$TEST_REPO/lib" "$TEST_REPO/docs"
}

# ── 01: script existe ─────────────────────────────────────────────────────────
@test "SE252-dist-01: bus-factor-distribute.sh existe" {
  [ -f "$DIST_SCRIPT" ]
}

# ── 02: script es invocable con bash ─────────────────────────────────────────
@test "SE252-dist-02: bus-factor-distribute.sh es invocable con bash" {
  [ -f "$DIST_SCRIPT" ]
  run bash -n "$DIST_SCRIPT"
  [ "$status" -eq 0 ]
}

# ── 03: bash -n syntax check ──────────────────────────────────────────────────
@test "SE252-dist-03: bash -n no detecta errores de sintaxis" {
  run bash -n "$DIST_SCRIPT"
  [ "$status" -eq 0 ]
}

# ── 04: sin argumentos → mensaje de uso ───────────────────────────────────────
@test "SE252-dist-04: sin argumentos imprime uso y sale con error" {
  run bash "$DIST_SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" =~ [Uu]sage|--project ]]
}

# ── 05: --project sin --target → error ────────────────────────────────────────
@test "SE252-dist-05: --project sin --target sale con error" {
  _setup_single_author_repo
  _run_scan
  run bash "$DIST_SCRIPT" --project "$TEST_REPO"
  [ "$status" -ne 0 ]
  [[ "$output" =~ [Ee][Rr][Rr][Oo][Rr]|--target ]]
}

# ── 06: sin JSON de scan → error claro ────────────────────────────────────────
@test "SE252-dist-06: sin JSON de scan disponible emite ERROR descriptivo" {
  _setup_single_author_repo
  run bash "$DIST_SCRIPT" --project "$TEST_REPO" --target "bob@test.com"
  [ "$status" -ne 0 ]
  [[ "$output" =~ [Ee][Rr][Rr][Oo][Rr]|scan ]]
}

# ── 07: BF_OUT vacio + project inexistente → error ───────────────────────────
@test "SE252-dist-07: BF_OUT vacio y project inexistente sale con error" {
  run bash "$DIST_SCRIPT" \
    --project "/tmp/ruta-que-no-existe-bf-$$" \
    --target "bob@test.com"
  [ "$status" -ne 0 ]
  [[ "$output" =~ [Ee][Rr][Rr][Oo][Rr]|scan ]]
}

# ── 08: JSON output es JSON válido ────────────────────────────────────────────
@test "SE252-dist-08: --format json produce JSON valido" {
  _setup_single_author_repo
  _inject_scan_json
  local outfile="$BATS_TMPDIR/dist08-$$.json"
  run bash "$DIST_SCRIPT" \
    --project "$TEST_REPO" \
    --target "bob@test.com" \
    --format json \
    --output "$outfile"
  [ "$status" -eq 0 ]
  [ -f "$outfile" ]
  run python3 -m json.tool "$outfile"
  [ "$status" -eq 0 ]
}

# ── 09: JSON contiene campo "target" ──────────────────────────────────────────
@test "SE252-dist-09: JSON output contiene campo target" {
  _setup_single_author_repo
  _inject_scan_json
  local outfile="$BATS_TMPDIR/dist09-$$.json"
  bash "$DIST_SCRIPT" \
    --project "$TEST_REPO" \
    --target "bob@test.com" \
    --format json \
    --output "$outfile" 2>/dev/null
  run python3 -c "
import json
d = json.load(open('$outfile'))
assert 'target' in d, 'no target field'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── 10: JSON contiene campo "plan" ────────────────────────────────────────────
@test "SE252-dist-10: JSON output contiene campo plan" {
  _setup_single_author_repo
  _inject_scan_json
  local outfile="$BATS_TMPDIR/dist10-$$.json"
  bash "$DIST_SCRIPT" \
    --project "$TEST_REPO" \
    --target "bob@test.com" \
    --format json \
    --output "$outfile" 2>/dev/null
  run python3 -c "
import json
d = json.load(open('$outfile'))
assert 'plan' in d, f'no plan field, keys: {list(d.keys())}'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── 11: módulos ordenados CRITICAL antes que HIGH ─────────────────────────────
@test "SE252-dist-11: plan JSON ordena CRITICAL antes de HIGH" {
  _setup_single_author_repo
  _inject_scan_json
  local outfile="$BATS_TMPDIR/dist11-$$.json"
  bash "$DIST_SCRIPT" \
    --project "$TEST_REPO" \
    --target "carol@test.com" \
    --format json \
    --output "$outfile" 2>/dev/null
  run python3 -c "
import json
d = json.load(open('$outfile'))
plan = d.get('plan', [])
risk_rank = {'CRITICAL':4,'HIGH':3,'MEDIUM':2,'LOW':1}
for i in range(len(plan)-1):
    r1 = risk_rank.get(plan[i]['risk_level'],0)
    r2 = risk_rank.get(plan[i+1]['risk_level'],0)
    assert r1 >= r2, f'Order error: {plan[i][\"risk_level\"]} before {plan[i+1][\"risk_level\"]}'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── 12: módulos ordenados HIGH antes que MEDIUM ───────────────────────────────
@test "SE252-dist-12: plan JSON ordena HIGH antes de MEDIUM" {
  _setup_single_author_repo
  _inject_scan_json
  local outfile="$BATS_TMPDIR/dist12-$$.json"
  bash "$DIST_SCRIPT" \
    --project "$TEST_REPO" \
    --target "nobody@test.com" \
    --format json \
    --output "$outfile" 2>/dev/null
  run python3 -c "
import json
d = json.load(open('$outfile'))
plan = d.get('plan', [])
risk_rank = {'CRITICAL':4,'HIGH':3,'MEDIUM':2,'LOW':1}
levels = [risk_rank.get(p['risk_level'],0) for p in plan]
assert levels == sorted(levels, reverse=True), f'Not sorted: {levels}'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── 13: markdown output contiene nombre de modulo ─────────────────────────────
@test "SE252-dist-13: --format markdown produce output con nombre de modulo" {
  _setup_single_author_repo
  _inject_scan_json
  run bash "$DIST_SCRIPT" \
    --project "$TEST_REPO" \
    --target "carol@test.com" \
    --format markdown
  [ "$status" -eq 0 ]
  [[ "$output" == *"src"* ]] || [[ "$output" == *"lib"* ]] || [[ "$output" == *"docs"* ]]
}

# ── 14: --output flag escribe archivo ─────────────────────────────────────────
@test "SE252-dist-14: --output escribe el resultado en archivo" {
  _setup_single_author_repo
  _inject_scan_json
  local outfile="$BATS_TMPDIR/dist14-$$.md"
  run bash "$DIST_SCRIPT" \
    --project "$TEST_REPO" \
    --target "carol@test.com" \
    --format markdown \
    --output "$outfile"
  [ "$status" -eq 0 ]
  [ -f "$outfile" ]
  [ -s "$outfile" ]
}

# ── 15: archivos donde el target es owner se marcan como conocidos ─────────────
@test "SE252-dist-15: archivos donde el target es owner tienen unknown_count=0" {
  _setup_single_author_repo
  _inject_scan_json
  local outfile="$BATS_TMPDIR/dist15-$$.json"
  bash "$DIST_SCRIPT" \
    --project "$TEST_REPO" \
    --target "alice@test.com" \
    --format json \
    --output "$outfile" 2>/dev/null
  run python3 -c "
import json
d = json.load(open('$outfile'))
for item in d.get('plan', []):
    if item['module'] == 'src':
        assert item['unknown_count'] == 0, f'alice deberia conocer src, unknown={item[\"unknown_count\"]}'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── 16: formato por defecto es markdown ───────────────────────────────────────
@test "SE252-dist-16: formato por defecto es markdown sin --format" {
  _setup_single_author_repo
  _inject_scan_json
  run bash "$DIST_SCRIPT" \
    --project "$TEST_REPO" \
    --target "carol@test.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"#"* ]] || [[ "$output" == *"-"* ]]
}

# ── 17: campo target en JSON coincide con el dev especificado ─────────────────
@test "SE252-dist-17: campo target en JSON coincide con el dev especificado" {
  _setup_single_author_repo
  _inject_scan_json
  local outfile="$BATS_TMPDIR/dist17-$$.json"
  bash "$DIST_SCRIPT" \
    --project "$TEST_REPO" \
    --target "carol@test.com" \
    --format json \
    --output "$outfile" 2>/dev/null
  run python3 -c "
import json
d = json.load(open('$outfile'))
assert d['target'] == 'carol@test.com', f'expected carol, got {d[\"target\"]}'
print('OK')
"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}
