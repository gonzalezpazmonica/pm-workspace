# Agent Team Patterns — Spec-Driven Development

> Patrones de orquestación de equipos de agentes Claude para la implementación de Specs.
> Cada patrón define roles, paralelismo, comunicación entre agentes y gestión de conflictos.

---

## Patrones Disponibles

| Patrón | Agentes | Paralelismo | Ideal para |
|--------|---------|-------------|-----------|
| `single` | 1 agente generalista | No aplica | Tasks ≤ 6h, bien definidas |
| `impl-test` | Implementador + Tester | Paralelo | Tasks con código producción + tests |
| `impl-test-review` | Implementador + Tester + Reviewer | Mixto | Tasks críticas o grandes |
| `full-stack` | API + Application + Tests | Paralelo | PBIs que abarcan 2+ capas verticales |
| `parallel-handlers` | N agentes para N handlers | Totalmente paralelo | Batch de handlers del mismo patrón |

---

## Patrón 1: `single` (Agent:Single)

### Descripción
Un único agente Claude implementa toda la Spec de inicio a fin.

### Cuándo usar
- Task ≤ 6h estimadas
- Solo una capa afectada (ej: solo Application, o solo Tests)
- El patrón es completamente claro y hay código de referencia

### Invocación
```bash
BASE="projects/{proyecto}"
SPEC_FILE="$BASE/specs/{sprint}/{spec_filename}.spec.md"
LOG_FILE="output/agent-runs/$(date +%Y%m%d-%H%M%S)-{task_id}-single.log"

claude --model claude-opus-4-6 \
  --system-prompt "$(cat $BASE/CLAUDE.md)" \
  --max-turns 40 \
  "Implementa la siguiente Spec exactamente como se describe.
   No tomes decisiones de diseño que no estén en la Spec.
   Si encuentras ambigüedad, detente y documenta la duda en la sección 'Blockers' de la Spec.
   Al terminar, actualiza la sección 'Estado de Implementación' a 'Completado' y lista los ficheros creados.

   $(cat $SPEC_FILE)

   Reglas de implementación:
   1. Sigue el patrón del ejemplo en la sección 'Código de Referencia' de la Spec
   2. Crea EXACTAMENTE los ficheros listados en 'Ficheros a Crear/Modificar'
   3. Los tests deben cubrir TODOS los escenarios de 'Test Scenarios'
   4. Ejecuta 'dotnet build' y 'dotnet test' al terminar; reporta el resultado
   5. Si algún test falla, corrígelo antes de marcar como Completado" \
  2>&1 | tee "$LOG_FILE"

echo "✅ Agente terminado. Log: $LOG_FILE"
```

---

## Patrón 2: `impl-test` (Implementador + Tester en Paralelo)

### Descripción
Dos agentes especializados trabajando en paralelo:
- **Agente Implementador**: escribe el código de producción (sin tests)
- **Agente Tester**: escribe los tests unitarios (sin código de producción)

### Cuándo usar
- Task ≥ 6h y bien definida
- Los tests son independientes del código de producción al inicio (mock-based)
- Hay presupuesto de tokens suficiente
- La Spec incluye interfaces/firmas exactas (el Tester puede escribir contra la interfaz antes de que exista la implementación)

### Requisito importante
La Spec debe definir las interfaces en la sección 2 con suficiente detalle para que el Tester pueda escribir tests antes de ver el código de producción.

### Invocación
```bash
BASE="projects/{proyecto}"
SPEC_FILE="$BASE/specs/{sprint}/{spec_filename}.spec.md"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Agente 1: Implementador — solo código de producción, sin tests
claude --model claude-opus-4-6 \
  --system-prompt "Eres un desarrollador .NET 8 senior especializado en Clean Architecture y CQRS.
Tu único rol es implementar el código de PRODUCCIÓN de la Spec:
- Ficheros en src/ (NO tests/)
- Sigue exactamente las interfaces de la sección 2 de la Spec
- No escribas tests — el Tester los escribirá en paralelo
- Si tienes dudas sobre la implementación, escríbelas en 'Blockers' de la Spec y detente

$(cat $BASE/CLAUDE.md)" \
  "$(cat $SPEC_FILE)" \
  2>&1 | tee "output/agent-runs/${TIMESTAMP}-{task_id}-implementador.log" &
PID_IMPL=$!

# Agente 2: Tester — solo tests, usando la interfaz definida en la Spec
claude --model claude-haiku-4-5-20251001 \
  --system-prompt "Eres un QA engineer senior especializado en .NET y xUnit.
Tu único rol es escribir los TESTS descritos en la Spec:
- Ficheros en tests/ (NO src/)
- Usa los interfaces definidas en la sección 2 de la Spec (mockea la implementación)
- Cubre TODOS los test scenarios de la sección 4
- Usa Moq para mocks, FluentAssertions para aserciones
- No implementes el código de producción — el Implementador lo hace en paralelo

$(cat $BASE/CLAUDE.md)" \
  "$(cat $SPEC_FILE)" \
  2>&1 | tee "output/agent-runs/${TIMESTAMP}-{task_id}-tester.log" &
PID_TEST=$!

echo "🚀 Agentes lanzados. Implementador PID: $PID_IMPL | Tester PID: $PID_TEST"
echo "⏳ Esperando a que ambos terminen..."

wait $PID_IMPL $PID_TEST
echo "✅ Ambos agentes han terminado."
echo "📋 Logs:"
echo "   Implementador: output/agent-runs/${TIMESTAMP}-{task_id}-implementador.log"
echo "   Tester:        output/agent-runs/${TIMESTAMP}-{task_id}-tester.log"
echo ""
echo "⚠️  Ejecuta: dotnet build && dotnet test para verificar que implementación + tests son compatibles"
```

### Paso post-paralelo manual
Después de que ambos agentes terminen, el Tech Lead (o un tercer agente reviewer) verifica que:
1. Los mocks del Tester coinciden con los constructores reales del Implementador
2. Los nombres de métodos/clases son idénticos
3. No hay conflictos en ficheros modificados (ej: DependencyInjection.cs)

---

## Patrón 3: `impl-test-review` (Completo con Reviewer)

### Descripción
Extiende el patrón 2 con un tercer agente Reviewer que valida la coherencia.

### Cuándo usar
- Task crítica o de alto impacto (ej: módulo de pagos, autenticación)
- Primera vez que se implementa un patrón en el proyecto
- El Tech Lead quiere una capa extra de validación antes del Code Review humano

### Invocación
```bash
BASE="projects/{proyecto}"
SPEC_FILE="$BASE/specs/{sprint}/{spec_filename}.spec.md"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# === FASE 1: Implementador + Tester en paralelo ===
# (igual que el patrón impl-test anterior)
claude ... &
PID_IMPL=$!
claude ... &
PID_TEST=$!
wait $PID_IMPL $PID_TEST

# === FASE 2: Reviewer (secuencial, después de los dos anteriores) ===
IMPL_LOG="output/agent-runs/${TIMESTAMP}-{task_id}-implementador.log"
TEST_LOG="output/agent-runs/${TIMESTAMP}-{task_id}-tester.log"

claude --model claude-opus-4-6 \
  --system-prompt "Eres un Tech Lead .NET revisando código generado por agentes IA.
Tu rol es SOLO revisar y reportar — NO modificar código.
Busca específicamente:
1. Discrepancias entre la Spec y la implementación
2. Tests que mockean incorrectamente (firmas diferentes de la implementación)
3. Reglas de negocio de la Spec que no están implementadas
4. Código generado innecesario (los agentes tienden a añadir más de lo pedido)
5. Violaciones de las convenciones del proyecto

Reporta todo en formato:
🔴 BLOQUEANTE: {descripción}
🟡 MEJORA: {descripción}
🟢 OK: {descripción}" \
  "Revisa la implementación del Implementador y los tests del Tester contra esta Spec.

   SPEC:
   $(cat $SPEC_FILE)

   LOG IMPLEMENTADOR (últimas 100 líneas):
   $(tail -100 $IMPL_LOG)

   LOG TESTER (últimas 100 líneas):
   $(tail -100 $TEST_LOG)

   Lista los ficheros creados que debes revisar y analiza su contenido." \
  2>&1 | tee "output/agent-runs/${TIMESTAMP}-{task_id}-reviewer.log"

echo ""
echo "📋 Review completado. Ver: output/agent-runs/${TIMESTAMP}-{task_id}-reviewer.log"
echo "⚠️  El Code Review final (E1) SIEMPRE es realizado por un humano."
```

---

## Patrón 4: `full-stack` (Vertical Completo)

### Descripción
Un equipo de agentes implementa un feature completo verticalmente: desde el endpoint hasta el repositorio, en paralelo por capa.

### Cuándo usar
- PBI completo con tasks bien especificadas en todas las capas
- Las capas son relativamente independientes al inicio (contratos definidos en la Spec)
- Alto volumen de código boilerplate

### Estructura del equipo
```
Agente API Layer       → Controller + DTOs de API
Agente App Layer       → Commands/Queries + Validators + Handlers
Agente Infra Layer     → Repository implementation + Entity config
Agente Test Layer      → Unit tests para Application + API tests

(Los 4 en paralelo durante la fase 1)
(Reviewer en la fase 2, secuencial)
```

### Requisito crítico
La Spec debe incluir las interfaces entre capas definidas exactamente, especialmente:
- Interfaces de repositorios (`IPatientRepository`)
- Contratos de Commands/Queries
- DTOs entre capas

### Invocación simplificada
```bash
BASE="projects/{proyecto}"
SPEC_FILE="$BASE/specs/{sprint}/{spec_filename}.spec.md"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SYSTEM_PROMPT=$(cat $BASE/CLAUDE.md)

for ROLE in "api" "application" "infrastructure" "tests"; do
  case $ROLE in
    "api")
      ROLE_PROMPT="Tu rol: implementar SOLO la capa API (Controller + DTOs de API en src/API/). No toques src/Application ni src/Infrastructure."
      ;;
    "application")
      ROLE_PROMPT="Tu rol: implementar SOLO la capa Application (Commands, Queries, Validators, Handlers en src/Application/). No toques src/API ni src/Infrastructure."
      ;;
    "infrastructure")
      ROLE_PROMPT="Tu rol: implementar SOLO la capa Infrastructure (Repositories, Entity configs en src/Infrastructure/). No toques src/API ni src/Application."
      ;;
    "tests")
      ROLE_PROMPT="Tu rol: implementar SOLO los tests unitarios (tests/ directory). No toques src/."
      ;;
  esac

  claude --model claude-opus-4-6 \
    --system-prompt "$SYSTEM_PROMPT. $ROLE_PROMPT" \
    "$(cat $SPEC_FILE)" \
    2>&1 | tee "output/agent-runs/${TIMESTAMP}-{task_id}-${ROLE}.log" &
done

wait
echo "✅ Todos los agentes del equipo full-stack han terminado."
echo "⚠️  Ejecuta dotnet build para verificar que no hay conflictos entre capas."
```

---

## Patrón 5: `parallel-handlers` (Batch de N Handlers)

### Descripción
N agentes en paralelo, cada uno implementando un handler diferente que sigue el mismo patrón.

### Cuándo usar
- Sprint con múltiples Commands/Queries del mismo módulo
- Todos siguen el mismo patrón (validar → consultar → crear → persistir)
- Se han detectado las Specs de todos como `agent:single`

### Invocación
```bash
BASE="projects/{proyecto}"
SPRINT_DIR="$BASE/specs/{sprint}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Lanzar un agente por spec file en el directorio del sprint
for SPEC_FILE in $SPRINT_DIR/*.spec.md; do
  SPEC_BASENAME=$(basename $SPEC_FILE .spec.md)

  # Solo procesar specs marcadas como agent:single (no human)
  DEVELOPER_TYPE=$(grep "^\*\*Developer Type:\*\*" $SPEC_FILE | awk '{print $NF}')
  if [ "$DEVELOPER_TYPE" != "agent:single" ]; then
    echo "⏭️  Saltando $SPEC_BASENAME (Developer Type: $DEVELOPER_TYPE)"
    continue
  fi

  echo "🚀 Lanzando agente para: $SPEC_BASENAME"
  claude --model claude-opus-4-6 \
    --system-prompt "$(cat $BASE/CLAUDE.md)" \
    --max-turns 30 \
    "Implementa esta Spec exactamente. No tomes decisiones fuera de la Spec.
     $(cat $SPEC_FILE)" \
    2>&1 | tee "output/agent-runs/${TIMESTAMP}-${SPEC_BASENAME}.log" &
done

wait
echo "✅ Todos los agentes del batch han terminado."
```

---

## Gestión de Conflictos entre Agentes

### Problema: Ficheros compartidos
Cuando dos agentes modifican el mismo fichero (ej: `DependencyInjection.cs`), puede haber conflictos.

### Estrategia de resolución

**Opción A — Reservar el fichero para un solo agente:**
```bash
# En el prompt de cada agente, especificar exactamente qué ficheros puede tocar
"NO modifiques DependencyInjection.cs — el Agente API se encargará de ese fichero."
```

**Opción B — Merge post-ejecución:**
```bash
# Después de que todos los agentes terminen, un agente merger resuelve conflictos
claude --model claude-haiku-4-5-20251001 \
  "Revisa los siguientes ficheros que han sido creados por múltiples agentes
   y fusiona los cambios en DependencyInjection.cs sin perder registros de ningún agente:

   Fichero actual: $(cat src/Infrastructure/DependencyInjection.cs)

   Añadidos por agente application: {lista de servicios}
   Añadidos por agente infrastructure: {lista de servicios}"
```

**Opción C — Spec define el fichero en un solo rol:**
La mejor práctica: la Spec asigna explícitamente cada fichero compartido a un único agente.

---

## Logging y Monitorización

### Estructura de logs
```
output/agent-runs/
├── {timestamp}-{task_id}-single.log           # Patrón single
├── {timestamp}-{task_id}-implementador.log    # Patrón impl-test
├── {timestamp}-{task_id}-tester.log
├── {timestamp}-{task_id}-reviewer.log         # Si aplica
└── {timestamp}-{task_id}-summary.md           # Generado post-ejecución
```

### Generar resumen post-ejecución
```bash
TIMESTAMP="20260404-143022"
TASK_ID="AB1234"

claude --model claude-haiku-4-5-20251001 \
  "Analiza los siguientes logs de ejecución de agentes y genera un resumen en formato markdown:
   - Estado de cada agente (completado/bloqueado/error)
   - Ficheros creados/modificados
   - Tests passing/failing
   - Blockers encontrados
   - Recomendación para el Tech Lead (listo para review / necesita intervención humana)

   $(cat output/agent-runs/${TIMESTAMP}-${TASK_ID}-*.log)" \
  > "output/agent-runs/${TIMESTAMP}-${TASK_ID}-summary.md"

cat "output/agent-runs/${TIMESTAMP}-${TASK_ID}-summary.md"
```

---

## Tokens y Costes Estimados

| Patrón | Agentes | Turns aprox. | Tokens input | Tokens output | Coste aprox.* |
|--------|---------|-------------|-------------|--------------|--------------|
| `single` | 1 | 20-40 | ~50K | ~30K | ~$0.60 |
| `impl-test` | 2 | 20-30 c/u | ~80K total | ~50K total | ~$0.80 |
| `impl-test-review` | 3 | 20-40 c/u | ~130K total | ~70K total | ~$1.20 |
| `full-stack` | 4 | 25-40 c/u | ~180K total | ~90K total | ~$1.80 |
| `parallel-handlers` (5 specs) | 5 | 20-30 c/u | ~200K total | ~120K total | ~$2.50 |

*Estimaciones con claude-opus-4-6 a $15/MTok input, $75/MTok output.
El patrón `tester` usa claude-haiku que es ~20x más barato.*

---

## Anti-Patrones a Evitar

### ❌ Agente sin Spec clara
El agente toma decisiones de diseño → resultado impredecible → más trabajo de review que hacer a mano.

### ❌ Agent:team sin contratos de interfaz
Si los agentes no tienen las interfaces definidas, cada uno asume cosas distintas → conflictos de integración.

### ❌ Paralelo con ficheros compartidos sin coordinación
Dos agentes modificando `DependencyInjection.cs` → pérdida de cambios de uno de ellos.

### ❌ Reviewer que modifica código
El agente reviewer es read-only. Si modifica código → loop infinito de correcciones. Solo reporta.

### ❌ `agent:team` para tasks < 4h
El overhead de coordinación y el coste de tokens supera el ahorro. Usar `agent:single`.

### ❌ Agente para Code Review (E1)
El Code Review siempre lo realiza un humano. Siempre. Sin excepción.

---

## Referencias

→ Spec template: `spec-template.md`
→ Matrix de asignación por capa: `layer-assignment-matrix.md`
→ Skill base SDD: `../SKILL.md`
→ Comando de ejecución: `.claude/commands/agent-run.md`
