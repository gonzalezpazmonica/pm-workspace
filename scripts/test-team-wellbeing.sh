#!/bin/bash
set -e

PASS=0
FAIL=0

echo "════════════════════════════════════════════════════════════════"
echo "  TEST: Team Wellbeing & Sustainability v0.67.0"
echo "════════════════════════════════════════════════════════════════"

# Test 1: Archivos existen
echo ""
echo "Test 1: Ficheros existen"
for cmd in burnout-radar workload-balance sustainable-pace team-sentiment; do
  if [ -f ".claude/commands/$cmd.md" ]; then
    echo "  ✅ .claude/commands/$cmd.md"
    ((PASS++))
  else
    echo "  ❌ .claude/commands/$cmd.md NO ENCONTRADO"
    ((FAIL++))
  fi
done

# Test 2: Frontmatter correcto
echo ""
echo "Test 2: Frontmatter válido"
for cmd in burnout-radar workload-balance sustainable-pace team-sentiment; do
  file=".claude/commands/$cmd.md"
  errors=0
  grep -q "^name: $cmd" "$file" || ((errors++))
  grep -q "^description:" "$file" || ((errors++))
  grep -q "^developer_type: all" "$file" || ((errors++))
  grep -q "^agent: task" "$file" || ((errors++))
  grep -q "^context_cost: medium" "$file" || ((errors++))
  
  if [ $errors -eq 0 ]; then
    echo "  ✅ $cmd frontmatter OK"
    ((PASS++))
  else
    echo "  ❌ $cmd frontmatter incompleto"
    ((FAIL++))
  fi
done

# Test 3: Líneas ≤ 150
echo ""
echo "Test 3: Ficheros ≤ 150 líneas"
for cmd in burnout-radar workload-balance sustainable-pace team-sentiment; do
  file=".claude/commands/$cmd.md"
  lines=$(wc -l < "$file")
  if [ "$lines" -le 150 ]; then
    echo "  ✅ $cmd: $lines líneas"
    ((PASS++))
  else
    echo "  ❌ $cmd: $lines líneas (máx 150)"
    ((FAIL++))
  fi
done

# Test 4: Conceptos clave presentes
echo ""
echo "Test 4: Conceptos clave"
if grep -qi "burnout\|SPACE\|wellbeing" .claude/commands/burnout-radar.md; then
  echo "  ✅ burnout-radar: conceptos OK"
  ((PASS++))
else
  echo "  ❌ burnout-radar: falta concepto"
  ((FAIL++))
fi

if grep -qi "balance\|carga\|especialidades\|WIP" .claude/commands/workload-balance.md; then
  echo "  ✅ workload-balance: conceptos OK"
  ((PASS++))
else
  echo "  ❌ workload-balance: falta concepto"
  ((FAIL++))
fi

if grep -qi "sostenible\|velocity\|quality" .claude/commands/sustainable-pace.md; then
  echo "  ✅ sustainable-pace: conceptos OK"
  ((PASS++))
else
  echo "  ❌ sustainable-pace: falta concepto"
  ((FAIL++))
fi

if grep -qi "sentimiento\|pulse\|tendencias" .claude/commands/team-sentiment.md; then
  echo "  ✅ team-sentiment: conceptos OK"
  ((PASS++))
else
  echo "  ❌ team-sentiment: falta concepto"
  ((FAIL++))
fi

# Test 5: Meta files actualizados (237)
echo ""
echo "Test 5: Meta files actualizados"

if grep -q "commands/ (237)" CLAUDE.md; then
  echo "  ✅ CLAUDE.md: commands/ (237)"
  ((PASS++))
else
  echo "  ❌ CLAUDE.md: NO actualizado"
  ((FAIL++))
fi

if grep -q "237 comandos" README.md; then
  echo "  ✅ README.md: 237 comandos"
  ((PASS++))
else
  echo "  ❌ README.md: NO actualizado"
  ((FAIL++))
fi

if grep -q "237 commands" README.en.md; then
  echo "  ✅ README.en.md: 237 commands"
  ((PASS++))
else
  echo "  ❌ README.en.md: NO actualizado"
  ((FAIL++))
fi

if grep -q "v0.67.0" CHANGELOG.md; then
  echo "  ✅ CHANGELOG.md: v0.67.0"
  ((PASS++))
else
  echo "  ❌ CHANGELOG.md: NO actualizado"
  ((FAIL++))
fi

# Test 6: Recuento total
echo ""
echo "Test 6: Recuento total de comandos"
cmd_count=$(find .claude/commands -name "*.md" -type f | wc -l)
echo "  Total comandos: $cmd_count"
if [ "$cmd_count" -eq 237 ]; then
  echo "  ✅ 237 comandos"
  ((PASS++))
else
  echo "  ❌ $cmd_count (esperado 237)"
  ((FAIL++))
fi

# Resumen
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  RESULTADOS"
echo "════════════════════════════════════════════════════════════════"
echo "  ✅ PASS: $PASS"
echo "  ❌ FAIL: $FAIL"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "  ✅ TODOS LOS TESTS PASARON"
  exit 0
else
  echo "  ❌ $FAIL TESTS FALLARON"
  exit 1
fi
