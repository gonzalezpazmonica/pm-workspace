# Matriz de Asignación de Tareas — Java/Spring Boot Hexagonal Architecture

> Matriz de referencia para proyectos Java 21+ con Spring Boot, arquitectura hexagonal + CQRS.
> Cada proyecto puede sobreescribir esta matriz en su `CLAUDE.md` bajo la sección `sdd_layer_assignment`.

---

## Principio General

```
Capas que favorecen `agent`:  Código estructural, mapeos, handlers, validadores
Capas que favorecen `human`:  Reglas de negocio, decisiones de persistencia, integraciones
```

El Tech Lead tiene siempre la última palabra.

---

## Matriz Principal por Capa y Tipo de Task

### 🔵 Domain Layer (`src/main/java/domain/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| Crear entidad de dominio (Sealed class, Record) | `human` | Decisiones de identidad y encapsulación |
| Añadir Value Object (Record immutable) | `agent:single` | Patrón claro: Record con equals/hashCode automáticos |
| Definir interfaz de repositorio | `agent:single` | Firma predecible, patrón idéntico |
| Crear Domain Event (Record) | `agent:single` | Estructura fija: record con propiedades |
| Implementar regla de dominio compleja | `human` | Requiere entendimiento del negocio |

---

### 🟢 Application Layer (`src/main/java/application/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Command Handler (CRUD Create/Update/Delete)** | `agent:single` | Patrón fijo: validate → check rules → execute → persist → return Result |
| **Query Handler (Get by ID, List con paginación)** | `agent:single` | Patrón fijo: fetch → map → return DTO |
| **DTO / Request / Response** | `agent:single` | Modelos planos, sin lógica; Record o @Data |
| **Validator con FluentValidation** | `agent:single` | Completamente derivable de la Spec |
| **MapStruct Profile** (Entity ↔ DTO) | `agent:single` | Mapeo mecánico |
| **Command/Query con lógica de dominio compleja** | `human` | El agente puede equivocarse en la orquestación |
| **Application Service (orquestación) complejo** | `human` | Alto riesgo si no está perfectamente especificado |

---

### 🟡 Infrastructure Layer (`src/main/java/infrastructure/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Implementación de Repositorio (JPA)** | `agent:single` | Patrón fijo: operaciones CRUD derivables del schema |
| **Entity Configuration (Fluent API JPA)** | `agent:single` | Completamente derivable del modelo de dominio |
| **Migration (Flyway)** | `human` ⚠️ | Las migraciones afectan BD de producción — siempre revisión |
| **HTTP Client** (RestTemplate, WebClient) | `human` | Depende de documentación externa; alto riesgo |
| **Email / Notification Service** | `agent:single` si patrón existe / `human` si nuevo | Verificar si existe servicio similar |
| **Caché Implementation** (Redis) | `human` | Decisiones de TTL, invalidación y coherencia |
| **Background Service / Scheduler** | `human` | Ciclo de vida y concurrencia requieren expertise |
| **Messaging Consumer** (Kafka, RabbitMQ) | `human` | At-least-once, idempotencia, DLQ handling |

---

### 🟠 Adapter/Web Layer (`src/main/java/adapter/web/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Endpoint CRUD estándar** (REST) | `agent:single` | Patrón fijo: @Post/Get/Put/Delete → dispatch → return response |
| **Endpoint con validación de entrada** | `agent:single` | @Valid + DTO con Bean Validation |
| **Endpoint con autorización compleja** | `human` | Reglas de acceso: rol + tenant + ownership |
| **DTO de API** (separado de Application) | `agent:single` | Modelos planos |
| **Swagger / OpenAPI annotations** | `agent:single` | Decoradores mecánicos |
| **Global Exception Handler** | `human` | Afecta toda la aplicación |
| **Authentication/Authorization config** | `human` | Seguridad: siempre revisión humana |

---

### 🔴 Tests

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Unit Test — Handler (Command/Query)** | `agent:single` | Los test scenarios están en la Spec |
| **Unit Test — Domain** | `agent:single` si Spec incluye escenarios / `human` si no | Requiere definición clara de escenarios |
| **Integration Test** (JpaRepository + DB) | `human` | Require setup de infraestructura, TestContainers |
| **API Test** (WebMvcTest, MockMvc) | `agent:single` si patrón existe | Verificar que hay tests API similares |
| **Performance / Load Tests** | `human` | Decisiones sobre umbrales aceptables |

---

### ⚪ Tareas Transversales

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Code Review** | `human` siempre | Por definición, requiere un humano |
| **Documentación técnica** (README, ADRs) | `agent:single` con revisión humana | Agente genera borrador; humano valida |
| **Actualización de dependencias** | `human` | Cambios de breaking, compatibilidad |
| **Optimización de performance** | `human` | Decisiones de índices, caching, queries |

---

## Heurísticas de Decisión Rápida

### ✅ Task ideal para `agent:single`

Marca al menos 4 de estos:
- [ ] Existe al menos 1 ejemplo del mismo tipo en el codebase
- [ ] El output está completamente determinado por los inputs
- [ ] Los tipos de todos los campos están especificados
- [ ] Los test scenarios están en la Spec
- [ ] El fichero de referencia está disponible
- [ ] No requiere conocimiento de sistemas externos sin documentar
- [ ] El Tech Lead puede verificar sin ejecutar el código

### ✅ Task ideal para `agent:team`

Además de criterios de `agent:single`:
- [ ] La task es ≥ 6h de implementación
- [ ] Los roles están claramente separados (código + tests)
- [ ] No hay dependencias fuertes entre implementador y tester
- [ ] Hay presupuesto de tokens disponible

### ❌ Task que DEBE ser `human`

Si aplica:
- Spec con "TBD" o incompleta
- Primera vez implementando ese patrón
- Decisiones de seguridad (autenticación, autorización)
- Modificación de BD de producción (migraciones)
- Integración con sistema externo sin documentación
- Criterios de aceptación vagos
- Tech Lead no puede verificar sin ejecutar en producción

---

## Impacto Esperado por Tipo de Task

| Capa/Tipo | Frecuencia | % Agentizable | Tiempo Ahorrado/Sprint |
|-----------|-----------|--------------|----------------------|
| Command Handlers (CRUD) | Alta | 85% | ~8h |
| Query Handlers | Alta | 90% | ~6h |
| Validators (FluentValidation) | Alta | 90% | ~3h |
| Repositorios JPA | Media | 80% | ~3h |
| Unit Tests (Application) | Alta | 85% | ~10h |
| DTOs y Models | Alta | 95% | ~3h |
| Endpoints CRUD | Media | 80% | ~4h |
| **Total estimado** | | | **~37h/sprint** |

---

## Referencias

→ Spec template: `spec-template.md`
→ Patrones de agent team: `agent-team-patterns.md`
→ Convenciones Java: `rules/java-conventions.md`
→ Política de estimación: `docs/politica-estimacion.md`
