#!/bin/bash
# test-context-eng-improvements.sh — Tests para Context Engineering Improvements
set -euo pipefail
PASS=0; FAIL=0; TOTAL=0
check() { TOTAL=$((TOTAL+1)); if eval "$2" 2>/dev/null; then PASS=$((PASS+1)); echo "✅ $1"; else FAIL=$((FAIL+1)); echo "❌ $1"; fi; }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Tests: Context Engineering Improvements"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# === Sección 1: Prompt Structure (Mejora 5) ===
echo -e "\n📋 Sección 1: Prompt Structure Compliance"
check "prompt-structure.md existe" "test -f docs/rules/domain/prompt-structure.md"
check "prompt-structure tiene frontmatter" "head -1 docs/rules/domain/prompt-structure.md | grep -q '^---'"
check "prompt-structure cubre Reasoning Guidance" "grep -q 'Reasoning Guidance' docs/rules/domain/prompt-structure.md"
check "prompt-structure cubre Output Template" "grep -q 'Output Template' docs/rules/domain/prompt-structure.md"
check "prompt-structure referencia 10-layer model" "grep -q '10-layer' docs/rules/domain/prompt-structure.md"
check "prompt-structure ≤150 líneas" "test $(wc -l < docs/rules/domain/prompt-structure.md) -le 150"

# === Sección 2: Example Patterns (Mejora 1) ===
echo -e "\n📋 Sección 2: Example Patterns"
check "example-patterns.md existe" "test -f docs/rules/domain/example-patterns.md"
check "example-patterns tiene frontmatter" "head -1 docs/rules/domain/example-patterns.md | grep -q '^---'"
check "example-patterns define formato positivo/negativo" "grep -q '✅ Correcto' docs/rules/domain/example-patterns.md"
check "example-patterns ≤150 líneas" "test $(wc -l < docs/rules/domain/example-patterns.md) -le 150"

# Verificar examples en 5 commands piloto
for cmd in project-audit sprint-plan spec-generate debt-track risk-log; do
    check "$cmd tiene sección Ejemplos" "grep -q '## Ejemplos' .opencode/commands/$cmd.md"
    check "$cmd tiene ejemplo positivo ✅" "grep -q '✅ Correcto' .opencode/commands/$cmd.md"
    check "$cmd tiene ejemplo negativo ❌" "grep -q '❌ Incorrecto' .opencode/commands/$cmd.md"
    check "$cmd ≤150 líneas" "test $(wc -l < .opencode/commands/$cmd.md) -le 150"
done

# === Sección 3: /eval-output (Mejora 2) ===
echo -e "\n📋 Sección 3: /eval-output (G-Eval)"
check "eval-output.md existe" "test -f .opencode/commands/eval-output.md"
check "eval-output tiene frontmatter con model" "grep -q 'model: opus' .opencode/commands/eval-output.md"
check "eval-output tiene sección Razonamiento" "grep -q '## Razonamiento' .opencode/commands/eval-output.md"
check "eval-output tiene sección Ejemplos" "grep -q '## Ejemplos' .opencode/commands/eval-output.md"
check "eval-output tiene template de output" "grep -q 'Template de Output' .opencode/commands/eval-output.md"
check "eval-output tiene modo Arena" "grep -q '\-\-compare' .opencode/commands/eval-output.md"
check "eval-output ≤150 líneas" "test $(wc -l < .opencode/commands/eval-output.md) -le 150"
check "eval-criteria.md existe" "test -f docs/rules/domain/eval-criteria.md"
check "eval-criteria tiene 4 tipos" "test $(grep -c '### Tipo:' docs/rules/domain/eval-criteria.md) -ge 4"
check "eval-criteria tiene escala scoring" "grep -q 'Escala de scoring' docs/rules/domain/eval-criteria.md"
check "eval-criteria ≤150 líneas" "test $(wc -l < docs/rules/domain/eval-criteria.md) -le 150"

# === Sección 4: Entity Memory (Mejora 3) ===
echo -e "\n📋 Sección 4: Entity Memory"
check "entity-recall.md existe" "test -f .opencode/commands/entity-recall.md"
check "entity-recall tiene sección Ejemplos" "grep -q '## Ejemplos' .opencode/commands/entity-recall.md"
check "entity-recall referencia memory-store" "grep -q 'memory-store' .opencode/commands/entity-recall.md"
check "entity-recall ≤150 líneas" "test $(wc -l < .opencode/commands/entity-recall.md) -le 150"
check "memory-store.sh tiene cmd_entity" "grep -q 'cmd_entity' scripts/memory-store.sh"
check "memory-store.sh soporta entity subcommand" "grep -q 'entity)' scripts/memory-store.sh"
check "memory-store.sh ≤150 líneas" "test $(wc -l < scripts/memory-store.sh) -le 150"

# Test funcional: entity save + list + find
TMPDIR_TEST=$(mktemp -d)
mkdir -p "$TMPDIR_TEST/output"
export PROJECT_ROOT="$TMPDIR_TEST"
bash scripts/memory-store.sh save --type entity --title "auth-service" \
    --content "JWT auth service" --concepts "component" \
    --topic "auth-service" --project "alpha" > /dev/null 2>&1
check "Entity save crea JSONL" "test -f $TMPDIR_TEST/output/.memory-store.jsonl"
check "Entity type=entity guardado" "grep -q '\"type\":\"entity\"' $TMPDIR_TEST/output/.memory-store.jsonl"
check "Entity concepts guardado" "grep -q '\"component\"' $TMPDIR_TEST/output/.memory-store.jsonl"
ELIST=$(STORE_FILE="$TMPDIR_TEST/output/.memory-store.jsonl" bash scripts/memory-store.sh entity list 2>/dev/null || true)
check "Entity list funcional" "echo '$ELIST' | grep -q 'auth-service'"
EFIND=$(STORE_FILE="$TMPDIR_TEST/output/.memory-store.jsonl" bash scripts/memory-store.sh entity find auth-service 2>/dev/null || true)
check "Entity find funcional" "echo '$EFIND' | grep -q 'auth-service'"
rm -rf "$TMPDIR_TEST"
unset PROJECT_ROOT

# === Sección 5: Tool Discovery (Mejora 4) ===
echo -e "\n📋 Sección 5: Tool Discovery"
check "tool-discovery.md existe" "test -f docs/rules/domain/tool-discovery.md"
check "tool-discovery tiene frontmatter" "head -1 docs/rules/domain/tool-discovery.md | grep -q '^---'"
check "tool-discovery define ≥10 grupos" "test $(grep -c '\*\*sprint\*\*\|\*\*project\*\*\|\*\*backlog\*\*\|\*\*architecture\*\*\|\*\*debt\*\*\|\*\*security\*\*\|\*\*testing\*\*\|\*\*devops\*\*\|\*\*reporting\*\*\|\*\*risk\*\*' docs/rules/domain/tool-discovery.md) -ge 1"
check "tool-discovery ≤150 líneas" "test $(wc -l < docs/rules/domain/tool-discovery.md) -le 150"
check "capability-groups.md existe" "test -f docs/capability-groups.md"
check "capability-groups define 15 grupos" "test $(grep -c '^### [0-9]' docs/capability-groups.md) -ge 15"
check "capability-groups ≤150 líneas" "test $(wc -l < docs/capability-groups.md) -le 150"

# === Sección 6: Documentación ===
echo -e "\n📋 Sección 6: Documentación"
check "docs/context-engineering-es.md existe" "test -f docs/context-engineering-es.md"
check "docs/context-engineering-en.md existe" "test -f docs/context-engineering-en.md"
check "Doc ES referencia las 5 mejoras" "test $(grep -c 'Mejora' docs/context-engineering-es.md) -ge 5"
check "Doc EN referencia 5 improvements" "test $(grep -c 'Improvement' docs/context-engineering-en.md) -ge 5"

# === Sección 7: Cross-references ===
echo -e "\n📋 Sección 7: Integridad cross-reference"
check "eval-output ref eval-criteria" "grep -q 'eval-criteria' .opencode/commands/eval-output.md"
check "entity-recall ref memory-store.sh" "grep -q 'memory-store' .opencode/commands/entity-recall.md"
check "tool-discovery ref nl-command-resolution" "grep -q 'nl-command-resolution' docs/rules/domain/tool-discovery.md"
check "prompt-structure ref context-health" "grep -q 'context-health' docs/rules/domain/prompt-structure.md"
check "example-patterns ref PII-Free" "grep -q 'PII-Free' docs/rules/domain/example-patterns.md"

# === Resumen ===
echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resultado: $PASS/$TOTAL passed | $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[[ $FAIL -eq 0 ]] && echo "🎉 Todos los tests pasaron" || echo "⚠️  $FAIL tests fallaron"
exit $FAIL
