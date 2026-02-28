---
name: patterns-go
description: Patrones de arquitectura para Go (Golang)
context_cost: low
---

# Patrones — Go

## 1. Clean Architecture (⭐ Recomendado)

**Folder Structure**:
```
project/
├── cmd/
│   └── server/
│       └── main.go        → Entry point
├── internal/
│   ├── domain/            → Business entities, interfaces
│   ├── usecase/           → Application logic
│   ├── handler/           → HTTP/gRPC handlers (presentation)
│   └── repository/        → Data access implementations
├── pkg/                   → Exportable packages
├── config/                → Configuration
├── migrations/            → Database migrations
└── go.mod
```

**Detection Markers**:
- `cmd/` para entry points (convención Go estándar)
- `internal/` para código no exportable
- `pkg/` para código exportable
- Interfaces en `domain/`, implementaciones en `repository/`
- Constructor functions: `NewUserService(repo UserRepository)`

## 2. Hexagonal

**Folder Structure**:
```
internal/
├── core/
│   ├── domain/           → Business models
│   ├── ports/            → Interface definitions
│   └── services/         → Business logic
├── adapters/
│   ├── handlers/         → HTTP, gRPC, CLI
│   └── repositories/     → Postgres, Redis, etc.
└── server/               → Server setup, routing
```

**Detection Markers**:
- `ports/` con interfaces Go (implícitas)
- `adapters/` con implementaciones
- Core sin imports de infrastructure
- Constructor injection via interfaces

## 3. DDD (Go idiomático)

**Detection Markers**:
- Packages por bounded context: `order/`, `user/`, `inventory/`
- Aggregate root pattern con métodos en structs
- Value objects como structs inmutables
- Repository interfaces en domain package

## 4. Standard Layout (golang-standards)

**Detection Markers**:
- Sigue `github.com/golang-standards/project-layout`
- `cmd/`, `internal/`, `pkg/`, `api/`, `web/`
- `Makefile` con targets estándar (build, test, lint)

## 5. Microservices (go-kit / go-zero)

**Detection Markers**:
- go-kit: `endpoint.Endpoint`, `transport.Server`, `service` interfaces
- go-zero: `.api` files, `handler/`, `logic/`, `svc/`
- Múltiples binarios en `cmd/`
- gRPC `.proto` files

## Go-Specific Patterns
- **Interfaces implícitas**: No se declara "implements", se cumple por duck typing
- **Table-driven tests**: `[]struct{ name string, input, expected }` pattern
- **Functional options**: `WithTimeout(5*time.Second)` constructor pattern
- **Error wrapping**: `fmt.Errorf("doing X: %w", err)` chain

## Tools de Enforcement
- **go vet**: Análisis estático builtin
- **golangci-lint**: Meta-linter con 50+ linters
- **depguard**: Restricción de imports por package
- **go-cleanarch**: Verificación de Clean Architecture
- **architecture-lint**: Custom rules para Go

## Anti-patterns comunes
- Package `utils/` o `helpers/` (falta cohesión)
- Interfaces con demasiados métodos (Go prefiere interfaces pequeñas)
- Goroutine leaks (falta context cancellation)
- Deep package nesting (Go prefiere flat packages)
