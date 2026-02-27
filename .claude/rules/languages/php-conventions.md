---
paths:
  - "**/*.php"
  - "**/composer.json"
---

# Regla: Convenciones y Prácticas PHP/Laravel
# ── Aplica a todos los proyectos Laravel en este workspace ──────────────────────

## Verificación obligatoria en cada tarea

Antes de dar una tarea por terminada, ejecutar siempre en este orden:

```bash
php artisan build                              # 1. ¿Compila sin warnings?
./vendor/bin/php-cs-fixer fix --dry-run       # 2. ¿Respeta el formato?
./vendor/bin/phpstan analyse --level=9        # 3. ¿Análisis estático sin errores?
php artisan test                               # 4. ¿Pasan los tests?
```

Si hay tests de integración o feature:
```bash
php artisan test --filter=Feature
```

## Convenciones de código PHP

- **Naming:** `PascalCase` para clases, `camelCase` para métodos/variables, `UPPER_SNAKE_CASE` para constantes, `snake_case` para archivos y namespaces
- **PHP version:** 8.3+ — usar attributes, match expressions, named arguments, typed properties
- **Type hints:** Obligatorios en parámetros y return types; `mixed` si realmente es necesario
- **Null safety:** Usar `?Type` para nullable; `null coalescing` `??`; `nullsafe operator` `?->`
- **Immutability:** `readonly` en propiedades que no cambian tras inicialización
- **Access modifiers:** `private` por defecto, `protected` solo en clases base, `public` explícito cuando sea necesario
- **Error handling:** Excepciones tipadas; nunca `throw new Exception()`; siempre mensaje significativo
- **Traits:** Para comportamientos transversales; documentar bien; no abusar para evadir responsabilidades

## Laravel — Service Container (DI)

- **Service providers:** Registrar bindeos en `boot()` method
- **Constructor injection:** Siempre; el container resuelve dependencias automáticamente
- **Contracts:** Usar interfaces del namespace `Illuminate\Contracts`; nunca depender de clases concretas

```php
// ✅ Bien
class OrderService {
    public function __construct(private OrderRepository $orders) {}
}

// ❌ Mal
class OrderService {
    private $orders;
    public function __construct() {
        $this->orders = new OrderRepository(); // Acoplamiento
    }
}
```

## Eloquent ORM

- **Modelos:** Un modelo por tabla; nombrar singular (`User`, no `Users`)
- **Relationships:** Lazy loading evitado; usar `with()` en queries o `#[WithoutRelations]` en serialización
- **Attributes:** Type hints en propiedades; usar `$casts` para conversión automática
- **Fillable/guarded:** Siempre definir explícitamente; nunca confiar en valores por defecto
- **Scopes:** Métodos `scope*` para queries reutilizables
- **Mutators/accessors:** Usar attribute casting en lugar de getters/setters cuando sea simple

```php
class User extends Model {
    protected $fillable = ['name', 'email'];
    protected $casts = [
        'email_verified_at' => 'datetime',
        'is_admin' => 'boolean',
        'metadata' => AsCollection::class, // colecciones automáticas
    ];
    
    public function scopeActive(Builder $query) {
        return $query->where('active', true);
    }
}
```

## Migraciones y Schema

```bash
php artisan make:migration create_users_table --create=users
php artisan make:migration add_status_to_orders --table=orders
php artisan migrate
php artisan migrate:rollback
php artisan migrate:status
```

- Una migración = un cambio lógico
- Nunca modificar migraciones ya aplicadas en producción — crear rollback + nueva
- Índices: `->index()`, `->unique()`, `->fullText()`
- Foreign keys: con `->constrained()` automático o explícito
- Columnas nullable: `->nullable()` solo cuando sea necesario

## HTTP y Routing

- **Routes:** Agrupar por recurso; nombres explícitos
- **Controllers:** Action classes (un método `__invoke()`) para acciones únicas
- **Request validation:** Form Requests en `app/Http/Requests/`; nunca en controllers
- **Response:** `response()->json()`, resources para formateo, status codes explícitos
- **CORS:** Configurar en `config/cors.php`; whitelist de dominios

```php
// routes/api.php
Route::middleware('auth:sanctum')->group(function () {
    Route::apiResource('orders', OrderController::class);
    Route::post('orders/{order}/cancel', [OrderController::class, 'cancel'])->name('orders.cancel');
});

// app/Http/Requests/StoreOrderRequest.php
class StoreOrderRequest extends FormRequest {
    public function rules(): array {
        return [
            'user_id' => 'required|integer|exists:users,id',
            'items' => 'required|array|min:1',
        ];
    }
}

// app/Http/Controllers/OrderController.php
class OrderController extends Controller {
    public function store(StoreOrderRequest $request, OrderRepository $orders) {
        $order = $orders->create($request->validated());
        return response()->json(new OrderResource($order), 201);
    }
}
```

## Tests — PHPUnit + Pest

```bash
php artisan test                               # todos los tests
php artisan test --filter=CreateUser           # tests específicos
php artisan test --parallel                    # paralelización
php artisan test --coverage                    # con cobertura (≥ 80%)
```

### PHPUnit tradicional
```php
class UserTest extends TestCase {
    public function test_user_creation() {
        $user = User::factory()->create();
        $this->assertNotNull($user->id);
    }
}
```

### Pest (recomendado para nuevos proyectos)
```php
test('user creation', function () {
    $user = User::factory()->create();
    expect($user->id)->not->toBeNull();
});
```

- Fixtures: `DatabaseSeeder`, `seeders/`; usar factories para datos de test
- Mocking: `Http::fake()`, `Queue::fake()`, `Mail::fake()`
- Feature tests: requieren tabla completa; usar `RefreshDatabase`
- Unit tests: mockear dependencias; más rápidos

## Estructura de proyecto (DDD adaptado a Laravel)

```
app/
├── Domain/                     ← lógica de negocio puro (sin Laravel)
│   ├── Models/                 ← entidades de dominio (no Eloquent)
│   ├── ValueObjects/           ← Money, Email, etc.
│   ├── Repositories/           ← interfaces de persistencia
│   └── Events/                 ← domain events
├── Application/                ← use cases, DTOs, validadores
│   ├── Actions/                ← acciones atómicas (ej: CreateOrderAction)
│   ├── DTOs/                   ← Data Transfer Objects
│   └── Services/               ← coordinadores de lógica
├── Infrastructure/             ← implementaciones técnicas
│   ├── Repositories/           ← implementaciones Eloquent de repo interfaces
│   ├── Persistence/            ← models Eloquent
│   └── Providers/              ← bindings del service container
└── Http/
    ├── Controllers/            ← solo orquestación
    ├── Requests/               ← validación de entrada
    ├── Resources/              ← serialización (JsonResource)
    ├── Middleware/
    └── Exceptions/

database/
├── migrations/
├── seeders/
└── factories/

tests/
├── Unit/                       ← sin BD, mockear todo
├── Feature/                    ← con BD (RefreshDatabase)
├── Integration/                ← servicios externos, APIs
└── Pest.php                    ← configuración global
```

## Comandos Artisan

```bash
# Generación de code
php artisan make:model Order -mrc                    # model + migration + controller + resource
php artisan make:request StoreOrderRequest
php artisan make:test UserTest --unit               # unit test
php artisan make:test CreateOrderTest --feature     # feature test
php artisan make:middleware CheckAdmin

# Base de datos
php artisan migrate:fresh --seed                    # reset completo
php artisan db:seed --class=CategorySeeder

# Cache y config
php artisan config:cache                            # producción
php artisan route:cache
php artisan view:cache

# Queue (si aplica)
php artisan queue:work                              # procesar jobs
php artisan queue:failed                            # ver jobs fallidos
```

## Gestión de dependencias

```bash
composer require {package}                         # añadir
composer require {package}:^2.0                    # con versión
composer update {package}                          # actualizar específico
composer outdated                                  # obsoletos
composer audit                                     # vulnerabilidades
```

- Usar Composer para todo; nunca descargar ficheros manualmente
- `composer.lock` siempre commiteado
- Separar dev dependencies con `--dev`
- Revisar: licencia, última actualización, issues abiertos

## Deploy

```bash
# Producción
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan migrate --force
php -d memory_limit=256M artisan optimize:clear

# Docker
docker build -t {app} .
docker run -e APP_KEY=base64:... {app}
```

- **Variables de entorno:** `.env` local, `.env.example` en repo; nunca secrets en código
- **Keys:** Generar con `php artisan key:generate`
- **Modo mantenimiento:** `php artisan down` / `php artisan up`

## Hooks recomendados para proyectos Laravel

Añadir en `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "cd $(git rev-parse --show-toplevel) && ./vendor/bin/phpstan analyse --level=9 --error-format=json 2>&1 | head -20"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "php artisan test --no-coverage 2>&1 | tail -30"
    }]
  }
}
```

