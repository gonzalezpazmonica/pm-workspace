---
name: patterns-php
description: Patrones de arquitectura para PHP/Laravel
context_cost: low
---

# Patrones — PHP / Laravel

## 1. DDD + Clean Architecture (⭐ Recomendado para apps enterprise)

**Folder Structure**:
```
app/
├── Domain/
│   ├── User/
│   │   ├── Models/        → Eloquent models + domain logic
│   │   ├── Events/        → Domain events
│   │   ├── ValueObjects/  → Immutable value objects
│   │   └── Repositories/  → Repository interfaces
│   └── Order/
├── Application/
│   ├── User/
│   │   ├── Commands/      → CreateUser, UpdateUser
│   │   ├── Queries/       → GetUserById, ListUsers
│   │   └── Services/      → Application services
│   └── Order/
├── Infrastructure/
│   ├── Persistence/       → Eloquent repository implementations
│   ├── External/          → API clients, mail services
│   └── Providers/         → Service providers
└── Presentation/
    ├── Http/
    │   ├── Controllers/   → HTTP controllers
    │   ├── Requests/      → Form requests (validation)
    │   └── Resources/     → API resources (transformers)
    └── Console/           → Artisan commands
```

**Detection Markers**:
- Carpetas `Domain/`, `Application/`, `Infrastructure/` dentro de `app/`
- Repository interfaces en Domain, implementaciones en Infrastructure
- Value Objects como clases inmutables
- Service Providers para binding interfaces

## 2. MVC — Laravel Estándar

**Folder Structure**:
```
app/
├── Http/
│   ├── Controllers/       → Request handlers
│   ├── Middleware/         → Request/response filters
│   └── Requests/          → Form validation
├── Models/                → Eloquent models
├── Providers/             → Service providers
└── Services/ (opcional)   → Business logic
```

**Detection Markers**:
- `artisan` en raíz → Laravel
- `app/Http/Controllers/` con `extends Controller`
- `app/Models/` con `extends Model` (Eloquent)
- `routes/web.php`, `routes/api.php`
- `config/`, `database/migrations/`, `resources/views/`

## 3. Service Layer Pattern

**Detection Markers**:
- Carpeta `app/Services/` con clases de negocio
- Controllers delegan a services
- Services no dependen de HTTP (testables independientemente)

## 4. Repository Pattern

**Detection Markers**:
- `app/Repositories/` con interfaces y implementaciones
- Binding en `AppServiceProvider`: `$this->app->bind(Interface, Implementation)`
- Abstracción sobre Eloquent

## 5. Event-Driven (Laravel Events)

**Detection Markers**:
- `app/Events/` con event classes
- `app/Listeners/` con event handlers
- `EventServiceProvider` con registros
- Laravel Horizon para queue management

## Laravel-Specific Tools
- **Laravel Pint**: Code style fixer (PSR-12)
- **PHPStan / Larastan**: Análisis estático
- **Pest / PHPUnit**: Testing
- **Deptrac**: Architecture dependency checking
- **PHPAT**: PHP Architecture Tester

## Anti-patterns comunes
- Fat controllers (lógica de negocio en controllers)
- Eloquent en controllers (en lugar de repository/service)
- God models (1000+ líneas en un Model)
- Falta de Form Requests (validación inline)
- Middleware overuse (lógica que debería estar en services)
