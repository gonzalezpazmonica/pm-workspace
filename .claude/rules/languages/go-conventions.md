---
paths:
  - "**/*.go"
  - "**/go.mod"
---

# Regla: Convenciones y Prácticas Go
# ── Aplica a todos los proyectos Go en este workspace ──────────────────────────

## Verificación obligatoria en cada tarea

Antes de dar una tarea por terminada, ejecutar siempre en este orden:

```bash
go build ./...                                 # 1. ¿Compila sin warnings?
go vet ./...                                   # 2. ¿Pasa análisis estático?
golangci-lint run ./...                        # 3. ¿Sin problemas de linting?
go test -v ./...                               # 4. ¿Pasan los tests?
```

Si hay tests de integración relevantes:
```bash
go test -v -tags=integration ./...
```

## Convenciones de código Go

- **Naming:** `PascalCase` para exported (públicos), `camelCase` para unexported (privados), `UPPER_SNAKE_CASE` para constantes
- **Error handling:** Siempre verificar `err != nil`; nunca ignorar errores con `_`
- **Interfaces:** Pequeñas (1-3 métodos), implícitas; satisfacción de interfaz automática sin declaración
- **Concurrencia:** `goroutines` + `channels` + `context.Context` para cancelación y timeouts
- **Paquetes:** Significado en el nombre; no usar nombres genéricos como `util`, `common`; importar por ruta completa
- **Documentación:** Comentarios en funciones/tipos exportados; imperativo en `//` (not `// Returns`, but `// NewUser creates...`)
- **Métodos receptores:** Usar pointer receiver (`(u *User)`) consistentemente si hay mutación
- **Defer:** Usar para cleanup (close, unlock); siempre antes del error check

## ORM y Persistencia

### sqlc (preferido)
- Type-safe SQL queries sin runtime overhead
- Workflow: `schema.sql` → `sqlc.yaml` → generated Go code
- Migraciones: Flyway o migrate CLI
- Nunca modificar migraciones ya aplicadas

### GORM (si sqlc no aplica)
- Hooks de ciclo de vida: `BeforeSave`, `AfterFind`
- `AsNoTracking()` equivalente para consultas de solo lectura
- Índices explícitos: `type: index` en tags
- Evitar N+1 con `Preload()`

## Frameworks Web

### net/http (estándar)
- Handlers tipados
- Middleware con function wrapping
- `http.HandleFunc` para rutas simples

### Chi (ligero, recomendado)
- Router modular con `r := chi.NewRouter()`
- Middleware chain-style
- Subrouters para namespacing (`r.Route("/api/v1", func(r chi.Router) { ... })`)

### Gin (performance, full-stack)
- Engine centralizado
- Middleware global y por ruta
- Validación con `binding` tags
- CORS configurado explícitamente

## Tests

- **Framework:** `testing` (estándar) + `testify/assert` para aserciones limpias
- **Pattern table-driven:** Datos en slice de structs, loop iterando casos
- **Naming:** `TestFunctionName_Scenario` (ej: `TestUserCreate_ValidEmail`)
- **Helpers:** Funciones `t.Helper()` para evitar ruido en stack traces
- **Mocking:** `mockgen` para generar mocks desde interfaces
- **Coverage:** `go test -cover ./...` ≥ 80%

```bash
go test -v ./...                               # todos los tests
go test -cover ./...                           # con cobertura
go test -run TestFunctionName                  # tests específicos
go test -short ./...                           # solo tests rápidos (tag "short")
```

## Gestión de dependencias

```bash
go mod tidy                                    # limpiar dependencias sin usar
go mod download                                # descargar dependencias
go get -u ./...                                # actualizar todo
go list -u -m all                              # ver paquetes actualizables
go mod verify                                  # verificar integridad
```

- **Siempre** usar `go.mod` para versionado de dependencias
- **Nunca** commitear `vendor/` a menos que sea monorepo dedicado
- Mantener `go.mod` y `go.sum` en sync (nunca editar `go.sum` manualmente)

## Estructura de proyecto

```
{proyecto}/
├── cmd/
│   ├── {app}/                  ← punto de entrada principal
│   └── {tool}/                 ← herramientas CLI secundarias
├── internal/
│   ├── domain/                 ← entidades, value objects, interfaces de repo
│   ├── application/            ← use cases, services, DTOs
│   ├── infrastructure/         ← DB repos, HTTP clients, config
│   ├── adapter/web/            ← handlers HTTP, middleware, schemas request/response
│   └── adapter/messaging/      ← Kafka/RabbitMQ consumers
├── pkg/                        ← código reutilizable por otros módulos (public API)
│   └── {packagename}/
├── migrations/                 ← SQL schema + migraciones (Flyway naming)
│   ├── V001__initial.sql
│   └── V002__add_users.sql
├── schema.sql                  ← schema actual (para sqlc)
├── sqlc.yaml                   ← config de sqlc
├── go.mod
├── go.sum
└── Makefile                    ← build targets: make build, make test, make lint
```

## Deploy

```bash
go build -o bin/{app} ./cmd/{app}              # build binario
./bin/{app}                                    # ejecutar

# Docker
docker build -t {app} .
docker run {app}

# Cross-compile
GOOS=linux GOARCH=amd64 go build -o bin/{app}-linux ./cmd/{app}
```

## Hooks recomendados para proyectos Go

Añadir en `.claude/settings.json` o `.claude/settings.local.json`:

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "cd $(git rev-parse --show-toplevel) && go vet ./... 2>&1 | head -10"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "go test -v ./... 2>&1 | tail -30"
    }]
  }
}
```

