#!/bin/bash
# Ejecutar todos los scripts de test y reportar fallos

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$WORKSPACE_ROOT"

LOG_DIR="$SCRIPT_DIR/test-logs"
mkdir -p "$LOG_DIR"

PASS=0
FAIL=0
SKIP=0
TOTAL=0

# Listar todos los scripts test-*.sh en scripts/
TEST_SCRIPTS=$(find scripts -name "test-*.sh" -type f | sort)

echo "═══════════════════════════════════════════════════════════════"
echo "  Ejecutando todos los tests de PM-Workspace"
echo "  Total scripts: $(echo "$TEST_SCRIPTS" | wc -l)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

for test_script in $TEST_SCRIPTS; do
    TOTAL=$((TOTAL + 1))
    echo -n "[$TOTAL] $test_script ... "
    
    # Omitir tests que requieren conexión externa (basado en nombre)
    if [[ "$test_script" == *"azure"* ]] || [[ "$test_script" == *"devops"* ]] || [[ "$test_script" == *"company"* ]] || [[ "$test_script" == *"hub"* ]] || [[ "$test_script" == *"integration"* ]]; then
        echo "SKIP (external)"
        SKIP=$((SKIP + 1))
        continue
    fi
    
    LOG_FILE="$LOG_DIR/$(basename "$test_script").log"
    
    # Ejecutar con timeout de 30 segundos
    timeout 30 bash "$test_script" > "$LOG_FILE" 2>&1
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo "PASS"
        PASS=$((PASS + 1))
    elif [ $EXIT_CODE -eq 124 ]; then
        echo "TIMEOUT"
        FAIL=$((FAIL + 1))
    else
        echo "FAIL (code $EXIT_CODE)"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  RESULTADO FINAL"
echo "═══════════════════════════════════════════════════════════════"
echo "  TOTAL:    $TOTAL scripts"
echo "  PASSED:   $PASS"
echo "  FAILED:   $FAIL"
echo "  SKIPPED:  $SKIP"
echo "═══════════════════════════════════════════════════════════════"

# Mostrar scripts fallidos
if [ $FAIL -gt 0 ]; then
    echo ""
    echo "Scripts fallidos:"
    for test_script in $TEST_SCRIPTS; do
        LOG_FILE="$LOG_DIR/$(basename "$test_script").log"
        if [ -f "$LOG_FILE" ]; then
            # Verificar si el log contiene algún indicio de fallo (no solo exit code)
            # Simplemente listar los que fallaron
            grep -q "FAIL\|failed\|error" "$LOG_FILE" 2>/dev/null && echo "  ❌ $test_script"
        fi
    done
fi

exit $((FAIL > 0 ? 1 : 0))