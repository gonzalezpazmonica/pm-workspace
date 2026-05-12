# Matriz de Asignación de Tareas — TypeScript/Node.js Clean Architecture

> Matriz de referencia para proyectos TypeScript con Node.js, arquitectura limpia + CQRS.
> Cada proyecto puede sobreescribir esta matriz en su `CLAUDE.md` bajo la sección `sdd_layer_assignment`.

---

## Principio General

```
Capas que favorecen `agent`:  Código estructural, repetitivo, con patrón claro
Capas que favorecen `human`:  Lógica de dominio, decisiones de arquitectura, integraciones externas
```

El Tech Lead tiene siempre la última palabra. Ver §Override Manual.

---

## Matriz Principal por Capa y Tipo de Task

### 🔵 Domain Layer (`src/domain/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| Crear nueva entidad de dominio (clase o interface) | `human` | Decisiones de encapsulación e invariantes de dominio |
| Añadir Value Object inmutable | `agent-single` | Patrón claro: constructor privado + factory + equals |
| Definir interfaz de repositorio | `agent-single` | Firma predecible, patrón idéntico entre módulos |
| Crear Domain Event | `agent-single` | Estructura fija: interfaz con propiedades del evento |
| Implementar regla de negocio compleja | `human` | Requiere entendimiento profundo del dominio |
| Crear servicio de dominio (lógica inter-agregado) | `human` | Alto riesgo de diseño incorrecto |

---

### 🟢 Application Layer (`src/application/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Use Case / Command Handler** (CRUD básico) | `agent-single` | Patrón fijo: validar → verificar reglas → ejecutar → retornar Result |
| **Query Handler** (Get by ID, listar con paginación) | `agent-single` | Patrón fijo: buscar → mapear → retornar DTO |
| **DTO / Request / Response** | `agent-single` | Modelos planos, sin lógica; completamente determinado por inputs |
| **Validator con reglas de dominio simples** | `agent-single` | Implementable directamente desde la Spec |
| **Use Case con lógica de dominio compleja** | `human` | El agente puede equivocarse orquestando reglas nuevas |
| **Servicio de aplicación (orquestación) complejo** | `human` | Alto riesgo si la orquestación no está perfectamente especificada |
| **Event handler de integración** | `human` | Requiere entender contratos de otros sistemas |
| **Mapper manual entre capas** | `agent-single` | Mapeo mecánico; si es repetitivo, usar librería (MapStruct TypeScript) |

---

### 🟡 Infrastructure Layer (`src/infrastructure/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Implementación de Repositorio** (Prisma) | `agent-single` | Patrón fijo: operaciones CRUD derivables del schema |
| **HTTP Client** (integración con API externa) | `human` | Depende de documentación externa; alto riesgo de integración |
| **Email / Notification Service** | `agent-single` si sigue patrón existente / `human` si es nuevo | Verificar si existe servicio similar implementado |
| **Caché Implementation** (Redis) | `human` | Decisiones de TTL, invalidación y coherencia requieren juicio |
| **Background Job / Scheduled Task** | `human` | Ciclo de vida, concurrencia y recuperación de fallos requieren expertise |
| **Mensaje Queue Consumer** (Kafka, RabbitMQ) | `human` | At-least-once, idempotencia, dead-letter handling requieren expertise |
| **Database migration** (Prisma) | `human` ⚠️ | Las migraciones afectan BD de producción — siempre revisión humana |

---

### 🟠 API Layer (`src/api/`)

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Endpoint CRUD estándar** (Express/NestJS) | `agent-single` | Patrón fijo: [POST/GET/PUT/DELETE] → dispatch use case → return response |
| **Endpoint con validación de entrada** (DTO + Zod) | `agent-single` | Patrón completamente derivable del schema |
| **Route grouping y estructura REST** | `agent-single` | Organización mecánica de routers |
| **Middleware transversal** (logging, timing) | `human` | Afecta toda la pipeline HTTP |
| **Autorización compleja** (roles + ownership) | `human` | Lógica de control de acceso: requiere revisión de seguridad |
| **Error handler global** | `human` | Afecta a toda la app; decisiones sobre respuestas de error |
| **OpenAPI/Swagger annotations** | `agent-single` | Decoradores mecánicos si la estructura ya existe |

---

### 🔴 Tests

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Unit Tests — Application Layer** (use cases, validators) | `agent-single` | Los escenarios están en la Spec; implementación mecánica |
| **Unit Tests — Domain Layer** | `agent-single` si la Spec incluye escenarios / `human` si no | Requiere que la Spec defina claramente los escenarios de test |
| **Integration Tests** (Prisma + DB) | `human` | Require setup de infraestructura, datos de prueba, fixtures |
| **API Tests** (supertest o similar) | `agent-single` si sigue patrón existente | Verificar que hay tests API similares en el proyecto |
| **End-to-End Tests** | `human` | Requieren flujos completos de usuario y decisiones de coverage |
| **Performance / Load Tests** | `human` | Decisiones sobre umbrales aceptables |

---

### ⚪ Tareas Transversales

| Tipo de Tarea | Developer Type | Justificación |
|--------------|---------------|---------------|
| **Code Review** | `human` siempre | Por definición, requiere un humano |
| **Documentación técnica** (README, ADRs) | `agent-single` con revisión humana | El agente genera borrador; humano valida |
| **Configuración de seguridad** (JWT, CORS, HTTPS) | `human` | Decisiones de seguridad: siempre revisión humana |
| **Migration script** | `human` ⚠️ | Afecta a datos de producción |

---

## Heurísticas de Decisión Rápida

### ✅ Task ideal para `agent-single`

Marca al menos 4 de estos:
- [ ] Existe al menos 1 ejemplo del mismo tipo en el codebase
- [ ] El output está completamente determinado por los inputs
- [ ] Los tipos de todos los campos están especificados
- [ ] Los test scenarios están escritos en la Spec
- [ ] El fichero de referencia (sección de referencias de la Spec) está disponible
- [ ] No requiere conocimiento de sistemas externos sin documentar
- [ ] El Tech Lead puede verificar la corrección sin ejecutar el código

### ✅ Task ideal para `agent-team`

Además de los criterios de `agent-single`:
- [ ] La task es ≥ 6h de implementación
- [ ] Los roles están claramente separados (código producción vs tests)
- [ ] No hay dependencias fuertes entre implementador y tester al inicio
- [ ] Hay presupuesto de tokens disponible (agent-team consume ~3x más que agent-single)

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
| Use Case Handlers (CRUD) | Alta | 85% | ~8h |
| Query Handlers | Alta | 90% | ~6h |
| DTOs y Models | Alta | 95% | ~4h |
| Validators | Alta | 85% | ~3h |
| Repositorio Prisma | Media | 80% | ~4h |
| Unit Tests Application | Alta | 85% | ~10h |
| Endpoints CRUD | Media | 80% | ~4h |
| **Total estimado** | | | **~39h/sprint** |

*Estimación basada en un sprint de 2 semanas con equipo de 4 devs.*
*Ahorro real varía según calidad de las Specs y madurez del proceso SDD.*

---

## Referencias

→ Spec template: `spec-template.md`
→ Patrones de agent team: `agent-team-patterns.md`
→ Convenciones TypeScript: `rules/typescript-conventions.md`
→ Política de estimación: `docs/politica-estimacion.md`
