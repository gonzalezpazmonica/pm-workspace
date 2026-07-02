#!/usr/bin/env bats
# tests/bats/test-se253-language-boundaries.bats — SE-253 Slice 7
#
# Tests de aceptacion de language boundaries y migracion test-workspace (AC-7.1 a AC-7.5)
# Ejecutar: bats tests/bats/test-se253-language-boundaries.bats

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    LANG_BOUNDS_DOC="$REPO_ROOT/docs/rules/domain/language-boundaries.md"
    TEST_WORKSPACE_PY="$REPO_ROOT/scripts/test_workspace.py"
    TEST_WORKSPACE_SH="$REPO_ROOT/scripts/test-workspace.sh"
    LB_CHECK="$REPO_ROOT/scripts/language-boundary-check.sh"
    PYTEST_SUITE="$REPO_ROOT/tests/test_workspace_migration.py"
}

# ─────────────────────────────────────────────────────────────────────────────
# AC-7.1: language-boundaries.md existe en docs/rules/domain/
# ─────────────────────────────────────────────────────────────────────────────

@test "AC-7.1a: language-boundaries.md existe" {
    [ -f "$LANG_BOUNDS_DOC" ]
}

@test "AC-7.1b: language-boundaries.md tiene context_tier L2" {
    grep -q "context_tier: L2" "$LANG_BOUNDS_DOC"
}

@test "AC-7.1c: language-boundaries.md referencia SE-253" {
    grep -q "SE-253" "$LANG_BOUNDS_DOC"
}

@test "AC-7.1d: language-boundaries.md define heuristica >=5 usos jq" {
    grep -q ">=5" "$LANG_BOUNDS_DOC"
}

# ─────────────────────────────────────────────────────────────────────────────
# AC-7.2: test_workspace.py existe y produce exit 0 en workspace actual
# ─────────────────────────────────────────────────────────────────────────────

@test "AC-7.2a: test_workspace.py existe" {
    [ -f "$TEST_WORKSPACE_PY" ]
}

@test "AC-7.2b: test_workspace.py tiene shebang python3" {
    head -1 "$TEST_WORKSPACE_PY" | grep -q "python3"
}

@test "AC-7.2c: test_workspace.py produce exit 0 en mock mode" {
    python3 "$TEST_WORKSPACE_PY" --mock > /dev/null 2>&1
}

@test "AC-7.2d: test_workspace.py acepta --only capacity" {
    python3 "$TEST_WORKSPACE_PY" --mock --only capacity > /dev/null 2>&1
}

@test "AC-7.2e: test_workspace.py acepta --only structure" {
    python3 "$TEST_WORKSPACE_PY" --mock --only structure > /dev/null 2>&1
}

@test "AC-7.2f: test_workspace.py produce exit 2 con argumento desconocido" {
    run python3 "$TEST_WORKSPACE_PY" --opcion-invalida-xyz
    [ "$status" -eq 2 ]
}

# ─────────────────────────────────────────────────────────────────────────────
# AC-7.3: El job CI invoca test-workspace.sh (wrapper preserva interfaz)
# ─────────────────────────────────────────────────────────────────────────────

@test "AC-7.3a: test-workspace.sh existe" {
    [ -f "$TEST_WORKSPACE_SH" ]
}

@test "AC-7.3b: test-workspace.sh es ejecutable" {
    [ -x "$TEST_WORKSPACE_SH" ]
}

@test "AC-7.3c: ci.yml referencia test-workspace.sh" {
    grep -q "test-workspace.sh" "$REPO_ROOT/.github/workflows/ci.yml"
}

@test "AC-7.3d: test-workspace.sh wrapper delega a test_workspace.py" {
    grep -q "test_workspace.py" "$TEST_WORKSPACE_SH"
}

@test "AC-7.3e: wrapper tiene <=15 lineas" {
    LINE_COUNT=$(wc -l < "$TEST_WORKSPACE_SH")
    [ "$LINE_COUNT" -le 15 ]
}

@test "AC-7.3f: wrapper invocado con --mock produce exit 0" {
    bash "$TEST_WORKSPACE_SH" --mock > /dev/null 2>&1
}

# ─────────────────────────────────────────────────────────────────────────────
# AC-7.4: pytest tests/test_workspace_migration.py pasa (>=10 tests)
# ─────────────────────────────────────────────────────────────────────────────

@test "AC-7.4a: tests/test_workspace_migration.py existe" {
    [ -f "$PYTEST_SUITE" ]
}

@test "AC-7.4b: pytest test_workspace_migration.py pasa" {
    run python3 -m pytest "$PYTEST_SUITE" --no-header -q 2>&1
    [ "$status" -eq 0 ]
}

@test "AC-7.4c: pytest ejecuta al menos 10 tests" {
    OUTPUT=$(python3 -m pytest "$PYTEST_SUITE" --no-header -q 2>&1)
    # Extrae el numero de tests pasados: "22 passed" o "10 passed"
    COUNT=$(echo "$OUTPUT" | grep -oE '[0-9]+ passed' | grep -oE '^[0-9]+' || echo "0")
    [ "$COUNT" -ge 10 ]
}

# ─────────────────────────────────────────────────────────────────────────────
# AC-7.5: language-boundary-check.sh existe y es ejecutable
# ─────────────────────────────────────────────────────────────────────────────

@test "AC-7.5a: language-boundary-check.sh existe" {
    [ -f "$LB_CHECK" ]
}

@test "AC-7.5b: language-boundary-check.sh es ejecutable" {
    [ -x "$LB_CHECK" ]
}

@test "AC-7.5c: language-boundary-check.sh --warn con fichero de 5 jqs emite WARN" {
    # Crear fichero temporal con 5 usos de jq
    TMPFILE=$(mktemp /tmp/test_jq_script_XXXXXX.sh)
    printf '#!/usr/bin/env bash\njq . a.json\njq . b.json\njq . c.json\njq . d.json\njq . e.json\n' > "$TMPFILE"
    run bash "$LB_CHECK" --warn "$TMPFILE"
    rm -f "$TMPFILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"* ]]
}

@test "AC-7.5d: language-boundary-check.sh --check con fichero de 5 jqs retorna exit 1" {
    TMPFILE=$(mktemp /tmp/test_jq_script_XXXXXX.sh)
    printf '#!/usr/bin/env bash\njq . a.json\njq . b.json\njq . c.json\njq . d.json\njq . e.json\n' > "$TMPFILE"
    run bash "$LB_CHECK" --check "$TMPFILE"
    rm -f "$TMPFILE"
    [ "$status" -eq 1 ]
}

@test "AC-7.5e: language-boundary-check.sh --warn con fichero de 4 jqs no emite WARN" {
    TMPFILE=$(mktemp /tmp/test_jq_script_XXXXXX.sh)
    printf '#!/usr/bin/env bash\njq . a.json\njq . b.json\njq . c.json\njq . d.json\n' > "$TMPFILE"
    run bash "$LB_CHECK" --warn "$TMPFILE"
    rm -f "$TMPFILE"
    [ "$status" -eq 0 ]
    [[ "$output" != *"WARN"* ]]
}

@test "AC-7.5f: language-boundary-check.sh respeta excepcion setup.sh" {
    TMPFILE=$(mktemp -t setup.sh.XXXXXX)
    # Renombrar para que sea "setup.sh"
    SETUP_FILE="$(dirname "$TMPFILE")/setup.sh"
    printf '#!/usr/bin/env bash\njq . a.json\njq . b.json\njq . c.json\njq . d.json\njq . e.json\n' > "$SETUP_FILE"
    run bash "$LB_CHECK" --check "$SETUP_FILE"
    rm -f "$SETUP_FILE" "$TMPFILE"
    [ "$status" -eq 0 ]
}
