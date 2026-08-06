#!/usr/bin/env bats
# tests/bats/test-se297-tabular-excel.bats
# SE-297 — Tabular Intelligence: Excel (.xlsx), deteccion relacional y
# correccion de citas. Cubre AC-1.1..1.4 (Slice 1) y AC-2.1..2.4 (Slice 2).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  PROFILER="$REPO_ROOT/scripts/tabular-profile.py"
  FIXTURES="$REPO_ROOT/tests/fixtures/tabular"
  HOOK="$REPO_ROOT/.claude/hooks/pre-llm-tabular-detect.sh"

  # openpyxl es dependencia OPCIONAL (AC-1.4). Intenta habilitarla para los
  # tests de lectura XLSX; si no se puede, esos tests se saltan (skip).
  if python3 -c "import openpyxl" >/dev/null 2>&1; then
    HAVE_OPENPYXL=1
  else
    HAVE_OPENPYXL=0
    pip3 install openpyxl -q >/dev/null 2>&1 && HAVE_OPENPYXL=1 || true
  fi
}

# ── Slice 1: Excel (.xlsx) ──────────────────────────────────────────────────

@test "AC-1.1: xlsx con 3 hojas produce perfil por hoja con nombre" {
  [[ "$HAVE_OPENPYXL" == "1" ]] || skip "openpyxl no disponible"
  run python3 "$PROFILER" "$FIXTURES/ventas_multi.xlsx"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"tables\""* ]]
  local names
  names=$(echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'tables' in d, d
print(sorted(t['name'] for t in d['tables']))
")
  [ "$names" = "['clientes', 'productos', 'ventas']" ]
}

@test "AC-1.2: formulas leidas como valores calculados, no como texto" {
  [[ "$HAVE_OPENPYXL" == "1" ]] || skip "openpyxl no disponible"
  run python3 "$PROFILER" "$FIXTURES/formulas.xlsx"
  [ "$status" -eq 0 ]
  local rtype rmin rmax
  read -r rtype rmin rmax <<<"$(echo "$output" | python3 -c '
import json, sys
d = json.load(sys.stdin)
p = [x for x in d["profiles"] if x["name"] == "resultado"][0]
print(p["type"], p.get("min"), p.get("max"))
')"
  # type numeric (no text) demuestra que se leyo el valor, no la formula "=B2+C2"
  [ "$rtype" = "numeric" ]
  [ "$rmin" = "15.0" ]
  [ "$rmax" = "96.0" ]
}

@test "AC-1.3: xlsx de fixture coincide en cifras con CSV equivalente" {
  [[ "$HAVE_OPENPYXL" == "1" ]] || skip "openpyxl no disponible"
  run python3 "$PROFILER" "$FIXTURES/ventas.csv"
  [ "$status" -eq 0 ]
  local csv_rows csv_mean
  read -r csv_rows csv_mean <<<"$(echo "$output" | python3 -c '
import json, sys
d = json.load(sys.stdin)
p = [x for x in d["profiles"] if x["name"] == "cantidad"][0]
print(d["rows"], p["mean"])
')"

  run python3 "$PROFILER" "$FIXTURES/ventas_one.xlsx"
  [ "$status" -eq 0 ]
  local xlsx_rows xlsx_mean
  read -r xlsx_rows xlsx_mean <<<"$(echo "$output" | python3 -c '
import json, sys
d = json.load(sys.stdin)
p = [x for x in d["profiles"] if x["name"] == "cantidad"][0]
print(d["rows"], p["mean"])
')"

  [ "$csv_rows" = "$xlsx_rows" ]
  [ "$csv_mean" = "$xlsx_mean" ]
}

@test "AC-1.4: degradacion explicita si openpyxl no esta (no fallo silencioso)" {
  # python3 -S (sin site-packages) + sin PYTHONPATH simulan la ausencia de
  # openpyxl de forma determinista, en cualquier entorno.
  run env -u PYTHONPATH python3 -S "$PROFILER" "$FIXTURES/ventas_one.xlsx"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Excel no soportado en este entorno"* ]]
}

# ── Slice 2: deteccion relacional ───────────────────────────────────────────

@test "AC-2.1: relacion detectada por clave compartida con solape medido" {
  run python3 "$PROFILER" "$FIXTURES/clientes.csv" "$FIXTURES/pedidos.csv"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c '
import json, sys
d = json.load(sys.stdin)
r = [x for x in d["relations"] if x["column_a"] == "id_cliente"]
assert len(r) == 1, r
assert r[0]["column_b"] == "id_cliente", r
assert r[0]["overlap_pct"] == 100.0, r
'
}

@test "AC-2.2: sin columnas relacionables -> relations vacia, no forzada" {
  run python3 "$PROFILER" "$FIXTURES/ventas.csv" "$FIXTURES/clientes.csv"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['relations'] == [], d['relations']
"
}

@test "AC-2.3: determinista — mismo par de tablas, mismo resultado" {
  local a b
  a=$(python3 "$PROFILER" "$FIXTURES/clientes.csv" "$FIXTURES/pedidos.csv")
  b=$(python3 "$PROFILER" "$FIXTURES/clientes.csv" "$FIXTURES/pedidos.csv")
  [ "$a" = "$b" ]
}

@test "AC-2.4: coste acotado — tope de muestreo declarado en codigo" {
  grep -q "RELATION_SAMPLE" "$PROFILER"
  grep -q "RELATION_SAMPLE *=" "$PROFILER"
  grep -q "O(n\*m)\|O(n.m)" "$PROFILER"
}

# ── Slice 1: hook pre-LLM detecta ruta .xlsx ────────────────────────────────

@test "hook pre-llm detecta ruta .xlsx y sustituye por perfil" {
  [[ "$HAVE_OPENPYXL" == "1" ]] || skip "openpyxl no disponible"
  run bash "$HOOK" <<< "analiza el fichero $FIXTURES/ventas_one.xlsx"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STATISTICAL PROFILE"* ]]
  [[ "$output" == *"ventas_one.xlsx"* ]]
}
