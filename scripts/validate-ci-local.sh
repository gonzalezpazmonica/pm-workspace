#!/usr/bin/env bash
# ── validate-ci-local.sh ─────────────────────────────────────────────────
# Réplica LOCAL de los checks del CI de GitHub Actions.
# Ejecutar ANTES de cada commit/push para detectar errores a tiempo.
#
# Uso:
#   bash scripts/validate-ci-local.sh          # todos los checks
#   bash scripts/validate-ci-local.sh --quick  # solo file sizes + frontmatter
# ──────────────────────────────────────────────────────────────────────────

set -uo pipefail

PASS=0
FAIL=0
WARN=0
ERRORS=""
QUICK_MODE=false

[ "${1:-}" = "--quick" ] && QUICK_MODE=true

pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }
warn() { ((WARN++)); echo "  ⚠️  $1"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🔍 Validación CI Local — pm-workspace"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ── 0. Branch check (NUNCA en main) ──────────────────────────────────
echo "📋 0. Branch actual"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
  fail "Estás en rama '$CURRENT_BRANCH' — cambia a feature branch antes de commit"
else
  pass "Rama: $CURRENT_BRANCH"
fi
echo ""

# ── 1. Validate file sizes (≤150 lines) ──────────────────────────────
echo "📋 1. File sizes (≤150 líneas)"

check_size() {
  local pattern="$1"
  local label="$2"
  local is_error="${3:-true}"
  for file in $pattern; do
    [ -f "$file" ] || continue
    lines=$(wc -l < "$file")
    if [ "$lines" -gt 150 ]; then
      if [ "$is_error" = "true" ]; then
        fail "$file ($lines líneas)"
      else
        warn "$file ($lines líneas)"
      fi
    fi
  done
}

check_size ".claude/commands/*.md" "commands" "true"
check_size ".claude/skills/*/SKILL.md" "skills" "true"
check_size ".claude/agents/*.md" "agents" "true"
check_size ".claude/rules/domain/*.md" "domain rules" "false"

# Count checked files
CMD_COUNT=$(ls -1 .claude/commands/*.md 2>/dev/null | wc -l)
SKILL_COUNT=$(ls -1 .claude/skills/*/SKILL.md 2>/dev/null | wc -l)
AGENT_COUNT=$(ls -1 .claude/agents/*.md 2>/dev/null | wc -l)
CHECKED=$((CMD_COUNT + SKILL_COUNT + AGENT_COUNT))
echo "  📊 $CHECKED ficheros verificados (${CMD_COUNT} commands, ${SKILL_COUNT} skills, ${AGENT_COUNT} agents)"
echo ""

# ── 2. Command frontmatter ────────────────────────────────────────────
echo "📋 2. Command frontmatter"

FM_FAIL=0
FM_LEGACY=0
for file in .claude/commands/*.md; do
  [ -f "$file" ] || continue
  if head -1 "$file" | grep -q "^---$"; then
    if ! grep -q "^name:" "$file"; then
      fail "$file: falta campo 'name'"
      FM_FAIL=$((FM_FAIL + 1))
    fi
    if ! grep -q "^description:" "$file"; then
      fail "$file: falta campo 'description'"
      FM_FAIL=$((FM_FAIL + 1))
    fi
  else
    FM_LEGACY=$((FM_LEGACY + 1))
  fi
done

if [ "$FM_FAIL" -eq 0 ]; then
  pass "Frontmatter válido ($FM_LEGACY legacy sin frontmatter)"
fi
echo ""

# ── 3. settings.json valid ────────────────────────────────────────────
echo "📋 3. settings.json"

if [ -f ".claude/settings.json" ]; then
  if python3 -c "import json; json.load(open('.claude/settings.json'))" 2>/dev/null; then
    pass "settings.json es JSON válido"
  else
    fail "settings.json tiene JSON inválido"
  fi
else
  warn "settings.json no encontrado"
fi
echo ""

# ── 4. CHANGELOG integrity ──────────────────────────────────────────
echo "📋 4. CHANGELOG.md integrity"

if [ -f "CHANGELOG.md" ]; then
  CL_FAIL=0

  # 4a. No merge conflict markers
  if grep -qE '^(<<<<<<<|=======|>>>>>>>)' CHANGELOG.md; then
    fail "CHANGELOG.md contiene marcadores de conflicto git (<<<<<<<, =======, >>>>>>>)"
    CL_FAIL=$((CL_FAIL + 1))
  fi

  # 4b. Versions in descending order (no out-of-order entries)
  VERSIONS=$(grep -oP '(?<=^## \[)[0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md)
  PREV=""
  LINE_NUM=0
  while IFS= read -r ver; do
    LINE_NUM=$((LINE_NUM + 1))
    if [ -n "$PREV" ]; then
      # Compare semver: PREV must be >= ver (descending)
      PREV_MAJOR=$(echo "$PREV" | cut -d. -f1)
      PREV_MINOR=$(echo "$PREV" | cut -d. -f2)
      PREV_PATCH=$(echo "$PREV" | cut -d. -f3)
      CUR_MAJOR=$(echo "$ver" | cut -d. -f1)
      CUR_MINOR=$(echo "$ver" | cut -d. -f2)
      CUR_PATCH=$(echo "$ver" | cut -d. -f3)
      OUT_OF_ORDER=false
      if [ "$CUR_MAJOR" -gt "$PREV_MAJOR" ]; then
        OUT_OF_ORDER=true
      elif [ "$CUR_MAJOR" -eq "$PREV_MAJOR" ] && [ "$CUR_MINOR" -gt "$PREV_MINOR" ]; then
        OUT_OF_ORDER=true
      elif [ "$CUR_MAJOR" -eq "$PREV_MAJOR" ] && [ "$CUR_MINOR" -eq "$PREV_MINOR" ] && [ "$CUR_PATCH" -gt "$PREV_PATCH" ]; then
        OUT_OF_ORDER=true
      fi
      if [ "$OUT_OF_ORDER" = true ]; then
        fail "CHANGELOG.md versiones fuera de orden: [$PREV] seguida de [$ver] (entrada #$LINE_NUM)"
        CL_FAIL=$((CL_FAIL + 1))
        break
      fi
    fi
    PREV="$ver"
  done <<< "$VERSIONS"

  # 4c. No consecutive gaps >1 in minor version (within same major)
  PREV=""
  while IFS= read -r ver; do
    if [ -n "$PREV" ]; then
      PREV_MAJOR=$(echo "$PREV" | cut -d. -f1)
      PREV_MINOR=$(echo "$PREV" | cut -d. -f2)
      CUR_MAJOR=$(echo "$ver" | cut -d. -f1)
      CUR_MINOR=$(echo "$ver" | cut -d. -f2)
      if [ "$PREV_MAJOR" -eq "$CUR_MAJOR" ]; then
        GAP=$((PREV_MINOR - CUR_MINOR))
        if [ "$GAP" -gt 2 ]; then
          warn "CHANGELOG.md posible gap de versiones: [$PREV] → [$ver] (salto de $GAP minor versions)"
        fi
      fi
    fi
    PREV="$ver"
  done <<< "$VERSIONS"

  # 4d. No duplicate version entries
  DUP_VERSIONS=$(grep -oP '(?<=^## \[)[0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md | sort | uniq -d)
  if [ -n "$DUP_VERSIONS" ]; then
    fail "CHANGELOG.md versiones duplicadas: $DUP_VERSIONS"
    CL_FAIL=$((CL_FAIL + 1))
  fi

  # 4e. Header present (Keep a Changelog reference)
  if ! head -6 CHANGELOG.md | grep -qi "keep a changelog\|changelog\|notable changes"; then
    warn "CHANGELOG.md: cabecera estándar no detectada en las primeras 6 líneas"
  fi

  # 4f. First version header has correct format
  FIRST_VER_LINE=$(grep -n '## \[' CHANGELOG.md | head -1)
  if [ -n "$FIRST_VER_LINE" ]; then
    if ! echo "$FIRST_VER_LINE" | grep -qP '## \[\d+\.\d+\.\d+\] — \d{4}-\d{2}-\d{2}'; then
      warn "CHANGELOG.md: primera entrada no sigue formato '## [x.y.z] — YYYY-MM-DD'"
    fi
  fi

  VER_COUNT=$(echo "$VERSIONS" | wc -l)
  if [ "$CL_FAIL" -eq 0 ]; then
    pass "CHANGELOG.md íntegro ($VER_COUNT versiones, orden correcto, sin duplicados, sin conflictos)"
  fi
else
  fail "CHANGELOG.md no encontrado"
fi
echo ""

if [ "$QUICK_MODE" = true ]; then
  echo "  (modo --quick: saltando checks extendidos)"
  echo ""
else
  # ── 5. Required open source files ────────────────────────────────────
  echo "📋 5. Ficheros open source requeridos"

  REQUIRED_FILES=(
    "LICENSE"
    "README.md"
    "CHANGELOG.md"
    "CONTRIBUTING.md"
    "CODE_OF_CONDUCT.md"
    "SECURITY.md"
    "docs/ROADMAP.md"
    ".github/pull_request_template.md"
    ".github/ISSUE_TEMPLATE/bug_report.yml"
    ".github/ISSUE_TEMPLATE/feature_request.yml"
  )
  for f in "${REQUIRED_FILES[@]}"; do
    if [ -f "$f" ]; then
      pass "$f"
    else
      fail "MISSING: $f"
    fi
  done
  echo ""

  # ── 6. JSON mock files ──────────────────────────────────────────────
  echo "📋 6. JSON mock files"

  JSON_OK=0
  JSON_FAIL=0
  for f in projects/sala-reservas/test-data/*.json; do
    [ -f "$f" ] || continue
    if jq empty "$f" 2>/dev/null; then
      JSON_OK=$((JSON_OK + 1))
    else
      fail "JSON inválido: $f"
      JSON_FAIL=$((JSON_FAIL + 1))
    fi
  done
  if [ "$JSON_FAIL" -eq 0 ]; then
    pass "$JSON_OK ficheros JSON válidos"
  fi
  echo ""

  # ── 7. Sensitive data scan ──────────────────────────────────────────
  echo "📋 7. Scan de datos sensibles"

  SECRETS_FOUND=false
  if grep -rn --include="*.md" --include="*.sh" --include="*.json" --include="*.yml" \
    -E '[a-z0-9]{52}' \
    --exclude-dir=".git" --exclude-dir="node_modules" \
    . 2>/dev/null | grep -v "mock" | grep -v "example" | grep -v "placeholder" | grep -v "test-data" > /dev/null 2>&1; then
    warn "Posible patrón de secreto detectado — revisar manualmente"
    SECRETS_FOUND=true
  fi
  if [ "$SECRETS_FOUND" = false ]; then
    pass "Sin patrones de secretos detectados"
  fi
  echo ""
fi

# ── Results ───────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
echo "═══════════════════════════════════════════════════════════════"
echo "  📊 Results: $PASS/$TOTAL passed, $WARN warnings"
echo "═══════════════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "  ❌ BLOQUEADO — corregir antes de push:"
  echo -e "$ERRORS"
  echo "  Ejecutar de nuevo tras corregir: bash scripts/validate-ci-local.sh"
  exit 1
fi
echo ""
echo "  ✅ Validación OK — safe to push"
exit 0
