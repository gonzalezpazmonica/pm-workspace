# Fases 4-8 Detallado: Asignación, Sprint Planning, Validación y Métricas

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

1. Presentar la descomposición completa al usuario en formato tabla (ver ejemplos en Fase 6)
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

## Fase 7: Slash Commands

### /pbi-decompose {id} [--project {nombre}] [--dry-run]

Descompone un PBI en Tasks con estimaciones y propuesta de asignación.
- `--dry-run`: Solo muestra la propuesta, no crea nada en Azure DevOps
- Default: dry-run (siempre mostrar antes de crear)

### /pbi-decompose-batch {id1,id2,id3} [--project {nombre}]

Descompone varios PBIs a la vez, optimizando las asignaciones en conjunto para equilibrar la carga global del equipo.

### /pbi-assign {pbi_id} [--rebalance]

Asigna (o reasigna) las Tasks existentes de un PBI según el algoritmo de asignación.
- `--rebalance`: Redistribuye considerando la carga actual del sprint completo

### /pbi-plan-sprint [--project {nombre}] [--sprint "Sprint N"]

Flujo completo para Sprint Planning:
1. Obtener PBIs candidatos (Approved, priorizados)
2. Calcular capacity del equipo
3. Proponer qué PBIs caben en el sprint
4. Descomponer cada PBI en Tasks
5. Asignar todas las Tasks optimizando la carga global
6. Presentar plan completo para confirmación

---

## Fase 8: Ejemplos de Adaptación por Contexto

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
