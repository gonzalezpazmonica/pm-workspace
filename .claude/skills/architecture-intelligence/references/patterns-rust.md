---
name: patterns-rust
description: Patrones de arquitectura para Rust
context_cost: low
---

# Patrones — Rust

## 1. Hexagonal Architecture (⭐ Recomendado)

Rust es idiomáticamente hexagonal: traits = ports, structs = adapters, ownership = dependency direction.

**Folder Structure**:
```
src/
├── domain/
│   ├── mod.rs            → Domain models, business rules
│   ├── entities.rs       → Core entities
│   └── errors.rs         → Domain errors
├── ports/
│   ├── mod.rs            → Trait definitions (interfaces)
│   ├── inbound.rs        → Driving ports (API contracts)
│   └── outbound.rs       → Driven ports (DB, external)
├── adapters/
│   ├── http/             → Actix-web/Axum handlers
│   ├── persistence/      → Diesel/SQLx implementations
│   └── external/         → External API clients
├── application/
│   ├── mod.rs            → Use cases
│   └── services.rs       → Application services
├── lib.rs
└── main.rs
```

**Detection Markers**:
- `pub trait` definitions como ports
- `impl Trait for Struct` como adapters
- `mod` organization por concern
- Constructor injection: `fn new(repo: impl UserRepository) -> Self`
- `Result<T, E>` para error handling explícito

## 2. Clean Architecture

**Detection Markers**:
- Workspace con múltiples crates: `domain`, `application`, `infrastructure`, `web`
- `Cargo.toml` workspace con members
- Domain crate sin dependencias externas
- Use cases como funciones o structs con `execute()` method

## 3. Actor Model (Actix)

**Detection Markers**:
- `impl Actor for MyActor`
- `impl Handler<Message> for MyActor`
- `Addr<MyActor>` para comunicación
- Actix-web: `HttpServer::new`, `web::resource`

## 4. Data-Oriented Design

**Detection Markers**:
- Structs of Arrays (SoA) en lugar de Array of Structs (AoS)
- `Vec<ComponentA>`, `Vec<ComponentB>` en paralelo
- ECS (Entity Component System): bevy, specs, legion
- Iteradores y traits para procesamiento

## Rust-Specific Patterns
- **Zero-cost abstractions**: Traits compilados a dispatch estático
- **Ownership model**: Fuerza dirección clara de dependencias
- **Error handling**: `thiserror` para library errors, `anyhow` para application errors
- **Builder pattern**: `MyStruct::builder().field(x).build()`
- **Newtype pattern**: `struct UserId(Uuid)` para type safety

## Web Frameworks y Detección
- **Axum**: `Router::new().route()`, extractors, tower middleware
- **Actix-web**: `HttpServer`, `App::new().service()`, `#[get]` macros
- **Rocket**: `#[launch]`, `#[get]`, `#[post]` macros

## Tools de Enforcement
- **cargo clippy**: Lint con 500+ reglas
- **cargo deny**: Auditoría de dependencias + licencias
- **cargo audit**: Vulnerabilidades en dependencias
- **cargo test**: Tests integrados con `#[cfg(test)]`

## Anti-patterns comunes
- `.unwrap()` en producción (en lugar de error handling)
- `.clone()` excesivo (evitable con referencias)
- Lifetimes innecesariamente complejos
- Módulos monolíticos (>500 líneas sin sub-módulos)
