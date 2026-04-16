# Equipo — Proyecto Sala Reservas (Test)

> Equipo ficticio para el proyecto de test del PM-Workspace.

## Configuración de Capacidad

```
HORAS_DIA_DEFAULT     = 8
FACTOR_FOCO           = 0.75
SPRINT_DIAS_HABILES   = 10
CAPACITY_DEFAULT_H    = 60     # 10 días × 8h × 0.75
```

---

## Miembros del Equipo

### Sofía Reyes — PM / Scrum Master
```
Email:              sofia.reyes@empresa.com
AzureDevOps alias:  sofia.reyes@empresa.com
Rol:                Project Manager, Scrum Master
Especialización:    Gestión de proyectos, Azure DevOps, reporting
Horas/día:          8
Capacidad sprint:   30h  (50% dedicación — gestiona 2 proyectos)
WIP máximo:         N/A  (no desarrolla)
```
**Notas:** No toma tasks de desarrollo. Se encarga de ceremonias, imputaciones y reporting.

---

### Carlos Mendoza — Tech Lead / Senior .NET
```
Email:              carlos.mendoza@empresa.com
AzureDevOps alias:  carlos.mendoza@empresa.com
Rol:                Tech Lead, Developer Backend Senior
Especialización:    .NET Core, Clean Architecture, DDD, SQL Server
Horas/día:          8
Capacidad sprint:   48h  (80% coding — 20% gestión técnica)
WIP máximo:         2 items Active
```
**Notas:** Lidera el Code Review (E1). Toma las tasks de Domain Layer y decisiones arquitectónicas.

---

### Laura Sánchez — Developer Full Stack
```
Email:              laura.sanchez@empresa.com
AzureDevOps alias:  laura.sanchez@empresa.com
Rol:                Developer Full Stack
Especialización:    .NET 8, Angular, REST APIs, xUnit
Horas/día:          8
Capacidad sprint:   60h
WIP máximo:         2 items Active
```

---

### Diego Torres — Developer Backend
```
Email:              diego.torres@empresa.com
AzureDevOps alias:  diego.torres@empresa.com
Rol:                Developer Backend
Especialización:    .NET, EF Core, SQL, Integration Tests
Horas/día:          8
Capacidad sprint:   60h
WIP máximo:         2 items Active
```

---

### Ana Morales — QA Engineer
```
Email:              ana.morales@empresa.com
AzureDevOps alias:  ana.morales@empresa.com
Rol:                QA / Testing
Especialización:    Testing manual, Postman, integration testing, criterios de aceptación
Horas/día:          8
Capacidad sprint:   60h
WIP máximo:         3 items Active
```
**Notas:** Define criterios de aceptación junto con Carlos. Ejecuta D2 (integration tests) y D3 (validación manual).

---

## Festivos y Vacaciones (Sprint 2026-04)

```
Festivos en el sprint (02/03–13/03):  Ninguno
Sofía:   Sin ausencias
Carlos:  Sin ausencias
Laura:   Sin ausencias
Diego:   Sin ausencias
Ana:     Sin ausencias
```

---

## Capacity por Sprint

| Sprint | Sofía | Carlos | Laura | Diego | Ana | 🤖 Agentes | Total |
|--------|-------|--------|-------|-------|-----|-----------|-------|
| 2026-04 (02/03-13/03) | 30h | 48h | 60h | 60h | 60h | ~35h est. | ~293h |
| 2026-05 (16/03-27/03) | 30h | 48h | 60h | 60h | 60h | ~35h est. | ~293h |

---

## Matriz de Habilidades

| Habilidad | Carlos | Laura | Diego | Ana |
|-----------|--------|-------|-------|-----|
| .NET Core / C# | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| Clean Architecture / DDD | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ | — |
| EF Core / SQL Server | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | — |
| REST API / ASP.NET Core | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| xUnit / Testing | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| Azure DevOps / CI-CD | ⭐⭐⭐ | ⭐⭐ | ⭐ | ⭐ |
| CQRS / MediatR | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ | — |
| Angular | ⭐ | ⭐⭐⭐ | ⭐ | — |

⭐ Básico | ⭐⭐ Competente | ⭐⭐⭐ Experto

---

## Agentes Claude — Developer Virtuales (SDD)

### claude-agent-opus — Implementador
```
ID (Azure DevOps tag):  dev:agent
Modelo:                 claude-opus-4-7
Rol:                    Application Layer + Infrastructure (cuando hay patrón de referencia)
Coste estimado:         ~$0.60-1.20 por spec
```

**Tasks de este proyecto para el agente:**
- CreateSalaCommandHandler, UpdateSalaCommandHandler, DeleteSalaCommandHandler
- GetSalasQueryHandler, GetSalaByIdQueryHandler
- CreateReservaCommandHandler, CancelReservaCommandHandler
- GetReservasQueryHandler (con filtro por sala y fecha)
- Todos los FluentValidation Validators
- ISalaRepository + EF Core impl, IReservaRepository + EF Core impl
- SalasController, ReservasController
- AutoMapper Profiles

### claude-agent-haiku — Tester
```
ID (Azure DevOps tag):  dev:agent-fast
Modelo:                 claude-haiku-4-5-20251001
Rol:                    Unit Tests para toda la capa Application
Coste estimado:         ~$0.02-0.05 por spec de tests
```

### Asignación estimada del sprint
```
Human tasks (Carlos + Laura + Diego + Ana):  Domain, Migraciones, Integration Tests, Code Review
Agent tasks (claude-agent):                  Application Layer (~9 handlers + validators), Infrastructure (~2 repos), API (~2 controllers), Unit Tests (~11 specs)

Horas humanas comprometidas:   ~163h de 258h disponibles (63%)
Horas de agente estimadas:     ~35h
Total efectivo:                ~198h
```
