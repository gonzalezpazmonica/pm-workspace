# Decision Trees — dotnet-developer

> Cap ≤80 lines. Implementación C#/.NET tras spec aprobada. Branching ≤4.

## Cuándo aceptar la tarea

El dotnet-developer acepta si:
- Hay spec SDD APPROVED para una feature en C#/.NET.
- Hay bugfix con causa raíz identificada (no requiere diseño).
- Se aplica refactor cuyo scope está definido y no cruza boundaries.
- Migración EF Core / EF6 con plan ya validado por architect.

El dotnet-developer **NO acepta** y delega si:
- Spec aún no APPROVED → vuelve a `sdd-spec-writer`.
- Toca decisión arquitectónica (capa, patrón) → `architect`.
- Requiere reinterpretación de regla de negocio → `business-analyst`.
- Cambio de infraestructura (Docker, Terraform) → `infrastructure-agent`.
- Lenguaje distinto (TS, Python, Go, Java) → developer correspondiente.

## Routing por tipo de cambio

| Cambio | Decisión |
|---|---|
| **Controller/Endpoint** nuevo | Implementar + DTO + tests integración (mín 1) |
| **Service layer** | Inyección por constructor, interface en mismo namespace |
| **Repository** | EF Core con `IQueryable<T>` interno, `Task<T>` público |
| **Domain entity** | Sin dependencias de Infrastructure, validar invariantes en constructor |
| **EF Migration** | `dotnet ef migrations add` + revisar SQL generado + tests rollback |
| **DTO + Mapper** | AutoMapper o mapper manual; nunca exponer entity directamente |

## Cuándo ejecutar tests vs delegar

- **Self-test** tras cada slice: `dotnet test --filter Category=Unit` (rápido <30s).
- **Integration tests**: ejecutar antes de marcar slice done (TestContainers ok).
- **E2E**: delegar a `test-runner` post-commit, NO bloquear desarrollo.
- **Coverage**: target `TEST_COVERAGE_MIN_PERCENT` (80%). Si baja → invocar `test-engineer`.

## Escalado a humano o a otro agente

Escalar SIEMPRE si:
- Detecto que la spec contradice una regla de negocio existente → `business-analyst`.
- Test falla 3 veces seguidas con misma causa → `architect` (puede ser diseño).
- Performance hit medible (>20% latencia) → `performance-audit` skill.
- Migration EF rompe schema producción → STOP + humano.

## Anti-patrones (NO hacer)

- Implementar sin leer spec completa — risk de scope creep.
- Saltar tests "porque es trivial" — Rule SDD: sin tests, sin done.
- Llamar `DbContext` directamente desde controller — viola Clean Architecture.
- Usar `.Result` o `.Wait()` en async — deadlock en ASP.NET.
- Hardcodear connection strings → siempre `IConfiguration` + secret manager.
