# Spec: Unit Tests — CreateSalaCommandHandler

**Task ID:**        AB#102
**PBI padre:**      AB#001 — Gestión de Salas (CRUD)
**Sprint:**         2026-04
**Fecha creación:** 2026-03-03
**Creado por:**     Carlos Mendoza (Tech Lead)

**Developer Type:** agent:single
**Modelo sugerido:** claude-haiku-4-5-20251001
**Asignado a:**     claude-agent-fast (dev:agent-fast)
**Estimación:**     2h
**Estado:**         Pendiente

---

## 1. Contexto y Objetivo

Implementar todos los unit tests para `CreateSalaCommandHandler`, `UpdateSalaCommandHandler` y `DeleteSalaCommandHandler` (implementados en AB#101-B3).

Los tests deben cubrir los escenarios de happy path, errores y edge cases definidos en la spec AB#101-B3. Los handlers ya existen (o se implementan en paralelo en el patrón `impl-test`).

**Nota para el agente:** Usar **mocks** (Moq) para todas las dependencias. Los tests son unit tests puros — sin base de datos, sin EF Core real.

---

## 2. Contrato Técnico

### 2.1 Interfaces a Mockear

```csharp
// Dependencias a mockear en los tests:
Mock<ISalaRepository> salaRepositoryMock;
Mock<IReservaRepository> reservaRepositoryMock;  // solo para DeleteSalaCommandHandler
Mock<IUnitOfWork> unitOfWorkMock;
Mock<ILogger<CreateSalaCommandHandler>> loggerMock;
Mock<ILogger<UpdateSalaCommandHandler>> loggerMock;
Mock<ILogger<DeleteSalaCommandHandler>> loggerMock;
```

### 2.2 Setup de Tests

```csharp
// Patrón de setup para cada handler:
private readonly Mock<ISalaRepository> _salaRepositoryMock = new();
private readonly Mock<IUnitOfWork> _unitOfWorkMock = new();
private CreateSalaCommandHandler _handler;

public CreateSalaCommandHandlerTests()
{
    _handler = new CreateSalaCommandHandler(
        _salaRepositoryMock.Object,
        _unitOfWorkMock.Object,
        Mock.Of<ILogger<CreateSalaCommandHandler>>()
    );
}
```

---

## 3. Reglas de Negocio a Verificar en Tests

Las mismas que en AB#101-B3 §3. Cada regla debe tener al menos un test de error.

---

## 4. Test Scenarios a Implementar

### CreateSalaCommandHandler Tests (7 tests)

```csharp
[Fact] Create_ConDatosValidos_RetornaSuccessConGuid()
  // Arrange: ExisteConNombreAsync = false
  // Act: Handler.Handle(comando con nombre válido, capacidad 10, ubicación)
  // Assert: resultado.IsSuccess == true && resultado.Value != Guid.Empty

[Fact] Create_NombreDuplicado_RetornaFailureConErrorCorrecto()
  // Arrange: ExisteConNombreAsync = true
  // Assert: resultado.IsFailure && resultado.Error == SalaErrors.NombreDuplicado

[Fact] Create_CapacidadCero_FallaPorValidacion()
  // Nota: La validación ocurre en el Validator (FluentValidation)
  // Este test valida que el Validator rechaza capacidad = 0
  // (Si el Validator está en la misma task, testarlo aquí; si no, marcar como blocker)

[Fact] Create_CapacidadMaxima200_EsAceptada()
  // Arrange: ExisteConNombreAsync = false, capacidad = 200
  // Assert: resultado.IsSuccess

[Fact] Create_NombreConLimiteSuperior100Chars_EsAceptado()
  // Arrange: nombre = new string('A', 100), ExisteConNombreAsync = false
  // Assert: resultado.IsSuccess

[Fact] Create_UbicacionNull_EsAceptada()
  // Arrange: ExisteConNombreAsync = false, ubicacion = null
  // Assert: resultado.IsSuccess

[Fact] Create_UnitOfWork_LlamaASaveChangesAsync()
  // Assert: _unitOfWorkMock.Verify(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once)
```

### UpdateSalaCommandHandler Tests (4 tests)

```csharp
[Fact] Update_SalaExistente_RetornaSuccess()
  // Arrange: GetByIdAsync = sala existente, ExisteConNombreAsync = false (nombre no cambia o es único)
  // Assert: resultado.IsSuccess

[Fact] Update_SalaNoEncontrada_RetornaNotFound()
  // Arrange: GetByIdAsync = null
  // Assert: resultado.IsFailure && resultado.Error == SalaErrors.NotFound

[Fact] Update_NombreDuplicado_RetornaConflict()
  // Arrange: GetByIdAsync = sala existente, ExisteConNombreAsync = true (otro nombre igual)
  // Assert: resultado.IsFailure && resultado.Error == SalaErrors.NombreDuplicado

[Fact] Update_CambioDeDisponibilidad_SeGuardaCorrectamente()
  // Arrange: sala con Disponible = true
  // Act: UpdateSalaCommand con Disponible = false
  // Assert: sala.Disponible == false después del handle
```

### DeleteSalaCommandHandler Tests (4 tests)

```csharp
[Fact] Delete_SalaSinReservasFuturas_RetornaSuccess()
  // Arrange: GetByIdAsync = sala, TieneReservasFuturasAsync = false
  // Assert: resultado.IsSuccess
  // Assert: _salaRepositoryMock.Verify(x => x.Remove(It.IsAny<Sala>()), Times.Once)

[Fact] Delete_SalaNoEncontrada_RetornaNotFound()
  // Arrange: GetByIdAsync = null
  // Assert: resultado.IsFailure && resultado.Error == SalaErrors.NotFound

[Fact] Delete_SalaConReservasFuturas_RetornaConflict()
  // Arrange: GetByIdAsync = sala, TieneReservasFuturasAsync = true
  // Assert: resultado.IsFailure && resultado.Error == SalaErrors.TieneReservasFuturas

[Fact] Delete_NoLlamaRemoveSiHayReservasFuturas()
  // Arrange: TieneReservasFuturasAsync = true
  // Assert: _salaRepositoryMock.Verify(x => x.Remove(It.IsAny<Sala>()), Times.Never)
```

**Total: 15 tests**

---

## 5. Ficheros a Crear / Modificar

### Crear (nuevos)
```
tests/Application.Tests/Salas/Commands/
├── CreateSalaCommandHandlerTests.cs    ← 7 tests
├── UpdateSalaCommandHandlerTests.cs    ← 4 tests
└── DeleteSalaCommandHandlerTests.cs    ← 4 tests
```

### NO tocar
```
src/                 ← Solo tests, no tocar código de producción
```

---

## 6. Código de Referencia

No hay tests previos en el proyecto (primer sprint). Seguir el patrón xUnit + Moq + FluentAssertions:

```csharp
// Ejemplo de patrón completo de un test:
[Fact]
public async Task Create_ConDatosValidos_RetornaSuccessConGuid()
{
    // Arrange
    var command = new CreateSalaCommand
    {
        Nombre = "Sala Picasso",
        Capacidad = 10,
        Ubicacion = "Planta 2"
    };

    _salaRepositoryMock
        .Setup(x => x.ExisteConNombreAsync(command.Nombre, It.IsAny<CancellationToken>()))
        .ReturnsAsync(false);

    _unitOfWorkMock
        .Setup(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()))
        .ReturnsAsync(1);

    // Act
    var result = await _handler.Handle(command, CancellationToken.None);

    // Assert
    result.IsSuccess.Should().BeTrue();
    result.Value.Should().NotBe(Guid.Empty);
}
```

**Paquetes NuGet requeridos en el proyecto de tests:**
```xml
<PackageReference Include="xunit" Version="2.9.0" />
<PackageReference Include="Moq" Version="4.20.70" />
<PackageReference Include="FluentAssertions" Version="6.12.0" />
<PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.10.0" />
<PackageReference Include="xunit.runner.visualstudio" Version="2.8.0" />
```

---

## 7. Configuración de Entorno

```bash
TEST_PROJECT="tests/Application.Tests"

dotnet test $TEST_PROJECT --filter "FullyQualifiedName~Salas.Commands" --no-build
# Resultado esperado: 15 tests, 0 failed
```

---

## 8. Estado de Implementación

**Estado:** Pendiente
**Último update:** 2026-03-03 09:00
**Actualizado por:** Carlos Mendoza

### Blockers
- [ ] Los handlers de AB#101-B3 deben existir para que compile (o ejecutar en patrón impl-test en paralelo)
- [ ] Las interfaces ISalaRepository e IUnitOfWork deben existir en Domain

---

## 9. Checklist Pre-Entrega

- [ ] Los 3 ficheros de tests existen en `tests/Application.Tests/Salas/Commands/`
- [ ] Los 15 tests están implementados (7 + 4 + 4)
- [ ] Todos los tests pasan: `dotnet test --filter "FullyQualifiedName~Salas.Commands"`
- [ ] Sin código hardcoded (usar variables/constantes)
- [ ] Cada test tiene `// Arrange`, `// Act`, `// Assert` claramente separados
- [ ] No se tocó ningún fichero en `src/`
