---
name: Java Performance Patterns
description: Anti-patrones async, JPA N+1, GC pressure y streams en Java
context_cost: low
---

# Java Performance Anti-Patterns

## Async Anti-Patterns

### CompletableFuture.get() blocking (CRITICAL)
- **Detect**: `.get()` sin timeout, `.join()` en thread principal
- **Risk**: bloquea indefinidamente si el future no completa
- **Fix**: `.get(timeout, TimeUnit.SECONDS)`, `.thenApply()`, `.thenCompose()`

### Blocking en Reactive Streams (CRITICAL)
- **Detect**: `.block()`, `.blockFirst()`, `.blockLast()` en WebFlux controllers
- **Detect**: `Thread.sleep()`, JDBC sync en reactive pipeline
- **Fix**: `subscribeOn(Schedulers.boundedElastic())` para I/O blocking

### Thread pool exhaustion (HIGH)
- **Detect**: `Executors.newFixedThreadPool()` con tamaño fijo sin monitoring
- **Detect**: tasks que bloquean threads indefinidamente
- **Fix**: `Executors.newVirtualThreadPerTaskExecutor()` (Java 21+), timeout, monitoring

### Synchronized en hot path (HIGH)
- **Detect**: `synchronized` block en método llamado frecuentemente
- **Fix**: `ConcurrentHashMap`, `AtomicReference`, lock-free patterns, `StampedLock`

## JPA / Hibernate

### N+1 Queries (CRITICAL)
- **Detect**: `FetchType.LAZY` (default) con acceso en loop
- **Detect**: `for (Entity e : list) { e.getRelation().getName(); }`
- **Fix**: `@EntityGraph`, `JOIN FETCH` en JPQL, `@BatchSize(size=25)`

### Hibernate query plan cache (HIGH)
- **Detect**: queries dinámicas con `IN` clause de tamaño variable
- **Risk**: cada variación genera un nuevo plan cacheado → memory leak
- **Fix**: `hibernate.query.in_clause_parameter_padding=true`, query parameterizada

### Missing pagination (HIGH)
- **Detect**: `findAll()` sin `Pageable`, `SELECT *` sin LIMIT
- **Fix**: `Pageable`, `LIMIT/OFFSET`, cursor-based pagination

### Eager loading excesivo (MEDIUM)
- **Detect**: `FetchType.EAGER` en entidades con muchas relaciones
- **Fix**: cambiar a `LAZY` + `@EntityGraph` selectivo

## Memory / GC

### Autoboxing en loops (HIGH)
- **Detect**: `int` ↔ `Integer` conversiones dentro de loop (boxing/unboxing)
- **Detect**: `Map<Integer, Integer>` con primitives
- **Fix**: usar primitives, `IntStream`, `int[]`, o Eclipse Collections

### String concat en loops (HIGH)
- **Detect**: `string += "..."` o `String.format()` dentro de for
- **Fix**: `StringBuilder`, `StringJoiner`, o `String.join()`

### Stream vs for-loop en hot paths (MEDIUM)
- **Detect**: `stream().filter().map().collect()` en código llamado >10K/s
- **Risk**: overhead de boxing, lambda allocation, iterator creation
- **Fix**: for-loop clásico en hot paths, streams en código no crítico

### GC Pressure (HIGH)
- **Detect**: alta tasa de object allocation en hot loops
- **Detect**: objetos de corta vida en generación joven
- **Fix**: object pooling, pre-allocation, `ByteBuffer.allocateDirect()`

## Patterns generales

### Exception for flow control (HIGH)
- **Detect**: try/catch usado para controlar flujo normal (NumberFormatException, IndexOutOfBounds)
- **Fix**: validación previa (null checks, bounds checks, `Optional`)

### Reflection en hot path (HIGH)
- **Detect**: `Class.forName()`, `Method.invoke()` en código frecuente
- **Fix**: cache de Method handles, `MethodHandle`, code generation

## Herramientas recomendadas

- **JMH (Java Microbenchmark Harness)**: benchmarks precisos con warmup
- **async-profiler**: CPU + allocation profiler, flame graphs
- **VisualVM**: monitoring en tiempo real, heap dumps
- **JFR (Java Flight Recorder)**: recording de bajo overhead
- **Eclipse MAT**: análisis de heap dumps
- **Micrometer**: métricas de aplicación
