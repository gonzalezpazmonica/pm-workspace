# /agent:run

Lanza un agente Claude (o equipo) directamente sobre una Spec, con soporte para patrón single, impl-test, impl-test-review o parallel batch.

## Uso
```
/agent:run {spec_file|--all-pending} [--project {nombre}] [--team] [--pattern {pattern}] [--model {model}]
```

- `{spec_file}`: Ruta a un `.spec.md` concreto
- `--all-pending`: Lanzar agentes para todas las specs pendientes `agent:single` del sprint
- `--team`: Usar patrón `agent:team` (default: `impl-test`)
- `--pattern {name}`: Patrón específico: `single` | `impl-test` | `impl-test-review` | `full-stack` | `parallel-handlers`
- `--model {model}`: Sobreescribir modelo (default: `claude-opus-4-6`)

## Este comando orquesta

→ `.claude/skills/spec-driven-development/SKILL.md` (Fase 3)
→ `.claude/skills/spec-driven-development/references/agent-team-patterns.md`

## Modo 1: Agente Single sobre una Spec

```bash
SPEC_FILE="{spec_file}"
BASE="projects/{proyecto}"
TASK_ID=$(grep "^\*\*Task ID:\*\*" $SPEC_FILE | grep -oE '[0-9]+')
MODEL="${model:-claude-opus-4-6}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="output/agent-runs/${TIMESTAMP}-AB${TASK_ID}-single.log"

echo "🤖 AGENT:SINGLE — AB#${TASK_ID}"
echo "   Spec:    $SPEC_FILE"
echo "   Modelo:  $MODEL"
echo "   Log:     $LOG_FILE"
echo "   Turns:   40 máx"
echo ""
echo "¿Lanzar agente? (s/n)"
```

Tras confirmación:
```bash
claude --model $MODEL \
  --system-prompt "$(cat $BASE/CLAUDE.md)" \
  --max-turns 40 \
  "Implementa la siguiente Spec exactamente como se describe.

   INSTRUCCIONES OBLIGATORIAS:
   1. Lee completamente la Spec antes de escribir código
   2. Revisa el código de referencia en la sección 6 antes de implementar
   3. Crea EXACTAMENTE los ficheros listados en la sección 5 (ni más ni menos)
   4. Sigue el patrón del código de referencia para naming y estructura
   5. Implementa TODAS las reglas de negocio de la sección 3
   6. Los tests deben cubrir TODOS los escenarios de la sección 4
   7. Al terminar: ejecuta 'dotnet build' y 'dotnet test'
   8. Si build o tests fallan: corrígelos (máx 3 intentos)
   9. Si encuentras ambigüedad que no está en la Spec: DETENTE, escribe el blocker en la sección 8 de la Spec, y para
   10. Al completar correctamente: actualiza la sección 8 a 'Estado: Completado' con el log de ficheros creados

   SPEC A IMPLEMENTAR:
   $(cat $SPEC_FILE)

   Directorio del código fuente: $BASE/source" \
  2>&1 | tee "$LOG_FILE"

echo ""
echo "═══════════════════════════════════════"
echo "✅ Agente terminado"
echo "📋 Log: $LOG_FILE"
echo ""

# Mostrar las últimas líneas del log (resumen del agente)
echo "📌 Resumen (últimas 30 líneas del log):"
tail -30 "$LOG_FILE"
```

## Modo 2: Agent Team sobre una Spec

Si `--team` o `--pattern impl-test`:

```bash
SPEC_FILE="{spec_file}"
BASE="projects/{proyecto}"
TASK_ID=$(grep "^\*\*Task ID:\*\*" $SPEC_FILE | grep -oE '[0-9]+')
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "🤖🤖 AGENT:TEAM (impl-test) — AB#${TASK_ID}"
echo "   Patrón:         impl-test (Implementador + Tester en paralelo)"
echo "   Modelo impl:    claude-opus-4-6"
echo "   Modelo tester:  claude-haiku-4-5-20251001"
echo ""
echo "¿Lanzar equipo de agentes? (s/n)"
```

Tras confirmación:
```bash
# Ver agent-team-patterns.md para el código completo del patrón impl-test
# Resumen:

# Agente Implementador (background)
claude --model claude-opus-4-6 \
  --system-prompt "$(cat $BASE/CLAUDE.md). Tu rol: SOLO código de producción en src/. No escribas tests." \
  "$(cat $SPEC_FILE)" \
  2>&1 | tee "output/agent-runs/${TIMESTAMP}-AB${TASK_ID}-implementador.log" &
PID_IMPL=$!

# Agente Tester (background)
claude --model claude-haiku-4-5-20251001 \
  --system-prompt "$(cat $BASE/CLAUDE.md). Tu rol: SOLO tests en tests/. Mockea las interfaces de la sección 2." \
  "$(cat $SPEC_FILE)" \
  2>&1 | tee "output/agent-runs/${TIMESTAMP}-AB${TASK_ID}-tester.log" &
PID_TEST=$!

echo "⏳ Agentes corriendo en paralelo..."
wait $PID_IMPL $PID_TEST

echo "✅ Ambos agentes terminaron."
echo "   Implementador: output/agent-runs/${TIMESTAMP}-AB${TASK_ID}-implementador.log"
echo "   Tester:        output/agent-runs/${TIMESTAMP}-AB${TASK_ID}-tester.log"
echo ""
echo "⚠️  Ejecuta 'dotnet build && dotnet test' para verificar compatibilidad implementación+tests"
```

Si `--pattern impl-test-review`:
```bash
# Después del wait anterior, lanzar el Reviewer
claude --model claude-opus-4-6 \
  --system-prompt "Eres un Tech Lead .NET. Tu rol: SOLO revisar y reportar — NO modificar código." \
  "Revisa estos logs contra la Spec y reporta discrepancias.
   $(cat $SPEC_FILE)
   LOG IMPLEMENTADOR: $(tail -80 output/agent-runs/${TIMESTAMP}-AB${TASK_ID}-implementador.log)
   LOG TESTER: $(tail -80 output/agent-runs/${TIMESTAMP}-AB${TASK_ID}-tester.log)" \
  2>&1 | tee "output/agent-runs/${TIMESTAMP}-AB${TASK_ID}-reviewer.log"
```

## Modo 3: Batch — Todas las specs pendientes

Con `--all-pending`:

```bash
BASE="projects/{proyecto}"
SPRINT="${sprint:-$(date +'%Y-%m')}"
SPECS_DIR="$BASE/specs/sprint-${SPRINT}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Recopilar specs pendientes de tipo agent:single
PENDING_SPECS=()
for SPEC_FILE in $SPECS_DIR/*.spec.md; do
  DEV_TYPE=$(grep "^\*\*Developer Type:\*\*" $SPEC_FILE | awk '{print $NF}')
  ESTADO=$(grep "^\*\*Estado:\*\*" $SPEC_FILE | awk '{print $NF}')
  if [ "$DEV_TYPE" = "agent:single" ] && [ "$ESTADO" = "Pendiente" ]; then
    PENDING_SPECS+=($SPEC_FILE)
  fi
done

echo "🤖 BATCH AGENT RUN — ${#PENDING_SPECS[@]} specs pendientes"
for SPEC in "${PENDING_SPECS[@]}"; do
  TASK_ID=$(grep "^\*\*Task ID:\*\*" $SPEC | grep -oE '[0-9]+')
  TITULO=$(grep "^# Spec:" $SPEC | sed 's/# Spec: //')
  echo "   AB#${TASK_ID} — ${TITULO}"
done
echo ""
echo "⚠️  Cada agente consume ~40-60K tokens. Total estimado: ~$((${#PENDING_SPECS[@]} * 50))K tokens"
echo "¿Lanzar todos en paralelo? (s/n)"
```

Tras confirmación:
```bash
for SPEC_FILE in "${PENDING_SPECS[@]}"; do
  TASK_ID=$(grep "^\*\*Task ID:\*\*" $SPEC_FILE | grep -oE '[0-9]+')
  LOG_FILE="output/agent-runs/${TIMESTAMP}-AB${TASK_ID}-single.log"

  claude --model claude-opus-4-6 \
    --system-prompt "$(cat $BASE/CLAUDE.md)" \
    --max-turns 40 \
    "Implementa la siguiente Spec: $(cat $SPEC_FILE)" \
    2>&1 | tee "$LOG_FILE" &
done

wait
echo "✅ Todos los agentes del batch han terminado."
echo "🔍 Ejecuta /spec:status para ver resultados"
```

## Gestión de Fallos

Si el agente escribe bloqueantes en la Spec:

```bash
# Detectar specs con blockers
for LOG in output/agent-runs/${TIMESTAMP}-*.log; do
  if grep -q "BLOCKER\|Bloqueado\|ambigüedad" $LOG; then
    echo "🚫 BLOCKER en: $LOG"
    grep -A3 "BLOCKER\|Bloqueado" $LOG
  fi
done
```

## Configuración del Modelo por Tipo

```bash
# Configuración en CLAUDE.md del proyecto o usar defaults:
CLAUDE_MODEL_AGENT="claude-opus-4-6"            # Para código de producción y lógica compleja
CLAUDE_MODEL_MID="claude-sonnet-4-6"            # Para tareas medianas/balanceadas
CLAUDE_MODEL_FAST="claude-haiku-4-5-20251001"   # Para tests, DTOs, validadores simples

# Criterios de selección:
# - Usar AGENT para: handlers, servicios con lógica, repositorios complejos
# - Usar MID para: tareas medianas, refactoring, lógica moderada
# - Usar FAST para: unit tests, DTOs/Records, validators simples, mappers
```

> ⚠️ RECORDATORIO: El Code Review (E1) siempre es realizado por un humano.
> El agente puede marcar la task como "In Review" pero NO puede aprobar el merge.
