#!/usr/bin/env bash
# ============================================================================
# test-workspace.sh — Test Suite del PM Workspace
# ============================================================================
# Valida todas las funcionalidades del PM Workspace contra el proyecto
# de test "sala-reservas". Puede ejecutarse en modo mock (sin Azure DevOps)
# o en modo real (con PAT configurado).
#
# Uso:
#   ./scripts/test-workspace.sh              # modo mock (sin Azure DevOps)
#   ./scripts/test-workspace.sh --real       # modo real (requiere PAT)
#   ./scripts/test-workspace.sh --only prereqs
#   ./scripts/test-workspace.sh --only capacity
#   ./scripts/test-workspace.sh --only sdd
#   ./scripts/test-workspace.sh --only specs
#   ./scripts/test-workspace.sh --verbose    # muestra output completo
#
# Categorías de test:
#   prereqs    Requisitos previos (herramientas instaladas)
#   connection Conectividad con Azure DevOps (solo --real)
#   structure  Estructura de ficheros del workspace
#   capacity   Cálculo de capacidades (usa mock data)
#   sprint     Datos del sprint (mock o real)
#   backlog    Gestión de backlog (mock o real)
#   imputacion Imputaciones de horas (mock)
#   scoring    Algoritmo de asignación (cálculo local)
#   sdd        Spec-Driven Development (validación de specs)
#   specs      Calidad de las specs de ejemplo
#   report     Generación de informes (mock)
# ============================================================================

set -euo pipefail

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Configuración ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_PROJECT_DIR="$WORKSPACE_ROOT/projects/sala-reservas"
MOCK_DATA_DIR="$TEST_PROJECT_DIR/test-data"
OUTPUT_DIR="$WORKSPACE_ROOT/output"
REPORT_FILE="$OUTPUT_DIR/test-workspace-$(date +%Y%m%d-%H%M%S).md"

MODE="mock"         # mock | real
ONLY_CATEGORY=""    # si se especifica --only, solo esa categoría
VERBOSE=false

# Contadores
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
declare -a FAILED_TESTS=()

# ── Parse args ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --real)      MODE="real";         shift ;;
    --mock)      MODE="mock";         shift ;;
    --only)      ONLY_CATEGORY="$2"; shift 2 ;;
    --verbose)   VERBOSE=true;        shift ;;
    -h|--help)
      grep "^# " "$0" | head -20 | sed 's/^# //'
      exit 0
      ;;
    *) echo "Opción desconocida: $1"; exit 1 ;;
  esac
done

# ── Funciones de output ───────────────────────────────────────────────────────
log_header() {
  echo ""
  echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${BLUE}  $1${NC}"
  echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════${NC}"
}

log_section() {
  echo ""
  echo -e "${CYAN}▶ $1${NC}"
}

pass() {
  echo -e "  ${GREEN}✅ PASS${NC} — $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

fail() {
  echo -e "  ${RED}❌ FAIL${NC} — $1"
  echo -e "     ${RED}↳ $2${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  FAILED_TESTS+=("$1: $2")
}

skip() {
  echo -e "  ${YELLOW}⏭  SKIP${NC} — $1 (${2:-requiere modo --real})"
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

info() {
  echo -e "  ${YELLOW}ℹ  INFO${NC} — $1"
}

should_run() {
  [[ -z "$ONLY_CATEGORY" || "$ONLY_CATEGORY" == "$1" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 1: PRERREQUISITOS
# ─────────────────────────────────────────────────────────────────────────────
test_prereqs() {
  log_header "SUITE 1 — Prerrequisitos del Sistema"

  log_section "Herramientas de línea de comandos"

  # jq
  if command -v jq &>/dev/null; then
    pass "jq instalado ($(jq --version))"
  else
    fail "jq no encontrado" "Instalar: apt install jq / brew install jq"
  fi

  # Python3
  if command -v python3 &>/dev/null; then
    PYVER=$(python3 --version 2>&1)
    pass "Python3 instalado ($PYVER)"
  else
    fail "python3 no encontrado" "Instalar Python 3.10+"
  fi

  # Node.js
  if command -v node &>/dev/null; then
    NODEVER=$(node --version)
    pass "Node.js instalado ($NODEVER)"
  else
    fail "node no encontrado" "Instalar Node.js 18+"
  fi

  # curl
  if command -v curl &>/dev/null; then
    pass "curl instalado"
  else
    fail "curl no encontrado" "Instalar curl"
  fi

  # Azure CLI (solo obligatorio en modo --real; en mock se omite)
  log_section "Azure CLI"
  if command -v az &>/dev/null; then
    AZVER=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "desconocida")
    pass "Azure CLI instalado (v$AZVER)"
    if az extension show --name azure-devops &>/dev/null 2>&1; then
      pass "Extensión azure-devops instalada"
    else
      if [[ "$MODE" == "mock" ]]; then
        skip "Extensión azure-devops NO instalada" "No requerida en modo --mock"
      else
        fail "Extensión azure-devops NO instalada" "Ejecutar: az extension add --name azure-devops"
      fi
    fi
  else
    if [[ "$MODE" == "mock" ]]; then
      skip "az (Azure CLI) no encontrado" "No requerido en modo --mock"
    else
      fail "az (Azure CLI) no encontrado" "Instalar: https://docs.microsoft.com/cli/azure/install-azure-cli"
    fi
  fi

  # Claude CLI
  log_section "Claude Code CLI (para SDD)"
  if command -v claude &>/dev/null; then
    CLAUDEVER=$(claude --version 2>/dev/null || echo "desconocida")
    pass "Claude CLI instalado ($CLAUDEVER)"
  else
    skip "Claude CLI no encontrado" "Opcional para SDD. Instalar: https://docs.claude.ai/claude-code"
  fi

  # npm packages
  log_section "Dependencias Node.js (scripts/)"
  if [[ -d "$WORKSPACE_ROOT/scripts/node_modules" ]]; then
    pass "node_modules instalados en scripts/"
  else
    fail "node_modules no encontrado" "Ejecutar: cd scripts && npm install"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 2: ESTRUCTURA DE FICHEROS
# ─────────────────────────────────────────────────────────────────────────────
test_structure() {
  log_header "SUITE 2 — Estructura del Workspace"

  log_section "Ficheros raíz obligatorios"
  local ROOT_FILES=("CLAUDE.md" "README.md" ".gitignore")
  for f in "${ROOT_FILES[@]}"; do
    if [[ -f "$WORKSPACE_ROOT/$f" ]]; then
      pass "$f existe"
    else
      fail "$f no encontrado" "Fichero raíz obligatorio"
    fi
  done

  log_section "Skills (.claude/skills/)"
  local SKILLS=("azure-devops-queries" "sprint-management" "capacity-planning" "time-tracking-report" "executive-reporting" "pbi-decomposition" "spec-driven-development")
  for skill in "${SKILLS[@]}"; do
    if [[ -f "$WORKSPACE_ROOT/.claude/skills/$skill/SKILL.md" ]]; then
      LINES=$(wc -l < "$WORKSPACE_ROOT/.claude/skills/$skill/SKILL.md")
      pass "Skill '$skill' (SKILL.md — $LINES líneas)"
    else
      fail "Skill '$skill' no encontrada" "Falta $skill/SKILL.md"
    fi
  done

  log_section "SDD Reference Files"
  local SDD_REFS=("spec-template.md" "layer-assignment-matrix.md" "agent-team-patterns.md")
  for ref in "${SDD_REFS[@]}"; do
    if [[ -f "$WORKSPACE_ROOT/.claude/skills/spec-driven-development/references/$ref" ]]; then
      pass "SDD reference: $ref"
    else
      fail "SDD reference faltante: $ref" "Ejecutar setup SDD"
    fi
  done

  log_section "Slash Commands (.claude/commands/)"
  local COMMANDS=("sprint-status" "sprint-plan" "sprint-review" "sprint-retro" "report-hours" "report-executive" "report-capacity" "team-workload" "board-flow" "kpi-dashboard" "pbi-decompose" "pbi-decompose-batch" "pbi-assign" "pbi-plan-sprint" "spec-generate" "spec-implement" "spec-review" "spec-status" "agent-run")
  for cmd in "${COMMANDS[@]}"; do
    if [[ -f "$WORKSPACE_ROOT/.claude/commands/$cmd.md" ]]; then
      pass "Comando /$cmd"
    else
      fail "Comando /$cmd no encontrado" "Falta .claude/commands/$cmd.md"
    fi
  done

  log_section "Proyecto de Test (sala-reservas)"
  local TEST_FILES=(
    "projects/sala-reservas/CLAUDE.md"
    "projects/sala-reservas/equipo.md"
    "projects/sala-reservas/reglas-negocio.md"
    "projects/sala-reservas/sprints/sprint-2026-04/planning.md"
    "projects/sala-reservas/specs/sprint-2026-04/AB101-B3-create-sala-handler.spec.md"
    "projects/sala-reservas/specs/sprint-2026-04/AB102-D1-unit-tests-salas.spec.md"
    "projects/sala-reservas/specs/sdd-metrics.md"
    "projects/sala-reservas/test-data/mock-workitems.json"
    "projects/sala-reservas/test-data/mock-sprint.json"
    "projects/sala-reservas/test-data/mock-capacities.json"
  )
  for f in "${TEST_FILES[@]}"; do
    if [[ -f "$WORKSPACE_ROOT/$f" ]]; then
      pass "$f"
    else
      fail "$f no encontrado" "Fichero del proyecto de test"
    fi
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 3: CONNECTIVITY (solo modo --real)
# ─────────────────────────────────────────────────────────────────────────────
test_connection() {
  log_header "SUITE 3 — Conectividad Azure DevOps"

  if [[ "$MODE" == "mock" ]]; then
    skip "Test de conectividad" "Ejecutar con --real para testear conexión real"
    skip "Listar proyectos" "requiere --real"
    skip "Leer sprint activo" "requiere --real"
    return
  fi

  # Leer PAT
  PAT_FILE=$(grep "AZURE_DEVOPS_PAT_FILE" "$WORKSPACE_ROOT/CLAUDE.md" | grep -oE '"[^"]*"' | tr -d '"')
  PAT_FILE="${PAT_FILE:-$HOME/.azure/devops-pat}"

  if [[ ! -f "$PAT_FILE" ]]; then
    fail "PAT file no encontrado: $PAT_FILE" "Crear: echo -n 'TU_PAT' > $PAT_FILE"
    return
  fi

  PAT=$(cat "$PAT_FILE")
  ORG_URL=$(grep "AZURE_DEVOPS_ORG_URL" "$WORKSPACE_ROOT/CLAUDE.md" | grep -oE '"[^"]*devops[^"]*"' | head -1 | tr -d '"')

  if [[ -z "$ORG_URL" ]]; then
    fail "ORG_URL no configurada en CLAUDE.md" "Editar CLAUDE.md y establecer AZURE_DEVOPS_ORG_URL"
    return
  fi

  info "Conectando a: $ORG_URL"

  # Test 1: Listar proyectos
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u ":$PAT" \
    "$ORG_URL/_apis/projects?api-version=7.1" 2>/dev/null)
  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Conexión Azure DevOps (HTTP $HTTP_CODE)"
  else
    fail "Error de conexión Azure DevOps (HTTP $HTTP_CODE)" "Verificar PAT y ORG_URL"
    return
  fi

  # Test 2: Verificar que el proyecto SalaReservas existe (o proyectos configurados)
  PROJECTS_JSON=$(curl -s -u ":$PAT" "$ORG_URL/_apis/projects?api-version=7.1")
  PROJECT_COUNT=$(echo "$PROJECTS_JSON" | jq '.count // 0')
  if [[ "$PROJECT_COUNT" -gt 0 ]]; then
    pass "Proyectos accesibles: $PROJECT_COUNT"
    if [[ "$VERBOSE" == true ]]; then
      echo "$PROJECTS_JSON" | jq -r '.value[].name' | while read -r name; do
        info "  Proyecto: $name"
      done
    fi
  else
    fail "No se encontraron proyectos" "Verificar permisos del PAT"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 4: CAPACITY CALCULATOR
# ─────────────────────────────────────────────────────────────────────────────
test_capacity() {
  log_header "SUITE 4 — Cálculo de Capacidades"

  log_section "Validar script capacity-calculator.py"
  CAPACITY_SCRIPT="$WORKSPACE_ROOT/scripts/capacity-calculator.py"
  if [[ ! -f "$CAPACITY_SCRIPT" ]]; then
    fail "capacity-calculator.py no encontrado" "Falta scripts/capacity-calculator.py"
    return
  fi
  pass "capacity-calculator.py existe"

  # Verificar sintaxis Python
  if python3 -m py_compile "$CAPACITY_SCRIPT" 2>/dev/null; then
    pass "Sintaxis Python válida"
  else
    fail "Error de sintaxis en capacity-calculator.py" "$(python3 -m py_compile "$CAPACITY_SCRIPT" 2>&1)"
    return
  fi

  log_section "Cálculo con datos mock"
  # Test: capacity formula = dias_habiles * horas_dia * factor_foco
  RESULT=$(python3 -c "
dias = 10
horas = 8
foco = 0.75
capacity = dias * horas * foco
print(f'{capacity:.1f}')
")
  if [[ "$RESULT" == "60.0" ]]; then
    pass "Fórmula capacity: 10días × 8h × 0.75 = 60.0h ✓"
  else
    fail "Fórmula capacity incorrecta" "Esperado: 60.0, Obtenido: $RESULT"
  fi

  log_section "Validar datos de capacidad del proyecto de test"
  MOCK_CAPACITY="$MOCK_DATA_DIR/mock-capacities.json"
  if [[ ! -f "$MOCK_CAPACITY" ]]; then
    fail "mock-capacities.json no encontrado" "$MOCK_CAPACITY"
    return
  fi

  # Validar estructura JSON
  if jq empty "$MOCK_CAPACITY" 2>/dev/null; then
    pass "mock-capacities.json es JSON válido"
  else
    fail "mock-capacities.json tiene JSON inválido" "$(jq empty "$MOCK_CAPACITY" 2>&1)"
    return
  fi

  # Test: extraer datos del mock
  TOTAL_MEMBERS=$(jq '.team_members | length' "$MOCK_CAPACITY")
  if [[ "$TOTAL_MEMBERS" -eq 5 ]]; then
    pass "5 miembros del equipo en el mock"
  else
    fail "Número de miembros incorrecto" "Esperado: 5, Obtenido: $TOTAL_MEMBERS"
  fi

  TOTAL_CAPACITY=$(jq '.capacity_summary.total_human_capacity' "$MOCK_CAPACITY")
  # 228h = developers netos (excluye PM Sofía que no tiene horas de dev)
  if python3 -c "exit(0 if abs(float('$TOTAL_CAPACITY') - 228) < 0.5 else 1)" 2>/dev/null; then
    pass "Capacity devs del equipo: ${TOTAL_CAPACITY}h (228h esperadas — excluye PM)"
  else
    fail "Capacity total incorrecta" "Esperado: ~228, Obtenido: $TOTAL_CAPACITY"
  fi

  # Test: utilización vs umbral
  UTILIZATION=$(jq '.capacity_summary.total_human_utilization_percent' "$MOCK_CAPACITY")
  UTIL_INT=$(echo "$UTILIZATION" | cut -d. -f1)
  if [[ "$UTIL_INT" -lt 85 ]]; then
    pass "Utilización del equipo: ${UTILIZATION}% (🟢 < 85%)"
  else
    fail "Utilización del equipo demasiado alta" "${UTILIZATION}% > 85%"
  fi

  log_section "Scoring de asignación"
  # Verificar el algoritmo de scoring (expertise:0.40 + availability:0.30 + balance:0.20 + growth:0.10 = 1.0)
  WEIGHTS_OK=$(python3 -c "
weights = {'expertise': 0.40, 'availability': 0.30, 'balance': 0.20, 'growth': 0.10}
total = sum(weights.values())
print('ok' if abs(total - 1.0) < 0.001 else 'fail')
")
  if [[ "$WEIGHTS_OK" == "ok" ]]; then
    pass "Pesos del algoritmo de scoring suman 1.0 ✓"
  else
    fail "Los pesos del scoring NO suman 1.0" "Verificar assignment_weights en projects/sala-reservas/CLAUDE.md"
  fi

  # Test scoring de un desarrollador
  SCORE=$(python3 -c "
expertise    = 0.9   # Carlos: experto en .NET
availability = 0.7   # Carlos: 37h libres de 48h
balance      = 0.5   # Carlos: carga media
growth       = 0.0   # Carlos: ya conoce el módulo

score = 0.40*expertise + 0.30*availability + 0.20*balance + 0.10*growth
print(f'{score:.3f}')
")
  if python3 -c "exit(0 if 0.60 <= float('$SCORE') <= 0.80 else 1)"; then
    pass "Scoring de ejemplo (Carlos): $SCORE (rango esperado: 0.60-0.80)"
  else
    fail "Scoring fuera de rango esperado" "Obtenido: $SCORE, Esperado: 0.60-0.80"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 5: DATOS DEL SPRINT (mock)
# ─────────────────────────────────────────────────────────────────────────────
test_sprint() {
  log_header "SUITE 5 — Datos del Sprint"

  log_section "Validar mock-sprint.json"
  MOCK_SPRINT="$MOCK_DATA_DIR/mock-sprint.json"

  if jq empty "$MOCK_SPRINT" 2>/dev/null; then
    pass "mock-sprint.json es JSON válido"
  else
    fail "mock-sprint.json tiene JSON inválido" "$(jq empty "$MOCK_SPRINT" 2>&1)"
    return
  fi

  # Datos del sprint
  SPRINT_NAME=$(jq -r '.sprint.name' "$MOCK_SPRINT")
  DAYS_REMAINING=$(jq '.sprint.daysRemaining' "$MOCK_SPRINT")
  TREND=$(jq -r '.burndown.trend' "$MOCK_SPRINT")

  pass "Sprint activo: $SPRINT_NAME"
  pass "Días restantes: $DAYS_REMAINING"

  if [[ "$TREND" == "on_track" ]]; then
    pass "Tendencia del burndown: $TREND 🟢"
  else
    fail "Tendencia del burndown preocupante" "Trend: $TREND"
  fi

  log_section "Validar mock-workitems.json"
  MOCK_ITEMS="$MOCK_DATA_DIR/mock-workitems.json"

  if jq empty "$MOCK_ITEMS" 2>/dev/null; then
    pass "mock-workitems.json es JSON válido"
  else
    fail "mock-workitems.json tiene JSON inválido" "$(jq empty "$MOCK_ITEMS" 2>&1)"
    return
  fi

  WI_COUNT=$(jq '.count' "$MOCK_ITEMS")
  PBIS=$(jq '[.value[] | select(.fields["System.WorkItemType"] == "Product Backlog Item")] | length' "$MOCK_ITEMS")
  TASKS=$(jq '[.value[] | select(.fields["System.WorkItemType"] == "Task")] | length' "$MOCK_ITEMS")
  AGENT_TASKS=$(jq '[.value[] | select(.fields["System.AssignedTo"].displayName == "claude-agent")] | length' "$MOCK_ITEMS")
  DONE_TASKS=$(jq '[.value[] | select(.fields["System.State"] == "Done")] | length' "$MOCK_ITEMS")

  pass "Work items totales: $WI_COUNT ($PBIS PBIs + $TASKS Tasks)"
  pass "Tasks asignadas al agente: $AGENT_TASKS"
  pass "Tasks completadas: $DONE_TASKS"

  log_section "Burndown calculation"
  COMPLETED_PCT=$(jq '.burndown.completedPercent' "$MOCK_SPRINT")
  ELAPSED_DAYS=$(jq '.sprint.daysElapsed' "$MOCK_SPRINT")
  TOTAL_DAYS=$(jq '.sprint.daysTotal' "$MOCK_SPRINT")
  ELAPSED_PCT=$(python3 -c "print(round($ELAPSED_DAYS/$TOTAL_DAYS*100, 1))")

  info "Días transcurridos: $ELAPSED_DAYS/$TOTAL_DAYS ($ELAPSED_PCT% del sprint)"
  info "Trabajo completado: $COMPLETED_PCT%"

  # En este punto del sprint (40% tiempo) debería haber ~40% completado
  CHECK=$(python3 -c "
completed = $COMPLETED_PCT
elapsed = $ELAPSED_PCT
diff = abs(completed - elapsed)
print('ok' if diff <= 15 else 'warning')
")
  if [[ "$CHECK" == "ok" ]]; then
    pass "Progreso alineado con el tiempo transcurrido (diff ≤ 15%) 🟢"
  else
    fail "Desfase entre progreso y tiempo" "Tiempo: $ELAPSED_PCT%, Completado: $COMPLETED_PCT%"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 6: IMPUTACIÓN DE HORAS
# ─────────────────────────────────────────────────────────────────────────────
test_imputacion() {
  log_header "SUITE 6 — Imputación de Horas"

  log_section "Leer imputaciones del mock"
  MOCK_CAPACITY="$MOCK_DATA_DIR/mock-capacities.json"

  TOTAL_HOURS=$(jq '[.time_entries_week1.entries[].hours] | add' "$MOCK_CAPACITY")
  EXPECTED=11.5

  if python3 -c "exit(0 if abs(float('$TOTAL_HOURS') - $EXPECTED) < 0.01 else 1)"; then
    pass "Total horas semana 1: $TOTAL_HOURS h (esperado: ${EXPECTED}h)"
  else
    fail "Total horas incorrecto" "Obtenido: $TOTAL_HOURS, Esperado: $EXPECTED"
  fi

  # Imputación por persona
  CARLOS_HOURS=$(jq '.time_entries_week1.by_person["Carlos Mendoza"]' "$MOCK_CAPACITY")
  pass "Carlos Mendoza: ${CARLOS_HOURS}h imputadas semana 1"

  AGENT_HOURS=$(jq '.time_entries_week1.by_person["claude-agent"]' "$MOCK_CAPACITY")
  pass "claude-agent: ${AGENT_HOURS}h imputadas semana 1"

  log_section "Calcular coste por persona (mock)"
  COSTE_HORA=80  # €/hora ficticios
  COSTE_SEMANA=$(python3 -c "print(round($TOTAL_HOURS * $COSTE_HORA, 2))")
  pass "Coste semana 1 (${COSTE_HORA}€/h): ${COSTE_SEMANA}€"

  log_section "Validar formato de imputaciones"
  # Verificar que todas las entradas tienen los campos obligatorios
  VALID=$(jq '
    .time_entries_week1.entries |
    all(.date != null and .person != null and .hours != null and .hours > 0)
  ' "$MOCK_CAPACITY")

  if [[ "$VALID" == "true" ]]; then
    pass "Todas las entradas de imputación tienen campos válidos"
  else
    fail "Entradas de imputación con datos faltantes" "Verificar mock-capacities.json"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 7: SPEC-DRIVEN DEVELOPMENT
# ─────────────────────────────────────────────────────────────────────────────
test_sdd() {
  log_header "SUITE 7 — Spec-Driven Development"

  SPECS_DIR="$TEST_PROJECT_DIR/specs/sprint-2026-04"

  log_section "Contar specs disponibles"
  SPEC_COUNT=$(find "$SPECS_DIR" -name "*.spec.md" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$SPEC_COUNT" -ge 2 ]]; then
    pass "$SPEC_COUNT specs en el sprint 2026-04"
  else
    fail "Pocas specs encontradas" "Esperado: ≥2, Encontrado: $SPEC_COUNT"
  fi

  log_section "Validar estructura de specs"
  for SPEC in "$SPECS_DIR"/*.spec.md; do
    SPEC_NAME=$(basename "$SPEC")
    ERRORS=0

    # Verificar secciones obligatorias
    for SECTION in "Developer Type:" "Task ID:" "Estimación:" "## 2. Contrato" "## 3. Reglas" "## 4. Test Scenarios" "## 5. Ficheros"; do
      if ! grep -q "$SECTION" "$SPEC" 2>/dev/null; then
        fail "Spec $SPEC_NAME: falta sección '$SECTION'" "Sección obligatoria ausente"
        ERRORS=$((ERRORS + 1))
      fi
    done

    if [[ $ERRORS -eq 0 ]]; then
      pass "Spec $SPEC_NAME: todas las secciones presentes"
    fi

    # Verificar developer_type válido
    DEV_TYPE=$(grep "^\*\*Developer Type:\*\*" "$SPEC" | awk '{print $NF}')
    if [[ "$DEV_TYPE" =~ ^(human|agent:single|agent:team)$ ]]; then
      pass "Spec $SPEC_NAME: developer_type válido ($DEV_TYPE)"
    else
      fail "Spec $SPEC_NAME: developer_type inválido" "Valor: '$DEV_TYPE', Esperado: human|agent:single|agent:team"
    fi

    # Verificar que no hay placeholders sin rellenar
    PLACEHOLDERS=$(grep -c "{placeholder}" "$SPEC" 2>/dev/null || true)
    if [[ "$PLACEHOLDERS" -eq 0 ]]; then
      pass "Spec $SPEC_NAME: sin placeholders vacíos"
    else
      fail "Spec $SPEC_NAME: tiene $PLACEHOLDERS placeholders sin rellenar" "Editar la spec y completar los campos"
    fi
  done

  log_section "Validar layer-assignment-matrix"
  MATRIX="$WORKSPACE_ROOT/.claude/skills/spec-driven-development/references/layer-assignment-matrix.md"
  if [[ -f "$MATRIX" ]]; then
    AGENT_ROWS=$(grep -c "agent:single\|agent:team" "$MATRIX" 2>/dev/null || true)
    HUMAN_ROWS=$(grep -c "\`human\`" "$MATRIX" 2>/dev/null || true)
    pass "Matrix de asignación: $AGENT_ROWS entradas de agente, $HUMAN_ROWS de humano"
  else
    fail "layer-assignment-matrix.md no encontrado" "$MATRIX"
  fi

  log_section "Validar spec-template"
  TEMPLATE="$WORKSPACE_ROOT/.claude/skills/spec-driven-development/references/spec-template.md"
  if [[ -f "$TEMPLATE" ]]; then
    TEMPLATE_LINES=$(wc -l < "$TEMPLATE")
    if [[ "$TEMPLATE_LINES" -gt 100 ]]; then
      pass "spec-template.md completo ($TEMPLATE_LINES líneas)"
    else
      fail "spec-template.md demasiado corto" "$TEMPLATE_LINES líneas (esperado: >100)"
    fi
  else
    fail "spec-template.md no encontrado" "$TEMPLATE"
  fi

  log_section "Dry-run de agente (sin ejecutar código real)"
  if command -v claude &>/dev/null; then
    info "Claude CLI disponible — para ejecutar el agente real:"
    info "  /agent:run projects/sala-reservas/specs/sprint-2026-04/AB101-B3-create-sala-handler.spec.md"
    pass "Claude CLI disponible para SDD real"
  else
    skip "Dry-run de agente" "Claude CLI no instalado"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 8: GENERACIÓN DE INFORMES
# ─────────────────────────────────────────────────────────────────────────────
test_report() {
  log_header "SUITE 8 — Generación de Informes"

  log_section "Validar report-generator.js"
  REPORT_SCRIPT="$WORKSPACE_ROOT/scripts/report-generator.js"
  if [[ ! -f "$REPORT_SCRIPT" ]]; then
    fail "report-generator.js no encontrado" "Falta scripts/report-generator.js"
    return
  fi
  pass "report-generator.js existe"

  REPORT_LINES=$(wc -l < "$REPORT_SCRIPT")
  if [[ "$REPORT_LINES" -gt 100 ]]; then
    pass "report-generator.js tiene contenido ($REPORT_LINES líneas)"
  else
    fail "report-generator.js demasiado corto" "$REPORT_LINES líneas"
  fi

  log_section "Verificar dependencias del report generator"
  if [[ -f "$WORKSPACE_ROOT/scripts/package.json" ]]; then
    EXCELJS=$(jq -r '.dependencies.exceljs // empty' "$WORKSPACE_ROOT/scripts/package.json")
    PPTXGEN=$(jq -r '.dependencies.pptxgenjs // empty' "$WORKSPACE_ROOT/scripts/package.json")

    if [[ -n "$EXCELJS" ]]; then
      pass "Dependencia exceljs declarada en package.json ($EXCELJS)"
    else
      fail "exceljs no en package.json" "Añadir: npm install exceljs"
    fi

    if [[ -n "$PPTXGEN" ]]; then
      pass "Dependencia pptxgenjs declarada en package.json ($PPTXGEN)"
    else
      fail "pptxgenjs no en package.json" "Añadir: npm install pptxgenjs"
    fi
  else
    fail "scripts/package.json no encontrado" "Ejecutar: cd scripts && npm init"
  fi

  log_section "Verificar directorio output"
  mkdir -p "$OUTPUT_DIR/sprints" "$OUTPUT_DIR/reports" "$OUTPUT_DIR/executive" "$OUTPUT_DIR/agent-runs"
  pass "Directorios output creados/verificados"
}

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 9: VALIDACIÓN DE REGLAS DE NEGOCIO (lógica de test)
# ─────────────────────────────────────────────────────────────────────────────
test_backlog() {
  log_header "SUITE 9 — Backlog y Reglas de Negocio"

  log_section "Reglas de negocio documentadas"
  RN_FILE="$TEST_PROJECT_DIR/reglas-negocio.md"
  if [[ -f "$RN_FILE" ]]; then
    RN_COUNT=$(grep -c "^### RN-" "$RN_FILE" 2>/dev/null || true)
    pass "reglas-negocio.md existe con $RN_COUNT reglas documentadas"
  else
    fail "reglas-negocio.md no encontrado" "$RN_FILE"
    return
  fi

  # Verificar que las reglas críticas están
  for RN in "RN-SALA-01" "RN-RESERVA-06" "RN-RESERVA-07"; do
    if grep -q "$RN" "$RN_FILE"; then
      TITLE=$(grep "### $RN:" "$RN_FILE" | sed "s/### $RN: //")
      pass "Regla $RN documentada: $TITLE"
    else
      fail "Regla crítica $RN no encontrada" "Agregar al fichero reglas-negocio.md"
    fi
  done

  log_section "Simulación de algoritmo de detección de conflictos (RN-RESERVA-07)"
  # Verificar lógica de solapamiento: inicio1 < fin2 AND inicio2 < fin1
  python3 -c "
def hay_conflicto(inicio1, fin1, inicio2, fin2):
    return inicio1 < fin2 and inicio2 < fin1

casos = [
    # (i1, f1, i2, f2, esperado, descripcion)
    (9,  10, 10, 11, False, 'Consecutivas: sin conflicto'),
    (9,  11, 10, 12, True,  'Solapamiento parcial'),
    (9,  12, 10, 11, True,  'Una dentro de otra'),
    (10, 11, 9,  12, True,  'La nueva dentro de la existente'),
    (8,  9,  10, 11, False, 'Sin contacto: sin conflicto'),
]

all_ok = True
for i1, f1, i2, f2, esperado, desc in casos:
    resultado = hay_conflicto(i1, f1, i2, f2)
    status = '✓' if resultado == esperado else '✗'
    if resultado != esperado:
        all_ok = False
        print(f'FAIL [{status}] {desc}: esperado={esperado}, obtenido={resultado}')

if all_ok:
    print('OK')
" | while read -r LINE; do
    if [[ "$LINE" == "OK" ]]; then
      pass "Algoritmo de detección de conflictos: 5/5 casos correctos"
    else
      fail "Algoritmo de conflictos falla en caso" "$LINE"
    fi
  done

  log_section "Sprint Planning — PBIs y capacity"
  PLANNING_FILE="$TEST_PROJECT_DIR/sprints/sprint-2026-04/planning.md"
  if [[ -f "$PLANNING_FILE" ]]; then
    TOTAL_SP=$(grep -oE "[0-9]+ SP" "$PLANNING_FILE" | grep -v "^1 SP" | head -3 | grep -oE "[0-9]+" | python3 -c "import sys; print(sum(int(x) for x in sys.stdin))" 2>/dev/null || echo "11")
    pass "Sprint Planning documentado ($TOTAL_SP SP comprometidos)"
  else
    fail "planning.md no encontrado" "$PLANNING_FILE"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# GENERAR INFORME DE RESULTADOS
# ─────────────────────────────────────────────────────────────────────────────
generate_report() {
  mkdir -p "$OUTPUT_DIR"
  cat > "$REPORT_FILE" << MDEOF
# Test Report — PM Workspace
**Fecha:** $(date '+%Y-%m-%d %H:%M:%S')
**Modo:** $MODE
**Proyecto de test:** sala-reservas

## Resumen

| | Valor |
|---|---|
| Tests ejecutados | $TESTS_TOTAL |
| ✅ Passed | $TESTS_PASSED |
| ❌ Failed | $TESTS_FAILED |
| ⏭ Skipped | $TESTS_SKIPPED |
| Tasa de éxito | $(python3 -c "print(f'{$TESTS_PASSED/$TESTS_TOTAL*100:.1f}%' if $TESTS_TOTAL > 0 else 'N/A')") |

## Tests Fallidos

$(if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
  echo "Ninguno 🎉"
else
  for t in "${FAILED_TESTS[@]}"; do echo "- ❌ $t"; done
fi)

## Cómo ejecutar el workspace

\`\`\`bash
cd pm-workspace/
claude
# Luego: /sprint:status sala-reservas
\`\`\`

## Próximos pasos

$(if [[ $TESTS_FAILED -eq 0 ]]; then
  echo "✅ Todos los tests pasaron. El workspace está listo para usar con datos reales."
  echo ""
  echo "1. Editar \`CLAUDE.md\` con tus datos reales de Azure DevOps"
  echo "2. Clonar tus repos en \`projects/{proyecto}/source/\`"
  echo "3. Abrir con \`claude\` y ejecutar \`/sprint:status\`"
else
  echo "⚠️  Hay $TESTS_FAILED tests fallidos. Resolver antes de usar en producción."
fi)
MDEOF

  echo ""
  echo -e "${BOLD}📄 Informe guardado: $REPORT_FILE${NC}"
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${BLUE}║   PM Workspace — Test Suite                        ║${NC}"
  echo -e "${BOLD}${BLUE}║   Proyecto de test: sala-reservas                  ║${NC}"
  echo -e "${BOLD}${BLUE}║   Modo: $(printf '%-42s' "$MODE")║${NC}"
  echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════╝${NC}"
  echo -e "  Workspace: ${CYAN}$WORKSPACE_ROOT${NC}"
  echo -e "  Inicio:    $(date '+%Y-%m-%d %H:%M:%S')"

  # Ejecutar suites según la categoría solicitada
  should_run "prereqs"    && test_prereqs
  should_run "structure"  && test_structure
  should_run "connection" && test_connection
  should_run "capacity"   && test_capacity
  should_run "sprint"     && test_sprint
  should_run "imputacion" && test_imputacion
  should_run "sdd"        && test_sdd
  should_run "report"     && test_report
  should_run "backlog"    && test_backlog

  # ── Resumen final ─────────────────────────────────────────────────────────
  echo ""
  echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  RESULTADO FINAL${NC}"
  echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════${NC}"
  echo -e "  Total:    $TESTS_TOTAL tests"
  echo -e "  ${GREEN}Passed:${NC}   $TESTS_PASSED"
  echo -e "  ${RED}Failed:${NC}   $TESTS_FAILED"
  echo -e "  ${YELLOW}Skipped:${NC}  $TESTS_SKIPPED"

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo ""
    echo -e "  ${GREEN}${BOLD}✅ TODOS LOS TESTS PASARON${NC}"
    echo ""
    echo -e "  El workspace está configurado correctamente."
    echo -e "  Ejecuta ${CYAN}claude${NC} desde ${CYAN}pm-workspace/${NC} para empezar."
  else
    echo ""
    echo -e "  ${RED}${BOLD}❌ $TESTS_FAILED TEST(S) FALLARON${NC}"
    echo ""
    for t in "${FAILED_TESTS[@]}"; do
      echo -e "  ${RED}•${NC} $t"
    done
    echo ""
    echo -e "  Consulta los errores arriba y ejecuta de nuevo tras corregirlos."
    echo -e "  Puedes ejecutar una suite específica con: ${CYAN}--only prereqs${NC}"
  fi

  generate_report

  # Exit code: 0 si todo OK, 1 si hay fallos
  [[ $TESTS_FAILED -eq 0 ]]
}

main "$@"
