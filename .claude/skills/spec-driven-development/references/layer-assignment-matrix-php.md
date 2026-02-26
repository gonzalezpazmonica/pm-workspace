# Matriz de Asignación de Tareas — PHP/Laravel DDD Architecture

> Matriz de referencia para proyectos PHP 8.3+ con Laravel, arquitectura Domain-Driven Design.
> Cada proyecto puede sobreescribir esta matriz en su `CLAUDE.md` bajo la sección `sdd_layer_assignment`.

---

## Principio General

```
Capas que favorecen `agent`:  Modelos, DTOs, validadores, controllers CRUD
Capas que favorecen `human`:  Lógica de dominio, decisiones de negocio, integraciones externas
```

El Tech Lead tiene siempre la última palabra.

---

## Matriz Principal por Capa y Tipo de Task

### 🔵 Domain Layer (`app/Domain/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| Crear entidad de dominio (Entity, Aggregate) | `human` | Decisiones de identidad y encapsulación |
| Añadir Value Object (immutable class) | `agent:single` | Patrón claro: constructor privado + factory + equals |
| Definir interfaz de repositorio | `agent:single` | Firma predecible, patrón idéntico |
| Crear Domain Event (class) | `agent:single` | Estructura fija con propiedades |
| Implementar regla de dominio compleja | `human` | Requiere entendimiento del negocio |
| Crear Specification (filtrado complejo) | `agent:single` si simple / `human` si complejo | Depende de lógica del criterio |

---

### 🟢 Application Layer (`app/Application/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Use Case / Action CRUD** | `agent:single` | Patrón: validate → check rules → execute → return |
| **Query / Finder para GetByID, List** | `agent:single` | Patrón: fetch → map → return DTO |
| **DTO / Data Transfer Object** | `agent:single` | Modelos con validación automática |
| **Laravel Validator** | `agent:single` | Completamente derivable de la Spec |
| **Use Case con lógica de dominio compleja** | `human` | El agente puede equivocarse en orquestación |
| **Service Orchestration** | `human` | Alto riesgo si no está perfectamente especificado |

---

### 🟡 Infrastructure Layer (`app/Infrastructure/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Implementación de Repositorio (Eloquent)** | `agent:single` | Patrón: query → map → return; derivable del modelo |
| **Eloquent Model** (sin lógica de negocio) | `agent:single` | Mapeo mecánico de propiedades |
| **HTTP Client** (GuzzleHttp) | `human` | Depende de documentación externa; alto riesgo |
| **Email / Notification Service** | `agent:single` si patrón existe / `human` si nuevo | Verificar si existe servicio similar |
| **Caché Implementation** (Redis, File) | `human` | Decisiones de TTL, invalidación y coherencia |
| **Background Job / Queue** (Queued Mail) | `agent:single` si patrón existe / `human` si nuevo | Ciclo de vida y retry logic |
| **Database Migration** | `human` ⚠️ | Las migraciones afectan BD de producción |

---

### 🟠 Http Layer (`app/Http/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Controller CRUD estándar** (REST) | `agent:single` | Patrón: validate → dispatch action → return response |
| **Request Validator** | `agent:single` | Laravel Form Request Rules derivables |
| **Resource** (JSON serialization) | `agent:single` | Mapeo de model → JSON |
| **Controller con autorización compleja** | `human` | Decisiones de control de acceso y policies |
| **Middleware transversal** | `human` | Afecta toda la aplicación |
| **API versioning** | `agent:single` si estructura existe | Organización mecánica de rutas |

---

### 🔴 Tests

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Unit Test — Action / Service** | `agent:single` | Los test scenarios están en la Spec |
| **Unit Test — Domain** | `agent:single` si Spec incluye escenarios / `human` si no | Requiere definición clara |
| **Feature Test** (Laravel tests) | `agent:single` | Integración controller + action con fixtures |
| **Integration Test** (Eloquent + DB) | `human` | Require setup, factories, seeding |
| **API Test** (HTTP assertions) | `agent:single` si patrón existe | Verificar que hay tests similares |

---

### ⚪ Tareas Transversales

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Code Review** | `human` siempre | Por definición |
| **Documentación técnica** (README, ADRs) | `agent:single` con revisión humana | Borrador automático |
| **Actualización de Laravel** (composer update) | `human` | Breaking changes, dependencias |
| **Optimización de performance** (eager loading, indexing) | `human` | Decisiones arquitectónicas |

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

### ❌ Task que DEBE ser `human`

Si aplica:
- Spec con "TBD" o incompleta
- Primera vez implementando ese patrón
- Decisiones de seguridad (autenticación, autorización)
- Modificación de BD de producción (migraciones)
- Integración con sistema externo sin documentación
- Criterios de aceptación vagos
- Tech Lead no puede verificar sin ejecutar

---

## Impacto Esperado por Tipo de Task

| Capa/Tipo | Frecuencia | % Agentizable | Tiempo Ahorrado/Sprint |
|-----------|-----------|--------------|----------------------|
| Actions CRUD | Alta | 85% | ~7h |
| Queries/Finders | Alta | 90% | ~4h |
| Validators (Form Requests) | Alta | 95% | ~3h |
| Controllers CRUD | Media | 85% | ~5h |
| Resources (JSON) | Alta | 95% | ~2h |
| Repositorio Eloquent | Media | 80% | ~3h |
| Unit Tests | Alta | 85% | ~9h |
| **Total estimado** | | | **~33h/sprint** |

---

## Referencias

→ Spec template: `spec-template.md`
→ Convenciones PHP: `rules/php-conventions.md`
→ Laravel Best Practices: `docs/laravel-guide.md`
