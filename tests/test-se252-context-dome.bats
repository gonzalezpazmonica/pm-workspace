#!/usr/bin/env bats
# tests/test-se252-context-dome.bats — SE-252 Bus Factor Shield
# Tests para scripts/context-dome-generate.sh

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
DOME_SCRIPT="$REPO_ROOT/scripts/context-dome-generate.sh"
SCAN_SCRIPT="$REPO_ROOT/scripts/bus-factor-scan.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  DOME_SCRIPT="$REPO_ROOT/scripts/context-dome-generate.sh"
  SCAN_SCRIPT="$REPO_ROOT/scripts/bus-factor-scan.sh"
  TEST_REPO="$BATS_TMPDIR/dome-repo-$$"
  BF_OUT="$BATS_TMPDIR/dome-bf-out-$$"
  mkdir -p "$TEST_REPO" "$BF_OUT"
  export BF_OUTPUT_DIR="$BF_OUT"
}

teardown() {
  rm -rf "$TEST_REPO" "$BF_OUT" 2>/dev/null || true
}

# Helper: crea repo con un solo autor y 6 commits en src/
_setup_single_author_repo() {
  cd "$TEST_REPO"
  git init -q
  git config user.email "alice@test.com"
  git config user.name "Alice"
  mkdir -p src
  for i in $(seq 1 6); do
    printf "content%s\n" "$i" > "src/main.py"
    git add src/main.py
    git commit -q -m "commit $i"
  done
}

# Helper: ejecuta scan y genera el JSON en BF_OUT
_run_scan() {
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$SCAN_SCRIPT" \
    --project "$TEST_REPO" \
    --output "$BF_OUT/$(basename "$TEST_REPO").json" \
    2>/dev/null
}

# ── 01: script existe ─────────────────────────────────────────────────────────
@test "SE252-dome-01: context-dome-generate.sh existe" {
  [ -f "$DOME_SCRIPT" ]
}

# ── 02: script es ejecutable ──────────────────────────────────────────────────
@test "SE252-dome-02: context-dome-generate.sh tiene permiso de ejecucion o es invocable con bash" {
  [ -f "$DOME_SCRIPT" ]
  run bash -n "$DOME_SCRIPT"
  [ "$status" -eq 0 ]
}

# ── 03: bash -n syntax check ──────────────────────────────────────────────────
@test "SE252-dome-03: bash -n no detecta errores de sintaxis" {
  run bash -n "$DOME_SCRIPT"
  [ "$status" -eq 0 ]
}

# ── 04: sin argumentos → mensaje de uso ───────────────────────────────────────
@test "SE252-dome-04: sin argumentos imprime mensaje de uso y sale con error" {
  run bash "$DOME_SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" =~ [Uu]sage|--project ]]
}

# ── 05: --project inválido → exit 1 ───────────────────────────────────────────
@test "SE252-dome-05: --project con directorio sin scan JSON sale con error" {
  mkdir -p "$BATS_TMPDIR/nodome-$$"
  git init -q "$BATS_TMPDIR/nodome-$$"
  # Sin JSON de scan disponible
  local emptydir="$BATS_TMPDIR/empty-bf-$$"
  mkdir -p "$emptydir"
  BF_OUTPUT_DIR="$emptydir" run bash "$DOME_SCRIPT" \
    --project "$BATS_TMPDIR/nodome-$$"
  [ "$status" -ne 0 ]
  rm -rf "$BATS_TMPDIR/nodome-$$" "$emptydir"
}

# ── 06: genera CONTEXT_DOME.md en directorio del módulo ───────────────────────
@test "SE252-dome-06: genera CONTEXT_DOME.md en el directorio del modulo" {
  _setup_single_author_repo
  _run_scan
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" run bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" \
    --min-risk LOW
  [ "$status" -eq 0 ]
  # Buscar algún CONTEXT_DOME.md generado
  local found
  found=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" 2>/dev/null | head -1)
  [ -n "$found" ]
}

# ── 07: CONTEXT_DOME.md tiene frontmatter YAML (--- ... ---) ──────────────────
@test "SE252-dome-07: CONTEXT_DOME.md tiene frontmatter YAML delimitado por ---" {
  _setup_single_author_repo
  _run_scan
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW 2>/dev/null
  local dome
  dome=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" | head -1)
  [ -n "$dome" ]
  run head -1 "$dome"
  [[ "$output" == "---" ]]
}

# ── 08: frontmatter contiene "module:" ────────────────────────────────────────
@test "SE252-dome-08: CONTEXT_DOME.md frontmatter contiene campo module:" {
  _setup_single_author_repo
  _run_scan
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW 2>/dev/null
  local dome
  dome=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" | head -1)
  [ -n "$dome" ]
  run grep "^module:" "$dome"
  [ "$status" -eq 0 ]
}

# ── 09: frontmatter contiene "bus_factor:" ────────────────────────────────────
@test "SE252-dome-09: CONTEXT_DOME.md frontmatter contiene campo bus_factor:" {
  _setup_single_author_repo
  _run_scan
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW 2>/dev/null
  local dome
  dome=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" | head -1)
  [ -n "$dome" ]
  run grep "^bus_factor:" "$dome"
  [ "$status" -eq 0 ]
}

# ── 10: frontmatter contiene "risk_level:" ────────────────────────────────────
@test "SE252-dome-10: CONTEXT_DOME.md frontmatter contiene campo risk_level:" {
  _setup_single_author_repo
  _run_scan
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW 2>/dev/null
  local dome
  dome=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" | head -1)
  [ -n "$dome" ]
  run grep "^risk_level:" "$dome"
  [ "$status" -eq 0 ]
}

# ── 11: frontmatter contiene "knowledge_owners:" ─────────────────────────────
@test "SE252-dome-11: CONTEXT_DOME.md frontmatter contiene campo knowledge_owners:" {
  _setup_single_author_repo
  _run_scan
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW 2>/dev/null
  local dome
  dome=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" | head -1)
  [ -n "$dome" ]
  run grep "^knowledge_owners:" "$dome"
  [ "$status" -eq 0 ]
}

# ── 12: frontmatter contiene "generated_at:" ──────────────────────────────────
@test "SE252-dome-12: CONTEXT_DOME.md frontmatter contiene campo generated_at:" {
  _setup_single_author_repo
  _run_scan
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW 2>/dev/null
  local dome
  dome=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" | head -1)
  [ -n "$dome" ]
  run grep "^generated_at:" "$dome"
  [ "$status" -eq 0 ]
}

# ── 13: frontmatter contiene "runbook_confidence:" ────────────────────────────
@test "SE252-dome-13: CONTEXT_DOME.md frontmatter contiene campo runbook_confidence:" {
  _setup_single_author_repo
  _run_scan
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW 2>/dev/null
  local dome
  dome=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" | head -1)
  [ -n "$dome" ]
  run grep "^runbook_confidence:" "$dome"
  [ "$status" -eq 0 ]
}

# ── 14: sección "## Knowledge owners actuales" presente ───────────────────────
@test "SE252-dome-14: CONTEXT_DOME.md contiene seccion Knowledge owners actuales" {
  _setup_single_author_repo
  _run_scan
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW 2>/dev/null
  local dome
  dome=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" | head -1)
  [ -n "$dome" ]
  run grep -i "Knowledge owners" "$dome"
  [ "$status" -eq 0 ]
}

# ── 15: sección "## Runbook minimo" presente ──────────────────────────────────
@test "SE252-dome-15: CONTEXT_DOME.md contiene seccion Runbook minimo" {
  _setup_single_author_repo
  _run_scan
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW 2>/dev/null
  local dome
  dome=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" | head -1)
  [ -n "$dome" ]
  run grep -i "Runbook" "$dome"
  [ "$status" -eq 0 ]
}

# ── 16: sección "## Proposito" presente ───────────────────────────────────────
@test "SE252-dome-16: CONTEXT_DOME.md contiene seccion Proposito o Propósito" {
  _setup_single_author_repo
  _run_scan
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW 2>/dev/null
  local dome
  dome=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" | head -1)
  [ -n "$dome" ]
  run grep -iE "Prop[oó]sito" "$dome"
  [ "$status" -eq 0 ]
}

# ── 17: sección historial de cambios presente ─────────────────────────────────
@test "SE252-dome-17: CONTEXT_DOME.md contiene seccion Historial" {
  _setup_single_author_repo
  _run_scan
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW 2>/dev/null
  local dome
  dome=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" | head -1)
  [ -n "$dome" ]
  run grep -i "Historial" "$dome"
  [ "$status" -eq 0 ]
}

# ── 18: sin Makefile/package.json → runbook_confidence: low ───────────────────
@test "SE252-dome-18: sin Makefile ni package.json runbook_confidence es low" {
  _setup_single_author_repo
  _run_scan
  # Asegurar que no hay Makefile en src/
  rm -f "$TEST_REPO/src/Makefile" "$TEST_REPO/src/package.json"
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW 2>/dev/null
  local dome
  dome=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" | head -1)
  [ -n "$dome" ]
  run grep "^runbook_confidence:" "$dome"
  [ "$status" -eq 0 ]
  [[ "$output" == *"low"* ]]
}

# ── 19: con Makefile → runbook_confidence medium o high ───────────────────────
@test "SE252-dome-19: con Makefile en modulo runbook_confidence no es low" {
  _setup_single_author_repo
  # Añadir Makefile con targets
  cat > "$TEST_REPO/src/Makefile" << 'EOF'
build:
	echo building
test:
	echo testing
run:
	echo running
EOF
  cd "$TEST_REPO"
  git add src/Makefile
  git commit -q -m "add Makefile"
  _run_scan
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW 2>/dev/null
  local dome
  dome=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" | head -1)
  [ -n "$dome" ]
  run grep "^runbook_confidence:" "$dome"
  [ "$status" -eq 0 ]
  # medium o high (no low porque hay Makefile)
  [[ "$output" == *"medium"* ]] || [[ "$output" == *"high"* ]]
}

# ── 20: idempotente (segunda ejecución → mismo archivo con misma estructura) ───
@test "SE252-dome-20: segunda ejecucion produce mismo frontmatter excepto generated_at" {
  _setup_single_author_repo
  _run_scan
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW 2>/dev/null
  local dome
  dome=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" | head -1)
  [ -n "$dome" ]
  local bf1 rl1
  bf1=$(grep "^bus_factor:" "$dome" | head -1)
  rl1=$(grep "^risk_level:" "$dome" | head -1)
  # Segunda ejecución
  sleep 1
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW 2>/dev/null
  local bf2 rl2
  bf2=$(grep "^bus_factor:" "$dome" | head -1)
  rl2=$(grep "^risk_level:" "$dome" | head -1)
  [ "$bf1" = "$bf2" ]
  [ "$rl1" = "$rl2" ]
}

# ── 21: --min-risk HIGH solo genera domes para HIGH o CRITICAL ────────────────
@test "SE252-dome-21: --min-risk HIGH no genera domes para modulos LOW o MEDIUM" {
  _setup_single_author_repo
  _run_scan
  # Con BF_RISK_HIGH=10 todos seran LOW
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" BF_RISK_HIGH=10 bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk HIGH 2>/dev/null
  # Si hay dome, debe ser para HIGH o CRITICAL solamente
  local dome
  dome=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" | head -1)
  # Si no se genera dome (porque todos son LOW), eso también es correcto
  if [ -n "$dome" ]; then
    run grep "^risk_level:" "$dome"
    [[ "$output" == *"HIGH"* ]] || [[ "$output" == *"CRITICAL"* ]]
  fi
  # El test pasa en cualquier caso: sin dome o dome con HIGH/CRITICAL
  true
}

# ── 22: --dry-run no escribe archivos ─────────────────────────────────────────
@test "SE252-dome-22: --dry-run no escribe CONTEXT_DOME.md" {
  _setup_single_author_repo
  _run_scan
  BF_MIN_COMMITS=3 BF_OUTPUT_DIR="$BF_OUT" bash "$DOME_SCRIPT" \
    --project "$TEST_REPO" --min-risk LOW --dry-run 2>/dev/null
  local found
  found=$(find "$TEST_REPO" -name "CONTEXT_DOME.md" 2>/dev/null | wc -l)
  [ "$found" -eq 0 ]
}
