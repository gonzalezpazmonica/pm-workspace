---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
---

# Regla: Convenciones y Prácticas Rust
# ── Aplica a todos los proyectos Rust en este workspace ────────────────────────

## Verificación obligatoria en cada tarea

Antes de dar una tarea por terminada, ejecutar siempre en este orden:

```bash
cargo build --release                          # 1. ¿Compila sin warnings?
cargo fmt --check                              # 2. ¿Formato correcto (rustfmt)?
cargo clippy -- -D warnings                    # 3. ¿Pasa clippy sin warnings?
cargo test                                     # 4. ¿Pasan los tests?
```

Si hay tests de integración relevantes:
```bash
cargo test --test '*'
```

## Convenciones de código Rust

- **Naming:** `snake_case` (funciones, variables, módulos), `PascalCase` (tipos, traits, structs, enums), `UPPER_SNAKE_CASE` (constantes)
- **Ownership y borrowing:** Movimiento explícito; `&T` para lecturas, `&mut T` para mutación; minimizar `clone()`
- **Error handling:** `Result<T, E>` + operador `?`; errores específicos con `thiserror` o `anyhow`
- **Type system:** Aprovechar system de tipos para prevenir estados inválidos; `newtype` pattern para seguridad
- **Immutability por defecto:** `let` sin `mut` por defecto; `mut` solo cuando sea necesario
- **Modules:** Estructura en módulos significativos; `mod.rs` o `module.rs` para submodelos; nunca `mod` en línea en producción
- **Traits:** Prefiere composición sobre herencia; usar trait objects `dyn Trait` para polimorfismo en runtime
- **Lifetimes:** Explícitos cuando sea necesario; `'_` para inferencia cuando es obvio; `'static` para globals
- **Macros:** Usar `derive` macros; crear macros solo cuando sea imprescindible (documentar bien)
- **Unsafe:** Comentarios explícitos explicando por qué; minimizar bloque; nunca en APIs públicas sin wrapping seguro

## Async y Concurrencia

- **Runtime:** Tokio (preferido para aplicaciones I/O-heavy)
- **async/await:** Moderno y preferido sobre callbacks; `.await` siempre que sea aplicable
- **Channels:** `tokio::sync::mpsc` para comunicación entre tasks
- **Spawning:** `tokio::spawn()` para background tasks; `tokio::join!` o `tokio::select!` para sincronización
- **Timeouts:** `tokio::time::timeout()` obligatorio en operaciones I/O externas

## ORM y Persistencia

### sqlx (preferido)
- Macros `sqlx::query!` para compile-time type checking
- Migraciones: `sqlx migrate` CLI
- Soporte async nativo con Tokio
- Nunca modificar migraciones ya aplicadas

### Diesel
- Schemaless queries con DSL Rust
- Migraciones integradas: `diesel migration`
- Type-safe por compilación

### SeaORM
- ORM async-first
- Entity generator desde schema existente
- Migrations soportadas

## Web Frameworks

### Axum (preferido)
- Router composable y modular
- Extractors tipados para deserialization
- Middleware tower-based
- Handlers como funciones; no verboso

### Actix-web
- Actor-based concurrency
- Built-in testing utilities
- Middleware system robusto

### Rocket
- Macro-based routing y guard system
- Desarrollo rápido
- Type-safe por compilación

## Tests

- **Framework:** `cargo test` (integrado en Rust)
- **Unit tests:** `#[cfg(test)]` module dentro del mismo fichero
- **Integration tests:** Directorio `tests/` en raíz de crate
- **Pattern:** `#[test]` attribute; funciones que retornan `Result<(), E>`
- **Naming:** `test_function_name_scenario`
- **Fixtures:** Modelos de setup/teardown en `tests/common/mod.rs`
- **Mocking:** `mockall` para generar mocks; `proptest` para property-based testing
- **Coverage:** `cargo tarpaulin` ≥ 80%

```bash
cargo test                                     # todos los tests
cargo test -- --test-threads=1                # ejecutar secuencialmente
cargo test --lib                               # solo unit tests
cargo test --test '*'                          # solo integration tests
cargo tarpaulin --out Html --output-dir coverage
```

## Gestión de dependencias

```bash
cargo add {crate}                              # añadir dependencia
cargo add --dev {crate}                        # dev dependency
cargo outdated                                 # paquetes actualizables
cargo audit                                    # vulnerabilidades conocidas
cargo update                                   # actualizar Cargo.lock
```

- **Siempre** especificar versiones en `Cargo.toml`; usar semver ranges (`0.2`, `^1.0`)
- **Revisar** licencias y actividad del crate (última actualización, issues abiertos)
- **Minimizar** dependencias transitivas; usar `cargo tree` para ver árbol

## Estructura de workspace monorepo

```
{proyecto}/
├── Cargo.workspace.toml        ← metadata compartida
├── domain/                     ← dominio (crate sin dependencias externas)
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs
│       ├── entity/
│       └── error/
├── app/                        ← application / use cases
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs
│       └── services/
├── infra/                      ← infrastructure (BD, HTTP, cache)
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs
│       ├── db/
│       └── http/
├── api/                        ← web / REST API
│   ├── Cargo.toml
│   └── src/
│       ├── main.rs
│       └── handlers/
└── tests/                      ← integration tests
    ├── Cargo.toml
    └── src/
        └── integration_tests.rs
```

### Crate individual (non-workspace)

```
{crate}/
├── src/
│   ├── lib.rs                  ← public API
│   ├── domain/                 ← entidades, traits
│   ├── application/            ← use cases
│   ├── infrastructure/         ← BD, HTTP, clients
│   └── error.rs                ← tipos de error (thiserror)
├── tests/                      ← integration tests
│   └── integration_test.rs
├── examples/                   ← ejemplos de uso
│   └── basic.rs
├── Cargo.toml
└── Cargo.lock                  ← siempre commitear en binaries, no en libraries
```

## Deploy

```bash
cargo build --release                          # build optimizado
./target/release/{app}                         # ejecutar

# Docker
docker build -t {app} .
docker run {app}

# Cross-compile
cargo install cross
cross build --target x86_64-unknown-linux-gnu --release
```

## Hooks recomendados para proyectos Rust

Añadir en `.claude/settings.json` o `.claude/settings.local.json`:

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "cd $(git rev-parse --show-toplevel) && cargo clippy -- -D warnings 2>&1 | head -15"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "cargo test -- --test-threads=1 2>&1 | tail -30"
    }]
  }
}
```

