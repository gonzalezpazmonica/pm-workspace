---
paths:
  - "**/*.vb"
  - "**/*.vbproj"
---

# Regla: Convenciones y Prácticas VB.NET
# ── Aplica a todos los proyectos VB.NET en este workspace ──────────────────────

## Verificación obligatoria en cada tarea

Antes de dar una tarea por terminada, ejecutar siempre en este orden:

```bash
dotnet build --configuration Release          # 1. ¿Compila sin warnings?
dotnet format --verify-no-changes             # 2. ¿Respeta el estilo del proyecto?
dotnet test --filter "Category=Unit"          # 3. ¿Pasan los tests unitarios?
```

## Nota sobre VB.NET y C#

VB.NET comparte el runtime .NET con C# — ambos compilan a MSIL e interoperan perfectamente.

- **VB.NET sintaxis:** Case-insensitive, `Option Explicit/Strict` obligatorios
- **C# sintaxis:** Case-sensitive, más conciso, preferido en ecosistema moderno
- **Convención del workspace:** C# es el idioma principal; VB.NET solo en proyectos legacy
- **Interoperabilidad:** Un proyecto VB.NET puede referenciar un assembly C# y viceversa

## Convenciones de código VB.NET

- **Naming:** `PascalCase` para públicos, `_camelCase` para privados
- **Null handling:** `Is Nothing`, `IsNot Nothing` para chequeos
- **Properties:** Usar `Property` con backing field o auto-properties
- **String:** Interpolación `$"Hello {name}"` preferida; LINQ para colecciones
- **Excepciones:** Específicas del dominio; nunca capturar `Exception` genérica
- **Access modifiers:** `Private` por defecto; `Public` solo lo necesario

## Arquitectura (igual a C# / .NET)

Aplicar mismos principios de arquitectura limpia que dotnet-conventions.md:

```
solution.sln
├── src/
│   ├── [Proyecto].Domain/
│   ├── [Proyecto].Application/
│   ├── [Proyecto].Infrastructure/
│   └── [Proyecto].API/
├── tests/
│   ├── [Proyecto].Tests.Unit/
│   └── [Proyecto].Tests.Integration/
└── docs/
```

## Ejemplos de sintaxis VB.NET

```vbnet
Public Class Order
    Public Property Id As Integer
    Public Property Total As Decimal
    
    Public Function GetSummary() As String
        Return $"Order #{Id}: {Total}"
    End Function
End Class

Public Class OrderService
    Private ReadOnly _repository As IOrderRepository
    
    Public Sub New(repository As IOrderRepository)
        _repository = repository
    End Sub
    
    Public Async Function CreateOrderAsync(total As Decimal) As Task(Of Order)
        Dim order = New Order With {.Total = total}
        Await _repository.AddAsync(order)
        Return order
    End Function
End Class
```

## Gestión de dependencias NuGet

```bash
dotnet list package --outdated
dotnet add package {paquete}
dotnet remove package {paquete}
```

Aplicar mismos criterios que C#: verificar licencia, CVEs, actividad.

## Entity Framework Core

```bash
dotnet ef migrations add {nombre}
dotnet ef database update
```

Idéntico a C# — nunca modificar migraciones ya aplicadas.

## Tests

Usar MSTest/xUnit/NUnit idénticos a C#. Naming: `Method_Scenario_Expected`.

## Deploy

```bash
dotnet publish -c Release -o ./publish
```

Variables de entorno: nunca hardcodear secrets.

## Hooks recomendados

Idénticos a dotnet-conventions.md.
