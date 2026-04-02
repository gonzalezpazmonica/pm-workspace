# Savia Model 02 — .NET 8+ Clean Architecture API

> Stack: C# 12 / .NET 8+ / ASP.NET Core / Entity Framework Core / MediatR / xUnit
> Architecture: Clean Architecture (4-layer) with CQRS
> Scale: 2-15 developers, single deployable, moderate domain complexity
> Sources: Jason Taylor CleanArchitecture, Ardalis CleanArchitecture, Milan Jovanovic,
> Microsoft eShopOnContainers, DORA 2025, TurboQuant context research

---

## 1. Philosophy and Culture

Clean Architecture optimizes for **changeability**. The domain model — the
most valuable code in the system — depends on nothing. Frameworks, databases,
and transport mechanisms are implementation details plugged in at the edges.

This model exists because most .NET APIs start correct and drift into
unmaintainable tangles within 6 months. The drift pattern is predictable:
controllers absorb business logic, EF entities leak into API responses,
and testing becomes impossible without a running database. Clean Architecture
prevents this by making the wrong thing hard to do.

### When this model IS appropriate

- APIs with domain logic beyond simple CRUD (validation rules, workflows,
  calculations, authorization decisions that depend on business state)
- Teams of 2-15 developers where shared conventions prevent merge conflicts
- Projects expected to live 2+ years where maintenance cost matters
- Systems where the database or framework may change during the project lifetime
- Agentic development with SDD where agents need clear boundaries per layer

### When this model is NOT appropriate

- Pure CRUD APIs with no business logic — use Minimal APIs directly
- Prototypes and spikes with <3 month expected lifetime
- Single-developer projects where the overhead exceeds the benefit
- Real-time systems where the indirection layers add unacceptable latency
- Microservices with <5 endpoints — Vertical Slice Architecture fits better

### Trade-offs accepted

- **More files**: a single feature touches 4+ files across layers. This is the
  cost of separation. Feature folders mitigate navigation pain.
- **Indirection**: a request flows through Controller -> MediatR -> Handler ->
  Repository -> Database. Each hop is a point of testability.
- **Learning curve**: new developers need 1-2 sprints to internalize the pattern.
  The investment pays off in month 3 when they stop producing coupled code.

---

## 2. Architecture Principles

### The 4 Layers

```
  API (Presentation)      ← Controllers, Middleware, DI wiring
       ↓ depends on
  Application             ← Commands, Queries, Handlers, Validators, DTOs
       ↓ depends on
  Domain                  ← Entities, Value Objects, Domain Events, Interfaces
       ↑ depends on NOTHING
  Infrastructure          ← EF DbContext, Repositories, External Services
       ↑ implements Domain interfaces
```

**The Dependency Rule**: source code dependencies point inward only. Domain
knows nothing about Application. Application knows nothing about Infrastructure
or API. Infrastructure implements interfaces defined in Domain.

### CQRS with MediatR

Commands mutate state. Queries read state. They use separate models:

- **Write side**: rich domain model with EF Core, aggregate validation,
  domain events. Commands return `Result<T>` (never raw entities).
- **Read side**: optimized read models, `AsNoTracking()`, projections.
  For complex reads, Dapper is acceptable alongside EF Core.

MediatR provides the in-process bus. Pipeline behaviors handle cross-cutting
concerns: validation, logging, transaction management, performance monitoring.

### Result Pattern over Exceptions

Business failures are NOT exceptions. A user submitting an invalid form is
expected behavior. Exceptions are for infrastructure failures (database down,
network timeout).

```csharp
// Domain/Common/Result.cs
public sealed class Result<T>
{
    public T? Value { get; }
    public Error? Error { get; }
    public bool IsSuccess => Error is null;

    private Result(T value) => Value = value;
    private Result(Error error) => Error = error;

    public static Result<T> Success(T value) => new(value);
    public static Result<T> Failure(Error error) => new(error);

    public TResult Match<TResult>(
        Func<T, TResult> onSuccess,
        Func<Error, TResult> onFailure) =>
        IsSuccess ? onSuccess(Value!) : onFailure(Error!);
}

public sealed record Error(string Code, string Description)
{
    public static readonly Error None = new(string.Empty, string.Empty);
    public static Error NotFound(string entity, object id) =>
        new($"{entity}.NotFound", $"{entity} with id '{id}' was not found.");
    public static Error Validation(string description) =>
        new("Validation", description);
    public static Error Conflict(string description) =>
        new("Conflict", description);
}
```

### Repository Pattern: when to use it

Use repositories when:
- The domain has aggregate roots with invariants to protect
- You need to swap persistence (testing with fakes, future migration)
- Multiple handlers share the same data access patterns

Skip repositories when:
- The read side is a simple projection (query handlers can use DbContext directly)
- The entity has no domain logic (pure CRUD — consider if Clean Arch is appropriate)

---

## 3. Project Structure

### Solution Layout

```
MyApp/
├── global.json
├── Directory.Build.props
├── Directory.Packages.props
├── .editorconfig
├── MyApp.sln
│
├── src/
│   ├── MyApp.Domain/                    ← Zero dependencies
│   │   ├── Common/
│   │   │   ├── BaseEntity.cs
│   │   │   ├── AggregateRoot.cs
│   │   │   ├── IDomainEvent.cs
│   │   │   ├── Result.cs
│   │   │   └── Error.cs
│   │   ├── Orders/                      ← Feature folder
│   │   │   ├── Order.cs                 ← Aggregate root
│   │   │   ├── OrderItem.cs             ← Entity
│   │   │   ├── OrderId.cs              ← Strongly-typed ID
│   │   │   ├── OrderStatus.cs           ← Value object / enum
│   │   │   ├── IOrderRepository.cs      ← Port
│   │   │   └── Events/
│   │   │       ├── OrderCreatedEvent.cs
│   │   │       └── OrderCompletedEvent.cs
│   │   └── Customers/
│   │       ├── Customer.cs
│   │       ├── CustomerId.cs
│   │       ├── Email.cs                 ← Value object
│   │       └── ICustomerRepository.cs
│   │
│   ├── MyApp.Application/              ← Depends on Domain only
│   │   ├── Common/
│   │   │   ├── Behaviors/
│   │   │   │   ├── ValidationBehavior.cs
│   │   │   │   ├── LoggingBehavior.cs
│   │   │   │   └── PerformanceBehavior.cs
│   │   │   ├── Interfaces/
│   │   │   │   ├── IApplicationDbContext.cs
│   │   │   │   └── ICurrentUserService.cs
│   │   │   └── Mappings/
│   │   │       └── MappingProfile.cs
│   │   ├── Orders/
│   │   │   ├── Commands/
│   │   │   │   ├── CreateOrder/
│   │   │   │   │   ├── CreateOrderCommand.cs
│   │   │   │   │   ├── CreateOrderCommandHandler.cs
│   │   │   │   │   └── CreateOrderCommandValidator.cs
│   │   │   │   └── CompleteOrder/
│   │   │   │       ├── CompleteOrderCommand.cs
│   │   │   │       └── CompleteOrderCommandHandler.cs
│   │   │   ├── Queries/
│   │   │   │   └── GetOrderById/
│   │   │   │       ├── GetOrderByIdQuery.cs
│   │   │   │       ├── GetOrderByIdQueryHandler.cs
│   │   │   │       └── OrderDto.cs
│   │   │   └── EventHandlers/
│   │   │       └── OrderCreatedEventHandler.cs
│   │   └── DependencyInjection.cs
│   │
│   ├── MyApp.Infrastructure/           ← Depends on Domain + Application
│   │   ├── Persistence/
│   │   │   ├── ApplicationDbContext.cs
│   │   │   ├── Configurations/
│   │   │   │   ├── OrderConfiguration.cs
│   │   │   │   └── CustomerConfiguration.cs
│   │   │   ├── Repositories/
│   │   │   │   └── OrderRepository.cs
│   │   │   ├── Interceptors/
│   │   │   │   ├── AuditableEntityInterceptor.cs
│   │   │   │   └── DomainEventDispatcherInterceptor.cs
│   │   │   └── Migrations/
│   │   ├── Services/
│   │   │   └── DateTimeProvider.cs
│   │   └── DependencyInjection.cs
│   │
│   └── MyApp.Api/                      ← Depends on Application + Infrastructure
│       ├── Controllers/
│       │   └── OrdersController.cs
│       ├── Middleware/
│       │   └── GlobalExceptionHandler.cs
│       ├── Filters/
│       │   └── ApiExceptionFilterAttribute.cs
│       ├── Program.cs
│       ├── appsettings.json
│       └── Dockerfile
│
├── tests/
│   ├── MyApp.Domain.Tests/             ← Zero mocks, pure logic
│   ├── MyApp.Application.Tests/        ← Mock ports (repositories, services)
│   ├── MyApp.Infrastructure.Tests/     ← TestContainers + real DB
│   └── MyApp.Api.Tests/               ← WebApplicationFactory + TestContainers
│
└── docs/
    └── architecture/
```

### Directory.Build.props

```xml
<Project>
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <AnalysisLevel>latest-all</AnalysisLevel>
    <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
  </PropertyGroup>
</Project>
```

### Directory.Packages.props (Central Package Management)

```xml
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>
  <ItemGroup>
    <PackageVersion Include="MediatR" Version="12.4.1" />
    <PackageVersion Include="FluentValidation" Version="11.11.0" />
    <PackageVersion Include="FluentValidation.DependencyInjectionExtensions" Version="11.11.0" />
    <PackageVersion Include="Microsoft.EntityFrameworkCore" Version="8.0.11" />
    <PackageVersion Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.11" />
    <PackageVersion Include="Serilog.AspNetCore" Version="8.0.3" />
    <PackageVersion Include="OpenTelemetry.Extensions.Hosting" Version="1.10.0" />
    <PackageVersion Include="xunit" Version="2.9.3" />
    <PackageVersion Include="Testcontainers.MsSql" Version="4.1.0" />
    <PackageVersion Include="Microsoft.AspNetCore.Mvc.Testing" Version="8.0.11" />
  </ItemGroup>
</Project>
```

### global.json

```json
{
  "sdk": {
    "version": "8.0.400",
    "rollForward": "latestMinor"
  }
}
```

---

## 4. Code Patterns

### BaseEntity with Domain Events

```csharp
// Domain/Common/BaseEntity.cs
public abstract class BaseEntity
{
    public int Id { get; protected set; }

    private readonly List<IDomainEvent> _domainEvents = [];
    public IReadOnlyCollection<IDomainEvent> DomainEvents => _domainEvents.AsReadOnly();

    public void AddDomainEvent(IDomainEvent domainEvent) =>
        _domainEvents.Add(domainEvent);

    public void ClearDomainEvents() => _domainEvents.Clear();
}

public interface IDomainEvent : MediatR.INotification
{
    DateTime OccurredOn { get; }
}

public abstract record DomainEvent : IDomainEvent
{
    public DateTime OccurredOn { get; } = DateTime.UtcNow;
}
```

### Strongly-Typed IDs

```csharp
// Domain/Orders/OrderId.cs
[JsonConverter(typeof(OrderIdJsonConverter))]
public readonly record struct OrderId(Guid Value)
{
    public static OrderId New() => new(Guid.NewGuid());
    public override string ToString() => Value.ToString();
}

// In EF Core configuration:
public sealed class OrderConfiguration : IEntityTypeConfiguration<Order>
{
    public void Configure(EntityTypeBuilder<Order> builder)
    {
        builder.HasKey(o => o.Id);
        builder.Property(o => o.Id)
            .HasConversion(
                id => id.Value,
                value => new OrderId(value));
    }
}
```

### Aggregate Root with Factory Method returning Result

```csharp
// Domain/Orders/Order.cs
public sealed class Order : BaseEntity
{
    public OrderId Id { get; private set; }
    public CustomerId CustomerId { get; private set; }
    public OrderStatus Status { get; private set; }
    public DateTime CreatedAt { get; private set; }

    private readonly List<OrderItem> _items = [];
    public IReadOnlyCollection<OrderItem> Items => _items.AsReadOnly();

    public decimal TotalAmount => _items.Sum(i => i.Price * i.Quantity);

    private Order() { } // EF Core

    public static Result<Order> Create(CustomerId customerId, List<OrderItemRequest> items)
    {
        if (items is null || items.Count == 0)
            return Result<Order>.Failure(
                Error.Validation("An order must have at least one item."));

        var order = new Order
        {
            Id = OrderId.New(),
            CustomerId = customerId,
            Status = OrderStatus.Pending,
            CreatedAt = DateTime.UtcNow
        };

        foreach (var item in items)
        {
            var addResult = order.AddItem(item.ProductId, item.Quantity, item.Price);
            if (!addResult.IsSuccess)
                return Result<Order>.Failure(addResult.Error!);
        }

        order.AddDomainEvent(new OrderCreatedEvent(order.Id));
        return Result<Order>.Success(order);
    }

    public Result<OrderItem> AddItem(string productId, int quantity, decimal price)
    {
        if (Status != OrderStatus.Pending)
            return Result<OrderItem>.Failure(
                Error.Validation("Cannot modify a non-pending order."));

        if (quantity <= 0)
            return Result<OrderItem>.Failure(
                Error.Validation("Quantity must be positive."));

        var item = new OrderItem(productId, quantity, price);
        _items.Add(item);
        return Result<OrderItem>.Success(item);
    }

    public Result<Order> Complete()
    {
        if (Status != OrderStatus.Pending)
            return Result<Order>.Failure(
                Error.Conflict($"Cannot complete order in '{Status}' status."));

        Status = OrderStatus.Completed;
        AddDomainEvent(new OrderCompletedEvent(Id, TotalAmount));
        return Result<Order>.Success(this);
    }
}
```

### Command + Handler with MediatR

```csharp
// Application/Orders/Commands/CreateOrder/CreateOrderCommand.cs
public sealed record CreateOrderCommand(
    Guid CustomerId,
    List<CreateOrderCommand.ItemDto> Items) : IRequest<Result<Guid>>
{
    public sealed record ItemDto(string ProductId, int Quantity, decimal Price);
}

// Application/Orders/Commands/CreateOrder/CreateOrderCommandHandler.cs
public sealed class CreateOrderCommandHandler(
    IOrderRepository orderRepository,
    IUnitOfWork unitOfWork)
    : IRequestHandler<CreateOrderCommand, Result<Guid>>
{
    public async Task<Result<Guid>> Handle(
        CreateOrderCommand request,
        CancellationToken cancellationToken)
    {
        var items = request.Items
            .Select(i => new OrderItemRequest(i.ProductId, i.Quantity, i.Price))
            .ToList();

        var orderResult = Order.Create(new CustomerId(request.CustomerId), items);

        if (!orderResult.IsSuccess)
            return Result<Guid>.Failure(orderResult.Error!);

        orderRepository.Add(orderResult.Value!);
        await unitOfWork.SaveChangesAsync(cancellationToken);

        return Result<Guid>.Success(orderResult.Value!.Id.Value);
    }
}
```

### FluentValidation + ValidationBehavior Pipeline

```csharp
// Application/Orders/Commands/CreateOrder/CreateOrderCommandValidator.cs
public sealed class CreateOrderCommandValidator : AbstractValidator<CreateOrderCommand>
{
    public CreateOrderCommandValidator()
    {
        RuleFor(x => x.CustomerId)
            .NotEmpty().WithMessage("Customer ID is required.");

        RuleFor(x => x.Items)
            .NotEmpty().WithMessage("At least one item is required.");

        RuleForEach(x => x.Items).ChildRules(item =>
        {
            item.RuleFor(i => i.ProductId).NotEmpty();
            item.RuleFor(i => i.Quantity).GreaterThan(0);
            item.RuleFor(i => i.Price).GreaterThan(0);
        });
    }
}

// Application/Common/Behaviors/ValidationBehavior.cs
public sealed class ValidationBehavior<TRequest, TResponse>(
    IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : IRequest<TResponse>
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        if (!validators.Any())
            return await next();

        var context = new ValidationContext<TRequest>(request);
        var failures = (await Task.WhenAll(
                validators.Select(v => v.ValidateAsync(context, cancellationToken))))
            .SelectMany(result => result.Errors)
            .Where(f => f is not null)
            .ToList();

        if (failures.Count != 0)
            throw new ValidationException(failures);

        return await next();
    }
}
```

### ProblemDetails + GlobalExceptionHandler

```csharp
// Api/Middleware/GlobalExceptionHandler.cs
public sealed class GlobalExceptionHandler(
    ILogger<GlobalExceptionHandler> logger)
    : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        logger.LogError(exception, "Unhandled exception: {Message}", exception.Message);

        var (statusCode, title, detail) = exception switch
        {
            ValidationException ve => (
                StatusCodes.Status400BadRequest,
                "Validation Error",
                string.Join("; ", ve.Errors.Select(e => e.ErrorMessage))),
            UnauthorizedAccessException => (
                StatusCodes.Status403Forbidden,
                "Forbidden",
                "You do not have permission to perform this action."),
            _ => (
                StatusCodes.Status500InternalServerError,
                "Server Error",
                "An unexpected error occurred.")
        };

        httpContext.Response.StatusCode = statusCode;
        await httpContext.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = statusCode,
            Title = title,
            Detail = detail,
            Instance = httpContext.Request.Path
        }, cancellationToken);

        return true;
    }
}

// In Controller — mapping Result to HTTP responses:
[ApiController]
[Route("api/[controller]")]
public sealed class OrdersController(ISender sender) : ControllerBase
{
    [HttpPost]
    [ProducesResponseType(typeof(Guid), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Create(
        CreateOrderCommand command,
        CancellationToken cancellationToken)
    {
        var result = await sender.Send(command, cancellationToken);

        return result.Match<IActionResult>(
            id => CreatedAtAction(nameof(GetById), new { id }, id),
            error => Problem(
                statusCode: error.Code == "Validation"
                    ? StatusCodes.Status400BadRequest
                    : StatusCodes.Status409Conflict,
                title: error.Code,
                detail: error.Description));
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(
        Guid id, CancellationToken cancellationToken)
    {
        var result = await sender.Send(
            new GetOrderByIdQuery(id), cancellationToken);

        return result.Match<IActionResult>(
            dto => Ok(dto),
            error => NotFound(new ProblemDetails
            {
                Status = 404,
                Title = error.Code,
                Detail = error.Description
            }));
    }
}
```

### Domain Event Dispatcher Interceptor

```csharp
// Infrastructure/Persistence/Interceptors/DomainEventDispatcherInterceptor.cs
public sealed class DomainEventDispatcherInterceptor(IPublisher publisher)
    : SaveChangesInterceptor
{
    public override async ValueTask<int> SavedChangesAsync(
        SaveChangesCompletedEventData eventData,
        int result,
        CancellationToken cancellationToken = default)
    {
        if (eventData.Context is not null)
            await DispatchDomainEvents(eventData.Context, cancellationToken);

        return result;
    }

    private async Task DispatchDomainEvents(
        DbContext context, CancellationToken cancellationToken)
    {
        var entities = context.ChangeTracker
            .Entries<BaseEntity>()
            .Where(e => e.Entity.DomainEvents.Count != 0)
            .Select(e => e.Entity)
            .ToList();

        var domainEvents = entities
            .SelectMany(e => e.DomainEvents)
            .ToList();

        entities.ForEach(e => e.ClearDomainEvents());

        foreach (var domainEvent in domainEvents)
            await publisher.Publish(domainEvent, cancellationToken);
    }
}
```

---

## 5. Testing and Quality

### Test Pyramid

| Level | Ratio | Project | What it tests | Mocks |
|-------|-------|---------|---------------|-------|
| Unit (Domain) | 70% | Domain.Tests | Entity logic, value objects, domain events | **Zero** — pure functions |
| Unit (Application) | — | Application.Tests | Handlers, validators, pipeline behaviors | Mock repositories and services |
| Integration | 25% | Infrastructure.Tests | EF configurations, repositories, migrations | Real SQL Server via TestContainers |
| E2E | 5% | Api.Tests | Full HTTP pipeline, auth, middleware | WebApplicationFactory + TestContainers |

### Coverage Targets

| Layer | Minimum | Target | Rationale |
|-------|---------|--------|-----------|
| Domain | 95% | 98% | Most valuable code, zero external deps, no excuse |
| Application | 85% | 90% | Handlers with mocked ports are fast to test |
| Infrastructure | 60% | 75% | EF config tested via integration, boilerplate exempt |
| API | 70% | 80% | Controller mapping + middleware + auth |

### Domain Tests (zero mocks)

```csharp
public sealed class OrderTests
{
    [Fact]
    public void Create_WithValidItems_ReturnsSuccess()
    {
        var items = new List<OrderItemRequest>
        {
            new("PROD-001", 2, 29.99m)
        };

        var result = Order.Create(new CustomerId(Guid.NewGuid()), items);

        result.IsSuccess.Should().BeTrue();
        result.Value!.Items.Should().HaveCount(1);
        result.Value.Status.Should().Be(OrderStatus.Pending);
        result.Value.DomainEvents.Should().ContainSingle()
            .Which.Should().BeOfType<OrderCreatedEvent>();
    }

    [Fact]
    public void Create_WithEmptyItems_ReturnsFailure()
    {
        var result = Order.Create(
            new CustomerId(Guid.NewGuid()), []);

        result.IsSuccess.Should().BeFalse();
        result.Error!.Code.Should().Be("Validation");
    }

    [Fact]
    public void Complete_WhenAlreadyCompleted_ReturnsConflict()
    {
        var order = CreateValidOrder();
        order.Complete(); // first time succeeds

        var result = order.Complete(); // second time fails

        result.IsSuccess.Should().BeFalse();
        result.Error!.Code.Should().Be("Conflict");
    }
}
```

### Handler Tests (mock ports)

```csharp
public sealed class CreateOrderCommandHandlerTests
{
    private readonly Mock<IOrderRepository> _repository = new();
    private readonly Mock<IUnitOfWork> _unitOfWork = new();

    [Fact]
    public async Task Handle_ValidCommand_ReturnsOrderId()
    {
        var handler = new CreateOrderCommandHandler(
            _repository.Object, _unitOfWork.Object);

        var command = new CreateOrderCommand(
            Guid.NewGuid(),
            [new("PROD-001", 1, 10.0m)]);

        var result = await handler.Handle(command, CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Value.Should().NotBeEmpty();
        _repository.Verify(r => r.Add(It.IsAny<Order>()), Times.Once);
        _unitOfWork.Verify(u => u.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }
}
```

### Integration Tests with WebApplicationFactory + TestContainers

```csharp
// Api.Tests/CustomWebApplicationFactory.cs
public sealed class CustomWebApplicationFactory
    : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly MsSqlContainer _dbContainer = new MsSqlBuilder()
        .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
        .Build();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            services.RemoveAll<DbContextOptions<ApplicationDbContext>>();
            services.AddDbContext<ApplicationDbContext>(options =>
                options.UseSqlServer(_dbContainer.GetConnectionString()));
        });
    }

    public async Task InitializeAsync()
    {
        await _dbContainer.StartAsync();
        // Apply migrations
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        await db.Database.MigrateAsync();
    }

    public new async Task DisposeAsync() =>
        await _dbContainer.DisposeAsync();
}

// Api.Tests/OrdersEndpointTests.cs
public sealed class OrdersEndpointTests(
    CustomWebApplicationFactory factory)
    : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client = factory.CreateClient();

    [Fact]
    public async Task CreateOrder_ReturnsCreated()
    {
        var command = new
        {
            CustomerId = Guid.NewGuid(),
            Items = new[] { new { ProductId = "P1", Quantity = 1, Price = 9.99m } }
        };

        var response = await _client.PostAsJsonAsync("/api/orders", command);

        response.StatusCode.Should().Be(HttpStatusCode.Created);
        response.Headers.Location.Should().NotBeNull();
    }

    [Fact]
    public async Task CreateOrder_EmptyItems_ReturnsBadRequest()
    {
        var command = new { CustomerId = Guid.NewGuid(), Items = Array.Empty<object>() };

        var response = await _client.PostAsJsonAsync("/api/orders", command);

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var problem = await response.Content.ReadFromJsonAsync<ProblemDetails>();
        problem!.Status.Should().Be(400);
    }
}
```

**Critical**: NEVER use EF Core InMemoryDatabase for testing. It does not enforce
constraints, relationships, or SQL behavior. TestContainers with a real SQL Server
container is the correct approach for integration tests.

---

## 6. Security and Data Sovereignty

### Authentication and Authorization

```csharp
// Program.cs — JWT Bearer + OIDC
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = builder.Configuration["Auth:Authority"];
        options.Audience = builder.Configuration["Auth:Audience"];
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30)
        };
    });

// Policy-based authorization
builder.Services.AddAuthorizationBuilder()
    .AddPolicy("OrderManager", policy =>
        policy.RequireRole("Admin", "OrderManager"))
    .AddPolicy("CanCompleteOrders", policy =>
        policy.RequireClaim("permission", "orders:complete"));
```

### Defense-in-Depth Validation

Validation happens at three levels:
1. **API layer**: FluentValidation on the command (shape and format)
2. **Application layer**: Business rule checks in the handler (authorization, existence)
3. **Domain layer**: Invariant enforcement in the aggregate (the last line of defense)

### Rate Limiting

```csharp
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("api", limiter =>
    {
        limiter.PermitLimit = 100;
        limiter.Window = TimeSpan.FromMinutes(1);
        limiter.QueueLimit = 0;
    });
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
});
```

### OWASP .NET Top 10 Checklist

| Risk | Mitigation |
|------|-----------|
| Injection | Parameterized queries only. Never `FromSqlRaw` with interpolation. |
| Broken Auth | JWT with short-lived tokens, refresh token rotation |
| Sensitive Data Exposure | HTTPS enforced, no secrets in config, Azure Key Vault |
| XXE | XML processing disabled by default in .NET 8 |
| Broken Access Control | Policy-based auth, resource-level checks in handlers |
| Security Misconfiguration | `TreatWarningsAsErrors`, analyzers enabled, HSTS |
| XSS | ASP.NET Core auto-encodes by default, CSP headers |
| Insecure Deserialization | System.Text.Json with strict options, no BinaryFormatter |
| Insufficient Logging | Serilog + OpenTelemetry, structured logging, audit trail |
| SSRF | HttpClient with allowed-list base addresses |

### Savia Shield Integration

Data classified as N4 (client project data) MUST pass through the data sovereignty
gate before any external API call. In practice: the EF DbContext interceptor logs
all mutations, and the Savia Shield regex layer scans any output destined for N1
(public) destinations.

---

## 7. DevOps and Operations

### CI Pipeline

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    services:
      sqlserver:
        image: mcr.microsoft.com/mssql/server:2022-latest
        env:
          ACCEPT_EULA: Y
          SA_PASSWORD: YourStr0ng!Pass
        ports: ['1433:1433']
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'
      - run: dotnet restore
      - run: dotnet build --no-restore --configuration Release
      - run: dotnet format --verify-no-changes
      - run: dotnet test --no-build --configuration Release
             --collect "XPlat Code Coverage"
             --results-directory ./coverage
      - name: Check coverage
        run: |
          dotnet tool install -g dotnet-reportgenerator-globaltool
          reportgenerator -reports:./coverage/**/coverage.cobertura.xml \
            -targetdir:./coverage-report -reporttypes:TextSummary
          cat ./coverage-report/Summary.txt
```

### Multi-Stage Dockerfile

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY Directory.Build.props Directory.Packages.props ./
COPY **/*.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish src/MyApp.Api/MyApp.Api.csproj \
    -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
RUN adduser --disabled-password --gecos '' appuser
USER appuser
COPY --from=build /app/publish .
EXPOSE 8080
ENTRYPOINT ["dotnet", "MyApp.Api.dll"]
```

### Health Checks

```csharp
builder.Services
    .AddHealthChecks()
    .AddDbContextCheck<ApplicationDbContext>("database")
    .AddCheck("self", () => HealthCheckResult.Healthy());

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = _ => false // liveness = app responds
});
```

### Observability: OpenTelemetry + Serilog

```csharp
// Program.cs
builder.Host.UseSerilog((context, config) => config
    .ReadFrom.Configuration(context.Configuration)
    .Enrich.FromLogContext()
    .Enrich.WithProperty("Service", "MyApp.Api")
    .WriteTo.OpenTelemetry(options =>
    {
        options.Endpoint = context.Configuration["Otlp:Endpoint"]!;
        options.ResourceAttributes["service.name"] = "MyApp.Api";
    }));

builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddEntityFrameworkCoreInstrumentation()
        .AddOtlpExporter())
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter());
```

### Migration Strategy

- **Development**: `dotnet ef database update` is acceptable
- **CI/CD**: migrations applied via `dotnet ef migrations bundle` (idempotent bundle)
- **Production**: NEVER auto-migrate. Generate SQL script with
  `dotnet ef migrations script --idempotent`, review it, apply via controlled process
- **Rollback**: every migration must have a corresponding `Down()`. Test rollback
  in CI before merging

---

## 8. Anti-Patterns and Guardrails

### 15 DOs

| # | Practice | Rationale |
|---|----------|-----------|
| 1 | `sealed` on all classes that are not designed for inheritance | Prevents accidental overrides, enables JIT devirtualization |
| 2 | Pass `CancellationToken` through the entire async chain | Enables graceful shutdown and request cancellation |
| 3 | `AsNoTracking()` on all read queries | Eliminates change tracker overhead (up to 40% faster reads) |
| 4 | Primary constructors for DI in handlers and services | Reduces boilerplate, C# 12 idiomatic |
| 5 | Feature folders inside each layer project | Navigation by feature, not by technical concern |
| 6 | One handler per file, one validator per command | Single responsibility, easy to locate |
| 7 | `ConfigureAwait(false)` in library code (Domain, Application) | Prevents deadlocks in non-ASP.NET hosts |
| 8 | Use `IReadOnlyCollection<T>` for aggregate collections | Protects invariants, forces mutation through aggregate methods |
| 9 | `record` types for Commands, Queries, DTOs, Value Objects | Immutability, structural equality, concise syntax |
| 10 | `IEntityTypeConfiguration<T>` per entity in separate files | Keeps DbContext clean, one config per entity |
| 11 | Central Package Management with `Directory.Packages.props` | Single source of truth for package versions |
| 12 | Health checks for every external dependency | Enables Kubernetes readiness/liveness probes |
| 13 | Structured logging with Serilog — message templates, not interpolation | Enables log querying, prevents log injection |
| 14 | Return `Result<T>` from domain operations, not exceptions | Expected failures are not exceptional |
| 15 | EF Core interceptors for cross-cutting concerns (audit, events) | Keeps DbContext clean, domain events dispatched reliably |

### 15 DON'Ts

| # | Anti-Pattern | Why it is wrong |
|---|-------------|-----------------|
| 1 | `Task.Result` or `.Wait()` anywhere | Deadlocks in ASP.NET, thread pool starvation |
| 2 | Empty `catch {}` blocks | Silently swallows errors, makes debugging impossible |
| 3 | `FromSqlRaw($"... {userInput}")` | SQL injection — use `FromSqlInterpolated` or parameterized |
| 4 | EF Core InMemoryDatabase for tests | Does not enforce constraints, gives false confidence |
| 5 | `ServiceLocator` pattern (`IServiceProvider.GetService` in domain) | Hides dependencies, makes testing hard, violates DI |
| 6 | Exposing EF entities in API responses | Couples database schema to API contract |
| 7 | Business logic in controllers | Controllers are transport adapters, not orchestrators |
| 8 | `async void` (except event handlers) | Unobservable exceptions, no cancellation support |
| 9 | Circular project references | Violates dependency rule, breaks layer isolation |
| 10 | Injecting `DbContext` directly into controllers | Bypasses application layer, couples API to persistence |
| 11 | Auto-migrate in production (`Database.Migrate()` in `Program.cs`) | Unpredictable, no review, no rollback plan |
| 12 | Magic strings for configuration keys | Use strongly-typed options pattern (`IOptions<T>`) |
| 13 | Calling `SaveChanges()` multiple times per request | Each call is a separate transaction, breaks atomicity |
| 14 | `Thread.Sleep()` in async code | Blocks thread pool thread, use `Task.Delay` |
| 15 | `public` setters on domain entities | Breaks encapsulation, allows invalid state mutations |

---

## 9. Agentic Integration

### Layer Assignment Matrix

| Task Type | Agent | Human | Rationale |
|-----------|-------|-------|-----------|
| Domain entity + value objects | Agent implements, human reviews | Human approves invariants | Domain logic is the most critical — human validates business rules |
| Command + Handler | Agent implements | Human reviews | Mechanical once spec is clear |
| FluentValidation validators | Agent implements | Human spot-checks | Deterministic from spec acceptance criteria |
| EF Core configuration | Agent implements | Human reviews migrations | Schema changes need human oversight |
| Controller endpoints | Agent implements | Human reviews auth policies | Transport mapping is mechanical |
| Unit tests (Domain) | Agent implements | Human reviews edge cases | Agent excels at generating test permutations |
| Integration tests | Agent scaffolds | Human validates setup | TestContainers setup requires environment knowledge |
| Security policies | Human designs | Agent implements | Security decisions require human judgment |
| CI/CD pipeline | Human designs | Agent implements YAML | Pipeline architecture is a human decision |
| Database migrations | Agent generates | Human reviews and applies | Migrations are irreversible in production |

### SDD Spec Template for Clean Architecture

```markdown
## Spec: [Feature Name]

### Layer: Domain
- Entities: [list with properties and invariants]
- Value Objects: [list with validation rules]
- Domain Events: [list with trigger conditions]
- Repository Interface: [methods needed]

### Layer: Application
- Commands: [list with input/output types]
- Queries: [list with input/output types]
- Validators: [rules per command]

### Layer: Infrastructure
- EF Configuration: [table mappings, indexes]
- Repository Implementation: [query patterns]

### Layer: API
- Endpoints: [HTTP method, route, auth policy]
- Response codes: [per endpoint]

### Acceptance Criteria
- Given [precondition], When [action], Then [expected result]

### Quality Gates
- Domain tests: >= 95% coverage on new entities
- Handler tests: all commands and queries covered
- Integration test: at least 1 happy path + 1 error path per endpoint
```

### Quality Gates for Agentic Implementation

| Gate | Automated Check | Threshold |
|------|----------------|-----------|
| Build | `dotnet build --configuration Release` | Zero errors, zero warnings |
| Format | `dotnet format --verify-no-changes` | Zero violations |
| Unit tests | `dotnet test --filter "Category=Unit"` | All pass |
| Integration tests | `dotnet test --filter "Category=Integration"` | All pass |
| Coverage | ReportGenerator summary | Domain >= 95%, Application >= 85% |
| Security scan | `dotnet list package --vulnerable` | Zero high/critical |
| Architecture | ArchUnitNET dependency tests | No layer violations |
| File size | No file > 150 lines | Per Savia Model rule |

### ArchUnitNET — Enforcing the Dependency Rule in CI

```csharp
// Tests/ArchitectureTests.cs
public sealed class ArchitectureTests
{
    private static readonly Architecture Architecture =
        new ArchLoader().LoadAssemblies(
            typeof(Order).Assembly,           // Domain
            typeof(CreateOrderCommand).Assembly, // Application
            typeof(ApplicationDbContext).Assembly, // Infrastructure
            typeof(Program).Assembly)         // Api
        .Build();

    [Fact]
    public void Domain_ShouldNotDependOn_Application()
    {
        Types().That().ResideInAssembly(typeof(Order).Assembly)
            .Should().NotDependOnAny(
                Types().That().ResideInAssembly(typeof(CreateOrderCommand).Assembly))
            .Check(Architecture);
    }

    [Fact]
    public void Domain_ShouldNotDependOn_Infrastructure()
    {
        Types().That().ResideInAssembly(typeof(Order).Assembly)
            .Should().NotDependOnAny(
                Types().That().ResideInAssembly(typeof(ApplicationDbContext).Assembly))
            .Check(Architecture);
    }
}
```

---

## References

- [Jason Taylor — Clean Architecture Template](https://github.com/jasontaylordev/CleanArchitecture)
- [Ardalis — Clean Architecture Template v8](https://ardalis.com/aspnetcore-clean-architecture-template-version-8/)
- [Milan Jovanovic — CQRS Pattern with MediatR](https://www.milanjovanovic.tech/blog/cqrs-pattern-with-mediatr)
- [CQRS with MediatR and FluentValidation in .NET 8](https://developersvoice.com/blog/dotnet/implementing-cqrs-with-mediatr-and-fluentvalidation/)
- [TestContainers — Testing an ASP.NET Core Web App](https://testcontainers.com/guides/testing-an-aspnet-core-web-app/)
- [TestContainers for .NET — ASP.NET Examples](https://dotnet.testcontainers.org/examples/aspnet/)
- [DDD with Entity Framework Core 8](https://thehonestcoder.com/ddd-ef-core-8/)
- [Microsoft — Domain Events Design and Implementation](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-events-design-implementation)
- [Serilog + OpenTelemetry in .NET](https://last9.io/blog/serilog-and-opentelemetry/)
- [.NET Observability with OpenTelemetry](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/observability-with-otel)
- [Andrew Lock — StronglyTypedId Generator](https://github.com/andrewlock/StronglyTypedId)
- [Microsoft ISE — Clean Architecture Boilerplate](https://devblogs.microsoft.com/ise/next-level-clean-architecture-boilerplate/)
