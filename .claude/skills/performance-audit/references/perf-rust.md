---
name: Rust Performance Patterns
description: Anti-patrones async Tokio, ownership, allocation y DB en Rust
context_cost: low
---

# Rust Performance Anti-Patterns

## Async Anti-Patterns (Tokio)

### Blocking en async context (CRITICAL)
- **Detect**: `std::thread::sleep()`, `std::fs::read()`, sync I/O en `async fn`
- **Risk**: bloquea el Tokio runtime thread, starving a otras tasks
- **Fix**: `tokio::time::sleep()`, `tokio::fs::read()`, `tokio::task::spawn_blocking()`

### std::sync::Mutex en async (CRITICAL)
- **Detect**: `std::sync::Mutex` o `std::sync::RwLock` held across `.await`
- **Risk**: deadlock si el lock se mantiene mientras la task es suspendida
- **Fix**: `tokio::sync::Mutex`, `tokio::sync::RwLock`, o restructurar para no hold across await

### Missing .await (HIGH)
- **Detect**: Future creado pero no `.await`ed (compiler warning, pero puede pasar con turbofish)
- **Fix**: añadir `.await`, o `tokio::spawn()` si fire-and-forget

### Task spawn sin JoinHandle (HIGH)
- **Detect**: `tokio::spawn(async { ... })` sin recoger `JoinHandle`
- **Risk**: errores silenciosos, panics no capturados
- **Fix**: recoger handle y `.await` o usar `tokio::spawn` con error logging

### CPU-bound en async runtime (HIGH)
- **Detect**: computación pesada en `async fn` sin `spawn_blocking`
- **Fix**: `tokio::task::spawn_blocking(move || { ... })` o usar thread pool dedicado

## Ownership / Memory

### Unnecessary cloning (HIGH)
- **Detect**: `.clone()` frecuente, especialmente en loops o hot paths
- **Detect**: `String` clonado cuando `&str` bastaría
- **Fix**: lifetimes, `Cow<'_, str>`, `Arc` para shared ownership, borrowing

### Vec pre-allocation (HIGH)
- **Detect**: `Vec::new()` seguido de `push()` en loop con tamaño conocido
- **Fix**: `Vec::with_capacity(n)` — evita reallocations

### HashMap sizing (MEDIUM)
- **Detect**: `HashMap::new()` cuando el tamaño es predecible
- **Fix**: `HashMap::with_capacity(n)` o `HashMap::with_capacity_and_hasher()`

### String allocation patterns (MEDIUM)
- **Detect**: `format!()` en loop para construir strings
- **Fix**: `String::with_capacity()` + `push_str()`, o `write!()` macro

### Box vs inline (MEDIUM)
- **Detect**: `Box<T>` para tipos pequeños que no necesitan heap allocation
- **Fix**: usar el tipo directamente si cabe en stack y no necesita trait object

## Zero-Copy Patterns

### Unnecessary copies (HIGH)
- **Detect**: `to_vec()`, `to_string()`, `to_owned()` en hot paths
- **Fix**: usar slices (`&[u8]`), `&str`, `Bytes` (bytes crate), zero-copy parsing

### Serialization copies (MEDIUM)
- **Detect**: serialize → buffer → deserialize con copias intermedias
- **Fix**: `serde` con `#[serde(borrow)]`, `zerocopy` crate, `rkyv`

## Database (SQLx / Diesel)

### SQLx query compilation (MEDIUM)
- **Detect**: `sqlx::query()` con strings dinámicos (no macro `query!`)
- **Fix**: usar `sqlx::query!()` macro para compile-time verification

### Connection pool sizing (HIGH)
- **Detect**: `PgPoolOptions::new()` sin `.max_connections()`
- **Fix**: `.max_connections(N)` basado en `(num_cpus * 2) + 1`

### Missing batch operations (HIGH)
- **Detect**: loop con `query.execute()` individual por item
- **Fix**: batch insert con `UNNEST`, `INSERT INTO ... SELECT`, o transacción

## Patterns generales

### Excessive error context (LOW)
- **Detect**: `anyhow::Context` o `map_err` con allocation en hot path
- **Fix**: error types estáticos, lazy formatting

### Iterator vs indexing (MEDIUM)
- **Detect**: `for i in 0..v.len() { v[i] }` con bounds checking en cada acceso
- **Fix**: `for item in &v` o `v.iter()` — el compilador elimina bounds checks

### Trait object dispatch (MEDIUM)
- **Detect**: `dyn Trait` en hot path (virtual dispatch por cada llamada)
- **Fix**: generics (`impl Trait` o `<T: Trait>`) para static dispatch, enum dispatch

## Herramientas recomendadas

- **cargo flamegraph**: flame graphs con perf/dtrace
- **criterion**: benchmarks estadísticos con regression detection
- **tokio-console**: monitoring de async tasks y resources
- **dhat**: heap profiling (allocation tracking)
- **cargo-bloat**: análisis de binary size por función
- **miri**: detección de undefined behavior (memory safety)
