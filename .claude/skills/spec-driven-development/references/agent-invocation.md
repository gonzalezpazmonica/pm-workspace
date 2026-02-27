# Fase 3: Ejecutar con Agente Claude — Invocación y Patrones

## 3.1 Preparar el contexto del agente

El agente necesita acceso a:
1. La Spec (`.spec.md`) — su instrucción principal
2. Las agent-notes previas del ticket — `projects/{proyecto}/agent-notes/{ticket}-*.md`
3. El código fuente del módulo — para seguir patrones existentes
4. Los ficheros de reglas relevantes — `docs/reglas-negocio.md`, `projects/{proyecto}/reglas-negocio.md`
5. El security checklist — si existe, el developer DEBE respetar sus recomendaciones

---

## 3.2 Prompt de invocación para `agent-single`

```bash
# Invocar Claude Code como subagente
claude --model $CLAUDE_MODEL_AGENT \
  --system-prompt "$(cat projects/{proyecto}/CLAUDE.md)" \
  --max-turns 30 \
  "Implementa la siguiente Spec exactamente como se describe.
   No tomes decisiones de diseño que no estén en la Spec; si encuentras ambigüedad, detente y documenta la duda en el fichero de spec.

   $(cat {spec_file})

   Reglas de implementación:
   - Sigue el patrón del ejemplo de código en la sección 'Código de Referencia'
   - Crea EXACTAMENTE los ficheros listados en 'Ficheros a Crear/Modificar'
   - Los tests deben cubrir TODOS los escenarios de la sección 'Test Scenarios'
   - Al terminar, actualiza el campo 'Estado de Implementación' en la Spec a 'Completado'
   - Si detectas que la Spec es incompleta o ambigua, actualiza 'Blockers' en la Spec y detente"
```

---

## 3.3 Patrón `agent-team` — Agentes especializados en paralelo

**Regla de serialización**: ANTES de lanzar tareas paralelas, verificar que los scopes (ficheros declarados en cada spec) no se solapan. Si dos specs tocan los mismos módulos → serializar o asignar a un solo agente. Ver `@docs/agent-teams-sdd.md` §"Regla de Serialización de Scope".

Para tasks grandes, se lanza un equipo de agentes con roles distintos:

```bash
# Agente 1: Implementador — escribe el código de producción
claude --model $CLAUDE_MODEL_AGENT \
  --system-prompt "Eres un implementador senior .NET. Tu único rol es implementar el código de producción de la Spec, sin escribir tests." \
  "$(cat {spec_file})" &
PID_IMPL=$!

# Agente 2: Tester — escribe los tests (puede ejecutarse en paralelo)
claude --model $CLAUDE_MODEL_FAST \
  --system-prompt "Eres un QA engineer senior. Tu único rol es escribir los tests descritos en la Spec." \
  "$(cat {spec_file})" &
PID_TEST=$!

wait $PID_IMPL $PID_TEST

# Agente 3: Reviewer — revisa el output de los dos anteriores (secuencial)
claude --model $CLAUDE_MODEL_AGENT \
  --system-prompt "Eres un Tech Lead revisando código. Verifica que la implementación cumple la Spec. Reporta discrepancias sin modificar código." \
  "Revisa los ficheros creados por el implementador y el tester contra esta Spec: $(cat {spec_file})"
```

**Importante:** El agente reviewer solo reporta — la decisión final de merge es siempre de un humano.

---

## 3.4 Logging de ejecuciones de agente

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="output/agent-runs/${TIMESTAMP}-AB{task_id}-{tipo}.log"

claude ... 2>&1 | tee "$LOG_FILE"
echo "Log guardado en: $LOG_FILE"
```

---

## 3.5 Agent-Note post-implementación

El developer DEBE escribir:
```
projects/{proyecto}/agent-notes/{ticket}-implementation-log-{fecha}.md
```
Con: ficheros creados/modificados, decisiones tomadas, desviaciones de la spec (si las hubo), y blockers encontrados.

---

## Context Requerido para Agentes

Cada agente de implementación necesita cargar estos ficheros ANTES de ejecutar:

```bash
# 1. Reglas globales del workspace
cat .claude/rules/domain/pm-config.md
cat .claude/rules/domain/environment-config.md

# 2. Reglas del proyecto
cat projects/{proyecto}/CLAUDE.md
cat projects/{proyecto}/reglas-negocio.md

# 3. Especificación ejecutable
cat {spec_file}

# 4. Código de referencia (patrones del proyecto)
find projects/{proyecto}/source/src -name "*{módulo}*" -type f | head -5

# 5. Tests existentes como plantilla
find projects/{proyecto}/source/tests -name "*{módulo}*" | head -3

# 6. Agent notes previas (contexto del ticket)
find projects/{proyecto}/agent-notes -name "{ticket}-*" | sort
```

---

## Selección del Modelo por Task

```
Tamaño de Task | Modelo | Razonamiento
---|---|---
< 2h (DTOs, validators, boilerplate) | Haiku 4.5 | Costo mínimo, suficiente precisión
2-6h (handlers, servicios, components) | Sonnet 4.6 | Balance costo/capacidad
> 6h (sistemas complejos, integraciones) | Opus 4.6 | Máxima capacidad de razonamiento
```

---

## Patrón: Validación de Output del Agente

Tras ejecutar un agente, SIEMPRE verificar:

```bash
# 1. Ficheros creados coinciden con la Spec
find . -newer /tmp/timestamp -name "*.cs" -o -name "*.ts" | sort

# 2. Tests pasan
dotnet test projects/{proyecto}/source/tests --no-build
# o
npm test --workspace={proyecto}

# 3. Build sin errores
dotnet build projects/{proyecto}/source --configuration Release --no-restore
# o
npm run build --workspace={proyecto}

# 4. Sin secrets en el código
grep -r "password\|secret\|token\|api.key" projects/{proyecto}/source/src --include="*.cs" --include="*.ts"

# 5. Coincide con patrones del proyecto
# Verificar: nombrado como clases existentes, inyección de dependencias, namespaces correctos
```

Si alguna validación falla → actualizar la Spec y reintentar con el agente.

---

## Manejo de Fallos de Agentes

### Fallo: "No implementé un patrón correcto"

→ Actualizar la Spec con ejemplo más claro de patrón
→ Reintentar con `agent-single`

### Fallo: "Tests insuficientes"

→ Actualizar Spec: sección "Test Scenarios" con casos específicos faltantes
→ Reintentar con `test-engineer` especializado

### Fallo: "Decisiones de diseño fuera de Spec"

→ Documentar las decisiones como "Desviaciones" en agent-note
→ Mostrar al code-reviewer humano para validar
→ NO mover a "Done" sin aprobación humana

### Fallo: "Código no sigue patrones del proyecto"

→ Leer más ficheros de referencia en la Spec
→ Reintentar con más contexto

---

## Patrón: Debugging de Agentes

Si un agente se atasca, usar:

```bash
# 1. Ver el último log
tail -100 output/agent-runs/LATEST.log

# 2. Identificar el error último
grep -i "error\|exception\|failed" output/agent-runs/LATEST.log | tail -5

# 3. Actualizar Spec con clarificación
# Y/O ejecutar el agente en modo "dry-run" primero (con --dry-run flag en Spec)

# 4. Reintentar con mensaje explícito
# "Detectamos que fallaste en X. Aquí está el error: Y. Intenta de nuevo con Z."
```

---

## Automatización: Orchestrador de Agentes

Para flujos complejos (SDD completo), considera crear un agente `sdd-orchestrator`:

```bash
# Flujo automated:
1. business-analyst → genera spec
2. test-engineer → escribe tests pre-implementación
3. security-guardian → valida seguridad
4. dotnet-developer (agent-team) → implementa + tests paralelo
5. code-reviewer → valida contra spec
6. commit-guardian → verifica checklist pre-commit
```

Esto se orquesta desde el comando `/spec-implement {task_id}` que invoca el orchestrator.
