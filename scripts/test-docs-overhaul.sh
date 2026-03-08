#!/bin/bash
# test-docs-overhaul.sh — Tests para Documentation Overhaul (Savia-led)
set -euo pipefail
PASS=0; FAIL=0; TOTAL=0
check() { TOTAL=$((TOTAL+1)); if bash -c "$2" 2>/dev/null; then PASS=$((PASS+1)); echo "✅ $1"; else FAIL=$((FAIL+1)); echo "❌ $1"; fi; }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Tests: Documentation Overhaul"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# === Sección 1: README ===
echo -e "\n📋 Sección 1: README"
check "README.md existe" "test -f README.md"
check "README.en.md existe" "test -f README.en.md"
check "README tiene sección roles" "grep -q '¿Quién eres?' README.md"
check "README tiene flujo de datos" "grep -q 'fluye la información' README.md"
check "README tiene estructura" "grep -q 'Dónde vive todo' README.md"
check "README.en tiene roles" "grep -q 'Who are you' README.en.md"
check "README.en tiene data flow" "grep -q 'information flows' README.en.md"
check "README ≤150 líneas" "test $(wc -l < README.md) -le 150"
check "README.en ≤150 líneas" "test $(wc -l < README.en.md) -le 150"

# === Sección 2: Quick-starts ES ===
echo -e "\n📋 Sección 2: Quick-starts ES"
for role in pm tech-lead developer qa po ceo; do
    F="docs/quick-starts/quick-start-$role.md"
    check "QS-ES $role existe" "test -f $F"
    check "QS-ES $role tiene Primeros 10" "grep -q 'Primeros 10' $F"
    check "QS-ES $role tiene Cómo hablarme" "grep -q 'Cómo hablarme' $F"
    check "QS-ES $role tiene ficheros" "grep -q 'Dónde están tus ficheros' $F"
    check "QS-ES $role tiene conexión" "grep -q 'Cómo se conecta' $F"
    check "QS-ES $role ≤150 líneas" "test $(wc -l < $F) -le 150"
done

# === Sección 3: Quick-starts EN ===
echo -e "\n📋 Sección 3: Quick-starts EN"
for role in pm tech-lead developer qa po ceo; do
    F="docs/quick-starts_en/quick-start-$role.md"
    check "QS-EN $role existe" "test -f $F"
    check "QS-EN $role tiene First 10" "grep -q 'First 10' $F"
    check "QS-EN $role tiene How to talk" "grep -q 'How to talk' $F"
    check "QS-EN $role ≤150 líneas" "test $(wc -l < $F) -le 150"
done

# === Sección 4: Data flow guide ===
echo -e "\n📋 Sección 4: Data Flow Guide"
check "data-flow-guide-es.md existe" "test -f docs/data-flow-guide-es.md"
check "data-flow-guide-en.md existe" "test -f docs/data-flow-guide-en.md"
check "DFG-ES tiene 4 flujos" "test $(grep -c '^## Flujo' docs/data-flow-guide-es.md) -ge 4"
check "DFG-EN tiene 4 flows" "test $(grep -c '^## Flow' docs/data-flow-guide-en.md) -ge 4"
check "DFG-ES tiene dependencias ocultas" "grep -q 'Dependencias ocultas' docs/data-flow-guide-es.md"
check "DFG-EN tiene hidden dependencies" "grep -q 'Hidden dependencies' docs/data-flow-guide-en.md"
check "DFG-ES ≤150 líneas" "test $(wc -l < docs/data-flow-guide-es.md) -le 150"
check "DFG-EN ≤150 líneas" "test $(wc -l < docs/data-flow-guide-en.md) -le 150"

# === Sección 5: 01-introduccion ===
echo -e "\n📋 Sección 5: 01-introduccion revisada"
check "01-intro ES existe" "test -f docs/readme/01-introduccion.md"
check "01-intro EN existe" "test -f docs/readme_en/01-introduction.md"
check "01-intro ES tiene routing por rol" "grep -q 'quick-start' docs/readme/01-introduccion.md"
check "01-intro EN tiene routing por rol" "grep -q 'quick-start' docs/readme_en/01-introduction.md"
check "01-intro ES ≤100 líneas" "test $(wc -l < docs/readme/01-introduccion.md) -le 100"
check "01-intro EN ≤100 líneas" "test $(wc -l < docs/readme_en/01-introduction.md) -le 100"

# === Sección 6: AI Augmentation ===
echo -e "\n📋 Sección 6: AI Augmentation Opportunities"
check "AI-aug ES existe" "test -f docs/ai-augmentation-opportunities-es.md"
check "AI-aug EN existe" "test -f docs/ai-augmentation-opportunities-en.md"
check "AI-aug ES tiene 3+ gaps" "test $(grep -c '### ' docs/ai-augmentation-opportunities-es.md) -ge 3"
check "AI-aug EN tiene 3+ gaps" "test $(grep -c '### ' docs/ai-augmentation-opportunities-en.md) -ge 3"
check "AI-aug ES ref Donut" "grep -q 'Donut' docs/ai-augmentation-opportunities-es.md"
check "AI-aug EN ref Donut" "grep -q 'Donut' docs/ai-augmentation-opportunities-en.md"
check "AI-aug ES ≤150 líneas" "test $(wc -l < docs/ai-augmentation-opportunities-es.md) -le 150"
check "AI-aug EN ≤150 líneas" "test $(wc -l < docs/ai-augmentation-opportunities-en.md) -le 150"

# === Sección 7: Savia voice ===
echo -e "\n📋 Sección 7: Savia voice check"
check "README.md voz Savia" "grep -q 'Soy Savia' README.md"
check "README.en voz Savia" "grep -q \"I'm Savia\" README.en.md"
check "01-intro ES voz Savia" "grep -q 'Soy Savia' docs/readme/01-introduccion.md"
check "01-intro EN voz Savia" "grep -q \"I'm Savia\" docs/readme_en/01-introduction.md"
check "DFG-ES voz Savia" "grep -q 'Soy Savia' docs/data-flow-guide-es.md"
check "DFG-EN voz Savia" "grep -q \"I'm Savia\" docs/data-flow-guide-en.md"

# === Sección 8: Consistencia bilingüe ===
echo -e "\n📋 Sección 8: Consistencia bilingüe"
ES_QS=$(ls docs/quick-starts/quick-start-*.md 2>/dev/null | wc -l)
EN_QS=$(ls docs/quick-starts_en/quick-start-*.md 2>/dev/null | wc -l)
check "Mismo nº quick-starts ES/EN ($ES_QS/$EN_QS)" "test $ES_QS -eq $EN_QS"

# === Resumen ===
echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resultado: $PASS/$TOTAL passed | $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[[ $FAIL -eq 0 ]] && echo "🎉 Todos los tests pasaron" || echo "⚠️  $FAIL tests fallaron"
exit $FAIL
