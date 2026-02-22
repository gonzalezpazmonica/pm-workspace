# Flujo de Trabajo del Equipo

> Define el workflow completo del equipo: estados del board, políticas de columna y proceso de trabajo diario.

## Constantes del Flujo

```
BOARD_NAME              = "Stories"                  # nombre del board principal en Azure DevOps
BOARD_COLUMNS           = ["New", "Approved", "Committed", "Active", "In Review", "Done"]
WIP_LIMITS = {
  "Active":      5,      # máximo 5 items activos en el board simultáneamente
  "In Review":   3,      # máximo 3 items en revisión/PR abierto
  "Done":        null    # sin límite (se limpia al cerrar el sprint)
}
BRANCH_PREFIX = {
  "feature":  "feature/AB#",
  "bugfix":   "bugfix/AB#",
  "hotfix":   "hotfix/AB#",
  "release":  "release/v"
}
```

---

## 1. Estados del Board y sus Significados

| Estado | Significado | Responsable de mover |
|--------|-------------|---------------------|
| **New** | Item en backlog del sprint, sin empezar | PO/SM durante Planning |
| **Approved** | PBI refinado y estimado, listo para sprint | PO tras refinement |
| **Committed** | Comprometido para este sprint | SM durante Planning |
| **Active** | Alguien está trabajando activamente en él | Developer al empezar |
| **In Review** | PR abierto o en revisión por QA | Developer al abrir PR |
| **Resolved** | Done técnicamente, pendiente validación PO | Developer tras merge |
| **Done** | Validado por PO, cumple DoD | PO en Review |
| **Closed** | Archivado, no entregado en este sprint | SM al cerrar sprint |

---

## 2. Proceso Paso a Paso — Development

### Paso 1: Inicio de una User Story / Task

```bash
# 1. Mover el item a "Active" en Azure DevOps
az boards work-item update --id XXXX --fields "System.State=Active"

# 2. Crear rama de feature
git checkout develop
git pull origin develop
git checkout -b feature/AB#XXXX-descripcion-corta

# 3. Actualizar RemainingWork inicial (si no está configurado desde Planning)
az boards work-item update --id XXXX \
  --fields "Microsoft.VSTS.Scheduling.RemainingWork=8"
```

### Paso 2: Durante el Desarrollo

```bash
# Commits referenciando el work item
git commit -m "[AB#XXXX] Add user authentication endpoint"
git commit -m "[AB#XXXX] Add unit tests for auth service"

# Actualizar RemainingWork diariamente (antes del Daily, 09:00)
az boards work-item update --id XXXX \
  --fields "Microsoft.VSTS.Scheduling.RemainingWork=4" \
           "Microsoft.VSTS.Scheduling.CompletedWork=4"
```

### Paso 3: Pull Request

```bash
# 1. Push de la rama
git push origin feature/AB#XXXX-descripcion-corta

# 2. Crear PR en Azure DevOps
az repos pr create \
  --title "[AB#XXXX] Descripción del cambio" \
  --description "Closes AB#XXXX\n\n## Cambios\n- ...\n\n## Tests\n- ...\n\n## Screenshots\n- ..." \
  --source-branch feature/AB#XXXX-descripcion-corta \
  --target-branch develop \
  --work-items XXXX \
  --auto-complete false

# 3. Mover item a "In Review"
az boards work-item update --id XXXX --fields "System.State=In Review"
```

### Paso 4: Merge y Cierre

```bash
# Tras aprobación del PR:
# 1. Merge a develop (squash merge recomendado)
# 2. Eliminar rama de feature
# 3. Mover item a "Resolved"
az boards work-item update --id XXXX \
  --fields "System.State=Resolved" \
           "Microsoft.VSTS.Scheduling.RemainingWork=0" \
           "Microsoft.VSTS.Scheduling.CompletedWork=8"

# 4. PO valida en el entorno de test → mueve a "Done"
```

---

## 3. Proceso de Code Review

### Checklist del Revisor

```
□ El código resuelve lo que describe el work item
□ No hay código innecesario o comentado
□ Los nombres de variables/clases/métodos son descriptivos
□ Hay tests unitarios para la lógica nueva
□ Los tests cubren casos límite (null, empty, edge cases)
□ No hay secrets ni credenciales hardcodeadas
□ El código sigue los estándares de .NET definidos en docs/reglas-negocio.md
□ La documentación XML está actualizada (si es API pública)
□ El PR description explica el "por qué", no solo el "qué"
```

### Tipos de comentarios en PR

- **[BLOCKING]** — Debe resolverse antes del merge (bugs, seguridad, lógica incorrecta)
- **[SUGGESTION]** — Mejora recomendable pero no bloqueante
- **[QUESTION]** — Duda o aclaración, no necesariamente un problema
- **[NIT]** — Detalle menor de estilo (no contar para el ciclo de review)

**SLA de review:** 1 día hábil para primera respuesta, 3 días hábiles para completar el ciclo.

---

## 4. Gestión de Bugs

### Flujo de bugs P1 (Crítico — Producción)

```
1. Se detecta el bug → crear work item Bug en AzDevOps con tag "P1"
2. Notificar inmediatamente al SM + Tech Lead
3. Asignar al developer más disponible
4. El SM mueve el bug al sprint actual (top of backlog)
5. Developer crea rama: hotfix/AB#XXXX-descripcion
6. Fix + test de regresión + PR con aprobación acelerada (1 revisor)
7. Merge a main (deploy hotfix) + merge a develop
8. Cerrar el bug + añadir tag "PostRelease" si vino de producción
9. Documentar root cause en el work item (campo Repro Steps / comments)
```

### Flujo de bugs P2/P3

```
1. Crear work item Bug → Refinement en el siguiente ciclo
2. Asignar severidad y prioridad
3. Entrar al sprint siguiente según prioridad del PO
4. Seguir el flujo normal de development
```

---

## 5. Gestión de Dependencias

### Tipos de links en Azure DevOps

| Link Type | Uso |
|-----------|-----|
| `Blocks` / `Blocked By` | Item A bloquea a Item B (no puede empezarse hasta que A esté Done) |
| `Duplicate Of` | Item duplicado de otro (cerrar el duplicado) |
| `Related` | Relacionados pero no dependientes |
| `Child` / `Parent` | Jerarquía: Epic → Feature → User Story → Task |
| `Tested By` | Test case que verifica el item |

### Política de bloqueos

- Si un item está bloqueado, añadir tag `blocked` y un comentario explicando el bloqueo
- El SM revisa los items bloqueados diariamente (parte del Daily)
- Los bloqueos que duren > 2 días se escalan según la tabla de `docs/reglas-negocio.md §6`

---

## 6. Gestión de Releases

### Cadencia de releases

```
RELEASE_CADENCIA    = "Al final de cada sprint" (o según contractual del proyecto)
RELEASE_BRANCH      = "release/vX.Y.Z"
HOTFIX_BRANCH       = "hotfix/AB#XXXX-descripcion"
VERSION_FORMAT      = "MAJOR.MINOR.PATCH"
  MAJOR: cambio de contrato / ruptura de compatibilidad
  MINOR: nueva funcionalidad
  PATCH: bug fix
```

### Proceso de release

```bash
# 1. Crear rama de release desde develop
git checkout develop && git pull
git checkout -b release/v1.2.0

# 2. Bump de versión (actualizar AssemblyInfo / csproj)
# 3. Ejecutar suite de tests completa en CI
# 4. Desplegar en staging → validación QA + PO
# 5. Si OK → merge a main + tag
git tag -a v1.2.0 -m "Release v1.2.0 — Sprint 2026-04"
git push origin v1.2.0

# 6. Merge release branch de vuelta a develop
# 7. Cerrar work items relacionados con la release
# 8. Actualizar CHANGELOG
```

---

## 7. Definición de "Blocked"

Un item se marca como **Blocked** (tag `blocked` en Azure DevOps) cuando:

- Depende de otro item externo no terminado
- Requiere una decisión del cliente no tomada
- Hay un impedimento técnico sin solución identificada
- Está a la espera de acceso a un entorno o recurso

**Al marcar como blocked:**
1. Añadir tag `blocked` al work item
2. Escribir un comentario con: qué bloquea, desde cuándo, quién debe resolverlo
3. Informar al SM en el mismo Daily
4. El SM crea un Task separado para gestionar el desbloqueo (si aplica)

---

## 8. Spec-Driven Development (SDD) — Workflow

> El SDD extiende el flujo de trabajo estándar con un paso adicional entre la descomposición del PBI y la implementación.
> Permite que las Tasks sean implementadas por desarrolladores humanos **o** por agentes Claude.

### 8.1 Flujo Completo SDD

```
PBI en Backlog
    ↓
/pbi:decompose {id}        → Tasks creadas con campo "Developer Type" (human | agent:single | agent:team)
    ↓
/spec:generate {task_id}   → Spec generada para cada task (fichero .spec.md)
    ↓
/spec:review {spec_file}   → PM/Tech Lead valida la Spec (calidad, completitud)
    ↓
         ┌──────────────────────────────────────────────┐
         │  ¿Developer Type?                            │
         │                                              │
         │  human          → Asignar al dev             │
         │                   Task: Active               │
         │                   Dev implementa normalmente │
         │                                              │
         │  agent:single   → /agent:run {spec_file}     │
         │                   Agente implementa la Spec  │
         │                   Task: Active → In Review   │
         │                                              │
         │  agent:team     → /agent:run {spec_file}     │
         │                        --team                │
         │                   Implementador + Tester     │
         │                   en paralelo                │
         └──────────────────────────────────────────────┘
    ↓
/spec:review {spec_file}   → Pre-check de implementación (--check-impl)
    ↓
Code Review (E1)           → SIEMPRE humano (Tech Lead)
    ↓
PR aprobado → Merge → Task: Done
```

### 8.2 Reglas SDD

**1. La Spec es el contrato.**
No se empieza a implementar sin una Spec aprobada. Ni humanos ni agentes.

**2. El Code Review es siempre humano.**
El tag `E1: Code Review` nunca puede tener `developer_type: agent`. Sin excepción.

**3. "Si el agente falla, la Spec no era suficientemente buena."**
Un fallo del agente indica una Spec incompleta, no un problema con el agente. Mejorar la Spec, no saltar el proceso.

**4. Un agente puede DETENERSE.**
Si el agente encuentra ambigüedad, escribe un Blocker en la sección 8 de la Spec y para. El Tech Lead resuelve el blocker y relanza el agente.

**5. Las tareas de dominio son siempre humanas.**
La Domain Layer (entidades, servicios de dominio, reglas de negocio nuevas) siempre requiere un desarrollador humano.

### 8.3 Estados de Azure DevOps para Tasks de Agente

| Estado | Significado en contexto SDD |
|--------|----------------------------|
| **New** | Task creada, Spec pendiente de generar |
| **Active** | Spec aprobada, agente ejecutándose |
| **In Review** | Agente terminó → pre-check OK → esperando Code Review humano |
| **Done** | Code Review humano aprobado, PR mergeado |

**Tag especiales:**
- `spec-driven` — task implementada mediante SDD (con o sin agente)
- `agent-implemented` — código generado por agente Claude
- `spec-blocked` — spec tiene blocker pendiente de resolución

### 8.4 Integración con el Daily Scrum

El Daily incluye ahora estado de los agentes:

```
Daily con SDD:
  → ¿Qué completé? (incluyendo specs generadas/revisadas + agentes completados)
  → ¿En qué voy a trabajar? (incluyendo generar specs o supervisar agentes)
  → ¿Hay impedimentos? (incluir blockers de specs o fallos de agentes)

Tiempo adicional estimado por SDD en el Daily: +2 minutos
```

### 8.5 Comandos SDD disponibles

| Comando | Propósito |
|---------|-----------|
| `/spec:generate {task_id}` | Generar Spec desde una Task de Azure DevOps |
| `/spec:implement {spec_file}` | Implementar una Spec (lanza agente o asigna humano) |
| `/spec:review {spec_file}` | Revisar calidad de Spec o validar implementación |
| `/spec:status` | Dashboard de todas las Specs del sprint |
| `/agent:run {spec_file}` | Lanzar agente directamente sobre una Spec |

### 8.6 Cuándo NO usar SDD

- Tasks menores de 1h (overhead de escribir la Spec supera el beneficio)
- Hotfixes urgentes (P1) — ir directamente al flujo de hotfix (sección 6)
- Spikes de investigación — no hay output concreto que especificar
- La primera sprint del proyecto (equipo sin patrones de referencia)
