# Skill: PBI Decomposition, Estimation & Smart Assignment

## Propósito

Descomponer Product Backlog Items (PBIs) en Tasks técnicas, estimarlas en horas y asignarlas inteligentemente a los miembros del equipo en base a su perfil técnico, capacity disponible y contexto del proyecto.

Esta skill combina análisis de código fuente, conocimiento del dominio del proyecto y datos de Azure DevOps para producir descomposiciones realistas y asignaciones equilibradas.

---

## Triggers

- Comando `/pbi:decompose` — Descompone uno o varios PBIs
- Comando `/pbi:assign` — Solo asignación (si las Tasks ya existen)
- Comando `/pbi:plan-sprint` — Descompone + estima + asigna todos los PBIs candidatos para un sprint
- Petición directa: "descompón el PBI #1234", "crea las tareas del PBI #1234", "asigna las tareas del sprint"

---

## Contexto Requerido (Progressive Disclosure)

Antes de ejecutar, el agente DEBE leer estos ficheros en orden:

1. `CLAUDE.md` (raíz) — Contexto global, convenciones, conexión Azure DevOps
2. `projects/{proyecto}/CLAUDE.md` — Stack tecnológico, arquitectura, repos, particularidades
3. `projects/{proyecto}/reglas-negocio.md` — Reglas de dominio que afectan a la implementación
4. `projects/{proyecto}/equipo.md` — Perfiles, skills, dedicación, solapamientos
5. `docs/politica-estimacion.md` — Reglas de estimación, tabla de calibración, máximos por task
6. `docs/reglas-scrum.md` — DoR, DoD, WIP limits
7. `docs/flujo-trabajo.md` — Flujo de git, code review, testing

Si el PBI involucra código, el agente DEBE además inspeccionar el código fuente:

8. `projects/{proyecto}/source/` — Estructura de la solución, proyectos existentes, patrones en uso

---

## Fase 1: Análisis del PBI

### 1.1 Obtener el PBI de Azure DevOps

```bash
PAT=$(cat $AZURE_DEVOPS_PAT_FILE)

# Obtener el PBI completo con todos sus campos
curl -s -u ":$PAT" \
  "$AZURE_DEVOPS_ORG_URL/{proyecto}/_apis/wit/workitems/{id}?\$expand=all&api-version=7.1" | jq .
```

Extraer:
- **Title**: Qué se pide
- **Description**: Detalle funcional (puede contener HTML — parsear)
- **Acceptance Criteria**: Criterios de aceptación (CLAVE para definir Tasks de testing)
- **Story Points**: Estimación de complejidad ya acordada por el equipo
- **Priority**: Para determinar urgencia
- **Tags**: Pueden indicar módulo, tipo de trabajo, etc.
- **Related Links**: Dependencias con otros items, PBIs padre (Feature/Epic)
- **Discussion/History**: Comentarios que aporten contexto adicional

### 1.2 Analizar el Dominio Funcional

A partir del título, descripción y criterios de aceptación, el agente debe identificar:

- **Módulo(s) afectado(s)**: ¿Qué parte de la aplicación se toca? Mapear a carpetas del código fuente
- **Tipo de cambio**: Nueva funcionalidad / Modificación / Corrección / Refactor / Configuración
- **Capas involucradas**: API, Application (services/handlers), Domain (entidades), Infrastructure (repos/DB), Frontend, Tests
- **Integraciones externas**: ¿Se comunica con sistemas externos? ¿APIs de terceros? ¿Colas de mensajes?
- **Impacto en datos**: ¿Requiere migración de DB? ¿Nuevo modelo? ¿Cambio de schema?
- **Requisitos de seguridad**: ¿Afecta a autenticación, autorización, datos sensibles?
- **Requisitos de compliance**: Consultar `reglas-negocio.md` del proyecto

### 1.3 Inspección del Código Fuente (si aplica)

```bash
# Identificar ficheros relacionados con el módulo del PBI
find projects/{proyecto}/source/src -type f -name "*.cs" | grep -i "{modulo}" | head -20

# Revisar estructura del proyecto afectado
ls projects/{proyecto}/source/src/{ProyectoAfectado}/

# Buscar entidades/servicios existentes relacionados
grep -rl "{concepto_del_PBI}" projects/{proyecto}/source/src/ --include="*.cs" | head -15

# Revisar si hay tests existentes del módulo
find projects/{proyecto}/source/tests -name "*{modulo}*" -type f | head -10

# Inspeccionar patrones en uso (ej: si usan MediatR, AutoMapper, etc.)
grep -r "IRequestHandler\|IMapper\|IRepository" projects/{proyecto}/source/src/ --include="*.cs" -l | head -5
```

Esta inspección permite:
- Entender qué ya existe y qué hay que crear desde cero
- Detectar patrones arquitectónicos del proyecto (CQRS, Repository, Unit of Work, etc.)
- Estimar mejor el esfuerzo sabiendo la complejidad real del código
- Identificar ficheros que se van a tocar (para asignar al dev que los conoce mejor)

---

## Fase 2: Descomposición en Tasks

### 2.1 Plantilla de Descomposición

Cada PBI se descompone siguiendo este esquema adaptativo. NO todas las categorías aplican siempre — el agente debe evaluar cuáles son necesarias según el análisis de la Fase 1.

#### Categoría A: Diseño y Análisis (si el PBI es complejo, ≥ 5 SP)
- **Task A1**: Análisis técnico y diseño de la solución
  - Incluye: revisión de requisitos, diseño de interfaces/contratos, decisiones de arquitectura
  - Output: comentario en el PBI con el diseño propuesto o documento técnico
  - Estimación típica: 2-4h

#### Categoría B: Backend / API
- **Task B1**: Crear/modificar entidades de dominio y value objects
  - Solo si hay cambios en el modelo de dominio
  - Estimación: depende de complejidad del modelo (1-4h)

- **Task B2**: Crear/modificar migraciones de base de datos
  - Solo si hay cambios de schema
  - Incluye: migration EF Core + seed data si aplica
  - Estimación: 1-3h

- **Task B3**: Implementar capa de Application (services, handlers, validators)
  - Commands/Queries si usan CQRS, Services si no
  - Incluye validaciones de negocio
  - Estimación: 2-8h (esta es normalmente la task más grande)

- **Task B4**: Implementar/modificar endpoints API (Controllers)
  - Rutas, DTOs de request/response, mapping
  - Estimación: 1-4h

- **Task B5**: Implementar integración externa
  - Solo si hay comunicación con sistemas externos
  - Incluye: cliente HTTP, serialización, manejo de errores, retry policies
  - Estimación: 2-6h

#### Categoría C: Frontend (si aplica)
- **Task C1**: Implementar componente(s) UI
  - Páginas, componentes, formularios
  - Estimación: 2-8h según complejidad visual

- **Task C2**: Integrar con API backend
  - Servicios HTTP, manejo de estado, error handling
  - Estimación: 1-4h

#### Categoría D: Testing
- **Task D1**: Unit tests
  - Tests de la lógica de negocio (Application + Domain layers)
  - Cobertura mínima según `reglas-negocio.md` del proyecto
  - Estimación: 2-4h (proporcional a Tasks B)

- **Task D2**: Integration tests
  - Tests de endpoints API, acceso a DB con Testcontainers si aplica
  - Estimación: 2-4h

- **Task D3**: Tests manuales / validación QA
  - Solo si hay QA dedicado en el equipo
  - Incluye: ejecutar criterios de aceptación, testing exploratorio
  - Estimación: 1-3h

#### Categoría E: Transversal
- **Task E1**: Code review
  - Tiempo reservado para que el reviewer revise el PR
  - Estimación: 1-2h (dependiendo del tamaño del cambio)

- **Task E2**: Documentación
  - Solo si el cambio afecta a documentación de usuario o API (OpenAPI specs)
  - Estimación: 1-2h

- **Task E3**: Configuración / DevOps
  - Solo si hay cambios de configuración, variables de entorno, pipelines
  - Estimación: 1-2h

### 2.2 Reglas de Descomposición

1. **Máximo 8h por Task** — Si una task supera 8h, subdividir
2. **Mínimo 1h por Task** — No crear micro-tasks de menos de 1h
3. **Una Task = Un Responsable** — Cada task se asigna a una persona
4. **Activity siempre definida** — Cada task debe tener el campo Activity (Development/Testing/Documentation/Design)
5. **Coherencia con SP** — La suma de horas estimadas debe ser coherente con los Story Points del PBI (consultar tabla de calibración en `politica-estimacion.md`)
6. **No inflar** — Si un PBI de 2 SP solo necesita 2 Tasks, no crear 7 Tasks por completismo

### 2.3 Adaptación por Stack Tecnológico

El agente DEBE adaptar las tasks al stack del proyecto (leído de `projects/{proyecto}/CLAUDE.md`):

**Proyecto .NET con Clean Architecture / DDD:**
- Tasks B separadas por capa (Domain → Application → Infrastructure → API)
- Si usan MediatR: Task específica para Command/Query Handler
- Si usan FluentValidation: incluir validators en la task de Application

**Proyecto .NET con arquitectura simple (N-Layer):**
- Menos tasks B, pueden fusionarse (ej: "Implementar servicio + endpoint")
- No separar Domain de Application si no están separados en el código

**Proyecto Blazor:**
- Tasks C específicas para componentes Blazor (no confundir con JS/React)
- Considerar state management (si usan Fluxor, etc.)

**Proyecto con microservicios:**
- Evaluar si el PBI toca uno o varios servicios
- Si toca varios: una Task por servicio + task de integración/testing entre servicios

---

## Fase 3: Estimación Inteligente

### 3.1 Factores de Ajuste

La estimación base de cada Task se ajusta multiplicando por factores contextuales:

```
horas_ajustadas = horas_base × factor_complejidad × factor_conocimiento × factor_riesgo
```

**Factor de complejidad** (del código inspeccionado):
- Código nuevo en módulo existente bien estructurado: ×1.0
- Código nuevo en módulo legacy o mal documentado: ×1.3
- Refactor de código existente con alta acoplamiento: ×1.5
- Integración con sistema externo sin SDK: ×1.4
- Primera vez que el equipo toca este módulo: ×1.2

**Factor de conocimiento** (del developer asignado — ver Fase 4):
- Expert en el módulo (lo ha tocado en últimos 3 sprints): ×0.8
- Conoce el módulo (lo ha tocado alguna vez): ×1.0
- No conoce el módulo pero conoce el stack: ×1.2
- Junior o primera vez con este tipo de tarea: ×1.5

**Factor de riesgo**:
- Tiene dependencias externas no controladas: ×1.2
- Afecta a datos de producción / migración: ×1.3
- Requisito de compliance estricto (HIPAA, GDPR): ×1.2
- Primera implementación de un patrón nuevo: ×1.3

### 3.2 Validación de Coherencia

Tras estimar todas las Tasks:

```
total_horas = SUM(horas_ajustadas de todas las Tasks)
rango_esperado = lookup(StoryPoints, tabla_calibracion)  // de politica-estimacion.md

Si total_horas < rango_esperado.min:
  → Posiblemente faltan Tasks o la estimación es optimista
  
Si total_horas > rango_esperado.max:
  → Revisar si el PBI debería tener más SP o si hay tasks innecesarias
```

Alertar al PM si la desviación es > 30% respecto al rango esperado.

---

## Fase 4: Asignación Inteligente

### 4.1 Obtener Datos del Equipo

```bash
PAT=$(cat $AZURE_DEVOPS_PAT_FILE)

# 1. Obtener iteración actual
ITERATION=$(curl -s -u ":$PAT" \
  "$AZURE_DEVOPS_ORG_URL/{proyecto}/{equipo}/_apis/work/teamsettings/iterations?\$timeframe=current&api-version=7.1")
ITER_ID=$(echo $ITERATION | jq -r '.value[0].id')

# 2. Obtener capacidades
CAPACITIES=$(curl -s -u ":$PAT" \
  "$AZURE_DEVOPS_ORG_URL/{proyecto}/{equipo}/_apis/work/teamsettings/iterations/$ITER_ID/capacities?api-version=7.1")

# 3. Obtener carga actual (tasks ya asignadas con RemainingWork)
# Usar WIQL de sprint-management/references/wiql-patterns.md
```

### 4.2 Construir el Perfil de Disponibilidad

Para cada miembro del equipo, calcular:

```
disponibilidad = {
  nombre: "María García",
  azure_id: "maria@empresa.com",
  capacity_total: 48h,        // del sprint (calculado con capacity-planning skill)
  carga_asignada: 32h,        // SUM(RemainingWork) de tasks ya asignadas
  horas_libres: 16h,          // capacity_total - carga_asignada
  actividades: {
    "Development": 6h/día,
    "Testing": 0h/día
  }
}
```

### 4.3 Construir el Perfil Técnico

Leer de `projects/{proyecto}/equipo.md` y complementar con datos del código:

```
perfil_tecnico = {
  nombre: "María García",
  rol: "Senior Dev",
  skills: ["C#", ".NET", "EF Core", "Blazor", "PostgreSQL"],
  modulos_experta: ["Auth", "Patients", "API"],    // módulos que ha tocado recientemente
  modulos_conoce: ["Billing", "Reports"],            // módulos que ha tocado alguna vez
  fortalezas: "Backend, arquitectura, performance",
  areas_desarrollo: "Frontend Blazor (en crecimiento)",
  dedicacion: 100%,
  solapamiento: null                                  // o "50% en Proyecto Beta"
}
```

Para enriquecer automáticamente los módulos expertos, el agente puede consultar el historial de git:

```bash
# Quién ha tocado más el módulo Auth en los últimos 3 meses
git -C projects/{proyecto}/source log --since="3 months ago" --format="%an" -- "src/**/Auth*" | sort | uniq -c | sort -rn | head -5

# Quién ha hecho más commits en el proyecto recientemente
git -C projects/{proyecto}/source shortlog -sn --since="3 months ago" | head -10
```

### 4.4 Algoritmo de Asignación

Para cada Task, el agente evalúa a los candidatos con un scoring:

```
score(persona, task) = 
    peso_expertise     × match_expertise(persona, task)
  + peso_disponibilidad × disponibilidad_normalizada(persona)
  + peso_equilibrio    × factor_equilibrio(persona, equipo)
  + peso_crecimiento   × factor_crecimiento(persona, task)
```

**Pesos por defecto** (configurables):
- `peso_expertise`: 0.40 — Priorizar a quien mejor conoce el módulo
- `peso_disponibilidad`: 0.30 — Priorizar a quien tiene más horas libres
- `peso_equilibrio`: 0.20 — Distribuir carga equitativamente
- `peso_crecimiento`: 0.10 — Dar oportunidades de aprendizaje

**match_expertise** (0 a 1):
- 1.0 = Experto en el módulo exacto + Activity coincide con su rol
- 0.8 = Conoce el módulo + Activity coincide
- 0.6 = Experto en módulo similar + conoce el stack
- 0.4 = Conoce el stack pero no el módulo
- 0.2 = Junior, primera vez

**disponibilidad_normalizada** (0 a 1):
- `horas_libres / max(horas_libres del equipo)`
- Si horas_libres < horas_task: score = 0 (no cabe)

**factor_equilibrio** (0 a 1):
- Basado en la desviación estándar de carga del equipo
- Favorece asignar a quien tiene menos carga relativa
- `1 - (carga_persona / carga_maxima_equipo)`

**factor_crecimiento** (0 a 1):
- 1.0 si la Task es una oportunidad de aprendizaje identificada en equipo.md
- 0.5 si el módulo es nuevo para la persona pero tiene el skill base
- 0.0 en otros casos
- NUNCA aplicar si el PBI es de Priority 1 o hay riesgo alto

### 4.5 Restricciones Duras

El algoritmo NUNCA asigna si:
- La persona no tiene horas libres suficientes para la Task
- La Activity de la Task no coincide con ninguna Activity configurada en capacity (ej: no asignar Task de Testing a alguien con capacity solo en Development)
- La persona tiene solapamiento con otro proyecto y la Task es crítica/urgente
- La persona está de vacaciones durante el sprint (Days Off cubre todo el sprint)

### 4.6 Caso Especial: Code Review (Task E1)

El reviewer NUNCA es la misma persona que implementó las Tasks B/C.
Priorizar:
1. Tech Lead (si el cambio es arquitectónico)
2. Persona que más conoce el módulo (después del implementador)
3. Persona con menos carga de review asignada

---

## Fase 5: Ejecución en Azure DevOps

### 5.1 Crear Tasks

```bash
PAT=$(cat $AZURE_DEVOPS_PAT_FILE)

# Crear una Task como hija del PBI
curl -s -u ":$PAT" \
  -H "Content-Type: application/json-patch+json" \
  -X POST \
  "$AZURE_DEVOPS_ORG_URL/{proyecto}/_apis/wit/workitems/\$Task?api-version=7.1" \
  -d '[
    {"op": "add", "path": "/fields/System.Title", "value": "B3: Implementar handler CreatePatientCommand"},
    {"op": "add", "path": "/fields/System.AssignedTo", "value": "maria@empresa.com"},
    {"op": "add", "path": "/fields/System.IterationPath", "value": "{proyecto}\\Sprint 14"},
    {"op": "add", "path": "/fields/System.AreaPath", "value": "{proyecto}\\Backend"},
    {"op": "add", "path": "/fields/Microsoft.VSTS.Scheduling.OriginalEstimate", "value": 4},
    {"op": "add", "path": "/fields/Microsoft.VSTS.Scheduling.RemainingWork", "value": 4},
    {"op": "add", "path": "/fields/Microsoft.VSTS.Common.Activity", "value": "Development"},
    {"op": "add", "path": "/fields/System.Description", "value": "<p>Implementar CreatePatientCommand con MediatR handler, validación con FluentValidation, y persistencia via IPatientRepository.</p><p>Ficheros a crear/modificar:<br/>- src/Application/Commands/CreatePatientCommand.cs<br/>- src/Application/Commands/CreatePatientCommandHandler.cs<br/>- src/Application/Validators/CreatePatientCommandValidator.cs</p>"},
    {"op": "add", "path": "/relations/-", "value": {
      "rel": "System.LinkTypes.Hierarchy-Reverse",
      "url": "$AZURE_DEVOPS_ORG_URL/{proyecto}/_apis/wit/workitems/{pbi_id}"
    }}
  ]'
```

### 5.2 IMPORTANTE: Confirmación Previa

**ANTES de crear cualquier Task en Azure DevOps**, el agente DEBE:

1. Presentar la descomposición completa al usuario en formato tabla:

```
📋 PBI #1234: Implementar registro de pacientes (5 SP)

   Módulos afectados: Patients (nuevo), API (modificar)
   Capas: Domain + Application + Infrastructure + API + Tests
   Riesgo: Medio (nuevo módulo, pero patrón conocido)

   ┌────┬─────────────────────────────────────────────┬──────────┬──────┬──────────────┬────────────────┐
   │ #  │ Task                                        │ Horas    │ Act. │ Asignado a   │ Developer Type │
   ├────┼─────────────────────────────────────────────┼──────────┼──────┼──────────────┼────────────────┤
   │ B1 │ Crear entidad Patient + value objects        │ 2h       │ Dev  │ María G.     │ human          │
   │ B2 │ Migration EF Core: tabla Patients            │ 1h       │ Dev  │ María G.     │ human          │
   │ B3 │ Handler CreatePatientCommand + validación    │ 4h       │ Dev  │ 🤖 agent     │ agent:single   │
   │ B4 │ Endpoint POST /api/patients + DTO            │ 2h       │ Dev  │ 🤖 agent     │ agent:single   │
   │ D1 │ Unit tests CreatePatientCommandHandler       │ 3h       │ Dev  │ 🤖 agent     │ agent:single   │
   │ D2 │ Integration test endpoint POST /patients     │ 2h       │ Dev  │ Carlos R.    │ human          │
   │ D3 │ Validación criterios aceptación              │ 2h       │ Test │ Ana L.       │ human          │
   │ E1 │ Code review                                  │ 1h       │ Dev  │ Pedro T. (TL)│ human          │
   └────┴─────────────────────────────────────────────┴──────────┴──────┴──────────────┴────────────────┘
   
   Total: 17h (rango esperado para 5 SP: 8-16h → ⚠️ ligeramente por encima)
   
   💡 Razón: Módulo nuevo requiere crear entidad + migration desde cero
   
   📊 Impacto en capacity del equipo:
      María G.: 32h asignadas → 39h (+7h) de 48h disponibles ✅
      Carlos R.: 28h asignadas → 35h (+7h) de 48h disponibles ✅
      Ana L.: 18h asignadas → 20h (+2h) de 30h disponibles ✅
      Pedro T.: 40h asignadas → 41h (+1h) de 42h disponibles ⚠️ casi al límite
```

2. Preguntar: "¿Creo estas Tasks en Azure DevOps? ¿Quieres ajustar algo?"

3. Solo tras confirmación, ejecutar las llamadas API

---

## Fase 6: Post-Creación

Tras crear las Tasks:

1. **Actualizar el PBI**: Cambiar estado a "Committed" si todas las tasks tienen IterationPath del sprint actual
2. **Dejar comentario en el PBI**: Resumen de la descomposición con links a las Tasks creadas
3. **Registrar decisiones**: Si hubo factores de ajuste relevantes, documentar el razonamiento en el comentario
4. **Alertar si hay riesgos**: Sobre-asignación, dependencias identificadas, módulos desconocidos

---

## Slash Commands

### /pbi:decompose {id} [--project {nombre}] [--dry-run]

Descompone un PBI en Tasks con estimaciones y propuesta de asignación.
- `--dry-run`: Solo muestra la propuesta, no crea nada en Azure DevOps
- Default: dry-run (siempre mostrar antes de crear)

### /pbi:decompose-batch {id1,id2,id3} [--project {nombre}]

Descompone varios PBIs a la vez, optimizando las asignaciones en conjunto para equilibrar la carga global del equipo.

### /pbi:assign {pbi_id} [--rebalance]

Asigna (o reasigna) las Tasks existentes de un PBI según el algoritmo de asignación.
- `--rebalance`: Redistribuye considerando la carga actual del sprint completo

### /pbi:plan-sprint [--project {nombre}] [--sprint "Sprint N"]

Flujo completo para Sprint Planning:
1. Obtener PBIs candidatos (Approved, priorizados)
2. Calcular capacity del equipo
3. Proponer qué PBIs caben en el sprint
4. Descomponer cada PBI en Tasks
5. Asignar todas las Tasks optimizando la carga global
6. Presentar plan completo para confirmación

---

## Ejemplos de Adaptación por Contexto

### Ejemplo 1: PBI simple en proyecto con Clean Architecture

**PBI**: "Añadir campo email alternativo a la ficha de paciente" (2 SP)

Inspección del código → El módulo Patients ya existe, con entidad Patient, CreatePatientCommand, etc.

**Descomposición adaptada** (mínima, coherente con 2 SP):
- B1+B2: Añadir propiedad AlternativeEmail a Patient + migration (2h)
- B3: Modificar CreatePatientCommand/UpdatePatientCommand + validación email (2h)
- D1: Actualizar tests existentes (1h)
- E1: Code review (1h)

Total: 6h → Dentro del rango 2-4h × factor_nuevo_campo = adecuado

### Ejemplo 2: PBI complejo con integración externa

**PBI**: "Integrar con servicio de verificación de identidad RENIEC" (8 SP)

Inspección → No hay módulo de integración RENIEC. Sí hay un patrón HttpClientFactory para otras integraciones.

**Descomposición adaptada** (más detallada):
- A1: Análisis técnico — diseño del cliente RENIEC, mapping de respuesta (3h)
- B1: Crear entidad VerificationResult + value objects (2h)
- B5: Implementar ReniecClient con HttpClientFactory, retry policy, circuit breaker (6h → dividir en dos)
  - B5a: ReniecClient básico + serialización (4h)
  - B5b: Retry policy, circuit breaker, timeout, logging (3h)
- B3: Implementar VerifyIdentityCommand handler (4h)
- B4: Endpoint POST /api/patients/{id}/verify (2h)
- D1: Unit tests con mock de ReniecClient (3h)
- D2: Integration tests con WireMock para simular RENIEC (3h)
- D3: Testing manual con entorno de sandbox RENIEC (2h)
- E1: Code review (2h — TL por ser integración nueva)
- E2: Documentar integración en README del módulo (1h)

Total: 30h → Rango esperado para 8 SP: 16-24h → ⚠️ Por encima
Razón: Primera integración con sistema externo sin SDK. Ajustar SP a 13 o aceptar la desviación documentando.

### Ejemplo 3: Bug urgente (prioridad 1)

**Bug**: "Login falla con Azure AD cuando el token expira" (sin SP)

**Descomposición adaptada** (urgente, mínima):
- B3: Investigar + fix en TokenRefreshService (3h) — asignar al experto en Auth
- D1: Test que reproduzca el escenario de token expirado (2h) — mismo dev
- E1: Code review urgente (0.5h) — TL
- D3: Validación en staging (1h) — QA

Total: 6.5h. Asignar todo a la persona que más conoce el módulo Auth. NO aplicar factor_crecimiento. Maximizar expertise y velocidad.

---

## Configuración de Pesos (Personalizable)

En `projects/{proyecto}/CLAUDE.md` se pueden override los pesos de asignación:

```markdown
## Configuración de Asignación de Tasks
assignment_weights:
  expertise: 0.40
  availability: 0.30
  balance: 0.20
  growth: 0.10

# Para equipos junior, priorizar expertise:
# expertise: 0.55, availability: 0.25, balance: 0.15, growth: 0.05

# Para equipos senior que quieren cross-training:
# expertise: 0.25, availability: 0.25, balance: 0.20, growth: 0.30
```

---

## Dependencias

- Skill `sprint-management` — Para obtener iteración y work items
- Skill `capacity-planning` — Para calcular disponibilidad
- Skill `azure-devops-queries` — Para WIQL y API patterns
- `docs/politica-estimacion.md` — Tabla de calibración SP→horas
- `projects/{proyecto}/equipo.md` — Perfiles técnicos del equipo
