# Spec: Command Handler — Crear, Actualizar y Eliminar Sala

**Task ID:**        AB#101
**PBI padre:**      AB#001 — Gestión de Salas (CRUD)
**Sprint:**         2026-04
**Fecha creación:** 2026-03-03
**Creado por:**     Carlos Mendoza (Tech Lead)

**Developer Type:** agent:single
**Asignado a:**     claude-agent (dev:agent)
**Estimación:**     4h
**Estado:**         Pendiente

---

## 1. Contexto y Objetivo

La aplicación de reserva de salas necesita un CRUD completo para la entidad `Sala`. Esta task implementa los tres Command Handlers para operaciones de escritura: crear sala, actualizar sala y eliminar sala.

La entidad `Sala` ya existe en el Domain Layer (creada en AB#101-B1 por Carlos). Esta task implementa exclusivamente la capa Application.

**Criterios de Aceptación del PBI relevantes:**
```
- [ ] POST /api/salas crea una sala y devuelve 201 + el recurso creado
- [ ] PUT /api/salas/{id} actualiza una sala; devuelve 200 o 404
- [ ] DELETE /api/salas/{id} elimina una sala si no tiene reservas futuras; devuelve 204 o 409
- [ ] Las validaciones de negocio se aplican (nombre único, capacidad 1-200)
```

---

## 2. Contrato Técnico

### 2.1 Interfaces / Firmas

```csharp
// ── CreateSalaCommand ──────────────────────────────────────────────────────────
public class CreateSalaCommand : IRequest<Result<Guid>>
{
    public string Nombre { get; init; }
    public int Capacidad { get; init; }
    public string? Ubicacion { get; init; }
}

public class CreateSalaCommandHandler : IRequestHandler<CreateSalaCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(CreateSalaCommand request, CancellationToken ct);
}

// ── UpdateSalaCommand ──────────────────────────────────────────────────────────
public class UpdateSalaCommand : IRequest<Result>
{
    public Guid Id { get; init; }
    public string Nombre { get; init; }
    public int Capacidad { get; init; }
    public string? Ubicacion { get; init; }
    public bool Disponible { get; init; }
}

public class UpdateSalaCommandHandler : IRequestHandler<UpdateSalaCommand, Result>
{
    public async Task<Result> Handle(UpdateSalaCommand request, CancellationToken ct);
}

// ── DeleteSalaCommand ──────────────────────────────────────────────────────────
public class DeleteSalaCommand : IRequest<Result>
{
    public Guid Id { get; init; }
}

public class DeleteSalaCommandHandler : IRequestHandler<DeleteSalaCommand, Result>
{
    public async Task<Result> Handle(DeleteSalaCommand request, CancellationToken ct);
}
```

### 2.2 Modelos de Entrada y Salida

```csharp
// Result<T> es el tipo estándar del proyecto (usa el patrón Railway Oriented Programming)
// Ver: src/Domain/Common/Result.cs (ya existe)
// Ver: src/Domain/Common/Error.cs (ya existe)
```

### 2.3 Dependencias e Inyección

```csharp
// CreateSalaCommandHandler necesita:
public CreateSalaCommandHandler(
    ISalaRepository salaRepository,        // para verificar nombre único y persistir
    IUnitOfWork unitOfWork,                // para commit
    ILogger<CreateSalaCommandHandler> logger
)

// UpdateSalaCommandHandler necesita:
public UpdateSalaCommandHandler(
    ISalaRepository salaRepository,
    IUnitOfWork unitOfWork,
    ILogger<UpdateSalaCommandHandler> logger
)

// DeleteSalaCommandHandler necesita:
public DeleteSalaCommandHandler(
    ISalaRepository salaRepository,
    IReservaRepository reservaRepository,  // para verificar reservas futuras
    IUnitOfWork unitOfWork,
    ILogger<DeleteSalaCommandHandler> logger
)
```

---

## 3. Reglas de Negocio

| # | Regla | Error a lanzar | Código HTTP |
|---|-------|---------------|-------------|
| RN-SALA-01 | Nombre único en el sistema | `SalaErrors.NombreDuplicado` | 409 |
| RN-SALA-04 | Nombre: 3-100 chars, no vacío | `ValidationException` | 400 |
| RN-SALA-02 | Capacidad mínima: 1 | `ValidationException` | 400 |
| RN-SALA-03 | Capacidad máxima: 200 | `ValidationException` | 400 |
| RN-SALA-05 | No eliminar si tiene reservas futuras | `SalaErrors.TieneReservasFuturas` | 409 |
| RN-SALA-06 | Update: sala no encontrada | `SalaErrors.NotFound` | 404 |
| — | Delete: sala no encontrada | `SalaErrors.NotFound` | 404 |

**Definir en `src/Domain/Salas/SalaErrors.cs`:**
```csharp
public static class SalaErrors
{
    public static readonly Error NotFound = Error.NotFound("Sala.NotFound", "La sala no existe");
    public static readonly Error NombreDuplicado = Error.Conflict("Sala.NombreDuplicado", "Ya existe una sala con ese nombre");
    public static readonly Error TieneReservasFuturas = Error.Conflict("Sala.TieneReservasFuturas", "No se puede eliminar una sala con reservas futuras");
}
```

Referencias:
→ `projects/sala-reservas/reglas-negocio.md §SALA-01 a SALA-06`

---

## 4. Test Scenarios

### Happy Path — CreateSalaCommand
```
Scenario: Crear sala con datos válidos
  Given nombre "Sala Picasso" que NO existe en el sistema
  And capacidad 10
  And ubicación "Planta 2, Ala Norte"
  When se envía CreateSalaCommand
  Then el resultado es Success
  And se retorna un Guid válido (no vacío)
  And la sala existe en el repositorio
```

### Happy Path — UpdateSalaCommand
```
Scenario: Actualizar sala existente
  Given una sala con Id conocido que existe
  When se envía UpdateSalaCommand con nuevos datos válidos
  Then el resultado es Success
  And los campos de la sala se actualizan correctamente
```

### Happy Path — DeleteSalaCommand
```
Scenario: Eliminar sala sin reservas futuras
  Given una sala que existe Y no tiene reservas futuras
  When se envía DeleteSalaCommand
  Then el resultado es Success
  And la sala no existe en el repositorio
```

### Casos de Error — Create
```
Scenario: Nombre duplicado
  Given nombre "Sala Picasso" que YA existe
  When se envía CreateSalaCommand con ese nombre
  Then el resultado es Failure
  And el error es SalaErrors.NombreDuplicado

Scenario: Capacidad = 0
  Given capacidad = 0
  When se envía CreateSalaCommand
  Then resultado es Failure (o ValidationException antes del handler)
  And mensaje menciona "Capacidad"

Scenario: Capacidad = 201
  Given capacidad = 201
  Then resultado es Failure
  And mensaje menciona "Capacidad"
```

### Casos de Error — Update
```
Scenario: Sala no encontrada
  Given un Id que no existe en el repositorio
  When se envía UpdateSalaCommand
  Then resultado es Failure
  And error es SalaErrors.NotFound
```

### Casos de Error — Delete
```
Scenario: Sala con reservas futuras
  Given una sala que tiene al menos 1 reserva con fecha >= hoy
  When se envía DeleteSalaCommand
  Then resultado es Failure
  And error es SalaErrors.TieneReservasFuturas

Scenario: Sala no encontrada para delete
  Given un Id que no existe
  When se envía DeleteSalaCommand
  Then resultado es Failure
  And error es SalaErrors.NotFound
```

### Edge Cases
```
Scenario: Nombre con exactamente 3 caracteres → aceptado
Scenario: Nombre con exactamente 100 caracteres → aceptado
Scenario: Nombre con 101 caracteres → rechazado
Scenario: Capacidad = 1 → aceptado
Scenario: Capacidad = 200 → aceptado
Scenario: Ubicación null → aceptado (campo opcional)
Scenario: Ubicación con 200 chars → aceptado
```

---

## 5. Ficheros a Crear / Modificar

### Crear (nuevos)
```
src/Application/Salas/Commands/CreateSala/
├── CreateSalaCommand.cs
├── CreateSalaCommandHandler.cs
└── CreateSalaCommandValidator.cs

src/Application/Salas/Commands/UpdateSala/
├── UpdateSalaCommand.cs
├── UpdateSalaCommandHandler.cs
└── UpdateSalaCommandValidator.cs

src/Application/Salas/Commands/DeleteSala/
├── DeleteSalaCommand.cs
└── DeleteSalaCommandHandler.cs

src/Domain/Salas/SalaErrors.cs
```

### Modificar (existentes)
```
src/Application/DependencyInjection.cs   ← NO modificar (MediatR usa auto-scan)
```

### NO tocar
```
src/Domain/Salas/Sala.cs                 ← Domain Entity (creada por Carlos en B1)
src/Infrastructure/                      ← Se crea en task C1
src/API/                                 ← Se crea en task C2
```

---

## 6. Código de Referencia

No hay handlers similares en el proyecto (primer sprint). Seguir el patrón estándar de la skill:
→ `.claude/skills/spec-driven-development/references/spec-template.md §6`

**Patrón Result<T> esperado:**
```csharp
public async Task<Result<Guid>> Handle(CreateSalaCommand request, CancellationToken ct)
{
    // 1. Verificar regla de negocio
    var existe = await _salaRepository.ExisteConNombreAsync(request.Nombre, ct);
    if (existe)
        return Result.Failure<Guid>(SalaErrors.NombreDuplicado);

    // 2. Crear la entidad (via factory method en Domain)
    var sala = Sala.Create(request.Nombre, request.Capacidad, request.Ubicacion);

    // 3. Persistir
    _salaRepository.Add(sala);
    await _unitOfWork.SaveChangesAsync(ct);

    return Result.Success(sala.Id);
}
```

**Interfaces de repositorio disponibles:**
```csharp
// Ya definidas en Domain Layer (B1) — usar estas firmas exactas:
public interface ISalaRepository
{
    Task<Sala?> GetByIdAsync(SalaId id, CancellationToken ct);
    Task<bool> ExisteConNombreAsync(string nombre, CancellationToken ct);
    Task<bool> TieneReservasFuturasAsync(SalaId id, CancellationToken ct);
    void Add(Sala sala);
    void Remove(Sala sala);
}
```

---

## 7. Configuración de Entorno

```bash
PROJECT_DIR="projects/sala-reservas/source"
SOLUTION_FILE="src/SalaReservas.sln"
TEST_PROJECT="tests/Application.Tests"

# Comandos de verificación post-implementación
dotnet build $SOLUTION_FILE
dotnet test $TEST_PROJECT --filter "Category=Unit&FullyQualifiedName~Sala" --no-build
```

---

## 8. Estado de Implementación

**Estado:** Pendiente
**Último update:** 2026-03-03 09:00
**Actualizado por:** Carlos Mendoza

### Blockers
> El agente debe detenerse si encuentra alguno de estos:
- [ ] La entidad `Sala.cs` en Domain no existe todavía (esperar merge de AB#101-B1)
- [ ] Las interfaces `ISalaRepository` o `IUnitOfWork` no están definidas en Domain

---

## 9. Checklist Pre-Entrega

### Implementación
- [ ] Todos los ficheros de la sección 5 han sido creados
- [ ] Las firmas coinciden con el contrato de la sección 2
- [ ] Las reglas de negocio de la sección 3 están implementadas
- [ ] Todos los test scenarios de la sección 4 tienen su test
- [ ] Los tests pasan: `dotnet test --filter "Category=Unit&FullyQualifiedName~Sala"`
- [ ] `SalaErrors.cs` creado con los tres errores definidos
- [ ] Sin hardcoding de valores configurables

### Específico para agente
- [ ] No se crearon ficheros fuera de la sección 5
- [ ] No se tocó `src/Domain/` ni `src/Infrastructure/` ni `src/API/`
- [ ] Los nombres siguen el patrón de la sección 6
