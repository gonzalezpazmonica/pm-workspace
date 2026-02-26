# Matriz de Asignación de Tareas — Python/FastAPI Clean Architecture

> Matriz de referencia para proyectos Python 3.12+ con FastAPI y SQLAlchemy, arquitectura hexagonal.
> Cada proyecto puede sobreescribir esta matriz en su `CLAUDE.md` bajo la sección `sdd_layer_assignment`.

---

## Principio General

```
Capas que favorecen `agent`:  DTOs, queries, routers mecánicos, validators
Capas que favorecen `human`:  Lógica de dominio, decisiones de BD, integraciones externas
```

El Tech Lead tiene siempre la última palabra.

---

## Matriz Principal por Capa y Tipo de Task

### 🔵 Domain Layer (`src/domain/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| Crear entidad de dominio (dataclass, Pydantic BaseModel) | `human` | Decisiones de identidad y encapsulación |
| Añadir Value Object immutable (frozen dataclass, NamedTuple) | `agent:single` | Patrón claro: immutable + equals automáticos |
| Definir interfaz de repositorio (Protocol) | `agent:single` | Firma predecible, patrón idéntico |
| Crear Domain Event (dataclass) | `agent:single` | Estructura fija con propiedades |
| Implementar regla de dominio compleja | `human` | Requiere entendimiento del negocio |

---

### 🟢 Application Layer (`src/application/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Use Case / Service CRUD (Create/Update/Delete)** | `agent:single` | Patrón: validate → check rules → execute → return Result |
| **Query / Service para Get by ID, List** | `agent:single` | Patrón: fetch → map → return DTO |
| **DTO / Pydantic Schema** | `agent:single` | Modelos con validación automática |
| **Validator con Pydantic** | `agent:single` | Completamente derivable de la Spec |
| **Use Case con lógica de dominio compleja** | `human` | El agente puede equivocarse en orquestación |
| **Application Service (orquestación) complejo** | `human` | Alto riesgo si no está perfectamente especificado |

---

### 🟡 Infrastructure Layer (`src/infrastructure/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Implementación de Repositorio (SQLAlchemy)** | `agent:single` | Patrón: query → map → return; derivable del schema |
| **HTTP Client** (httpx async) | `human` | Depende de documentación externa; alto riesgo |
| **Email / Notification Service** | `agent:single` si patrón existe / `human` si nuevo | Verificar si existe servicio similar |
| **Caché Implementation** (Redis) | `human` | Decisiones de TTL, invalidación y coherencia |
| **Background Job / Scheduled Task** (Celery) | `human` | Ciclo de vida, concurrencia, retry logic |
| **Mensaje Queue Consumer** (Kafka, RabbitMQ) | `human` | At-least-once, idempotencia, DLQ handling |
| **Database Migration** (Alembic) | `human` ⚠️ | Las migraciones afectan BD de producción |

---

### 🟠 API Layer (`src/api/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Endpoint CRUD estándar** (FastAPI router) | `agent:single` | Patrón: @post/@get/@put/@delete → dispatch → return |
| **Endpoint con validación de entrada** | `agent:single` | Pydantic schema + path/query params |
| **Router grouping y estructura** | `agent:single` | Organización mecánica de APIRouter |
| **Dependency Injection setup** | `agent:single` | Patrón: Depends(get_db), Depends(get_service) |
| **Authorization/Permission setup** | `human` | Decisiones de control de acceso |
| **Global exception handler** | `human` | Afecta toda la aplicación |
| **OpenAPI/Swagger documentation** | `agent:single` | Tags, descriptions mecánicos |

---

### 🔴 Tests

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Unit Test — Use Case / Service** | `agent:single` | Los test scenarios están en la Spec |
| **Unit Test — Domain** | `agent:single` si Spec incluye escenarios / `human` si no | Requiere definición clara |
| **Integration Test** (SQLAlchemy + DB) | `human` | Require setup, TestContainers, fixtures |
| **API Test** (FastAPI TestClient) | `agent:single` si patrón existe | Verificar que hay tests similares |
| **Performance / Load Tests** | `human` | Decisiones sobre umbrales |

---

### ⚪ Tareas Transversales

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Code Review** | `human` siempre | Por definición |
| **Documentación técnica** (README, ADRs) | `agent:single` con revisión humana | Borrador automático |
| **Actualización de dependencias** | `human` | Breaking changes, compatibilidad |
| **Optimización de performance** | `human` | Decisiones de índices, queries |

---

## Impacto Esperado por Tipo de Task

| Capa/Tipo | Frecuencia | % Agentizable | Tiempo Ahorrado/Sprint |
|-----------|-----------|--------------|----------------------|
| Use Cases (CRUD) | Alta | 85% | ~7h |
| Query Services | Alta | 90% | ~5h |
| Validators (Pydantic) | Alta | 95% | ~3h |
| Repositorios SQLAlchemy | Media | 80% | ~3h |
| Unit Tests | Alta | 85% | ~10h |
| DTOs / Schemas | Alta | 95% | ~3h |
| Endpoints CRUD | Media | 85% | ~5h |
| **Total estimado** | | | **~36h/sprint** |

---

## Referencias

→ Spec template: `spec-template.md`
→ Convenciones Python: `rules/python-conventions.md`
→ FastAPI Best Practices: `docs/fastapi-guide.md`
