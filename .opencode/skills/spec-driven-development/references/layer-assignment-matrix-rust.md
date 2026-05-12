# Matriz de Asignación de Tareas — Rust/Axum Clean Architecture

> Matriz de referencia para proyectos Rust con Axum, arquitectura limpia hexagonal.
> Cada proyecto puede sobreescribir esta matriz en su `CLAUDE.md` bajo la sección `sdd_layer_assignment`.

---

## Principio General

```
Capas que favorecen `agent`:  Handlers tipados, queries simples, mappers
Capas que favorecen `human`:  Lógica de negocio, decisiones de lifetime/ownership, error handling
```

El Tech Lead tiene siempre la última palabra.

---

## Matriz Principal por Capa y Tipo de Task

### 🔵 Domain Crate (`domain/src/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| Crear entidad de dominio (struct, enum) | `human` | Decisiones de identidad, lifetimes, ownership |
| Añadir Value Object (newtype pattern, struct) | `agent-single` | Patrón claro: tipo fuerte con derive |
| Definir trait de repositorio | `agent-single` | Firma predecible, patrón idéntico |
| Crear Domain Event (struct, derive Clone) | `agent-single` | Estructura fija con propiedades |
| Implementar regla de negocio compleja | `human` | Requiere entendimiento del negocio |

---

### 🟢 Application Crate (`app/src/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Use Case / Service CRUD** | `agent-single` | Patrón: validate → check rules → execute → Result |
| **Query / Service para GetByID, List** | `agent-single` | Patrón: fetch → map → return Result |
| **DTO / Request structs (serde)** | `agent-single` | Modelos con serde::Serialize/Deserialize |
| **Use Case con lógica compleja** | `human` | El agente puede equivocarse en orquestación |
| **Error handling con thiserror/anyhow** | `agent-single` | Patrón: custom error type con Display |

---

### 🟡 Infrastructure Crate (`infra/src/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Implementación de Repositorio (sqlx)** | `agent-single` | Patrón: query → map → return Result |
| **HTTP Client (reqwest)** | `human` | Depende de documentación externa; alto riesgo |
| **Email / Notification Service** | `agent-single` si patrón existe / `human` si nuevo | Verificar si existe servicio similar |
| **Caché Implementation** (Redis) | `human` | Decisiones de TTL, invalidación y coherencia |
| **Background Job / Task** | `human` | Ciclo de vida, spawn logic, error recovery |
| **Mensaje Queue Consumer** | `human` | At-least-once, idempotencia, error handling |
| **Database Migration** (sqlx) | `human` ⚠️ | Las migraciones afectan BD de producción |

---

### 🟠 API Crate (`api/src/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **HTTP Handler CRUD** (Axum) | `agent-single` | Patrón: decode → call service → encode response |
| **Handler con validación** | `agent-single` | Axum extractors tipados |
| **Router setup y structure** | `agent-single` | Organización mecánica de rutas |
| **Middleware simple** (logging) | `agent-single` | Patrón predecible: tower middleware |
| **Authorization middleware complejo** | `human` | Decisiones de control de acceso |
| **Error responder** | `agent-single` | Error → HTTP response mapping |

---

### 🔴 Tests

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Unit Test — Use Case / Service** | `agent-single` | Los test scenarios están en la Spec |
| **Unit Test — Domain** | `agent-single` si Spec incluye escenarios / `human` si no | Requiere definición clara |
| **Integration Test** (sqlx + DB) | `human` | Require setup, TestContainers |
| **HTTP Handler Test** (Axum) | `agent-single` si patrón existe | Verificar que hay tests similares |
| **Property-based Tests** (proptest) | `human` | Decisiones de estrategias de testing |

---

## Impacto Esperado por Tipo de Task

| Capa/Tipo | Frecuencia | % Agentizable | Tiempo Ahorrado/Sprint |
|-----------|-----------|--------------|----------------------|
| Use Cases (CRUD) | Alta | 80% | ~5h |
| Query Services | Alta | 85% | ~4h |
| Handlers HTTP | Media | 80% | ~4h |
| Repositorios sqlx | Media | 75% | ~3h |
| Unit Tests | Alta | 80% | ~8h |
| DTOs / Structs | Alta | 90% | ~2h |
| **Total estimado** | | | **~26h/sprint** |

---

## Referencias

→ Spec template: `spec-template.md`
→ Convenciones Rust: `rules/rust-conventions.md`
→ Axum Best Practices: `docs/axum-guide.md`
