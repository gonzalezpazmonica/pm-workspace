# Sprint Planning — Sprint 2026-04

**Fecha:** 2026-03-02 · 10:00–14:00
**Facilitador:** Sofía Reyes (PM/SM)
**Asistentes:** Carlos, Laura, Diego, Ana + Claude (consulta de datos)

---

## Capacity Real del Sprint

| Persona | Días hábiles | Ausencias | Días efectivos | h/día | Factor foco | Capacity |
|---------|-------------|-----------|----------------|-------|-------------|---------|
| Sofía (PM) | 10 | 0 | 10 | 8 | 0.50 | 40h → 30h dev |
| Carlos (TL) | 10 | 0 | 10 | 8 | 0.80 | 48h (20% gestión) |
| Laura | 10 | 0 | 10 | 8 | 0.75 | 60h |
| Diego | 10 | 0 | 10 | 8 | 0.75 | 60h |
| Ana (QA) | 10 | 0 | 10 | 8 | 0.75 | 60h |
| 🤖 Claude Agent | ∞ | — | — | — | — | ~35h est. |

**Total humano:** 258h
**Total con agentes:** ~293h efectivas

---

## Sprint Goal

> CRUD completo de Salas y Reservas con API REST funcional y tests unitarios al 80%.

---

## PBIs Comprometidos

### AB#001 — Gestión de Salas (CRUD) — 3 SP — 11h → 22h con tests
**Descripción:** Endpoint REST para gestionar salas de reuniones: crear, listar, editar y eliminar.

**Criterios de Aceptación:**
- [ ] GET /api/salas devuelve listado de salas con id, nombre, capacidad, ubicación, disponible
- [ ] GET /api/salas/{id} devuelve el detalle de una sala o 404
- [ ] POST /api/salas crea una sala y devuelve 201 + el recurso creado
- [ ] PUT /api/salas/{id} actualiza una sala; devuelve 200 o 404
- [ ] DELETE /api/salas/{id} elimina una sala si no tiene reservas futuras; devuelve 204 o 409
- [ ] Las validaciones de negocio se aplican (nombre único, capacidad 1-200)
- [ ] Tests unitarios de los handlers con cobertura ≥ 80%

**Definition of Ready:** ✅ Criterios claros, reglas de negocio documentadas, estimación acordada

**Desglose de Tasks (propuesto por Claude `/pbi-decompose 001`):**

| # | Task | h | Act. | Asignado a | Developer Type |
|---|------|---|------|-----------|----------------|
| B1 | Entidad `Sala` + Value Objects (`SalaId`, `CapacidadSala`) | 2h | Dev | Carlos | human |
| B2 | Migration EF Core: tabla `Salas` + seed data (3 salas de ejemplo) | 1h | Dev | Diego | human |
| B3 | Handlers: CreateSala, UpdateSala, DeleteSala (+ Validators) | 4h | Dev | 🤖 agent | agent-single |
| B4 | Handlers: GetSalas (paginado), GetSalaById | 2h | Dev | 🤖 agent | agent-single |
| C1 | `ISalaRepository` + implementación EF Core | 2h | Dev | 🤖 agent | agent-single |
| C2 | `SalasController` (5 endpoints) + DTOs de API | 2h | Dev | 🤖 agent | agent-single |
| D1 | Unit Tests: CreateSalaCommandHandler (7 scenarios) | 2h | Dev | 🤖 agent | agent-single |
| D2 | Integration Tests: endpoints API Salas (Postman / WebApplicationFactory) | 2h | Dev | Ana | human |
| E1 | Code Review | 1h | Dev | Carlos (TL) | human |
| **Total** | | **18h** | | | 9h human / 9h agent |

---

### AB#002 — Gestión de Reservas (CRUD) — 5 SP — 18h → 32h con tests
**Descripción:** Endpoint REST para gestionar reservas de salas: crear, listar por sala/fecha, cancelar.

**Criterios de Aceptación:**
- [ ] GET /api/reservas?salaId={id}&fecha={YYYY-MM-DD} devuelve reservas del día
- [ ] GET /api/reservas/{id} devuelve detalle o 404
- [ ] POST /api/reservas crea una reserva; devuelve 201 o 409 (conflicto)
- [ ] DELETE /api/reservas/{id} cancela una reserva futura; devuelve 204 o 409
- [ ] Las validaciones de negocio se aplican (horario laboral, duración, solapamiento)
- [ ] Al intentar reservar una sala en conflicto, el error incluye la reserva conflictiva
- [ ] Tests unitarios de los handlers con cobertura ≥ 80%

**Definition of Ready:** ✅ Depende de AB#001 (entidad Sala debe existir)

**Desglose de Tasks:**

| # | Task | h | Act. | Asignado a | Developer Type |
|---|------|---|------|-----------|----------------|
| B1 | Entidad `Reserva` + Value Objects (`ReservaId`, `HorarioReserva`) | 3h | Dev | Carlos | human |
| B2 | Migration EF Core: tabla `Reservas` + FK a Salas | 1h | Dev | Diego | human |
| B3 | Handler: `CreateReservaCommand` + Validator | 4h | Dev | 🤖 agent | agent-single |
| B4 | Handlers: `GetReservasQuery` (filtro sala+fecha), `GetReservaByIdQuery` | 2h | Dev | 🤖 agent | agent-single |
| B5 | Handler: `CancelReservaCommand` + Validator | 2h | Dev | 🤖 agent | agent-single |
| C1 | `IReservaRepository` + implementación EF Core | 3h | Dev | 🤖 agent | agent-single |
| C2 | `ReservasController` (4 endpoints) + DTOs de API | 2h | Dev | 🤖 agent | agent-single |
| D1 | Unit Tests: CreateReservaCommandHandler (10 scenarios) | 3h | Dev | 🤖 agent | agent-single |
| D2 | Unit Tests: CancelReservaCommandHandler (4 scenarios) | 2h | Dev | 🤖 agent | agent-single |
| D3 | Integration Tests: endpoints API Reservas | 3h | Dev | Ana | human |
| E1 | Code Review | 1h | Dev | Carlos (TL) | human |
| **Total** | | **26h** | | | 11h human / 15h agent |

---

### AB#003 — Validación de conflictos de reservas — 3 SP — 11h
**Descripción:** Domain Service que detecta solapamientos de reservas en la misma sala y lo integra en el flujo de creación.

**Criterios de Aceptación:**
- [ ] El sistema detecta solapamientos y devuelve 409 con la reserva conflictiva en el body
- [ ] El servicio es invocado desde el CreateReservaCommandHandler (no lógica duplicada)
- [ ] Los tests cubren los 4 escenarios de solapamiento (antes, durante, después, exacto)
- [ ] Sin solapamiento → reserva se crea correctamente

**Nota:** Esta PBI requiere AB#001 y AB#002 comprometidos o en progreso.

**Desglose de Tasks:**

| # | Task | h | Act. | Asignado a | Developer Type |
|---|------|---|------|-----------|----------------|
| B3 | Domain Service: `ValidarConflictoReservaService` | 3h | Dev | Carlos | human |
| B4 | Integrar `ValidarConflictoReservaService` en `CreateReservaCommandHandler` | 2h | Dev | Laura | human |
| D1 | Unit Tests: `ValidarConflictoReservaService` (6 scenarios) | 2h | Dev | 🤖 agent | agent-single |
| D2 | Integration Test: escenario de conflicto end-to-end | 2h | Dev | Ana | human |
| E1 | Code Review | 1h | Dev | Carlos (TL) | human |
| **Total** | | **10h** | | | 8h human / 2h agent |

---

## Resumen de Capacity

| Persona | h comprometidas | h disponibles | Utilización |
|---------|----------------|--------------|-------------|
| Carlos (TL) | 11h code + 3h review | 48h | 29% ✅ (margen para imprevistos) |
| Laura | 2h | 60h | 3% ✅ |
| Diego | 2h | 60h | 3% ✅ (rellenar con refinement/soporte) |
| Ana | 7h | 60h | 12% ✅ (rellenar con regression testing) |
| 🤖 Claude Agent | 26h | ∞ | N/A |

> ⚠️ Laura y Diego tienen mucha capacidad libre en este primer sprint. Se usará para:
> - Setup del proyecto (.NET solution, pipelines CI/CD, configuración AzDO)
> - Refinement de las PBIs del Sprint 2026-05
> - Diego: creará la infraestructura Azure (App Service + SQL Server)

---

## Decisiones Técnicas del Planning

1. **¿Clean Architecture completa?** → Sí. Carlos insiste en hacerlo bien desde el principio aunque sea un proyecto pequeño.
2. **¿CQRS desde el inicio?** → Sí. Permite testear los handlers de forma aislada.
3. **¿Frontend ahora?** → No. Solo API REST + Swagger en Sprint 1. Frontend en Sprint 2.
4. **¿Las specs SDD para el agente?** → Carlos generará las specs de las tasks B3, B4, C1, C2 y D1 antes del miércoles.
5. **¿Orden de implementación?** → B1→B2 (humano) en paralelo con specs del agente → lanzar agente tras merge de B1+B2.

---

## Impedimentos Identificados

- Ninguno en el Sprint Planning
- Risk: El agente necesita que el código del Domain (B1, B2) esté mergeado antes de poder compilar sus implementaciones
