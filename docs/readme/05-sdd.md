# Spec-Driven Development (SDD)

El SDD es la característica más avanzada del workspace. Permite que las tasks técnicas sean implementadas por un desarrollador humano **o por un agente Claude**, dependiendo del tipo de tarea.

Una Spec es un contrato que describe exactamente qué implementar. Si el contrato es suficientemente claro, un agente puede implementarlo sin intervención humana.

## Tipos de developer

| Tipo | Quién implementa | Cuándo |
|------|-----------------|--------|
| `human` | Desarrollador del equipo | Lógica de dominio, migraciones, integraciones externas, Code Review |
| `agent-single` | Un agente Claude | Handlers, Repositorios, Validators, Unit Tests, DTOs, Controllers |
| `agent-team` | Implementador + Tester en paralelo | Tasks ≥ 6h con código producción + tests |

## Flujo de trabajo SDD

```
1. /pbi-decompose → propuesta de tasks con columna "Developer Type"
2. /spec-generate {task_id} → genera el fichero .spec.md desde Azure DevOps
3. /spec-review {spec_file} → valida la spec (calidad, completitud)
4. Si developer_type = agent:
     /agent-run {spec_file} → agente implementa la spec
   Si developer_type = human:
     Asignar al desarrollador
5. /spec-review {spec_file} --check-impl → pre-check del código generado
6. Code Review (E1) → SIEMPRE humano (Tech Lead)
7. PR → merge → Task: Done
```

## La plantilla de Spec

Cada Spec (`.spec.md`) tiene 9 secciones que eliminan la ambigüedad:

1. **Cabecera** — Task ID, developer_type, estimación, asignado a
2. **Contexto y Objetivo** — por qué existe la task, criterios de aceptación relevantes
3. **Contrato Técnico** — firma exacta de clases/métodos, DTOs con tipos y restricciones, dependencias a inyectar
4. **Reglas de Negocio** — tabla con cada regla, su excepción y código HTTP
5. **Test Scenarios** — Given/When/Then para happy path, errores y edge cases
6. **Ficheros a Crear/Modificar** — lista exacta de rutas (el agente no puede salirse de esta lista)
7. **Código de Referencia** — ejemplo del mismo patrón en el proyecto
8. **Estado de Implementación** — log del agente, blockers
9. **Checklist Pre-Entrega** — verificación antes de pasar a Code Review

## Qué tasks puede hacer un agente (por defecto)

La matrix completa está en `.opencode/skills/spec-driven-development/references/layer-assignment-matrix.md` (existe una matrix por cada lenguaje soportado). Resumen general:

**El agente puede hacer:** Application/Service Layer (Handlers, Services, Validators, Mappers, DTOs), Infrastructure/Data Layer (Repositorios, Entity Configurations, Migraciones simples), API/Presentation (Controllers CRUD, endpoints, documentación), Tests (Unit Tests cuando los escenarios están en la Spec).

**Siempre humano:** Domain Layer (nuevas entidades raíz de agregado, Domain Services, lógica de negocio compleja), Migraciones de base de datos complejas, Configuración de autenticación/autorización, Integraciones con sistemas externos, Infraestructura cloud (apply/create requiere aprobación humana), Code Review (E1) — sin excepciones.

---

## Ejemplo — Flujo SDD completo: de task a código en producción

_Escenario: La task AB#302-B3 "GetHistorialCitasQueryHandler" está lista para que el agente la implemente._

### Paso 1 — Generar la spec

**Tú escribes:**
```
/spec-generate 302-B3 --project GestiónClínica
```

**Claude responde:**
```
Leyendo AB#302 (PBI padre) y AB#302-B3 (Task)...
Analizando código existente en projects/gestión-clinica/source/...
→ Módulo: Citas / Capa: Application / Tipo: QueryHandler
→ Developer type: agent-single (patrón repetible, interfaces definidas)

Spec generada:
  projects/gestión-clinica/specs/sprint-2026-05/AB302-B3-get-historial-citas-handler.spec.md

Vista previa de la sección más crítica (Contrato Técnico):
┌─────────────────────────────────────────────────────────────────┐
│  public sealed class GetHistorialCitasQuery                     │
│      : IRequest<PagedResult<HistorialCitaDto>>                  │
│  {                                                              │
│      public Guid PacienteId { get; init; }                      │
│      public DateOnly FechaInicio { get; init; }                 │
│      public DateOnly FechaFin { get; init; }                    │
│      public string? Cursor { get; init; }   // paginación       │
│      public int PageSize { get; init; } = 20;                   │
│  }                                                              │
└─────────────────────────────────────────────────────────────────┘

¿Revisas la spec antes de implementar? → /spec-review AB302-B3-...
```

### Paso 2 — Validar la spec

**Tú escribes:**
```
/spec-review AB302-B3-get-historial-citas-handler.spec.md
```

**Claude responde:**
```
Revisando calidad de la spec...

✅ Cabecera completa (Task ID, developer_type, estimación, asignado)
✅ Contrato técnico definido (interfaces, DTOs, dependencias)
✅ Reglas de negocio documentadas: 4 reglas con excepciones y HTTP codes
✅ Test scenarios: 6 escenarios (happy path + fechas inválidas + paciente no encontrado)
✅ Ficheros a crear listados: 3 ficheros en rutas exactas
✅ Código de referencia incluido (GetCitasDelDíaQueryHandler como patrón)

══════════════════════
  ✅ SPEC LISTA
  Puedes ejecutar /agent-run
══════════════════════
```

### Paso 3 — Lanzar el agente

**Tú escribes:**
```
/agent-run projects/gestión-clinica/specs/sprint-2026-05/AB302-B3-get-historial-citas-handler.spec.md
```

**Claude responde:**
```
Lanzando agente claude-opus-4-7 sobre AB302-B3...
Log en tiempo real: output/agent-runs/20260519-094512-AB302-B3-single.log

[09:45:14] Agente iniciado — leyendo spec y contexto del proyecto
[09:45:31] Creando GetHistorialCitasQuery.cs
[09:45:44] Creando GetHistorialCitasQueryHandler.cs
[09:46:02] Creando HistorialCitaDto.cs + AutoMapper profile
[09:46:18] Ejecutando dotnet build... ✅ 0 errores
[09:46:35] Ejecutando dotnet test --filter "GetHistorial"... 6/6 ✅
[09:46:41] Agente finalizado.

══════════════════════════════════════════════
  ✅ IMPLEMENTACIÓN COMPLETADA
  Build: OK | Tests: 6/6 | Duración: 87s
  Coste estimado: ~$0.62 USD
══════════════════════════════════════════════

Ficheros creados:
  + Application/Citas/Queries/GetHistorialCitas/GetHistorialCitasQuery.cs
  + Application/Citas/Queries/GetHistorialCitas/GetHistorialCitasQueryHandler.cs
  + Application/Citas/Queries/GetHistorialCitas/HistorialCitaDto.cs

⚠️  IMPORTANTE: Code Review (E1) es obligatorio antes del merge.
    Asigna AB#302-E1 a Carlos TL para revisión.

¿Actualizo la Task AB#302-B3 en Azure DevOps a estado "In Review"?
```

**Tú escribes:**
```
Sí, actualiza el estado
```

**Claude responde:**
```
✅ AB#302-B3 actualizada en Azure DevOps:
   Estado: In Review
   Tags añadidos: spec-driven; agent-implemented
   Comentario: "Implementado por claude-opus-4-7. Build OK, 6/6 tests. Pendiente Code Review."
```

---

## Ejemplo — Dashboard de specs del sprint

_Escenario: Quieres ver el estado de todas las tasks SDD del sprint de un vistazo._

**Tú escribes:**
```
/spec-status --project GestiónClínica
```

**Claude responde:**
```
══════════════════════════════════════════════════════════════════
  SDD Status · GestiónClínica · Sprint 2026-05
══════════════════════════════════════════════════════════════════

  Task                             Spec         Dev Type     Estado   h    Asignado
  ─────────────────────────────────────────────────────────────────────────────────
  AB#302-B3 GetHistorialCitas      ✅ lista      agent-single  ✅ done  4h   agente
  AB#302-C1 HistorialController    ✅ lista      agent-single  🔄 impl  3h   agente
  AB#302-C2 Paginación cursor      ✅ lista      agent-single  ⏳ cola  3h   agente
  AB#302-D1 Unit tests handler     ✅ lista      agent-single  ⏳ cola  2h   agente
  AB#301-B3 SendConfirmationCmd    ⚠️ incompleta agent-single  🚫 bloq  4h   agente
  AB#301-D1 EmailTemplateService   ⏳ pendiente  agent-single  ⏳ cola  3h   agente

  Resumen:
    Completadas: 1 | En curso: 1 | En cola: 3 | Bloqueadas: 1
    Horas de agente ahorradas (completadas): 4h (~$2.48 USD)
    Horas de agente estimadas (total sprint): 19h (~$11.78 USD est.)

  ⚠️  AB#301-B3 bloqueada:
     La spec tiene una sección de Contrato Técnico incompleta —
     falta la firma de IEmailService. Ejecuta /spec-review AB301-B3-...
     para ver qué falta exactamente.
```

---

## Patrones de equipos de agentes

Para tasks grandes, puedes usar un equipo de agentes en paralelo:

```bash
/agent-run {spec_file} --team
# Lanza: Implementador (opus) + Tester (haiku) en paralelo
# Tiempo: ~50% menos que secuencial
# Coste: ~$0.80-1.80 por spec
```

Los patrones disponibles están documentados en `references/agent-team-patterns.md`:

- `single` — 1 agente (tasks ≤ 6h)
- `impl-test` — Implementador + Tester en paralelo
- `impl-test-review` — añade un Reviewer tras la fase paralela
- `full-stack` — 4 agentes por capa (API, Application, Infrastructure, Tests)
- `parallel-handlers` — N agentes para N specs simultáneas

---

## Ejemplo — Lanzar un equipo de agentes para una task grande

_Escenario: La task AB#301-B3 "SendCitaConfirmationCommandHandler" es compleja (6h), tiene código de producción y necesita tests. Usas el patrón `impl-test`._

**Tú escribes:**
```
/agent-run projects/gestión-clinica/specs/sprint-2026-05/AB301-B3-send-confirmation-cmd.spec.md --team
```

**Claude responde:**
```
Patrón seleccionado: impl-test (código producción + tests en paralelo)
  Agente 1 — Implementador: claude-opus-4-7  (handler + service)
  Agente 2 — Tester:        claude-haiku-4-5-20251001 (unit tests + mocks)

Coste estimado: ~$1.40 USD
¿Confirmas el lanzamiento?
```

**Tú escribes:**
```
Sí
```

**Claude responde:**
```
Lanzando 2 agentes en paralelo...

[Agente 1 — opus] 09:51:03 → Implementando SendCitaConfirmationCommandHandler...
[Agente 2 — haiku] 09:51:04 → Generando unit tests para SendCitaConfirmationCommand...

[Agente 1] 09:52:41 → Handler + EmailTemplateService completos. Build OK.
[Agente 2] 09:52:58 → 9 unit tests generados. Esperando implementación para ejecutar.

[Sincronizando] → Ejecutando dotnet test... 9/9 ✅

══════════════════════════════════════════════
  ✅ EQUIPO COMPLETADO
  Duración total: 118s (vs ~210s secuencial)
  Build: OK | Tests: 9/9
  Coste real: $1.22 USD
══════════════════════════════════════════════
```

---
