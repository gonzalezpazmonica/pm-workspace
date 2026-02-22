# Layer Assignment Matrix — Spec-Driven Development

> Matrix por defecto para proyectos .NET 8 Clean Architecture + CQRS.
> Cada proyecto puede sobreescribir esta matrix en su `CLAUDE.md` bajo la sección `sdd_layer_assignment`.

---

## Principio General

```
Capas que favorecen `agent`:  Código estructural, repetitivo, con patrón claro
Capas que favorecen `human`:  Lógica de dominio, decisiones de arquitectura, integraciones externas
```

El Tech Lead tiene siempre la última palabra. Ver §Override Manual.

---

## Matrix Principal por Capa y Tipo de Task

### 🔵 Domain Layer (`src/Domain/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| Crear nueva entidad raíz de agregado | `human` | Decisiones de identidad y encapsulación de dominio |
| Añadir Value Object simple (con validación) | `agent:single` | Patrón claro: constructor privado + factory method + equals |
| Añadir propiedad a entidad existente (sin lógica) | `agent:single` | Mecánico, sigue el patrón existente |
| Definir Domain Event | `agent:single` | Estructura fija: record inmutable con propiedades |
| Implementar regla de dominio compleja | `human` | Requiere entendimiento del negocio |
| Crear Domain Service (lógica inter-agregado) | `human` | Alto riesgo de diseño incorrecto |
| Definir interfaz de repositorio (`IPatientRepository`) | `agent:single` | Firma predecible, patrón idéntico entre módulos |
| Crear Specification (patrón Specification) | `agent:single` si spec simple / `human` si compleja | Depende de la lógica de filtrado |

---

### 🟢 Application Layer (`src/Application/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Command Handler** (Create/Update/Delete) | `agent:single` | Patrón fijo: validate → check business rules → create/modify → persist → return Result |
| **Query Handler** (Get by ID, List con paginación) | `agent:single` | Patrón fijo: fetch → map → return DTO |
| **Command con lógica de dominio compleja** | `human` | El agente puede equivocarse en la orquestación de reglas de negocio nuevas |
| **FluentValidation Validator** | `agent:single` | Completamente derivable de la Spec (tipos, restricciones, reglas de negocio simples) |
| **AutoMapper Profile** | `agent:single` | Mapeo mecánico entre entidades y DTOs |
| **DTO / Request / Response** | `agent:single` | Modelos de datos planos, sin lógica |
| **Pipeline Behavior** (logging, performance) | `human` | Afecta transversalmente a toda la app |
| **Integration Event Handler** | `human` | Requiere entender contratos de otros sistemas |
| **Application Service** (orquestación compleja) | `human` | Alto riesgo si la orquestación no está perfectamente especificada |

---

### 🟡 Infrastructure Layer (`src/Infrastructure/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Implementación de Repositorio** (EF Core) | `agent:single` | Patrón fijo: DbSet operations, AsNoTracking para queries, SaveChangesAsync |
| **Entity Configuration** (Fluent API EF Core) | `agent:single` | Completamente derivable del modelo de dominio |
| **Migration** EF Core | `human` ⚠️ | Las migraciones afectan a la BD de producción — siempre revisión humana |
| **External Service Client** (HTTP/REST) | `human` | Depende de documentación externa; alto riesgo de integración |
| **Email / Notification Service** | `agent:single` si sigue patrón existente / `human` si es nuevo | Verificar si hay un servicio similar ya implementado |
| **Caché Implementation** | `human` | Decisiones de TTL, invalidación y coherencia requieren juicio |
| **Background Service / Hosted Service** | `human` | Ciclo de vida y concurrencia requieren expertise |
| **Azure Service Bus / Event Grid Consumer** | `human` | Integración con mensajería: at-least-once, idempotencia |

---

### 🟠 API / Presentation Layer (`src/API/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Endpoint CRUD estándar** (Controller Action) | `agent:single` | Patrón fijo: [HttpPost/Get/Put/Delete] → dispatch command/query → return ActionResult |
| **Endpoint con lógica de autorización compleja** | `human` | Reglas de acceso: rol + tenant + ownership |
| **DTO de API** (separado del Application DTO) | `agent:single` | Modelos planos |
| **Swagger / OpenAPI annotations** | `agent:single` | Decoradores mecánicos |
| **Middleware** | `human` | Afecta toda la pipeline HTTP |
| **Authentication/Authorization config** | `human` | Seguridad: siempre revisión humana |
| **SignalR Hub** | `human` | Gestión de conexiones concurrentes |

---

### 🔴 Tests

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Unit Tests — Application Layer** (handlers, validators) | `agent:single` | Los test scenarios están en la Spec; el agente los implementa mecánicamente |
| **Unit Tests — Domain Layer** | `agent:single` si la Spec incluye escenarios / `human` si no | Requiere que la Spec defina los escenarios |
| **Integration Tests** | `human` | Requieren setup de infraestructura, datos de prueba, puertos |
| **API Tests (WebApplicationFactory)** | `agent:single` si sigue patrón existente | Verificar que hay tests API similares en el proyecto |
| **Performance / Load Tests** | `human` | Requieren decisiones sobre umbrales aceptables |
| **Mutation Tests** | `human` | Análisis de cobertura de mutaciones: requiere criterio |

---

### ⚪ Tareas Transversales

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Code Review** (`E1`) | `human` siempre | Por definición, el Code Review requiere un humano |
| **Documentación técnica** (README, ADRs) | `agent:single` con revisión humana | El agente genera el borrador; el humano lo valida |
| **Script SQL de migración de datos** | `human` ⚠️ | Afecta datos de producción |
| **Pipeline CI/CD** (YAML) | `agent:single` si sigue patrón existente | Si hay un pipeline similar de referencia |
| **Análisis de Performance / Profiling** | `human` | Requiere interpretación y decisiones |

---

## Reglas de Override

### Override por Condición del Proyecto

```yaml
# En projects/{proyecto}/CLAUDE.md → sección sdd_layer_assignment

sdd_layer_assignment:
  overrides:
    # Ejemplo: el equipo no está cómodo con agentes en Infrastructure todavía
    - layer: "Infrastructure"
      force: "human"
      reason: "Equipo sin experiencia con patrón Repository en este proyecto"

    # Ejemplo: sprint de alta presión, maximizar uso de agentes
    - task_category: "D1"  # Unit tests
      force: "agent:single"
      reason: "Sprint 2026-04: velocidad crítica, todos los tests por agente"

    # Ejemplo: módulo crítico de seguridad
    - module: "Authorization"
      force: "human"
      reason: "Módulo de autorización — siempre revisión humana sin excepción"
```

### Override Manual (caso a caso)

El PM o Tech Lead puede sobreescribir el developer_type en la Spec directamente:

```markdown
**Developer Type:** human    ← cambiado manualmente de agent:single
**Razón del override:** El PBI tiene criterios de aceptación incompletos en el área de validación
```

O en el work item en Azure DevOps con tags: `dev:human`, `dev:agent`, `dev:agent-team`

---

## Heurísticas de Decisión Rápida

### ✅ Task ideal para `agent:single`

Marca al menos 4 de estos:
- [ ] Existe al menos 1 ejemplo del mismo tipo en el codebase
- [ ] El output está completamente determinado por los inputs (sin decisiones de diseño)
- [ ] Los tipos de todos los campos están especificados
- [ ] Los test scenarios están escritos en la Spec
- [ ] El fichero de referencia (sección 6 de la Spec) está disponible
- [ ] No requiere conocimiento de sistemas externos sin documentar
- [ ] El Tech Lead puede verificar la corrección del output sin ejecutar el código

### ✅ Task ideal para `agent:team`

Además de los criterios de `agent:single`:
- [ ] La task es ≥ 6h de implementación
- [ ] Los roles están claramente separados (código producción vs tests)
- [ ] No hay dependencias fuerte entre implementador y tester al inicio
- [ ] Hay presupuesto de tokens disponible (agent:team consume ~3x más que agent:single)

### ❌ Task que DEBE ser `human`

Si cualquiera de estos aplica:
- La Spec tiene campos marcados como "TBD" o "a criterio del dev"
- Es la primera vez que el equipo implementa ese patrón
- La task involucra decisiones de seguridad (autenticación, autorización, cifrado)
- La task modifica la base de datos de producción (migraciones, scripts de datos)
- La task integra con un sistema externo sin documentación suficiente
- Los criterios de aceptación del PBI padre son vagos o incompletos
- La task es `E1: Code Review`
- El Tech Lead no puede verificar la corrección sin ejecutar el código en producción

---

## Impacto Esperado por Tipo de Task

| Capa/Tipo | Frecuencia | % Agentizable | Tiempo Ahorrado/Sprint |
|-----------|-----------|--------------|----------------------|
| Command Handlers (CRUD) | Alta | 80% | ~8h |
| Query Handlers | Alta | 85% | ~6h |
| Validators | Alta | 90% | ~4h |
| Repositorios EF Core | Media | 75% | ~3h |
| Unit Tests Application | Alta | 85% | ~10h |
| DTOs y Models | Alta | 95% | ~3h |
| Controllers CRUD | Media | 80% | ~4h |
| **Total estimado** | | | **~38h/sprint** |

*Estimación basada en un sprint de 2 semanas con equipo de 4 devs.*
*Ahorro real varía según calidad de las Specs y madurez del proceso SDD.*

---

## Referencias

→ Spec template: `spec-template.md`
→ Patrones de agent team: `agent-team-patterns.md`
→ Reglas de estimación: `docs/politica-estimacion.md`
→ Arquitectura del proyecto: `projects/{proyecto}/CLAUDE.md`
