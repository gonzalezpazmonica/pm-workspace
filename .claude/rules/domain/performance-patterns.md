---
name: Performance Anti-Patterns
description: Umbrales de rendimiento cross-language, patrones N+1, blocking async y memory allocation
globs: ["**/*.cs", "**/*.ts", "**/*.tsx", "**/*.js", "**/*.py", "**/*.java", "**/*.go", "**/*.rs"]
context_cost: low
---

# Performance Anti-Patterns — Cross-Language

## Umbrales de complejidad

| Métrica | OK | MEDIUM | HIGH | CRITICAL |
|---------|-----|--------|------|----------|
| Cyclomatic complexity | ≤10 | 11-15 | 16-20 | ≥21 |
| Cognitive complexity | ≤15 | 16-20 | 21-25 | ≥26 |
| Method length (LOC) | ≤30 | 31-50 | 51-80 | ≥81 |
| Nesting depth | ≤3 | 4 | 5 | ≥6 |
| Fan-out (deps called) | ≤7 | 8-10 | 11-15 | ≥16 |
| Parameters count | ≤4 | 5-6 | 7-8 | ≥9 |

## N+1 Query Patterns

### SQL / ORM
- **Detect**: loop que ejecuta query por iteración (`SELECT` dentro de `foreach`/`for`/`map`)
- **Detect**: lazy loading en colección iterada (EF `.Navigation`, JPA `FetchType.LAZY`, Django FK access)
- **Fix**: eager loading (`Include`/`select_related`/`JOIN FETCH`), batch queries, DataLoader

### GraphQL
- **Detect**: resolver que hace query individual por item en lista
- **Fix**: DataLoader pattern, batch resolver

### Severidad
- En hot path (controller/handler): CRITICAL
- En background job / batch: HIGH
- En setup / initialization: MEDIUM

## Blocking in Async Context

| Lenguaje | Anti-pattern | Fix |
|----------|-------------|-----|
| C# | `Task.Result`, `.Wait()`, `Task.GetAwaiter().GetResult()` | `await` |
| C# | `async void` (excepto event handlers) | `async Task` |
| TypeScript | `await` en loop secuencial | `Promise.all()` / `Promise.allSettled()` |
| TypeScript | floating promise (no `await`, no `.catch()`) | `await` o `.catch()` |
| Python | `time.sleep()` en `async def` | `await asyncio.sleep()` |
| Python | CPU-bound en event loop | `run_in_executor()` |
| Java | `CompletableFuture.get()` sin timeout | `.get(timeout, unit)` o `.thenApply()` |
| Java | blocking I/O en reactive stream | `subscribeOn(Schedulers.boundedElastic())` |
| Go | goroutine sin cancelación context | `select { case <-ctx.Done(): }` |
| Go | channel sin close ni timeout | `defer close(ch)` + `select` con timeout |
| Rust | `std::sync::Mutex` en async | `tokio::sync::Mutex` |
| Rust | blocking en async sin `spawn_blocking` | `tokio::task::spawn_blocking()` |

## Memory Allocation Patterns

### String concatenation en loops
- **Detect**: `+=` con string dentro de loop
- **Fix por lenguaje**: StringBuilder (C#/Java), `join()` (Python/JS), `strings.Builder` (Go), `String::with_capacity` (Rust)
- **Severidad**: HIGH si >100 iteraciones estimadas, MEDIUM si <100

### Object allocation en hot loops
- **Detect**: `new` / constructor dentro de loop en hot path
- **Fix**: pre-allocate, object pooling, move allocation fuera del loop
- **Severidad**: HIGH en hot paths, MEDIUM en otros

### Collection sizing
- **Detect**: `List`/`Vec`/`slice`/`map` sin capacidad inicial cuando el tamaño es conocido
- **Fix**: pre-size con capacidad estimada
- **Severidad**: LOW (excepto si en hot path → MEDIUM)

## Estimated Big-O Detection

Detectar loops anidados para estimar complejidad algorítmica:
- 1 loop → O(n)
- 2 loops anidados sobre misma colección → O(n²)
- 3 loops anidados → O(n³) → CRITICAL si n puede ser >100
- Loop + búsqueda lineal interna → O(n²) → sugerir hash lookup O(n)
- Sort dentro de loop → O(n² log n) → mover sort fuera

## Matriz: Tipo × Severidad

| Tipo de issue | En hot path | En lógica normal | En setup/init |
|---------------|-------------|-------------------|---------------|
| N+1 query | CRITICAL | HIGH | MEDIUM |
| Blocking async | CRITICAL | HIGH | MEDIUM |
| O(n²) con n>100 | CRITICAL | HIGH | MEDIUM |
| String concat loop | HIGH | MEDIUM | LOW |
| Object alloc loop | HIGH | MEDIUM | LOW |
| Missing pre-alloc | MEDIUM | LOW | LOW |
| Deep nesting (≥6) | HIGH | HIGH | MEDIUM |
| High fan-out (≥16) | HIGH | MEDIUM | MEDIUM |

## Integración con /debt-track

Hallazgos con severidad ≥HIGH se registran automáticamente:
- **Categoría**: `performance`
- **ID referencia**: `PA-{NNN}`
- **Estimación esfuerzo**: CRITICAL ~8h, HIGH ~4h, MEDIUM ~2h, LOW ~1h
- **Prioridad**: mapea directamente de severidad

## Hot Path Identification

Un path se considera "hot" si:
1. Es llamado desde un controller/handler HTTP (request path)
2. Es parte de un pipeline de procesamiento en tiempo real
3. Es invocado en un loop de procesamiento batch con alto volumen
4. Es un event handler o callback de alta frecuencia

Los issues en hot paths elevan su severidad +1 nivel automáticamente.
