# Spec Template — Spec-Driven Development

> Plantilla estándar para specs ejecutables por humanos o agentes Claude.
> Copiar y rellenar para cada Task. El objetivo es que no quede ningún campo ambiguo.

---

## Cabecera

```markdown
# Spec: {Tipo} — {Título descriptivo}

**Task ID:**        AB#{id}
**PBI padre:**      AB#{pbi_id} — {título del PBI}
**Sprint:**         {sprint, ej: 2026-04}
**Fecha creación:** {YYYY-MM-DD}
**Creado por:**     {PM/Tech Lead}

**Developer Type:** human | agent:single | agent:team
**Asignado a:**     {nombre_dev | claude-agent | claude-agent-team}
**Estimación:**     {Xh}
**Estado:**         Pendiente | En Progreso | Completado | Bloqueado
```

---

## 1. Contexto y Objetivo

> *¿Por qué existe esta task? ¿Qué problema resuelve? 2-4 frases.*

```
Contexto del PBI:
[Describe brevemente el PBI padre y cómo encaja esta task dentro del PBI.]

Objetivo de esta task:
[Qué debe existir al finalizar esta task que no existía antes.]
```

**Criterios de Aceptación del PBI (extracto relevante):**
```
- [ ] {AC relevante al alcance de esta task}
- [ ] {AC relevante al alcance de esta task}
```

---

## 2. Contrato Técnico

> *El contrato define exactamente qué se debe implementar. Debe ser inequívoco.*

### 2.1 Interfaz / Firma

```csharp
// Clase / interface / método principal que debe existir al terminar la task

// Ejemplo para un Command Handler:
public class CreatePatientCommand : IRequest<Result<Guid>>
{
    public string Name { get; init; }
    public DateTime BirthDate { get; init; }
    public string NationalId { get; init; }  // DNI/NIE
}

public class CreatePatientCommandHandler : IRequestHandler<CreatePatientCommand, Result<Guid>>
{
    Task<Result<Guid>> Handle(CreatePatientCommand request, CancellationToken ct);
}

// Ejemplo para un endpoint:
// POST /api/v1/patients
// Request body: CreatePatientRequest (definida en sección 2.2)
// Response: 201 Created + { "id": "{guid}" }
// Errores: 400 (validación), 409 (DNI duplicado), 500 (error interno)
```

### 2.2 Modelos de Entrada y Salida

```csharp
// Todos los DTOs, Request y Response deben estar definidos aquí
// con sus tipos de datos y restricciones

public record CreatePatientRequest
{
    [Required]
    [MaxLength(200)]
    public string Name { get; init; }

    [Required]
    public DateTime BirthDate { get; init; }

    [Required]
    [RegularExpression(@"^[0-9]{8}[A-Z]$|^[XYZ][0-9]{7}[A-Z]$")]
    public string NationalId { get; init; }  // DNI o NIE
}

public record CreatePatientResponse
{
    public Guid Id { get; init; }
}
```

### 2.3 Dependencias e Inyección

```csharp
// Interfaces que debe recibir por inyección el componente a implementar

// Ejemplo:
public CreatePatientCommandHandler(
    IPatientRepository patientRepository,   // Repositorio de pacientes
    IUnitOfWork unitOfWork,                 // Para commit de transacción
    IMapper mapper,                          // AutoMapper para mapeos
    ILogger<CreatePatientCommandHandler> logger
)
```

---

## 3. Reglas de Negocio

> *Cada regla debe ser verificable en tests. No usar "según corresponda" ni "a criterio del dev".*

| # | Regla | Error a lanzar | Código HTTP |
|---|-------|---------------|-------------|
| RN-01 | El DNI/NIE debe ser único en el sistema | `DuplicateNationalIdException` | 409 |
| RN-02 | El nombre no puede estar vacío ni tener solo espacios | `ValidationException` | 400 |
| RN-03 | La fecha de nacimiento no puede ser futura | `ValidationException` | 400 |
| RN-04 | La edad mínima del paciente es 0 años (recién nacidos permitidos) | - | - |
| RN-05 | El `NationalId` debe coincidir con el algoritmo de validación DNI/NIE español | `ValidationException` | 400 |

**Referencias a docs de reglas de negocio:**
```
→ projects/{proyecto}/reglas-negocio.md §{sección}
→ docs/reglas-dominio/{módulo}.md
```

---

## 4. Test Scenarios

> *Estos escenarios son los tests que DEBEN existir al finalizar la task.*
> *Si el developer_type es agent, el agente debe generar exactamente estos tests.*

### Happy Path
```
Scenario: Crear paciente con datos válidos
  Given un DNI válido "12345678A" que no existe en el sistema
  And un nombre "Juan García López"
  And una fecha de nacimiento "1985-03-15"
  When se envía el comando CreatePatientCommand
  Then el resultado es Success
  And se retorna un Guid válido (no vacío)
  And el paciente existe en la base de datos
  And se disparó el evento PatientCreatedDomainEvent
```

### Casos de Error
```
Scenario: DNI duplicado
  Given un DNI "12345678A" que YA existe en el sistema
  When se envía el comando CreatePatientCommand con ese DNI
  Then el resultado es Failure
  And el error es DuplicateNationalIdException
  And no se creó ningún paciente nuevo

Scenario: Nombre vacío
  Given un nombre ""
  When se envía el comando CreatePatientCommand
  Then el resultado es Failure (o lanza ValidationException antes de llegar al handler)
  And el mensaje de error menciona el campo "Name"

Scenario: Fecha de nacimiento futura
  Given una fecha de nacimiento DateTime.UtcNow.AddDays(1)
  When se envía el comando CreatePatientCommand
  Then el resultado es Failure
  And el mensaje de error menciona "fecha de nacimiento"

Scenario: DNI con formato inválido
  Given un DNI "AAAAAAAA1" (formato incorrecto)
  When se envía el comando CreatePatientCommand
  Then el resultado es Failure
  And el mensaje de error menciona "NationalId"
```

### Edge Cases
```
Scenario: Nombre con 200 caracteres (límite máximo)
  → Debe ser aceptado

Scenario: Nombre con 201 caracteres
  → Debe ser rechazado con ValidationException

Scenario: Recién nacido (fecha de nacimiento = hoy)
  → Debe ser aceptado

Scenario: Transacción fallida (UnitOfWork lanza excepción)
  → Debe propagar el error sin crear el paciente parcialmente
```

---

## 5. Ficheros a Crear / Modificar

> *Lista exacta de ficheros. El agente debe crear/modificar EXACTAMENTE estos, ni más ni menos.*

### Crear (nuevos)
```
src/Application/Patients/Commands/CreatePatient/
├── CreatePatientCommand.cs          # Command + Response
├── CreatePatientCommandHandler.cs   # Handler principal
└── CreatePatientCommandValidator.cs # FluentValidation rules

tests/Application.Tests/Patients/Commands/
└── CreatePatientCommandHandlerTests.cs  # Tests del handler
```

### Modificar (existentes)
```
src/Application/DependencyInjection.cs   # Registrar el handler (si no usa MediatR auto-scan)
src/API/Controllers/PatientsController.cs # Añadir endpoint POST
```

### NO tocar
```
src/Domain/Patients/              # Domain layer — solo modificación explícita por humano
src/Infrastructure/               # Infrastructure layer — según Fase 2 de descomposición del PBI
```

---

## 6. Código de Referencia

> *Ejemplos del mismo patrón en el proyecto para que el developer/agente siga la convención.*

### Ejemplo de Command Handler similar (mismo patrón):
```
→ src/Application/Appointments/Commands/CreateAppointment/CreateAppointmentCommandHandler.cs
```

```csharp
// Fragmento del handler de referencia para mostrar el patrón de Result<T>:
public async Task<Result<Guid>> Handle(CreateAppointmentCommand request, CancellationToken ct)
{
    var existingAppointment = await _appointmentRepository
        .GetByPatientAndDateAsync(request.PatientId, request.Date, ct);

    if (existingAppointment is not null)
        return Result.Failure<Guid>(AppointmentErrors.DuplicateAppointment);

    var appointment = Appointment.Create(
        request.PatientId,
        request.Date,
        request.DoctorId
    );

    _appointmentRepository.Add(appointment);
    await _unitOfWork.SaveChangesAsync(ct);

    return Result.Success(appointment.Id);
}
```

### Ejemplo de Validator similar:
```
→ src/Application/Appointments/Commands/CreateAppointment/CreateAppointmentCommandValidator.cs
```

### Ejemplo de Tests similar:
```
→ tests/Application.Tests/Appointments/Commands/CreateAppointmentCommandHandlerTests.cs
```

---

## 7. Configuración de Entorno

> *Lo que el agente necesita saber sobre el entorno de ejecución.*

```bash
# Proyecto
PROJECT_DIR="projects/{proyecto}/source"
SOLUTION_FILE="src/{Proyecto}.sln"
TEST_PROJECT="tests/Application.Tests"

# Comandos de verificación post-implementación
dotnet build $SOLUTION_FILE
dotnet test $TEST_PROJECT --filter "Category=Unit" --no-build
```

**Variables de entorno necesarias para tests:**
```
# Los tests unitarios NO deben necesitar variables de entorno externas
# Si necesitan base de datos → usar InMemory o SQLite en memoria
```

---

## 8. Estado de Implementación

> *El developer/agente actualiza esta sección durante la implementación.*

```markdown
**Estado:** Pendiente | En Progreso | Completado | Bloqueado

**Último update:** {YYYY-MM-DD HH:MM}
**Actualizado por:** {dev/agent}

### Log de implementación (si agent:single o agent:team)
- {timestamp} — [AGENT] Iniciando implementación
- {timestamp} — [AGENT] Handler creado: CreatePatientCommandHandler.cs
- {timestamp} — [AGENT] Validator creado: CreatePatientCommandValidator.cs
- {timestamp} — [AGENT] Tests creados: 7 scenarios
- {timestamp} — [AGENT] Build: ✅ OK
- {timestamp} — [AGENT] Tests: ✅ 7/7 passing
- {timestamp} — [AGENT] Implementación completada

### Blockers (si los hay)
> El agente DEBE detenerse y escribir aquí si encuentra ambigüedad o bloqueo

- [ ] {descripción del blocker} — Necesita decisión de: {PM | Tech Lead | humano}
```

---

## 9. Checklist Pre-Entrega

> *El developer (humano o agente) verifica antes de marcar la task como "In Review".*

```markdown
### Implementación
- [ ] Todos los ficheros de la sección 5 han sido creados/modificados
- [ ] Las firmas coinciden exactamente con el contrato de la sección 2
- [ ] Todas las reglas de negocio de la sección 3 están implementadas y testadas
- [ ] Todos los test scenarios de la sección 4 tienen su test correspondiente
- [ ] Los tests pasan localmente (dotnet test)
- [ ] El código sigue el patrón del ejemplo en sección 6
- [ ] Sin hardcoding de valores que deberían ser configurables
- [ ] Sin código comentado ni TODOs sin resolver

### Específico para agente
- [ ] No se tomaron decisiones de diseño fuera de la Spec
- [ ] No se crearon ficheros no listados en la sección 5
- [ ] Las dependencias inyectadas coinciden con la sección 2.3
- [ ] Los nombres siguen las convenciones del proyecto (sección 6)
```

---

## Notas para el Revisor (Tech Lead)

> *Información adicional para el Code Review. No afecta la implementación.*

```
{Notas del PM/Tech Lead sobre decisiones de diseño, contexto histórico,
 riesgos identificados, o aspectos específicos a revisar con cuidado.}
```

---

*Template versión 1.0 — SDD Skill para {Workspace Name}*
*Basado en Clean Architecture .NET 8 + CQRS + MediatR*
