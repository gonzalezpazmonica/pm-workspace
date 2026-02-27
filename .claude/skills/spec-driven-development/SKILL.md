# Skill: Spec-Driven Development (SDD)

> Metodología que transforma Tasks de Azure DevOps en Specs ejecutables por un Developer humano **o** un agente Claude. El PM/Tech Lead escribe la Spec; el Developer (humano o agente) la implementa sin ambigüedad.

**Prerequisitos:** Leer `../azure-devops-queries/SKILL.md` y `../pbi-decomposition/SKILL.md`

---

## Concepto Central

```
PBI  →  Tasks (pbi-decomposition)  →  Specs (SDD)  →  Implementación (Human | Agent)
                                                               ↓
                                                     Code Review (siempre humano)
                                                               ↓
                                                          Azure DevOps Done
```

Un **Developer** en este workspace puede ser:

| Tipo | Descripción | Cuándo usar |
|------|-------------|-------------|
| `human` | Desarrollador humano del equipo | Lógica de dominio compleja, decisiones de arquitectura, código con alta ambigüedad |
| `agent-single` | Un Claude Code agent ejecutando la Spec | Tasks bien definidas, patrones repetitivos, boilerplate, tests |
| `agent-team` | Varios agentes Claude especializados en paralelo | Tasks grandes que se benefician de separación (implementer + tester + reviewer) |

La Spec es el **contrato** que hace posible esta dualidad: debe ser suficientemente precisa para que un agente la implemente correctamente, y suficientemente expresiva para que un humano entienda el "por qué".

---

## Constantes de esta skill

```bash
SPECS_DIR="projects/{proyecto}/specs"          # directorio de specs del proyecto
SPECS_SPRINT_DIR="$SPECS_DIR/{sprint}"         # specs del sprint actual
SPEC_EXTENSION=".spec.md"                      # extensión de los ficheros de spec
AGENT_LOGS_DIR="output/agent-runs"             # logs de ejecuciones de agentes
CLAUDE_MODEL_AGENT="claude-opus-4-6"           # modelo para agentes (configurable por proyecto)
CLAUDE_MODEL_MID="claude-sonnet-4-6"           # modelo para tareas medianas/balanceadas
CLAUDE_MODEL_FAST="claude-haiku-4-5-20251001"  # modelo para tareas simples (tests, DTOs)
```

---

## Fase 1 — Determinar el Developer Type de una Task

Antes de generar la Spec, determinar si la tarea es para humano o agente.

### 1.1 Leer la matrix del proyecto

Cada proyecto define en su `CLAUDE.md` la sección `sdd_layer_assignment`. Si no existe, usar la matrix global en `references/layer-assignment-matrix.md`.

### 1.2 Factores de decisión

**Favorecen `agent-single` o `agent-team`:**
- La task tiene un patrón claro y repetible en el proyecto
- El output es determinístico dado el input (tests, DTOs, validators, mappers)
- Existen ejemplos similares en el código fuente que el agente puede seguir
- Las reglas de negocio están completamente especificadas
- No requiere decisiones de diseño no descritas en la Spec

**Favorecen `human`:**
- Involucra lógica de dominio novedosa o ambigua
- Requiere juicio sobre trade-offs de arquitectura
- Integración con sistemas externos con poca documentación
- Primera vez que el equipo implementa ese patrón
- El PBI tiene criterios de aceptación incompletos o vagos
- La Task es `E1: Code Review` → **siempre humano**

**Favorecen `agent-team`:**
- La Task es grande (> 6h) Y bien definida
- Beneficia de separación de responsabilidades (un agente implementa, otro escribe tests)
- La velocidad es crítica y hay budget de tokens disponible

### 1.3 Override manual

El PM o Tech Lead puede sobreescribir el developer_type en cualquier momento editando el campo en la Spec o en el work item (tag `dev:human`, `dev:agent`, `dev:agent-team`).

---

## Fase 2 — Generar la Spec

### 2.1 Información requerida para la Spec

```bash
# Obtener la Task completa de Azure DevOps
PAT=$(cat $AZURE_DEVOPS_PAT_FILE)
curl -s -u ":$PAT" \
  "$AZURE_DEVOPS_ORG_URL/{proyecto}/_apis/wit/workitems/{task_id}?\$expand=all&api-version=7.1" | jq .

# Obtener el PBI padre para extraer criterios de aceptación
# (el task tiene un link Hierarchy-Reverse al PBI)
curl -s -u ":$PAT" \
  "$AZURE_DEVOPS_ORG_URL/{proyecto}/_apis/wit/workitems/{pbi_id}?\$expand=all&api-version=7.1" \
  | jq '.fields | {"title": .["System.Title"], "description": .["System.Description"], "acceptance": .["Microsoft.VSTS.Common.AcceptanceCriteria"]}'
```

### 2.2 Inspeccionar el código existente

```bash
# Encontrar código relacionado con el módulo de la task
PROYECTO_SOURCE="projects/{proyecto}/source"

# Patrón arquitectónico: buscar ejemplos del mismo tipo de implementación
# Si la task es "Crear Handler X", buscar handlers existentes
find $PROYECTO_SOURCE/src -name "*Handler.cs" | head -5

# Leer uno de los handlers existentes como ejemplo de patrón
cat $PROYECTO_SOURCE/src/Application/Commands/ExistingCommand/ExistingCommandHandler.cs

# Si la task es "Tests de X", buscar tests existentes del mismo módulo
find $PROYECTO_SOURCE/tests -name "*Tests.cs" | grep -i "{modulo}" | head -5
```

### 2.3 Construir la Spec

Usar la plantilla en `references/spec-template.md`. La Spec se guarda en:
```
projects/{proyecto}/specs/{sprint}/AB{task_id}-{tipo}-{descripcion-corta}.spec.md
```

**Ejemplo:** `projects/proyecto-alpha/specs/sprint-2026-04/AB1234-B3-create-patient-handler.spec.md`

### 2.4 Criterios de calidad de una Spec

Una Spec es ejecutable por un agente cuando:
- [ ] El contrato (interface/firma) está definido exactamente
- [ ] Todos los campos de entrada y salida están tipados
- [ ] Las reglas de negocio son inequívocas (sin "según corresponda" ni "a criterio del dev")
- [ ] Los test scenarios cubren casos normales Y edge cases
- [ ] Los ficheros a crear/modificar están listados con sus rutas exactas
- [ ] Hay al menos un ejemplo de código similar del proyecto para guiar el patrón
- [ ] Los criterios de aceptación son verificables automáticamente

Si algún punto no se puede completar → la task es `developer_type: human`.

### 2.5 Agent-Note del análisis

El agente que genera la spec (business-analyst o sdd-spec-writer) DEBE escribir una agent-note:
```
projects/{proyecto}/agent-notes/{ticket}-legacy-analysis-{fecha}.md
```
Con: análisis del código existente, patrones encontrados, decisiones sobre developer_type, y dependencias identificadas. Ver `@docs/agent-notes-protocol.md`.

---

## Fase 2.5 — Security Review Pre-Implementación

**Antes** de que cualquier developer (humano o agente) implemente, ejecutar `/security-review {spec}`:

1. `security-guardian` revisa la spec y arquitectura contra OWASP Top 10
2. Produce checklist en: `projects/{proyecto}/agent-notes/{ticket}-security-checklist-{fecha}.md`
3. Si hay hallazgos 🔴 → corregir la spec antes de implementar
4. El checklist se convierte en **input** para el developer

**Obligatorio** para: auth, pagos, datos personales, APIs públicas, infraestructura.
**Recomendado** para: cualquier spec de complejidad M o superior.

---

## Fase 2.6 — TDD Gate: Tests Antes de Implementar

El `test-engineer` escribe los tests **ANTES** de que el developer implemente:

1. `test-engineer` lee: spec + architecture-decision + security-checklist
2. Escribe test suites que fallan (Red) — cubren todos los scenarios de la spec
3. Produce agent-note: `projects/{proyecto}/agent-notes/{ticket}-test-strategy-{fecha}.md`
4. **GATE**: el developer NO puede editar código de producción sin que existan tests
   - Enforcement: hook `tdd-gate.sh` (PreToolUse en developer agents)
   - Si el hook bloquea → el developer debe pedir al test-engineer que cree los tests primero

---

## Fase 3 — Ejecutar con Agente Claude

### 3.1 Preparar el contexto del agente

El agente necesita acceso a:
1. La Spec (`.spec.md`) — su instrucción principal
2. Las agent-notes previas del ticket — `projects/{proyecto}/agent-notes/{ticket}-*.md`
3. El código fuente del módulo — para seguir patrones existentes
4. Los ficheros de reglas relevantes — `docs/reglas-negocio.md`, `projects/{proyecto}/reglas-negocio.md`
5. El security checklist — si existe, el developer DEBE respetar sus recomendaciones

### 3.2 Prompt de invocación para `agent-single`

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

### 3.3 Patrón `agent-team` — Agentes especializados en paralelo

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

### 3.4 Logging de ejecuciones de agente

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="output/agent-runs/${TIMESTAMP}-AB{task_id}-{tipo}.log"

claude ... 2>&1 | tee "$LOG_FILE"
echo "Log guardado en: $LOG_FILE"
```

---

### 3.5 Agent-Note post-implementación

El developer DEBE escribir:
```
projects/{proyecto}/agent-notes/{ticket}-implementation-log-{fecha}.md
```
Con: ficheros creados/modificados, decisiones tomadas, desviaciones de la spec (si las hubo), y blockers encontrados.

---

## Fase 4 — Review y Validación Post-Implementación

Independientemente de si implementó un humano o un agente:

### 4.1 Checklist de review para el Tech Lead

```markdown
## Review Checklist — AB#{task_id} — {título}
### Verificación contra Spec
- [ ] Todos los ficheros listados en la Spec han sido creados/modificados
- [ ] Las firmas de métodos/clases coinciden exactamente con el contrato de la Spec
- [ ] Todas las reglas de negocio de la Spec están implementadas
- [ ] Los test scenarios descritos en la Spec tienen su test correspondiente
- [ ] Los tests pasan en el pipeline CI

### Calidad de código
- [ ] El código sigue los patrones del proyecto (detectados en Fase 1.3)
- [ ] Sin hardcoding de valores que deberían ser configurables
- [ ] Manejo de errores implementado (no solo happy path)
- [ ] Sin código comentado ni TODOs sin resolver

### Específico para implementaciones de agente
- [ ] El agente no tomó decisiones de diseño fuera de la Spec
- [ ] No hay código generado innecesario (el agente tiende a añadir más de lo pedido)
- [ ] Las dependencias inyectadas coinciden con el patrón de inyección del proyecto
- [ ] Los nombres de clases/métodos siguen las convenciones del proyecto
```

### 4.2 Actualizar el work item en Azure DevOps

```bash
PAT=$(cat $AZURE_DEVOPS_PAT_FILE)

# Mover la Task a "In Review" (si la implementó un agente, el estado lo cambia el agente al terminar)
curl -s -u ":$PAT" \
  -H "Content-Type: application/json-patch+json" \
  -X PATCH \
  "$AZURE_DEVOPS_ORG_URL/{proyecto}/_apis/wit/workitems/{task_id}?api-version=7.1" \
  -d '[
    {"op": "replace", "path": "/fields/System.State", "value": "In Review"},
    {"op": "add", "path": "/fields/System.Tags", "value": "spec-driven,agent-implemented"},
    {"op": "add", "path": "/fields/Microsoft.VSTS.Scheduling.CompletedWork", "value": {horas_reales}}
  ]'
```

---

## Fase 5 — Aprendizaje y Mejora Continua

### 5.1 Métricas de SDD

Registrar en `projects/{proyecto}/specs/sdd-metrics.md`:

```markdown
| Sprint | Task ID | Developer Type | Spec Quality | Impl OK? | Review Issues | Horas Estimadas | Horas Reales |
|--------|---------|---------------|--------------|----------|---------------|----------------|--------------|
| 2026-04 | AB#1234-B3 | agent-single | ✅ Completa | ✅ | 0 | 4h | 3.5h |
| 2026-04 | AB#1234-D1 | agent-single | ✅ Completa | ✅ | 1 (naming) | 3h | 2h |
| 2026-04 | AB#1235-B3 | human | ✅ Completa | ✅ | 0 | 6h | 7h |
```

### 5.2 Regla de iteración

Si un agente produce código que el reviewer rechaza (> 2 issues bloqueantes):
→ Documentar qué faltó en la Spec y mejorar la plantilla/guidelines
→ Considerar mover esa categoría de task a `human` hasta que la Spec mejore

Principio: **"Si el agente falla, la Spec no era suficientemente buena"**

---

## Referencias

→ Spec template: `references/spec-template.md`
→ Matrix de asignación por capa: `references/layer-assignment-matrix.md`
→ Patrones de agent team: `references/agent-team-patterns.md`
→ Skill base: `../pbi-decomposition/SKILL.md`
→ Comandos: `/spec-generate`, `/spec-implement`, `/spec-review`, `/spec-status`, `/agent-run`
