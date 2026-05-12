---
name: patterns-dotnet
description: Patrones de arquitectura para C#/.NET y VB.NET
context_cost: low
---

# Patrones — C# / .NET

## 1. Clean Architecture (⭐ Recomendado)

**Folder Structure**:
```
MyApp.Domain/           → Entities, Value Objects, Interfaces
MyApp.Application/      → Use Cases, DTOs, Validators, MediatR handlers
MyApp.Infrastructure/   → EF Core, External APIs, Email, File Storage
MyApp.Api/              → Controllers, Middleware, Program.cs
MyApp.Tests/            → Unit + Integration tests
```

**Detection Markers**:
- Proyectos separados por capa (`.csproj` por capa)
- `Program.cs` o `Startup.cs` con DI container configuration
- MediatR para CQRS (IRequest, IRequestHandler)
- FluentValidation para validaciones
- AutoMapper para mapping DTO↔Entity

**Tools**: NetArchTest, ArchUnitNET, SonarQube

## 2. CQRS + MediatR

**Detection Markers**:
- Carpetas `Commands/`, `Queries/`, `Handlers/`
- Clases `*Command : IRequest<T>`, `*Query : IRequest<T>`
- `*CommandHandler : IRequestHandler<T>`
- NuGet: MediatR, MediatR.Extensions.Microsoft.DependencyInjection

## 3. Hexagonal (Ports & Adapters)

**Detection Markers**:
- Carpetas `Ports/`, `Adapters/`
- Interfaces como ports en Domain: `IUserRepository`, `IEmailService`
- Implementaciones en Infrastructure: `SqlUserRepository`, `SmtpEmailService`
- Sin referencia de Domain a Infrastructure en `.csproj`

## 4. MVVM (WPF / MAUI / Blazor)

**Detection Markers**:
- Carpetas `ViewModels/`, `Views/`, `Models/`
- Clases heredando `INotifyPropertyChanged` o `ObservableObject`
- Data Binding en XAML: `{Binding PropertyName}`
- CommunityToolkit.Mvvm NuGet

## 5. Microservices

**Detection Markers**:
- Múltiples `.sln` o proyectos con `Dockerfile` propio
- Ocelot o YARP como API Gateway
- MassTransit o NServiceBus para messaging
- Health checks con `Microsoft.Extensions.Diagnostics.HealthChecks`

## Fitness Functions (.NET)

```csharp
// NetArchTest example
var result = Types.InAssembly(domainAssembly)
    .ShouldNot()
    .HaveDependencyOn("MyApp.Infrastructure")
    .GetResult();
Assert.True(result.IsSuccessful);
```

## Anti-patterns comunes
- God controllers (>200 líneas)
- Anemic domain models (solo DTOs sin lógica)
- Repository over repository (doble abstracción innecesaria)
- Inyección de DbContext en controllers directamente
