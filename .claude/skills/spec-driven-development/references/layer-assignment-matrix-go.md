# Matriz de Asignación de Tareas — Go Clean Architecture

> Matriz de referencia para proyectos Go 1.22+, arquitectura limpia hexagonal.
> Cada proyecto puede sobreescribir esta matriz en su `CLAUDE.md` bajo la sección `sdd_layer_assignment`.

---

## Principio General

```
Capas que favorecen `agent`:  Handlers mecánicos, queries simples, mappers
Capas que favorecen `human`:  Lógica de negocio, decisiones de concurrencia, integraciones
```

El Tech Lead tiene siempre la última palabra.

---

## Matriz Principal por Capa y Tipo de Task

### 🔵 Domain Layer (`internal/domain/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| Crear entidad de dominio (struct) | `human` | Decisiones de identidad y encapsulación |
| Añadir Value Object immutable (struct + private fields) | `agent:single` | Patrón claro: constructor factory + equals |
| Definir interfaz de repositorio | `agent:single` | Firma predecible, patrón idéntico |
| Crear Domain Event (struct) | `agent:single` | Estructura fija con propiedades |
| Implementar regla de negocio compleja | `human` | Requiere entendimiento del negocio |

---

### 🟢 Application Layer (`internal/application/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Use Case / Service CRUD** | `agent:single` | Patrón: validate → check rules → execute → return error |
| **Query / Service para GetByID, List** | `agent:single` | Patrón: fetch → map → return data |
| **DTO / Request structs** | `agent:single` | Modelos planos con validación tags |
| **Use Case con lógica compleja** | `human` | El agente puede equivocarse en orquestación |
| **Application Service (orquestación) complejo** | `human` | Alto riesgo si no está perfectamente especificado |

---

### 🟡 Infrastructure Layer (`internal/infrastructure/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Implementación de Repositorio (sqlc o sqlx)** | `agent:single` | Patrón: query → scan → return; derivable del schema |
| **HTTP Client** | `human` | Depende de documentación externa; alto riesgo |
| **Email / Notification Service** | `agent:single` si patrón existe / `human` si nuevo | Verificar si existe servicio similar |
| **Caché Implementation** (Redis) | `human` | Decisiones de TTL, invalidación y coherencia |
| **Background Job / Scheduled Task** | `human` | Ciclo de vida, concurrencia, context management |
| **Mensaje Queue Consumer** | `human` | At-least-once, idempotencia, error handling |
| **Database Migration** | `human` ⚠️ | Las migraciones afectan BD de producción |

---

### 🟠 Adapter/Handler Layer (`internal/adapter/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **HTTP Handler CRUD** | `agent:single` | Patrón: decode request → call service → encode response |
| **Handler con validación de entrada** | `agent:single` | Validación tags en structs |
| **Router setup y structure** | `agent:single` | Organización mecánica de rutas |
| **Middleware simple** (logging) | `agent:single` | Patrón predecible: wrap handler |
| **Authorization middleware complejo** | `human` | Decisiones de control de acceso |
| **Global error handling** | `human` | Afecta toda la aplicación |

---

### 🔴 Tests

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Unit Test — Use Case / Service** | `agent:single` | Los test scenarios están en la Spec |
| **Unit Test — Domain** | `agent:single` si Spec incluye escenarios / `human` si no | Requiere definición clara |
| **Integration Test** (sqlc + DB) | `human` | Require setup, TestContainers, fixtures |
| **HTTP Handler Test** | `agent:single` si patrón existe | Verificar que hay tests similares |
| **Performance / Load Tests** | `human` | Decisiones sobre umbrales |

---

## Impacto Esperado por Tipo de Task

| Capa/Tipo | Frecuencia | % Agentizable | Tiempo Ahorrado/Sprint |
|-----------|-----------|--------------|----------------------|
| Use Cases (CRUD) | Alta | 85% | ~6h |
| Query Services | Alta | 90% | ~4h |
| Handlers HTTP | Media | 85% | ~4h |
| Repositorios sqlc | Media | 80% | ~3h |
| Unit Tests | Alta | 85% | ~9h |
| DTOs / Structs | Alta | 95% | ~2h |
| **Total estimado** | | | **~28h/sprint** |

---

## Referencias

→ Spec template: `spec-template.md`
→ Convenciones Go: `rules/go-conventions.md`
→ sqlc Best Practices: `docs/sqlc-guide.md`
