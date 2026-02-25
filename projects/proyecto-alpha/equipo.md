# Equipo — Proyecto Alpha

> Composición del equipo, disponibilidad y especialización. Actualizar cuando cambien los recursos.

## Configuración de Capacidad

```
HORAS_DIA_DEFAULT     = 8          # jornada estándar
FACTOR_FOCO           = 0.75       # 75% productivo
SPRINT_DIAS_HABILES   = 10         # sprint de 2 semanas
CAPACITY_DEFAULT_H    = 60         # 10 días × 8h × 0.75 = 60h por persona por sprint
```

---

## Miembros del Equipo

### Juan García — Tech Lead / Senior Developer
```
Email:              juan.garcia@empresa.com
AzureDevOps alias:  juan.garcia@empresa.com
Rol:                Tech Lead, Developer Backend
Especialización:    .NET Core, SQL Server, Arquitectura
Horas/día:          8
Capacidad sprint:   60h (sin festivos ni vacaciones)
WIP máximo:         2 items Active
```
**Notas:** Lidera el Code Review. Asignarle items de arquitectura y decisiones técnicas complejas.

---

### Ana López — Developer Full Stack
```
Email:              ana.lopez@empresa.com
AzureDevOps alias:  ana.lopez@empresa.com
Rol:                Developer Full Stack
Especialización:    .NET Core, Angular, REST APIs
Horas/día:          8
Capacidad sprint:   60h
WIP máximo:         2 items Active
```

---

### Pedro Ruiz — Developer Backend
```
Email:              pedro.ruiz@empresa.com
AzureDevOps alias:  pedro.ruiz@empresa.com
Rol:                Developer Backend
Especialización:    .NET, EF Core, Azure Services
Horas/día:          8
Capacidad sprint:   60h
WIP máximo:         2 items Active
```

---

### María Fernández — QA Engineer
```
Email:              maria.fernandez@empresa.com
AzureDevOps alias:  maria.fernandez@empresa.com
Rol:                QA / Testing
Especialización:    Testing manual, Selenium, Postman, BDD
Horas/día:          8
Capacidad sprint:   60h
WIP máximo:         3 items (puede hacer testing en paralelo)
```
**Notas:** Coordina con Tech Lead para definir criterios de aceptación. Revisa PRs desde perspectiva funcional.

---

## Festivos y Vacaciones del Equipo

> Actualizar antes de cada sprint. Claude Code usará esta información para calcular la capacity real.

### Festivos de la Comunidad de Madrid (2026)
```
2026-01-01  Año Nuevo
2026-01-06  Reyes Magos
2026-04-02  Jueves Santo
2026-04-03  Viernes Santo
2026-05-01  Día del Trabajo
2026-05-02  Día de la Comunidad de Madrid
2026-10-12  Día de la Hispanidad
2026-11-01  Todos los Santos
2026-11-09  Día de la Almudena
2026-12-06  Día de la Constitución
2026-12-08  Inmaculada Concepción
2026-12-25  Navidad
```

### Vacaciones individuales planificadas
```
Juan García:     Semana Santa (30/03 - 03/04/2026)
Ana López:       Sin vacaciones planificadas hasta agosto
Pedro Ruiz:      22/02 - 01/03 (ajustar sprint)
María Fernández: Sin vacaciones planificadas en Q1
```

> **Importante:** Registrar siempre los días off en Azure DevOps (sprint → capacity → días off de la persona) para que el burndown sea preciso.

---

## Disponibilidad por Sprint

Tabla de capacity estimada por persona para los próximos sprints:

| Sprint | Juan | Ana | Pedro | María | Total equipo |
|--------|------|-----|-------|-------|--------------|
| 2026-04 (02/03-13/03) | 60h | 60h | 50h* | 60h | 230h |
| 2026-05 (16/03-27/03) | 60h | 60h | 60h | 60h | 240h |
| 2026-06 (30/03-10/04) | 45h** | 60h | 60h | 60h | 225h |

*Pedro tiene 1 día de ajuste por vacaciones anteriores
**Juan tiene Semana Santa del 30/03 al 03/04

---

## Matriz de Habilidades

| Habilidad | Juan | Ana | Pedro | María |
|-----------|------|-----|-------|-------|
| .NET Core / C# | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| Angular / TypeScript | ⭐ | ⭐⭐⭐ | ⭐ | ⭐ |
| SQL Server / EF Core | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | — |
| Azure DevOps / CI-CD | ⭐⭐⭐ | ⭐ | ⭐⭐ | ⭐ |
| Testing / QA | ⭐⭐ | ⭐⭐ | ⭐ | ⭐⭐⭐ |
| Arquitectura | ⭐⭐⭐ | ⭐ | ⭐⭐ | — |
| Azure Services | ⭐⭐ | ⭐ | ⭐⭐⭐ | — |

⭐ Básico | ⭐⭐ Competente | ⭐⭐⭐ Experto

---

## Agentes Claude — Developer Virtuales (SDD)

> Los agentes Claude son "developers" del equipo en el contexto de Spec-Driven Development.
> No consumen capacity humana ni aparecen en las métricas de Azure DevOps de personas.
> Su "capacidad" es ilimitada en paralelo, pero está limitada por la calidad de las Specs y el budget de tokens.

### claude-agent-opus — Implementador Principal
```
ID (Azure DevOps tag):  dev:agent
Modelo:                 claude-opus-4-6
Rol:                    Developer virtual — código de producción complejo
Capacidad efectiva:     Ilimitada (paralelo), limitada por presupuesto de tokens
Coste estimado:         ~$0.60-1.20 por spec implementada
WIP máximo:             Sin límite técnico (considerar 5 paralelos max por sprint)
```

**Tipos de tasks asignables:**
- Command Handlers (Application Layer) — patrón CQRS
- Query Handlers con lógica de mapeo
- Repositorios EF Core (Infrastructure Layer)
- Entity Configurations (Fluent API)
- Controllers CRUD estándar (API Layer)

**Limitaciones (NO asignar):**
- Lógica de dominio nueva o compleja (Domain Layer — siempre humano)
- Integraciones con sistemas externos sin documentación completa
- Migraciones de base de datos (riesgo producción)
- Code Review (E1) — siempre humano
- Decisiones de arquitectura

---

### claude-agent-haiku — Tester / Scaffolding
```
ID (Azure DevOps tag):  dev:agent-fast
Modelo:                 claude-haiku-4-5-20251001
Rol:                    Developer virtual — tests, DTOs, validators, mappers
Capacidad efectiva:     Ilimitada (paralelo), muy bajo coste
Coste estimado:         ~$0.02-0.05 por spec de tests
WIP máximo:             Sin límite técnico
```

**Tipos de tasks asignables:**
- Unit Tests (Application Layer) — siempre que los escenarios estén en la Spec
- FluentValidation Validators
- AutoMapper Profiles
- DTOs / Request / Response records
- Entity Configurations simples

**Limitaciones:**
- No usar para lógica compleja — puede simplificar en exceso
- Los tests que genera requieren revisión de cobertura por el Tech Lead

---

### claude-agent-team — Equipo Especializado
```
ID (Azure DevOps tag):  dev:agent-team
Composición:            claude-agent-opus (implementador) + claude-agent-haiku (tester)
Patrón:                 impl-test (paralelo) o impl-test-review (con reviewer)
Coste estimado:         ~$0.80-1.80 por spec
WIP máximo:             Máx 3 equipos en paralelo por sprint (limitación de gestión)
```

**Cuándo usar agent-team:**
- Tasks ≥ 6h bien definidas
- Código producción + tests deben implementarse en el mismo sprint
- La velocidad es crítica

---

## Reglas de Asignación a Agentes

```yaml
# Estas reglas están en la matrix de SDD. Resumen ejecutivo:

Favorece agente:
  - Task tiene patrón claro y ejemplo de referencia en el código
  - Output es determinístico dado el input
  - Reglas de negocio 100% especificadas en la Spec
  - No requiere decisiones de diseño no descritas

Fuerza humano:
  - Cualquier tarea E1 (Code Review)
  - Lógica de dominio nueva o ambigua
  - Integraciones con sistemas externos poco documentados
  - Migraciones de datos o cambios de esquema
  - Primera vez que el equipo implementa ese patrón
```

## Capacity Total con Agentes

| Sprint | Juan | Ana | Pedro | María | 🤖 Agentes | Total efectivo |
|--------|------|-----|-------|-------|-----------|----------------|
| 2026-04 | 60h | 60h | 50h | 60h | ~40h estimadas | ~270h efectivas |
| 2026-05 | 60h | 60h | 60h | 60h | ~40h estimadas | ~280h efectivas |

> Las horas de agentes son estimadas. Varían según número de specs `agent:single` aprobadas ese sprint.
> El Tech Lead decide sprint a sprint cuántas specs se delegan a agentes.
